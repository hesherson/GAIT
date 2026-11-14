"""Current GAIT locomotion source invariants.

This is intentionally not a replacement for the historical RC4/alpha11 byte
preservation harness. It guards the current architecture and user-visible
non-negotiables without rewriting historical hashes.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
FUNCTIONS = ROOT / "addons/gait/functions"
GRAPH = ROOT / "addons/gait/slope_actions.hpp"


def read(name):
    return (FUNCTIONS / name).read_text(encoding="utf-8-sig")


def executable(text):
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    text = re.sub(r"//[^\n]*", " ", text)
    text = re.sub(r'"(?:\\.|[^"\\])*"', '""', text)
    return text


class LocomotionInvariants(unittest.TestCase):
    def test_version_identity(self):
        project = (ROOT / ".hemtt/project.toml").read_text()
        config = (ROOT / "addons/gait/config.cpp").read_text()
        mod = (ROOT / "mod.cpp").read_text()
        self.assertIn("build = 28", project)
        self.assertIn('versionStr = "1.8.0-alpha28";', config)
        self.assertIn("versionAr[] = {1,8,0,28};", config)
        self.assertIn('tooltip = "GAIT 1.8.0-alpha28";', mod)

    def test_graph_pose_and_no_walk_contract(self):
        text = GRAPH.read_text()
        states = re.findall(r"class AmovPerc(?:Mstp|Mrun|Meva)\w+_GAIT(?:Sprint)?:", text)
        self.assertEqual(len(states), 90)
        self.assertEqual(len(re.findall(r"class AmovPercMstp\w+Dnon_GAITStop:", text)), 5)
        self.assertEqual(len(re.findall(r"class GAIT_Slope\w+Actions:", text)), 15)
        self.assertNotRegex(text, r"class AmovPercMwlk\w+_GAIT(?:Sprint)?:")
        for family in ("SrasWrfl", "SlowWrfl", "SrasWpst", "SlowWpst", "SnonWnon"):
            self.assertEqual(len(re.findall(rf"class AmovPerc(?:Mstp|Mrun|Meva){family}\w+_GAIT(?:Sprint)?:", text)), 18)
        self.assertIn("class GAIT_SlopePistolLowActions: PistolLowStandActions", text)

    def test_direction_owns_input_not_speed_phase(self):
        slope = read("fn_slopeLocomotion.sqf")
        self.assertIn('GAIT_directionChangedThisFrame', slope)
        self.assertIn('GAIT_fnc_readLocomotionAnimation', slope)
        self.assertIn('GAIT_fnc_readLocomotionStance', slope)
        self.assertNotIn('![_unit] call GAIT_fnc_readLocomotionSprintAllowed', slope)
        self.assertIn('!([_unit] call GAIT_fnc_readLocomotionSprintAllowed)', slope)
        self.assertIn('_phase in ["entering", "active"]', slope)
        self.assertIn('GAIT_liveInputDirection', slope)
        self.assertIn('"_GAITSprint"', slope)
        main = read("fn_initSprintSystem.sqf")
        self.assertIn("Direction is never filtered", main)
        self.assertIn("GAIT_fnc_sprintAccelerationRamp", main)

    def test_native_like_stance_yield_keeps_coefficient(self):
        slope = read("fn_slopeLocomotion.sqf")
        start = slope.index("GAIT_fnc_beginStanceYield = {")
        end = slope.index("GAIT_fnc_clearSlopeLocomotionState = {", start)
        stance = executable(slope[start:end])
        self.assertNotIn("GAIT_fnc_releaseSpeedCoefficient", stance)
        self.assertIn("GAIT_stanceCarryCoefficient", slope[start:end])
        self.assertIn("GAIT_fnc_clearLocomotionInputHistory", slope)
        main = read("fn_initSprintSystem.sqf")
        self.assertIn("if (_stanceYieldActive) then", main)

    def test_lowered_pistol_never_collapses_to_raised_family(self):
        slope = read("fn_slopeLocomotion.sqf")
        traversal = read("fn_traversalHelpers.sqf")
        self.assertIn('_families = ["SlowWpst", "SrasWpst"]', slope)
        self.assertIn('(_pistolAnim find "slowwpst") >= 0', slope)
        self.assertIn('_leftFamily isNotEqualTo _rightFamily', traversal)
        self.assertIn('"slowwpst"', traversal)

    def test_slope_and_downhill_contract(self):
        main = read("fn_initSprintSystem.sqf")
        slope = read("fn_slopeLocomotion.sqf")
        downhill = read("fn_downhillPace.sqf")
        self.assertIn("GAIT_fnc_ordinarySlopeJogIntent", slope)
        self.assertIn("GAIT_fnc_uphillLaunchBraceFactor", main)
        self.assertEqual(main.count("call GAIT_fnc_capDownhillPace"), 2)
        self.assertIn("call GAIT_fnc_uphillSprintFloor", main)
        self.assertIn("call GAIT_fnc_sprintLaunchBraceDuration", main)
        self.assertIn("GAIT_fnc_lookupUnitPaceReference", main)
        self.assertIn("GAIT_fnc_locomotionPaceReferences", main)
        self.assertIn("GAIT_sprintReferenceCalibrated", main)
        self.assertIn("min _maximumPace", downhill)
        self.assertNotRegex(executable(downhill), r"\bvelocity\b")

    def test_locomotion_has_no_velocity_injection_or_animation_watchdog(self):
        for name in ("fn_slopeLocomotion.sqf", "fn_nativeController.sqf",
                     "fn_braceMomentum.sqf", "fn_downhillPace.sqf"):
            code = executable(read(name))
            self.assertNotRegex(code, r"\bsetVelocity(?:ModelSpace)?\b", name)
            count_switch = len(re.findall(r"\bswitchMove\b", code))
            self.assertEqual(count_switch, int(name == "fn_slopeLocomotion.sqf"), name)
        slope = executable(read("fn_slopeLocomotion.sqf"))
        self.assertEqual(len(re.findall(r"\bplayMoveNow\b", slope)), 1)

    def test_no_weapon_sway_or_native_fatigue_writers(self):
        forbidden = ("setCustomAimCoef", "setUnitRecoilCoefficient", "setFatigue")
        for path in FUNCTIONS.glob("*.sqf"):
            code = executable(path.read_text(encoding="utf-8-sig"))
            for command in forbidden:
                self.assertNotRegex(code, rf"\b{command}\b", f"{path.name}: {command}")

    def test_vanilla_terrain_and_live_walk_control(self):
        config = (ROOT / "addons/gait/config.cpp").read_text()
        self.assertNotIn("terrainSpeedCoef", config)
        native = read("fn_nativeController.sqf")
        main = read("fn_initSprintSystem.sqf")
        slope = read("fn_slopeLocomotion.sqf")
        self.assertIn('inputAction "WalkRunTemp"', native)
        self.assertIn('if (_nativeWalk && {!_allowCarry}) exitWith', native)
        self.assertIn('[player, _currentSpeed, false, true] call GAIT_fnc_applyNativeMovement', main)
        self.assertIn('[player] call GAIT_fnc_releaseNativeWalkPace', slope)
        self.assertIn('!_nativeWalk', slope)

    def test_deceleration_uses_only_the_common_speed_ramp(self):
        main = read("fn_initSprintSystem.sqf")
        start = main.index('call GAIT_fnc_jogDecelerationRamp;')
        end = main.index('call GAIT_fnc_applyNativeMovement;', start)
        self.assertIn('call GAIT_fnc_stepSpeedCoefficient;', main[start:end])
        self.assertFalse((FUNCTIONS / "fn_releaseMomentum.sqf").exists())
        self.assertFalse((FUNCTIONS / "fn_uphillBrake.sqf").exists())
        slope = read("fn_slopeLocomotion.sqf")
        self.assertNotIn('GAIT_fnc_applyNativeMovement', slope)
        self.assertNotIn('GAIT_ss_shiftReleaseRunTaper', slope)
        self.assertNotIn('GAIT_paceHandoff', slope)

    def test_locality_and_reset_contract(self):
        helper = read("fn_traversalHelpers.sqf")
        main = read("fn_initSprintSystem.sqf")
        module = read("fn_moduleResetEffects.sqf")
        reset = read("fn_resetEffects.sqf")
        self.assertIn("!local _unit", helper)
        self.assertIn("CBA_fnc_targetEvent", module)
        self.assertNotIn("remoteExecCall", module)
        self.assertIn("GAIT_fnc_clearLocomotionInputHistory", reset)
        self.assertIn("GAIT_resetRequested", reset)
        self.assertIn("GAIT_resetRequested", main)
        reset_anchor = main.index('if (_resetRequest > _lastResetRequestHandled) then {')
        reset_block = main[reset_anchor:main.index('// Refresh live Addon Options settings each tick.', reset_anchor)]
        self.assertIn('_lastForwardReleaseSerial = player getVariable ["GAIT_forwardReleaseSerial", 0];', reset_block)
        self.assertIn('_lastForwardPressSerial = player getVariable ["GAIT_forwardPressSerial", 0];', reset_block)
        self.assertIn('!isTouchingGround _unit', helper)

    def test_ace_owns_fatigue_feedback(self):
        addon = ROOT / "addons/gait"
        self.assertFalse((ROOT / "addons/heartbeat").exists())
        self.assertFalse((addon / "sounds/tinnitus_loop.ogg").exists())
        self.assertFalse((FUNCTIONS / "fn_fatigueVisuals.sqf").exists())
        self.assertFalse((FUNCTIONS / "fn_aceFatigueVisualBridge.sqf").exists())
        config = (addon / "config.cpp").read_text()
        self.assertNotIn("GAIT_tinnitus_loop", config)
        for path in FUNCTIONS.glob("*.sqf"):
            source = path.read_text(encoding="utf-8-sig")
            self.assertNotIn("ace_advanced_fatigue_ppeBlackout", source, path.name)
            prohibited = r"ppEffect\w+|ace_common_fnc_setHearingCapability|playSound3D|addCamShake"
            if path.name != "fn_aceHeartbeatVolume.sqf":
                prohibited += r"|playSoundUI"
            self.assertNotRegex(executable(source), rf"\b(?:{prohibited})\b", path.name)
        heartbeat = read("fn_aceHeartbeatVolume.sqf")
        self.assertIn("GAIT_ss_aceHeartbeatVolume", heartbeat)
        self.assertIn("ace_medical_feedback_fnc_effectHeartBeat", heartbeat)


    def test_single_suspended_context_definition(self):
        count = 0
        locations = []
        for path in FUNCTIONS.glob("*.sqf"):
            if "GAIT_fnc_isSuspendedContext = {" in path.read_text(encoding="utf-8-sig"):
                count += 1
                locations.append(path.name)
        self.assertEqual((count, locations), (1, ["fn_traversalHelpers.sqf"]))


if __name__ == "__main__":
    unittest.main(verbosity=2)
