"""Verify the ACE and ACM heartbeat startup routes and local gain contract."""

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "addons/gait"
ROOT_CONFIG = (ADDON / "config.cpp").read_text()
ACM_CONFIG = (ADDON / "acm_heartbeat/config.cpp").read_text()
STARTUP = (ADDON / "functions/fn_redirectAceStartup.sqf").read_text()
PLAYBACK = (ADDON / "functions/fn_aceHeartbeatVolume.sqf").read_text()
ACE_PATH = r"\z\ace\addons\medical_feedback"
PLAYBACK_PATH = r"\gait\functions\fn_aceHeartbeatVolume.sqf"


class HeartbeatAudioContract(unittest.TestCase):
    def test_ace_recompiles_only_heartbeat_playback_in_both_phases(self):
        self.assertRegex(ROOT_CONFIG, r'requiredAddons\[\].*"ace_medical_feedback"')
        for phase in ("Start", "Init"):
            with self.subTest(phase=phase):
                marker = f"class Extended_Pre{phase}_EventHandlers"
                event = ROOT_CONFIG[ROOT_CONFIG.index(marker):]
                self.assertRegex(event, r"(?s)^.*?class ace_medical_feedback\s*\{")
                self.assertIn(
                    f"['{ACE_PATH}\\XEH_pre{phase}.sqf', "
                    f"'{ACE_PATH}\\functions\\fnc_effectHeartBeat.sqf', '{PLAYBACK_PATH}'] "
                    r"call compileScript ['\gait\functions\fn_redirectAceStartup.sqf']",
                    event,
                )
        self.assertIn("preprocessFileLineNumbers _startupPath", STARTUP)
        self.assertIn("(_source select [0, _start]) + _replacementPath + _remainder", STARTUP)
        self.assertIn("call compile _redirected;", STARTUP)
        self.assertEqual(STARTUP.count("call compileScript [_startupPath];"), 2)
        self.assertNotIn("uiNamespace", STARTUP)

    def test_acm_optional_layer_registers_its_effective_function(self):
        self.assertIn('requiredAddons[] = {"gait", "ACM_core"};', ACM_CONFIG)
        self.assertIn("skipWhenMissingDependencies = 1;", ACM_CONFIG)
        self.assertRegex(
            ACM_CONFIG, r"(?s)class CfgFunctions.*?class overwrite_medical_feedback"
            r'.*?tag = "ace_medical_feedback".*?class ace_medical_feedback.*?class effectHeartBeat'
        )
        self.assertIn(f'file = "{PLAYBACK_PATH}";', ACM_CONFIG)
        self.assertEqual(ACM_CONFIG.count("file ="), 1)

    def test_local_gain_keeps_ace_and_acm_cadence(self):
        self.assertIn("if (!hasInterface) exitWith {};", PLAYBACK)
        self.assertIn('["GAIT_ss_aceHeartbeatVolume", 10]', PLAYBACK)
        self.assertIn("if (isGameFocused && {_percentage > 0})", PLAYBACK)
        self.assertIn("if (_percentage isEqualTo 100) then", PLAYBACK)
        self.assertIn("playSound _sound;", PLAYBACK)
        self.assertIn('[_sound, _gain * (_percentage / 100)]', PLAYBACK)
        self.assertIn('[_path, _gain * (_percentage / 100), _pitch, true]', PLAYBACK)
        self.assertIn("[160, 140] select _acm", PLAYBACK)
        self.assertIn("_heartRate >= 60", PLAYBACK)
        self.assertIn("[140, 190, _heartRate, 0.1, 1, true]", PLAYBACK)
        self.assertIn("[60, 45, _heartRate, 0.1, 1, true]", PLAYBACK)
        self.assertIn("[ace_medical_feedback_fnc_effectHeartBeat, [], 60 / _heartRate] call CBA_fnc_waitAndExecute;", PLAYBACK)
        sound_names = set(re.findall(r'"(ACE_[^"]+)"', PLAYBACK))
        self.assertEqual(sound_names, {"ACE_heartbeat_fast_1", "ACE_heartbeat_slow_1", "ACE_heartbeat_slow_2"})
        self.assertNotRegex(PLAYBACK, r"\bfadeSound\b|\bremoteExec(?:Call)?\b")


if __name__ == "__main__":
    unittest.main()
