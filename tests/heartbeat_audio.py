#!/usr/bin/env python3
"""Guard the narrow ACE heartbeat config patch against source-contract drift.

The ACE reference is addons/medical_feedback/CfgSounds.hpp, reviewed at
https://github.com/acemod/ACE3/blob/a8332b182e2764947b8b2e551386452e712eff11/addons/medical_feedback/CfgSounds.hpp
These checks verify gain, sample/pitch preservation and optional load order.
They cannot verify perceived loudness inside Arma.
"""
from pathlib import Path
import math
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "addons/heartbeat/config.cpp"
VARIANTS = ("fast_1", "fast_2", "fast_3", "norm_1", "norm_2", "slow_1", "slow_2")


class HeartbeatAudioContract(unittest.TestCase):
    def setUp(self):
        self.source = re.sub(r"//[^\n]*|/\*.*?\*/", "", SOURCE.read_text(), flags=re.S)

    def test_only_heartbeat_classes_are_patched(self):
        classes = re.findall(r"\bclass\s+(\w+)", self.source)
        self.assertEqual(classes, ["CfgPatches", "gait_heartbeat", "CfgSounds"] +
                         ["ACE_heartbeat_" + variant for variant in VARIANTS])
        self.assertEqual(list((ROOT / "addons/heartbeat").rglob("*.sqf")), [])

    def test_all_variants_keep_samples_and_pitch_at_ten_percent_original_gain(self):
        entries = re.findall(r'class (ACE_heartbeat_\w+)\s*\{\s*sound\[\]\s*=\s*'
                             r'\{"([^"]+)",\s*([0-9.]+),\s*([0-9.]+)\};\s*\};', self.source)
        self.assertEqual(len(entries), len(VARIANTS))
        target_original_gain = 0.1 * 10 ** (1 / 20)
        for (name, path, gain, pitch), variant in zip(entries, VARIANTS):
            self.assertEqual(name, "ACE_heartbeat_" + variant)
            self.assertEqual(path, "\\z\\ace\\addons\\medical_feedback\\sounds\\" + variant + ".wav")
            self.assertTrue(math.isclose(float(gain), target_original_gain, rel_tol=1e-8))
            self.assertEqual(float(pitch), 1)

    def test_ace_owns_playback_and_addon_is_optional(self):
        self.assertRegex(self.source, r'requiredAddons\[\]\s*=\s*\{"ace_medical_feedback"\}')
        self.assertRegex(self.source, r'skipWhenMissingDependencies\s*=\s*1;')
        self.assertNotRegex(self.source, r'(?i)playSound|fadeSound|CfgFunctions|Extended_\w+_EventHandlers')


if __name__ == "__main__":
    unittest.main()
