"""Guard the public options and prevent retired settings from affecting gameplay."""

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FUNCTIONS = ROOT / "addons/gait/functions"
REGISTRY = FUNCTIONS / "fn_registerSettings.sqf"
REGISTRATION = re.compile(
    r'\["(GAIT_ss_\w+)", "[^"]+", "[^"]+",\s*'
    r'_category(Movement|Player),\s*(\[[^\]]+\]|true|false)(?:, (true|false))?'
    r'\]\s*call _add(Checkbox|Slider);'
)
EXPECTED = {
    "GAIT_ss_enabled": ("Movement", "Checkbox", True, True),
    "GAIT_ss_sprintWalkTaperDuration": ("Movement", "Slider", True, [2.3, 2.9, 2.7, 1]),
    "GAIT_ss_masterTripFrequency": ("Movement", "Slider", True, [0, 1.5, 1, 2]),
    "GAIT_ss_vegetationDragMax": ("Movement", "Slider", True, [0, 0.25, 0.18, 2]),
    "GAIT_ss_aceHeartbeatVolume": ("Player", "Slider", False, [0, 100, 10, 0]),
    "GAIT_ss_debugHudEnabled": ("Player", "Checkbox", False, False),
}


class SettingsAudit(unittest.TestCase):
    def test_only_supported_settings_are_registered(self):
        source = REGISTRY.read_text()
        observed = {}
        for name, category, values, scope, kind in REGISTRATION.findall(source):
            self.assertNotIn(name, observed)
            observed[name] = (category, kind, scope != "false", json.loads(values))
        self.assertEqual(observed, EXPECTED)
        self.assertCountEqual(re.findall(r'"(GAIT_ss_\w+)"', source), EXPECTED.keys())

    def test_only_supported_settings_are_read_at_runtime(self):
        runtime = "\n".join(path.read_text() for path in FUNCTIONS.glob("*.sqf") if path != REGISTRY)
        self.assertEqual(set(re.findall(r'"(GAIT_ss_\w+)"', runtime)), set(EXPECTED))
        self.assertNotIn("GAIT_fnc_applyPreset", runtime)

    def test_numeric_values_remain_bounded_with_older_profiles(self):
        for name, (_, kind, _, values) in EXPECTED.items():
            if kind != "Slider":
                continue
            low, high, default, _ = values
            pattern = rf'\(missionNamespace getVariable \["{name}", {default}\]\) max {low} min {high}\b'
            self.assertTrue(any(re.search(pattern, path.read_text()) for path in FUNCTIONS.glob("*.sqf")), name)

    def test_cleanup_cannot_be_disabled(self):
        main = (FUNCTIONS / "fn_initSprintSystem.sqf").read_text()
        helper = (FUNCTIONS / "fn_traversalHelpers.sqf").read_text()
        self.assertIn('["player_object_changed"] call GAIT_fnc_resetEffects;', main)
        self.assertIn('if (_foreignCamera) exitWith {true};', helper)
        self.assertIn('if (player getVariable ["ACE_isUnconscious", false]) exitWith {true};', helper)
        self.assertNotIn('GAIT_fnc_isSuspendedContext = {', main)
        reset = (FUNCTIONS / "fn_resetEffects.sqf").read_text()
        module = (FUNCTIONS / "fn_moduleResetEffects.sqf").read_text()
        self.assertIn("GAIT_fnc_clearLocomotionInputHistory", reset)
        self.assertIn("CBA_fnc_targetEvent", module)
        self.assertNotIn("remoteExecCall", module)


if __name__ == "__main__":
    unittest.main()
