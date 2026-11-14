"""Check the narrow startup patch against ACE and ACM playback layouts."""

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "addons/gait/functions/fn_aceHeartbeatVolume.sqf").read_text()
CONFIG = (ROOT / "addons/gait/config.cpp").read_text()

# Playback shapes from ACE 3.21.2 and ACM Extended a888b45, after macro
# expansion. The heartbeat schedule is outside the replaced statements.
ACE_SOURCE = """
if (isGameFocused) then { playSound "ACE_heartbeat_fast_1"; };
[ace_medical_feedback_fnc_effectHeartBeat, [], _waitTime] call CBA_fnc_waitAndExecute;
if (isGameFocused) then { playSound (selectRandom ["ACE_heartbeat_slow_1", "ACE_heartbeat_slow_2"]); };
"""
ACM_SOURCE = """
if (isGameFocused) then {
    playSoundUI ["ACE_heartbeat_fast_1", (linearConversion [140, 190, _heartRate, 0.1, 1, true])];
};
[ace_medical_feedback_fnc_effectHeartBeat, [], _waitTime] call CBA_fnc_waitAndExecute;
if (isGameFocused) then {
    playSoundUI [(selectRandom ["ACE_heartbeat_slow_1", "ACE_heartbeat_slow_2"]),
        (linearConversion [60, 45, _heartRate, 0.1, 1, true])];
};
"""


def patterns(acm=False):
    literals = dict(re.findall(r"private _(\w+)\s*=\s*'(.*)';", SOURCE))
    literals.update({name: value.replace("''", "'") for name, value in literals.items()})
    command = r"playSoundUI\s*\[\s*" if acm else r"playSound\s+"
    tail = literals["uiGain"] if acm else r"\s*;/g"
    return [
        re.compile((literals["focus"] + command + literals[variant] + tail).removesuffix("/g"))
        for variant in ("fastSound", "slowSound")
    ]


def patch_playback(source, acm=False):
    playback = patterns(acm)
    if any(len(list(pattern.finditer(source))) != 1 for pattern in playback):
        return source
    args = r"\2, \3" if acm else r"\2"
    for pattern in playback:
        source = pattern.sub(
            r'\1[' + args + '] call (uiNamespace getVariable "GAIT_fnc_playAceHeartbeat");',
            source,
        )
    return source


class HeartbeatAudioContract(unittest.TestCase):
    def test_ace_prestart_is_forwarded_after_cache_seed(self):
        self.assertRegex(CONFIG, r'requiredAddons\[\].*"ace_medical_feedback"')
        self.assertRegex(CONFIG, r'(?s)Extended_PreStart_EventHandlers\s*\{.*class ace_medical_feedback')
        self.assertIn(
            r"'\gait\functions\fn_aceHeartbeatVolume.sqf']; call compileScript "
            r"['\z\ace\addons\medical_feedback\XEH_preStart.sqf']",
            CONFIG,
        )
        self.assertIn('private _aceFunction = "ace_medical_feedback_fnc_effectHeartBeat"', SOURCE)
        self.assertIn('if (!isNil {uiNamespace getVariable _aceFunction}) exitWith {};', SOURCE)
        self.assertIn('uiNamespace setVariable [_aceFunction, compileFinal _source]', SOURCE)

    def test_supported_playback_keeps_ace_cadence_and_acm_gain(self):
        for original, acm in ((ACE_SOURCE, False), (ACM_SOURCE, True)):
            with self.subTest(acm=acm):
                patched = patch_playback(original, acm)
                self.assertEqual(patched.count("GAIT_fnc_playAceHeartbeat"), 2)
                self.assertIn("call CBA_fnc_waitAndExecute", patched)
                self.assertIn('selectRandom ["ACE_heartbeat_slow_1", "ACE_heartbeat_slow_2"]', patched)
                if acm:
                    self.assertIn("linearConversion [140, 190, _heartRate, 0.1, 1, true]", patched)
                    self.assertIn("linearConversion [60, 45, _heartRate, 0.1, 1, true]", patched)

    def test_missing_duplicate_or_unrelated_playback_is_unchanged(self):
        for original in (
            ACE_SOURCE.replace("ACE_heartbeat_fast_1", "different_sample"),
            ACE_SOURCE + ACE_SOURCE,
            'if (isGameFocused) then { playSound "ACE_fracture_1"; };',
        ):
            self.assertEqual(patch_playback(original), original)
        self.assertNotRegex(SOURCE, r"\bfadeSound\b|\bremoteExec(?:Call)?\b")
        self.assertIn('["GAIT_ss_aceHeartbeatVolume", 10]', SOURCE)
        self.assertIn('if (_percentage <= 0) exitWith {};', SOURCE)
        self.assertIn('if (_percentage >= 100) exitWith {playSound _soundClass;};', SOURCE)


if __name__ == "__main__":
    unittest.main()
