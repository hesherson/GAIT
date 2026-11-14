"""Audit the guarded insertion points in ACE 3.21.2's fatigue loop.

Pass --ace-source /path/to/ACE3 to check the installed source layout as well.
The fixture exercises source rewriting only. It does not simulate ACE or Arma.
"""
from pathlib import Path
import argparse
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
HOOK = ROOT / "addons/gait/functions/fn_aceSprintReserveHook.sqf"
CONFIG = ROOT / "addons/gait/config.cpp"
SOURCE = None

# Minimal macro-expanded shape of the surrounding ACE statements.
LOOP = """\
ace_advanced_fatigue_ae2Reserve = _aerobicAfter;
ace_advanced_fatigue_anReserve  = 0 max (ace_advanced_fatigue_anReserve  -  _anPower / ace_advanced_fatigue_anWattsPerATP);
ace_advanced_fatigue_anFatigue = _acidosisAfter;
ace_advanced_fatigue_anReserve = _anaerobicAfterRecovery;
ace_advanced_fatigue_aeReservePercentage = _aerobicPercentage;
ace_advanced_fatigue_anReservePercentage = ace_advanced_fatigue_anReserve / 2300;
[ACE_player, _perceivedFatigue, _overexhausted, _fwdAngle, _sideAngle] call ace_advanced_fatigue_fnc_handleEffects;
[ace_advanced_fatigue_anReserve / 2300] call ace_advanced_fatigue_fnc_handleStaminaBar;
"""


def literal(hook, name):
    return re.search(rf"private _{name} = '([^']+)';", hook)[1]


def instrument(source):
    hook = HOOK.read_text()
    matches = []
    for name in ("before", "after"):
        pattern = literal(hook, name)
        assert pattern.endswith("/g")
        matches.append(list(re.finditer(pattern[:-2], source)))
    before, after = matches
    if len(before) != 1 or len(after) != 1 or before[0].start() >= after[0].start():
        return source
    start, end = before[0].start(), after[0].start()
    return source[:start] + literal(hook, "capture") + source[start:end] + literal(hook, "filter") + source[end:]


class AceSprintReserveHook(unittest.TestCase):
    def test_installed_loop_keeps_all_ace_instructions_in_place(self):
        hook = HOOK.read_text()
        result = instrument(LOOP)
        capture, filter_at = literal(hook, "capture"), literal(hook, "filter")
        self.assertEqual(result.count(capture), 1)
        self.assertEqual(result.count(filter_at), 1)
        self.assertEqual(result.replace(capture, "", 1).replace(filter_at, "", 1), LOOP)
        self.assertLess(result.index(capture), result.index("0 max"))
        self.assertLess(result.index("_anaerobicAfterRecovery"), result.index(filter_at))
        self.assertLess(result.index(filter_at), result.index("anReservePercentage"))
        self.assertLess(result.index(filter_at), result.index("fnc_handleEffects"))
        self.assertLess(result.index(filter_at), result.index("fnc_handleStaminaBar"))
        self.assertIn("ACE_player, _anPower / ace_advanced_fatigue_anWattsPerATP]", filter_at)

    def test_unknown_or_ambiguous_loop_keeps_stock_behavior(self):
        self.assertEqual(instrument(LOOP.replace("2300", "2400")), LOOP.replace("2300", "2400"))
        self.assertEqual(instrument(LOOP * 2), LOOP * 2)
        reversed_loop = "\n".join(reversed(LOOP.splitlines()))
        self.assertEqual(instrument(reversed_loop), reversed_loop)
        hook = HOOK.read_text()
        self.assertIn('"GAIT_fnc_filterAceSprintReserve", {_this select 1}', hook)
        self.assertIn('_loop = compileScript [_originalPath, true];', hook)
        self.assertIn('_this call _loop;', hook)

    def test_ace_compiles_its_original_function_name_in_both_startup_phases(self):
        config = CONFIG.read_text()
        for phase in ("PreStart", "PreInit"):
            event = config.split(f"class Extended_{phase}_EventHandlers", 1)[1]
            block = event.split("class ace_advanced_fatigue", 1)[1].split("};", 1)[0]
            self.assertIn(rf"\z\ace\addons\advanced_fatigue\XEH_{phase[0].lower() + phase[1:]}.sqf", block)
            self.assertIn(r"\advanced_fatigue\functions\fnc_mainLoop.sqf", block)
            self.assertIn(r"\gait\functions\fn_aceSprintReserveHook.sqf", block)
            self.assertIn(r"\gait\functions\fn_redirectAceStartup.sqf", block)

    def test_reference_checkout(self):
        if SOURCE is None:
            self.skipTest("Pass --ace-source to check an ACE checkout")
        # The release SQF uses ACE macros. Expand only the two identifier and
        # constant forms relevant to the production regexes.
        source = (SOURCE / "addons/advanced_fatigue/functions/fnc_mainLoop.sqf").read_text()
        expanded = re.sub(r"\bGVAR\((\w+)\)", r"ace_advanced_fatigue_\1", source).replace("AN_MAXRESERVE", "2300")
        result = instrument(expanded)
        self.assertNotEqual(result, expanded)
        self.assertLess(result.index("GAIT_fnc_filterAceSprintReserve"), result.index("call FUNC(handleEffects)"))
        self.assertLess(result.index("GAIT_fnc_filterAceSprintReserve"), result.index("call FUNC(handleStaminaBar)"))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--ace-source", type=Path)
    args, unittest_args = parser.parse_known_args()
    SOURCE = args.ace_source
    unittest.main(argv=[__file__, *unittest_args], verbosity=2)
