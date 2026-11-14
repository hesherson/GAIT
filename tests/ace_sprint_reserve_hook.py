"""Audit reserve and movement-lock edits in the installed ACE fatigue code.

Pass --ace-source /path/to/ACE3 to check the installed source layout as well.
Pass --effects-source /path/to/fnc_handleEffects_AF.sqf to check ACM or ACME.
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
EFFECTS_SOURCES = []

# Minimal macro-expanded shape of the surrounding ACE statements.
LOOP = """\
_currentWork = [_gearMass, _terrainGradient * ace_advanced_fatigue_terrainGradientFactor * 0.1, _terrainFactor, _currentSpeed] call ace_advanced_fatigue_fnc_getMetabolicCosts;
ace_advanced_fatigue_ae2Reserve = _aerobicAfter;
ace_advanced_fatigue_anReserve  = 0 max (ace_advanced_fatigue_anReserve  -  _anPower / ace_advanced_fatigue_anWattsPerATP);
ace_advanced_fatigue_anFatigue = _acidosisAfter;
ace_advanced_fatigue_anReserve = _anaerobicAfterRecovery;
ace_advanced_fatigue_aeReservePercentage = _aerobicPercentage;
ace_advanced_fatigue_anReservePercentage = ace_advanced_fatigue_anReserve / 2300;
[ACE_player, _perceivedFatigue, _overexhausted, _fwdAngle, _sideAngle] call ace_advanced_fatigue_fnc_handleEffects;
[ace_advanced_fatigue_anReserve / 2300] call ace_advanced_fatigue_fnc_handleStaminaBar;
"""

EFFECTS = '''\
if (ace_advanced_fatigue_isSwimming) exitWith {
    [_unit,"blockSprint","ace_advanced_fatigue",true] call ace_common_fnc_statusEffect_set
};
_unit setAnimSpeedCoef 1;
if (_fatigue >= 1) then {
    [_unit, "forceWalk", "ace_advanced_fatigue", true] call ace_common_fnc_statusEffect_set;
    [_unit, "blockSprint", "ace_advanced_fatigue", true] call ace_common_fnc_statusEffect_set
};
if (_fwdAngle > 20) then {
    [_unit, "blockSprint", "ace_advanced_fatigue", true] call ace_common_fnc_statusEffect_set;
};
[_unit, "forceWalk", "ace_advanced_fatigue", false] call ace_common_fnc_statusEffect_set;
[_unit, "blockSprint", "ace_medical_fracture", true] call ace_common_fnc_statusEffect_set;
_unit setVariable ["ace_advanced_fatigue_aimFatigue", _fatigue];
'''


def literal(hook, name):
    return re.search(rf"private _{name} = '([^']+)';", hook)[1]


def instrument(source):
    hook = HOOK.read_text()
    matches = []
    for name in ("work", "before", "after"):
        pattern = literal(hook, name)
        assert pattern.endswith("/g")
        matches.append(list(re.finditer(pattern[:-2], source)))
    work, before, after = matches
    if any(len(found) != 1 for found in matches) or not work[0].start() < before[0].start() < after[0].start():
        return source
    start, end = before[0].start(), after[0].start()
    return source[:start] + literal(hook, "capture") + source[start:end] + literal(hook, "filter") + source[end:]


def regex(name):
    pattern = literal(HOOK.read_text(), name)
    assert pattern.endswith("/gi")
    return re.compile(pattern[:-3], re.IGNORECASE)


def instrument_effects(source):
    pattern = regex("fatigueLock")
    matches = pattern.findall(source)
    if len(matches) != 4 or sum(name.lower() == "blocksprint" for name in matches) != 3:
        return source
    return pattern.sub("", source)


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
        self.assertIn("ACE_player, _anPower / ace_advanced_fatigue_anWattsPerATP, _fwdAngle,", filter_at)
        self.assertIn("[_currentWork, _gearMass, _terrainGradient * ace_advanced_fatigue_terrainGradientFactor * 0.1,", filter_at)
        self.assertIn("_terrainFactor, _currentSpeed, ace_advanced_fatigue_anWattsPerATP]", filter_at)

    def test_unknown_or_ambiguous_loop_keeps_stock_behavior(self):
        self.assertEqual(instrument(LOOP.replace("2300", "2400")), LOOP.replace("2300", "2400"))
        changed_work = LOOP.replace("* 0.1", "* 0.2")
        self.assertEqual(instrument(changed_work), changed_work)
        self.assertEqual(instrument(LOOP * 2), LOOP * 2)
        reversed_loop = "\n".join(reversed(LOOP.splitlines()))
        self.assertEqual(instrument(reversed_loop), reversed_loop)
        hook = HOOK.read_text()
        self.assertIn('"GAIT_fnc_filterAceSprintReserve", {_this select 1}', hook)
        self.assertIn('_loop = compileScript [_originalPath, true];', hook)
        self.assertIn('_this call _loop;', hook)

    def test_effect_dispatch_is_independent_of_reserve_instrumentation(self):
        pattern = regex("effectsCall")
        for source in (LOOP, LOOP.replace("/ 2300;", "/ 2400;")):
            self.assertEqual(len(pattern.findall(source)), 1)
            result = pattern.sub("call _gaitRunFatigueEffects;", source)
            self.assertEqual(result.replace("_gaitRunFatigueEffects", "ace_advanced_fatigue_fnc_handleEffects"), source)
        hook = HOOK.read_text()
        self.assertIn('_supported || {_effectsSupported}', hook)
        self.assertIn('count (_source regexFind [_effectsCall]) isEqualTo 1', hook)

    def test_effect_guard_removes_only_af_true_writes(self):
        guarded = instrument_effects(EFFECTS)
        self.assertNotEqual(guarded, EFFECTS)
        self.assertNotIn('"ace_advanced_fatigue", true]', guarded)
        self.assertIn('"ace_advanced_fatigue", false]', guarded)
        self.assertIn('"ace_medical_fracture", true]', guarded)
        self.assertIn('_unit setAnimSpeedCoef 1', guarded)
        self.assertIn('"ace_advanced_fatigue_aimFatigue"', guarded)
        self.assertEqual(instrument_effects(EFFECTS * 2), EFFECTS * 2)
        ambiguous = EFFECTS.replace('"forceWalk", "ace_advanced_fatigue", true', '"blockSprint", "ace_advanced_fatigue", true')
        self.assertEqual(instrument_effects(ambiguous), ambiguous)

    def test_live_effects_are_used_and_cached_only_while_identical(self):
        hook = HOOK.read_text()
        self.assertIn('private _original = ace_advanced_fatigue_fnc_handleEffects;', hook)
        self.assertIn('"GAIT_fnc_ownsFatigueMovementPolicy", {false}', hook)
        self.assertLess(hook.index('_this call _original'), hook.index('toString _original'))
        self.assertIn('_original isNotEqualRef (_cache select 0)', hook)
        self.assertIn('private _guarded = _original;', hook)
        self.assertIn('_cache = [_original, _guarded]', hook)

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
        # Expand only the identifiers and constant used by the reserve hook.
        source = (SOURCE / "addons/advanced_fatigue/functions/fnc_mainLoop.sqf").read_text()
        expanded = re.sub(r"\bGVAR\((\w+)\)", r"ace_advanced_fatigue_\1", source).replace("AN_MAXRESERVE", "2300")
        expanded = expanded.replace("FUNC(getMetabolicCosts)", "ace_advanced_fatigue_fnc_getMetabolicCosts")
        result = instrument(expanded)
        self.assertNotEqual(result, expanded)
        self.assertLess(result.index("GAIT_fnc_filterAceSprintReserve"), result.index("call FUNC(handleEffects)"))
        self.assertLess(result.index("GAIT_fnc_filterAceSprintReserve"), result.index("call FUNC(handleStaminaBar)"))

    def test_reference_effects_sources(self):
        sources = list(EFFECTS_SOURCES)
        if SOURCE is not None:
            sources.append(SOURCE / "addons/advanced_fatigue/functions/fnc_handleEffects.sqf")
        if not sources:
            self.skipTest("Pass --ace-source or --effects-source to check installed effects sources")
        for path in sources:
            with self.subTest(path=path):
                source = path.read_text()
                source = re.sub(r'QUOTE\((ADDON|ACE_ADDON\(advanced_fatigue\))\)', '"ace_advanced_fatigue"', source)
                source = re.sub(r'(EFUNC|ACEFUNC)\(common,statusEffect_set\)', 'ace_common_fnc_statusEffect_set', source)
                guarded = instrument_effects(source)
                self.assertNotEqual(guarded, source)
                self.assertIn('"ace_advanced_fatigue", false]', guarded)
                self.assertIn('playSound', guarded)
                self.assertIn('ppEffectAdjust', guarded)
                self.assertIn('setAnimSpeedCoef', guarded)
                self.assertIn('aimFatigue', guarded)
                if '_AF' in path.name:
                    self.assertIn('Pneumothorax_State', guarded)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--ace-source", type=Path)
    parser.add_argument("--effects-source", type=Path, action="append", default=[])
    args, unittest_args = parser.parse_known_args()
    SOURCE = args.ace_source
    EFFECTS_SOURCES = args.effects_source
    unittest.main(argv=[__file__, *unittest_args], verbosity=2)
