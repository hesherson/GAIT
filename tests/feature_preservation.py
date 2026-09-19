#!/usr/bin/env python3
"""Protect GAIT's retained RC4 tuning with exact user-authorized deltas through alpha7.

Run: python tests/feature_preservation.py [project-root] [--self-test]
No Arma, third-party packages or adjacent old checkout is required.
Reference digests below were captured from the reviewed 1.7.0-rc4 source.
Do not regenerate them from the current implementation to silence a failure.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import tempfile

TOKEN_RE = re.compile('"(?:[^\\"]|\\"\\")*"|\'(?:[^\']|\'\')*\'|//[^\\n]*|/\\*[\\s\\S]*?\\*/|[A-Za-z_][A-Za-z_0-9]*|(?:\\d+\\.\\d*|\\.\\d+|\\d+)(?:[eE][+-]?\\d+)?|>>|<<|>=|<=|==|!=|&&|\\|\\||[^\\s]')

BYTE_FILES = {'addons/gait/functions/fn_registerSettings.sqf': '4bdeb8c81bacd60fc98082ae830c10d4de6ff5ea784b5d40ed266f0f226a6dd7',
 'addons/gait/functions/fn_applyPreset.sqf': 'ab34104bdee31d0a14f4b9c6a70bf4255b1d8996b7e379b42f348e28de5f314d',
 'addons/gait/functions/fn_slopePaceModel.sqf': '13cd0a00860a4ad0e178c3f2148ccff3712ad8783f95df7932bc2bf34861f69c'}

BLOCKS = [{'name': 'trip_ragdoll_recovery',
  'baseline_file': 'addons/gait/functions/fn_initSprintSystem.sqf',
  'baseline_lines': [205, 260],
  'token_count': 354,
  'prefix': ['GAIT_fnc_tripPlayer',
             '=',
             '{',
             'params',
             '[',
             '[',
             '"_duration"',
             ',',
             '1.25',
             ',',
             '[',
             '0',
             ']',
             ']',
             ']',
             ';',
             'if',
             '(',
             'isNull',
             'player',
             ')',
             'exitWith',
             '{',
             '}'],
  'sha256': '0f971e85af0ca1cdf4d4553bc83387116410eb2aa77e2c2e0eb3452841843052'},
 {'name': 'legacy_visual_cleanup',
  'baseline_file': 'addons/gait/functions/fn_initSprintSystem.sqf',
  'baseline_lines': [318, 373],
  'token_count': 163,
  'prefix': ['GAIT_fnc_clearOldExhaustionVignette',
             '=',
             '{',
             'disableSerialization',
             ';',
             'private',
             '_ctrls',
             '=',
             'uiNamespace',
             'getVariable',
             '[',
             '"GAIT_exhaustionVignetteCtrls"',
             ',',
             '[',
             ']',
             ']',
             ';',
             '{',
             'if',
             '(',
             '!',
             'isNull',
             '_x',
             ')'],
  'sha256': '0adf92ba48f128f3e6052b19713857f52c51af7a1e70e8187f611f6245003e12'},
 {'name': 'sway_and_shared_initial_state',
  'baseline_file': 'addons/gait/functions/fn_initSprintSystem.sqf',
  'baseline_lines': [377, 506],
  'token_count': 626,
  'prefix': ['[',
             ']',
             'spawn',
             '{',
             'waitUntil',
             '{',
             'sleep',
             '0.25',
             ';',
             '!',
             'isNull',
             'player',
             '}',
             ';',
             'waitUntil',
             '{',
             'sleep',
             '0.25',
             ';',
             '!',
             'isNull',
             'findDisplay',
             '46',
             '}'],
  'sha256': 'bf2e5d5ff2fd9dad0a15f19ca32a72823d7fb9ca8034bd660a960717698ea1f2'},
 {'name': 'initial_tuning_and_momentum_state',
  'baseline_file': 'addons/gait/functions/fn_initSprintSystem.sqf',
  'baseline_lines': [527, 760],
  'token_count': 1648,
  'prefix': ['private',
             '_normalSpeed',
             '=',
             'missionNamespace',
             'getVariable',
             '[',
             '"GAIT_ss_normalSpeed"',
             ',',
             '0.86',
             ']',
             ';',
             'private',
             '_sprintReserveMax',
             '=',
             'missionNamespace',
             'getVariable',
             '[',
             '"GAIT_ss_sprintReserveMax"',
             ',',
             '25.0',
             ']',
             ';',
             'private',
             '_sprintRecoverTime'],
  'sha256': 'c7a353ed368fb928ba51b28516be4edbff7c8648bacb09657981f064fa5ad0ce'},
 {'name': 'preset_and_reset_state',
  'baseline_file': 'addons/gait/functions/fn_initSprintSystem.sqf',
  'baseline_lines': [772, 801],
  'token_count': 151,
  'prefix': ['private',
             '_selectedPreset',
             '=',
             'missionNamespace',
             'getVariable',
             '[',
             '"GAIT_ss_preset"',
             ',',
             '"Balanced"',
             ']',
             ';',
             'private',
             '_lastPresetApplied',
             '=',
             'missionNamespace',
             'getVariable',
             '[',
             '"GAIT_lastPresetApplied"',
             ',',
             '""',
             ']',
             ';',
             'if',
             '!'],
  'sha256': 'c1f8804614de79917ae7b77e0ee1459ba5b98d1df2aa0966f48e67b8899509e2'},
 {'name': 'live_settings_and_reserve_resize',
  'baseline_file': 'addons/gait/functions/fn_initSprintSystem.sqf',
  'baseline_lines': [805, 942],
  'token_count': 1304,
  'prefix': ['_debugHudEnabled',
             '=',
             'missionNamespace',
             'getVariable',
             '[',
             '"GAIT_ss_debugHudEnabled"',
             ',',
             'false',
             ']',
             ';',
             '_debugHudInterval',
             '=',
             'missionNamespace',
             'getVariable',
             '[',
             '"GAIT_ss_debugHudInterval"',
             ',',
             '0.10',
             ']',
             ';',
             '_downhillMomentumEasyTriggerDegrees',
             '=',
             'missionNamespace',
             'getVariable'],
  'sha256': 'cba44557598f85b97cb9e57a4a306e440f31dec57310acf25d5488b4fac5b205'},
 {'name': 'forward_sprint_intent',
  'baseline_file': 'addons/gait/functions/fn_initSprintSystem.sqf',
  'baseline_lines': [977, 978],
  'token_count': 18,
  'prefix': ['private',
             '_isForwardHeld',
             '=',
             '(',
             '_movementInput',
             'select',
             '0',
             ')',
             '>',
             '0.05',
             ';',
             'private',
             '_turboHeld',
             '=',
             '_movementInput',
             'select',
             '2',
             ';'],
  'sha256': 'd131ad4a8875d432c697cd7e6042321a43e817f4dd4788e5bfd8f80cd99c12f3'},
 {'name': 'sprint_pace_gate',
  'baseline_file': 'addons/gait/functions/fn_initSprintSystem.sqf',
  'baseline_lines': [983, 983],
  'token_count': 35,
  'prefix': ['private',
             '_isSprinting',
             '=',
             '_turboHeld',
             '&&',
             '{',
             '_isForwardHeld',
             '}',
             '&&',
             '{',
             '!',
             '(',
             '(',
             'stance',
             'player',
             ')',
             'isEqualTo',
             '"PRONE"',
             ')',
             '}',
             '&&',
             '{',
             '_movementEligible',
             '}'],
  'sha256': '8562d1c8620e861def07e93555e027d4c1684c655f5163753149065bcb37dc22'},
 {'name': 'stance_and_direction_gates',
  'baseline_file': 'addons/gait/functions/fn_initSprintSystem.sqf',
  'baseline_lines': [992, 998],
  'token_count': 77,
  'prefix': ['private',
             '_gaitStanceOk',
             '=',
             '(',
             '(',
             'stance',
             'player',
             ')',
             'isEqualTo',
             '"STAND"',
             ')',
             '&&',
             '{',
             'private',
             '_gaitAnimLow',
             '=',
             'toLower',
             '(',
             'animationState',
             'player',
             ')',
             ';',
             '(',
             '('],
  'sha256': 'fb4fca1e971296fd65de14d06e3f96d90dbb11653db5d6f405314ec2052fb4de'},
 {'name': 'hard_landing_and_sprint_tracking',
  'baseline_file': 'addons/gait/functions/fn_initSprintSystem.sqf',
  'baseline_lines': [1000, 1046],
  'token_count': 310,
  'prefix': ['private',
             '_onGroundNow',
             '=',
             'isTouchingGround',
             'player',
             ';',
             'if',
             '(',
             '_hardLandingCamShakeEnabled',
             '&&',
             '{',
             '_onGroundNow',
             '}',
             '&&',
             '{',
             '!',
             '_lastOnGround',
             '}',
             '&&',
             '{',
             '_lastVerticalSpeed',
             '<',
             '-',
             '('],
  'sha256': 'b3d387585cb65e2cee8872a225d0946f74117e705010732dd21c14a10b2324f3'},
 {'name': 'forward_release_rearm',
  'baseline_file': 'addons/gait/functions/fn_initSprintSystem.sqf',
  'baseline_lines': [1048, 1049],
  'token_count': 30,
  'prefix': ['if',
             '(',
             '_isForwardHeld',
             ')',
             'then',
             '{',
             '_lastForwardInputTime',
             '=',
             'time',
             ';',
             '}',
             ';',
             'private',
             '_forwardReleasedLongEnough',
             '=',
             '!',
             '_isForwardHeld',
             '&&',
             '{',
             '(',
             '(',
             'time',
             '-',
             '_lastForwardInputTime'],
  'sha256': 'e61e65fa5571a10ddbb6720909490f2798b184a3fa5bd468b21c8547ac6699d4'},
 {'name': 'gear_weight_and_brace_relief',
  'baseline_file': 'addons/gait/functions/fn_initSprintSystem.sqf',
  'baseline_lines': [1060, 1077],
  'token_count': 128,
  'prefix': ['private',
             '_gearLbs',
             '=',
             '(',
             'loadAbs',
             'player',
             ')',
             '/',
             '(',
             '_loadAbsPerLb',
             'max',
             '0.01',
             ')',
             ';',
             'private',
             '_weightSpeedMult',
             '=',
             '[',
             '_gearLbs',
             ',',
             '[',
             '_lightWeightMax',
             ',',
             '_mediumWeightMax'],
  'sha256': '10763acc7e1d2fe25aee5ea6fd9e5de369f0dac7ebc60511e0cf988d522f5594'},
 {'name': 'directional_grade_trips_and_walk_pace',
  'baseline_file': 'addons/gait/functions/fn_initSprintSystem.sqf',
  'baseline_lines': [1085, 1223],
  'token_count': 1082,
  'prefix': ['private',
             '_slopeDegrees',
             '=',
             '0',
             ';',
             'private',
             '_slopeSpeedMultiplier',
             '=',
             '1',
             ';',
             'if',
             '(',
             '_slopeHandlingEnabled',
             '&&',
             '{',
             '_isOnFoot',
             '}',
             '&&',
             '{',
             '!',
             '_isAceDragging',
             '}',
             ')',
             'then'],
  'sha256': '09e215c46427ecd9ab20e3307c7e49c7c419c7ffc2261b6ddf38cf26d012f8c9'},
 {'name': 'step_off_brace_and_sprint_end',
  'baseline_file': 'addons/gait/functions/fn_initSprintSystem.sqf',
  'baseline_lines': [1229, 1368],
  'token_count': 670,
  'prefix': ['private',
             '_isBraceReadyState',
             '=',
             '!',
             '_isSprinting',
             '&&',
             '{',
             '!',
             '_isAceDragging',
             '}',
             '&&',
             '{',
             '_isOnFoot',
             '}',
             '&&',
             '{',
             '(',
             '(',
             'abs',
             '(',
             'speed',
             'player',
             ')',
             ')'],
  'sha256': '5ddc1398b6d41a824c84bfd75799375dcaabcebba709a7cad989da4f951fbecb'},
 {'name': 'reserve_and_exhaustion_effects',
  'baseline_file': 'addons/gait/functions/fn_initSprintSystem.sqf',
  'baseline_lines': [1373, 1548],
  'token_count': 933,
  'prefix': ['private',
             '_reserveRatio',
             '=',
             '1',
             ';',
             'private',
             '_uphillFatigueDrainSeverityNow',
             '=',
             '0',
             ';',
             'private',
             '_uphillFatigueDrainMultiplierNow',
             '=',
             '1',
             ';',
             'if',
             '(',
             '_uphillFatigueDrainEnabled',
             '&&',
             '{',
             '_isSprinting',
             '}',
             '&&',
             '{'],
  'sha256': 'ed998330e80a72c6a5462f3d4a5564552d88bd952d06428d15c420fe2d07451c'},
 {'name': 'sprint_targets_and_ace_carry',
  'baseline_file': 'addons/gait/functions/fn_initSprintSystem.sqf',
  'baseline_lines': [1553, 1573],
  'token_count': 177,
  'prefix': ['private',
             '_flatSprintPace',
             '=',
             '_sprintExhaustedSpeed',
             '+',
             '(',
             '(',
             '_sprintFullSpeed',
             '-',
             '_sprintExhaustedSpeed',
             ')',
             '*',
             '_reserveRatio',
             ')',
             ';',
             'if',
             '(',
             '(',
             'currentWeapon',
             'player',
             ')',
             'isEqualTo',
             '""',
             ')'],
  'sha256': '573e0aebe841b422897198538f7394a70dcd76cb8699a4eceffe7eb7e947ab21'},
 {'name': 'shift_release_hold_and_taper',
  'baseline_file': 'addons/gait/functions/fn_initSprintSystem.sqf',
  'baseline_lines': [1578, 1609],
  'token_count': 287,
  'prefix': ['private',
             '_shiftReleaseTaperActiveNow',
             '=',
             'false',
             ';',
             'private',
             '_shiftReleaseTaperHoldActiveNow',
             '=',
             'false',
             ';',
             'private',
             '_shiftReleaseTaperKeepNow',
             '=',
             '0',
             ';',
             'private',
             '_shiftReleaseTaperTargetKmhNow',
             '=',
             '0',
             ';',
             'if',
             '(',
             '_shiftReleaseRunTaperEnabled',
             '&&'],
  'sha256': '9f1bfd931cd96cc393b05e47be29483487cdc973134a1a8a5b4206e2533997a9'},
 {'name': 'brace_or_momentum_speed_ramp',
  'baseline_file': 'addons/gait/functions/fn_initSprintSystem.sqf',
  'baseline_lines': [1614, 1616],
  'token_count': 60,
  'prefix': ['private',
             '_ramp',
             '=',
             'if',
             '(',
             '_isSprinting',
             '&&',
             '{',
             '_sprintBraceEndTime',
             '>',
             'time',
             '}',
             ')',
             'then',
             '{',
             '_sprintStartBraceLerp',
             '}',
             'else',
             '{',
             '_speedLerp',
             '}',
             ';',
             'private',
             '_rampTarget'],
  'sha256': 'e813c29d3dc1d4d2c88f56e5533d9ed676c3cdb099e5b30aaf02925ae3db85d3'},
 {'name': 'sideways_and_external_lock_speed_cap',
  'baseline_file': 'addons/gait/functions/fn_initSprintSystem.sqf',
  'baseline_lines': [1618, 1621],
  'token_count': 28,
  'prefix': ['private',
             '_coef',
             '=',
             '_currentSpeed',
             ';',
             'if',
             '(',
             '!',
             '_isForwardHeld',
             '||',
             '{',
             '_externalSprintLock',
             '}',
             '||',
             '{',
             '_externalWalkLock',
             '}',
             ')',
             'then',
             '{',
             '_coef',
             '=',
             '_coef',
             'min'],
  'sha256': 'e4daf048c56ca7ac85eea619849d1105dfd5e3f0103303eb4921db5652323daa'},
 {'name': 'native_movement_input_resolver',
  'baseline_file': 'addons/gait/functions/fn_traversalHelpers.sqf',
  'baseline_lines': [8, 26],
  'token_count': 158,
  'prefix': ['GAIT_fnc_resolveMovementInput',
             '=',
             '{',
             'params',
             '[',
             '"_forwardAction"',
             ',',
             '"_backAction"',
             ',',
             '"_leftAction"',
             ',',
             '"_rightAction"',
             ',',
             '"_turboAction"',
             ']',
             ';',
             'private',
             '_forward',
             '=',
             '(',
             '_forwardAction',
             'max',
             '0',
             'min'],
  'sha256': 'f6d92f6d4386c32a4f22a5763a915aa85c14c0b7146d186b9f5c7db39a4abf5a'},
 {'name': 'frame_rate_independent_ramp',
  'baseline_file': 'addons/gait/functions/fn_traversalHelpers.sqf',
  'baseline_lines': [28, 32],
  'token_count': 58,
  'prefix': ['GAIT_fnc_stepSpeedCoefficient',
             '=',
             '{',
             'params',
             '[',
             '"_current"',
             ',',
             '"_target"',
             ',',
             '"_ramp"',
             ',',
             '"_dt"',
             ']',
             ';',
             'private',
             '_alpha',
             '=',
             '1',
             '-',
             '(',
             '(',
             '1',
             '-',
             '('],
  'sha256': '16ef465a7fc3bbe7ae9b8dfddff6d28ca181268ec69ed8c00f05ac495279e916'},
 {'name': 'intended_direction_terrain_grade',
  'baseline_file': 'addons/gait/functions/fn_traversalHelpers.sqf',
  'baseline_lines': [129, 179],
  'token_count': 377,
  'prefix': ['GAIT_fnc_getTravelSlopeDegrees',
             '=',
             '{',
             'params',
             '[',
             '[',
             '"_unit"',
             ',',
             'player',
             ',',
             '[',
             'objNull',
             ']',
             ']',
             ',',
             '[',
             '"_sampleDistance"',
             ',',
             '2.0',
             ',',
             '[',
             '0',
             ']',
             ']'],
  'sha256': '0a03f10afd91386c36c786769b6564537ed8c738f29b441b1fb6237083727066'},
 {'name': 'hearing_capability_ownership',
  'baseline_file': 'addons/gait/functions/fn_initSprintSystem.sqf',
  'baseline_lines': [139, 164],
  'token_count': 107,
  'prefix': ['GAIT_fnc_setSprintHearing',
             '=',
             '{',
             'params',
             '[',
             '[',
             '"_volume"',
             ',',
             '1',
             ',',
             '[',
             '0',
             ']',
             ']',
             ',',
             '[',
             '"_fade"',
             ',',
             '0.2',
             ',',
             '[',
             '0',
             ']',
             ']'],
  'sha256': '510e657471155a9780a25d0849229d1293ad08f2a88a3007bb3d84b5fb44acfb'},
 {'name': 'vegetation_drag_tuning',
  'baseline_file': 'addons/gait/functions/fn_nativeController.sqf',
  'baseline_lines': [89, 104],
  'token_count': 162,
  'prefix': ['private',
             '_drag',
             '=',
             '0',
             ';',
             'if',
             '(',
             'missionNamespace',
             'getVariable',
             '[',
             '"GAIT_ss_vegetationDragEnabled"',
             ',',
             'true',
             ']',
             ')',
             'then',
             '{',
             'if',
             '(',
             'time',
             '>=',
             '(',
             'missionNamespace',
             'getVariable'],
  'sha256': '557aed7018bea2ead6e13eb092c895151c560bf435f1f69d71d4dc3d4bd96b85'},
 {'name': 'vegetation_coefficient_product',
  'baseline_file': 'addons/gait/functions/fn_nativeController.sqf',
  'baseline_lines': [114, 114],
  'token_count': 15,
  'prefix': ['private',
             '_final',
             '=',
             '(',
             '_coefficient',
             '*',
             '(',
             '1',
             '-',
             '_drag',
             ')',
             ')',
             'max',
             '0.000001',
             ';'],
  'sha256': '02730813ded44e848bffd4366d9eafaa79e9bb4cb12190ad015929397215d452'}]


def tokenize(code: str) -> list[str]:
    # Quoted SQF strings are matched before comment alternatives. Their contents,
    # numeric literal spelling and variable names remain part of the fingerprint.
    return [value for value in TOKEN_RE.findall(code)
            if not value.startswith(("//", "/*"))]


def token_digest(values: list[str]) -> str:
    payload = json.dumps(values, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


# Keep the original byte digest above as provenance. The user authorized two
# description updates (including one display label) and two added sliders in
# alpha2, plus one alpha3 uphill-release checkbox. The rest of registration
# code must match the fixed RC4 token digest.
SETTINGS_FILE = "addons/gait/functions/fn_registerSettings.sqf"
PRESETS_FILE = "addons/gait/functions/fn_applyPreset.sqf"
SETTINGS_RC4_TOKEN_SHA256 = "f7bd1d615a86f458f89f1a13b4cda438ede05e6241dc5ea12bcdf3b53b929ee5"
MAIN_FILE = "addons/gait/functions/fn_initSprintSystem.sqf"

# Exact, reviewed source deltas are reversed ONLY for comparison to RC4.
# A missing or altered authorized fragment fails. This is not a wildcard
# exemption for these blocks and none of the historical hashes are changed.
# New helpers also require their separate SQF behavior tests.
AUTHORIZED_BLOCK_DELTAS = [('trip_ragdoll_recovery',
  'alpha7 clear intermittent visuals before trip',
  '[] call GAIT_fnc_releaseFatigueVisuals;\n'
  '[] call GAIT_fnc_releaseNativeStaminaOwnership;\n'
  '[] call GAIT_fnc_releaseNativeMovement;\n'
  'player setVariable ["GAIT_isTripping", true, false];',
  '[] call GAIT_fnc_releaseNativeStaminaOwnership;\n'
  '[] call GAIT_fnc_releaseNativeMovement;\n'
  'player setVariable ["GAIT_isTripping", true, false];'),
 ('sway_and_shared_initial_state',
  'alpha7 remove sway writers but preserve every shared movement initializer',
  '[ ] spawn {\n'
  'waitUntil { sleep 0.25 ; ! isNull player } ;\n'
  'waitUntil { sleep 0.25 ; ! isNull findDisplay 46 } ;\n'
  'missionNamespace setVariable [ "GAIT_shiftHeld" , false ] ;\n'
  'missionNamespace setVariable [ "GAIT_lastShiftRelease" , - 999 ] ;\n'
  'missionNamespace setVariable [ "GAIT_lastForwardKeyRelease" , - 999 ] ;\n'
  'missionNamespace setVariable [ "GAIT_slopeDegrees" , 0 ] ;\n'
  'missionNamespace setVariable [ "GAIT_slopeSpeedMultiplier" , 1 ] ;\n'
  'missionNamespace setVariable [ "GAIT_lastTripTime" , - 999 ] ;\n'
  'missionNamespace setVariable [ "GAIT_tripEligible" , false ] ;\n'
  'missionNamespace setVariable [ "GAIT_downhillTerminalReachedTime" , - 999 ] ;\n'
  'missionNamespace setVariable [ "GAIT_downhillTerminalVelocityKmh" , 35.0 ] ;\n'
  'missionNamespace setVariable [ "GAIT_tripChancePerSecond" , 0 ] ;\n'
  'missionNamespace setVariable [ "GAIT_tripCooldownRemaining" , 0 ] ;\n'
  'missionNamespace setVariable [ "GAIT_tripImmunityRemaining" , 0 ] ;\n'
  'missionNamespace setVariable [ "GAIT_tripSustainedGateReady" , false ] ;\n'
  'missionNamespace setVariable [ "GAIT_tripSustainedSprintSeconds" , 0 ] ;\n'
  'missionNamespace setVariable [ "GAIT_tripSustainedHighSpeedSeconds" , 0 ] ;\n'
  'missionNamespace setVariable [ "GAIT_guaranteeDropTime" , - 999 ] ;\n'
  'missionNamespace setVariable [ "GAIT_lastStrafeAnimTime" , - 999 ] ;\n'
  '} ;',
  '[ ] spawn {\n'
  'waitUntil { sleep 0.25 ; ! isNull player } ;\n'
  'waitUntil { sleep 0.25 ; ! isNull findDisplay 46 } ;\n'
  'private _recoveryTime = 4 ;\n'
  'private _restingAimCoef = 0.02 ;\n'
  'private _runningAimCoef = 2.0 ;\n'
  'missionNamespace setVariable [ "GAIT_shiftHeld" , false ] ;\n'
  'missionNamespace setVariable [ "GAIT_lastShiftRelease" , - 999 ] ;\n'
  'missionNamespace setVariable [ "GAIT_lastForwardKeyRelease" , - 999 ] ;\n'
  'missionNamespace setVariable [ "GAIT_currentAimCoef" , _restingAimCoef ] ;\n'
  'missionNamespace setVariable [ "GAIT_slopeDegrees" , 0 ] ;\n'
  'missionNamespace setVariable [ "GAIT_slopeSpeedMultiplier" , 1 ] ;\n'
  'missionNamespace setVariable [ "GAIT_lastTripTime" , - 999 ] ;\n'
  'missionNamespace setVariable [ "GAIT_tripEligible" , false ] ;\n'
  'missionNamespace setVariable [ "GAIT_downhillTerminalReachedTime" , - 999 ] ;\n'
  'missionNamespace setVariable [ "GAIT_downhillTerminalVelocityKmh" , 35.0 ] ;\n'
  'missionNamespace setVariable [ "GAIT_tripChancePerSecond" , 0 ] ;\n'
  'missionNamespace setVariable [ "GAIT_tripCooldownRemaining" , 0 ] ;\n'
  'missionNamespace setVariable [ "GAIT_tripImmunityRemaining" , 0 ] ;\n'
  'missionNamespace setVariable [ "GAIT_tripSustainedGateReady" , false ] ;\n'
  'missionNamespace setVariable [ "GAIT_tripSustainedSprintSeconds" , 0 ] ;\n'
  'missionNamespace setVariable [ "GAIT_tripSustainedHighSpeedSeconds" , 0 ] ;\n'
  'missionNamespace setVariable [ "GAIT_guaranteeDropTime" , - 999 ] ;\n'
  'missionNamespace setVariable [ "GAIT_lastStrafeAnimTime" , - 999 ] ;\n'
  'player setCustomAimCoef _restingAimCoef ;\n'
  '[ ] spawn {\n'
  'private _restingAimCoef = missionNamespace getVariable [ "GAIT_ss_restingAimCoef" , 0.02 ] ;\n'
  'private _walkingAimCoef = missionNamespace getVariable [ "GAIT_ss_walkingAimCoef" , 0.01 ] ;\n'
  'private _runningAimCoef = missionNamespace getVariable [ "GAIT_ss_runningAimCoef" , 2.0 ] ;\n'
  'private _recoveryTime = missionNamespace getVariable [ "GAIT_ss_swayRecoveryTime" , 6.0 ] ;\n'
  'private _walkingSpeedThreshold = missionNamespace getVariable [ "GAIT_ss_walkingSpeedThreshold" , 0.6 ] '
  ';\n'
  'private _recovering = false ;\n'
  'private _recoveryStartTime = - 999 ;\n'
  'private _recoveryStartCoef = _runningAimCoef ;\n'
  'missionNamespace setVariable [ "GAIT_currentAimCoef" , _restingAimCoef ] ;\n'
  'player setCustomAimCoef _restingAimCoef ;\n'
  'while { true } do {\n'
  'private _swayEnabled = missionNamespace getVariable [ "GAIT_ss_swayEnabled" , true ] ;\n'
  '_restingAimCoef = missionNamespace getVariable [ "GAIT_ss_restingAimCoef" , 0.02 ] ;\n'
  '_walkingAimCoef = missionNamespace getVariable [ "GAIT_ss_walkingAimCoef" , 0.01 ] ;\n'
  '_runningAimCoef = missionNamespace getVariable [ "GAIT_ss_runningAimCoef" , 2.0 ] ;\n'
  '_recoveryTime = missionNamespace getVariable [ "GAIT_ss_swayRecoveryTime" , 6.0 ] ;\n'
  '_walkingSpeedThreshold = missionNamespace getVariable [ "GAIT_ss_walkingSpeedThreshold" , 0.6 ] ;\n'
  'if ( alive player && { call GAIT_fnc_modeAllowsSway } && { _swayEnabled } && { ! ( call '
  'GAIT_fnc_isSuspendedContext ) } ) then {\n'
  'private _isOnFoot = isNull objectParent player ;\n'
  'private _isForwardHeld = ( inputAction "MoveForward" ) > 0.05 ;\n'
  'private _isSprinting = ( ( inputAction "Turbo" ) > 0 ) && { _isForwardHeld } && { _isOnFoot } ;\n'
  'private _isWalking = _isOnFoot && { ! _isSprinting } && { ( abs ( speed player ) ) > '
  '_walkingSpeedThreshold } ;\n'
  'private _baselineAimCoef = if ( _isWalking ) then {\n'
  '_walkingAimCoef\n'
  '} else {\n'
  '_restingAimCoef\n'
  '} ;\n'
  'private _targetAimCoef = _baselineAimCoef ;\n'
  'if ( _isSprinting ) then {\n'
  '_targetAimCoef = _runningAimCoef ;\n'
  '_recovering = false ;\n'
  '_recoveryStartTime = - 999 ;\n'
  '_recoveryStartCoef = _runningAimCoef ;\n'
  'missionNamespace setVariable [ "GAIT_lastShiftRelease" , time ] ;\n'
  '} else {\n'
  'private _currentStored = missionNamespace getVariable [ "GAIT_currentAimCoef" , _baselineAimCoef ] ;\n'
  'if ( ! _recovering && { _currentStored > _baselineAimCoef } ) then {\n'
  '_recovering = true ;\n'
  '_recoveryStartTime = time ;\n'
  '_recoveryStartCoef = _currentStored ;\n'
  '} ;\n'
  'if ( _recovering ) then {\n'
  'private _elapsed = time - _recoveryStartTime ;\n'
  'private _progress = _elapsed / _recoveryTime ;\n'
  '_progress = ( _progress max 0 ) min 1 ;\n'
  '_targetAimCoef = _recoveryStartCoef - ( ( _recoveryStartCoef - _baselineAimCoef ) * _progress ) ;\n'
  'if ( _progress >= 1 ) then {\n'
  '_targetAimCoef = _baselineAimCoef ;\n'
  '_recovering = false ;\n'
  '} ;\n'
  '} ;\n'
  '} ;\n'
  'missionNamespace setVariable [ "GAIT_currentAimCoef" , _targetAimCoef ] ;\n'
  'player setCustomAimCoef _targetAimCoef ;\n'
  '} else {\n'
  'missionNamespace setVariable [ "GAIT_currentAimCoef" , 1 ] ;\n'
  'player setCustomAimCoef 1 ;\n'
  '} ;\n'
  'uiSleep 0.02 ;\n'
  '} ;\n'
  '} ;\n'
  '} ;'),
 ('initial_tuning_and_momentum_state',
  'alpha7 retire native fatigue effect settings',
  'private _carrySprintExhaustedSpeed = missionNamespace getVariable [ "GAIT_ss_carrySprintExhaustedSpeed" , '
  '0.9 ] ;\n'
  'private _hearingMinVolume = missionNamespace getVariable [ "GAIT_ss_hearingMinVolume" , 0.20 ] ;',
  'private _carrySprintExhaustedSpeed = missionNamespace getVariable [ "GAIT_ss_carrySprintExhaustedSpeed" , '
  '0.9 ] ;\n'
  'private _freshFatigue = missionNamespace getVariable [ "GAIT_ss_freshFatigue" , 0.05 ] ;\n'
  'private _exhaustedFatigue = missionNamespace getVariable [ "GAIT_ss_exhaustedFatigue" , 0.85 ] ;\n'
  'private _fatigueRecoverRate = ( _exhaustedFatigue - _freshFatigue ) / _sprintRecoverTime ;\n'
  'private _hearingMinVolume = missionNamespace getVariable [ "GAIT_ss_hearingMinVolume" , 0.20 ] ;'),
 ('initial_tuning_and_momentum_state',
  'alpha7 remove obsolete strength comparison state',
  'private _tunnelMaxStrength = missionNamespace getVariable [ "GAIT_ss_tunnelMaxStrength" , 1.0 ] ;\n'
  'missionNamespace setVariable [ "GAIT_exhaustionLevel" , 0 ] ;',
  'private _tunnelMaxStrength = missionNamespace getVariable [ "GAIT_ss_tunnelMaxStrength" , 1.0 ] ;\n'
  'private _lastTunnelStrength = 0.0 ;\n'
  'missionNamespace setVariable [ "GAIT_exhaustionLevel" , 0 ] ;'),
 ('initial_tuning_and_momentum_state',
  'alpha7 retire native fatigue state and uphill gain',
  'private _uphillFatigueDrainStartDegrees = missionNamespace getVariable [ '
  '"GAIT_ss_uphillFatigueDrainStartDegrees" , 10.0 ] ;\n'
  'private _lastTick = time ;\n'
  'private _currentSpeed = _normalSpeed ;\n'
  'private _wasSprinting = false ;',
  'private _uphillFatigueDrainStartDegrees = missionNamespace getVariable [ '
  '"GAIT_ss_uphillFatigueDrainStartDegrees" , 10.0 ] ;\n'
  'private _uphillVanillaFatigueExtraPerSecond = missionNamespace getVariable [ '
  '"GAIT_ss_uphillVanillaFatigueExtraPerSecond" , 0.018 ] ;\n'
  'private _lastTick = time ;\n'
  'private _currentSpeed = _normalSpeed ;\n'
  'private _visualFatigue = _freshFatigue ;\n'
  'private _wasSprinting = false ;'),
 ('preset_and_reset_state',
  'alpha7 remove retired native fatigue reset',
  '_sprintReserve = _sprintReserveMax ;\n_currentSpeed = _normalSpeed ;\n_wasSprinting = false ;',
  '_sprintReserve = _sprintReserveMax ;\n'
  '_currentSpeed = _normalSpeed ;\n'
  '_visualFatigue = _freshFatigue ;\n'
  '_wasSprinting = false ;'),
 ('preset_and_reset_state',
  'alpha7 remove obsolete strength reset',
  '_downhillTripHighSpeedStartTime = - 1 ;\n[ ] call GAIT_fnc_releaseNativeMovement ;\n} ;',
  '_downhillTripHighSpeedStartTime = - 1 ;\n'
  '_lastTunnelStrength = 0 ;\n'
  '[ ] call GAIT_fnc_releaseNativeMovement ;\n'
  '} ;'),
 ('live_settings_and_reserve_resize',
  'alpha7 remove retired uphill native fatigue refresh',
  '_uphillFatigueDrainStartDegrees = missionNamespace getVariable [ "GAIT_ss_uphillFatigueDrainStartDegrees" '
  ', 10.0 ] ;\n'
  'private _oldSprintReserveMax = _sprintReserveMax ;',
  '_uphillFatigueDrainStartDegrees = missionNamespace getVariable [ "GAIT_ss_uphillFatigueDrainStartDegrees" '
  ', 10.0 ] ;\n'
  '_uphillVanillaFatigueExtraPerSecond = missionNamespace getVariable [ '
  '"GAIT_ss_uphillVanillaFatigueExtraPerSecond" , 0.018 ] ;\n'
  'private _oldSprintReserveMax = _sprintReserveMax ;'),
 ('live_settings_and_reserve_resize',
  'alpha7 remove retired native fatigue refresh',
  '_carrySprintExhaustedSpeed = missionNamespace getVariable [ "GAIT_ss_carrySprintExhaustedSpeed" , 0.9 ] '
  ';\n'
  '_hearingMinVolume = missionNamespace getVariable [ "GAIT_ss_hearingMinVolume" , 0.20 ] ;',
  '_carrySprintExhaustedSpeed = missionNamespace getVariable [ "GAIT_ss_carrySprintExhaustedSpeed" , 0.9 ] '
  ';\n'
  '_freshFatigue = missionNamespace getVariable [ "GAIT_ss_freshFatigue" , 0.05 ] ;\n'
  '_exhaustedFatigue = missionNamespace getVariable [ "GAIT_ss_exhaustedFatigue" , 0.85 ] ;\n'
  '_fatigueRecoverRate = ( _exhaustedFatigue - _freshFatigue ) / ( _sprintRecoverTime max 0.01 ) ;\n'
  '_hearingMinVolume = missionNamespace getVariable [ "GAIT_ss_hearingMinVolume" , 0.20 ] ;'),
 ('reserve_and_exhaustion_effects',
  'alpha7 replace persistent/native fatigue feedback with refreshed vignette lease',
  'private _tunnelStrength = 0 ;\n'
  'if ( _gaitEffectsEnabled && { missionNamespace getVariable [ "GAIT_ss_fatigueVignetteEnabled" , true ] } '
  '&& { _exhaustion > _tunnelStartExhaustion } ) then {\n'
  '_tunnelStrength = linearConversion [ _tunnelStartExhaustion , 1 , _exhaustion , 0 , _tunnelMaxStrength , '
  'true ] ;\n'
  '} ;\n'
  '[ player , _tunnelStrength ] call GAIT_fnc_updateFatigueVisuals ;',
  'private _tunnelStrength = 0 ;\n'
  'if ( _gaitEffectsEnabled && { missionNamespace getVariable [ "GAIT_ss_visualFxEnabled" , true ] } && { '
  '_exhaustion > _tunnelStartExhaustion } ) then {\n'
  '_tunnelStrength = linearConversion [ _tunnelStartExhaustion , 1 , _exhaustion , 0 , _tunnelMaxStrength , '
  'true ] ;\n'
  '} ;\n'
  'if ( abs ( _tunnelStrength - _lastTunnelStrength ) > 0.02 ) then {\n'
  '[ _tunnelStrength ] call GAIT_fnc_setTunnelVisionFX ;\n'
  '_lastTunnelStrength = _tunnelStrength ;\n'
  '} ;\n'
  'if ( _isSprinting && { _sprintReserve <= 0 } ) then {\n'
  '_visualFatigue = _exhaustedFatigue ;\n'
  '} else {\n'
  '_visualFatigue = _visualFatigue - ( _fatigueRecoverRate * _dt ) ;\n'
  'if ( _visualFatigue < _freshFatigue ) then {\n'
  '_visualFatigue = _freshFatigue ;\n'
  '} ;\n'
  '} ;\n'
  'if ( _uphillFatigueDrainSeverityNow > 0 ) then {\n'
  '_visualFatigue = ( _visualFatigue + ( ( _uphillVanillaFatigueExtraPerSecond max 0 ) * '
  '_uphillFatigueDrainSeverityNow * _dt ) ) min _exhaustedFatigue ;\n'
  '} ;\n'
  'if ( ! _aceAdvancedFatigueActive && { _gaitMovementEnabled } && { _movementEligible } ) then {\n'
  'player setFatigue _visualFatigue ;\n'
  '} ;')] + [
    ("trip_ragdoll_recovery", "alpha6 release scoped native stamina before tripping", """
        [] call GAIT_fnc_releaseNativeStaminaOwnership;
        [] call GAIT_fnc_releaseNativeMovement;
        player setVariable ["GAIT_isTripping", true, false];
    """, """
        [] call GAIT_fnc_releaseNativeMovement;
        player setVariable ["GAIT_isTripping", true, false];
    """),
    ("gear_weight_and_brace_relief", "alpha6 similar running brace across gear tiers", """
        private _effectiveBraceRelief = (_braceRelief max 0 min 1) * 0.20;
        private _effectiveBraceSpeed = (_sprintStartBraceSpeed + ((_normalSpeed - _sprintStartBraceSpeed) * _effectiveBraceRelief)) * _weightSpeedMult;
    """, """
        private _effectiveBraceSpeed = (_sprintStartBraceSpeed + ((_normalSpeed - _sprintStartBraceSpeed) * _braceRelief)) * _weightSpeedMult;
    """),
    # Alpha5 corrects the heavy-kit overreach and confines the release curve
    # to held forward input. Exact reversals still target the original RC4 hash.
    ("step_off_brace_and_sprint_end", "alpha5 forward release latch replaces lateral veto", """
        if (_isForwardHeld && {!_isBackHeld} && {!_forwardReleasedSinceTick} && {_movementEligible}) then {
    """, """
        if (_isForwardHeld && {!_isBackHeld} && {!_isLateralHeld} && {_movementEligible}) then {
    """),
    ("shift_release_hold_and_taper", "alpha5 finite forward release curve with endpoint consumption", """
        if (_shiftReleaseRunTaperEnabled && {!_isSprinting} && {_movementEligible} && {!_externalWalkLock} && {!_externalSprintLock} && {_isForwardHeld} && {!_isBackHeld} && {_shiftReleaseTaperActiveUntil >= 0}) then {
            private _releaseCurve = [_shiftReleaseTaperStartSpeed, _targetSpeed,
                (time - _lastShiftReleaseTime) max 0, _activeCoastDuration, _shiftReleaseRunTaperCurve]
                call GAIT_fnc_forwardCoastPace;
            _targetSpeed = (_releaseCurve select 0) min _currentSpeed;
            _shiftReleaseTaperActiveNow = true;
            _shiftReleaseTaperKeepNow = _releaseCurve select 1;
            _shiftReleaseTaperTargetKmhNow = _actualSpeedKmh;
            // Consume the endpoint once even if a delayed tick crosses
            // the deadline; no residual speed or animation tail remains.
            if !(_releaseCurve select 2) then {_shiftReleaseTaperActiveUntil = -999;};
        } else {
            _shiftReleaseTaperActiveUntil = -999;
        };
    """, """
        if (_shiftReleaseRunTaperEnabled && {!_isSprinting} && {_movementEligible} && {!_externalWalkLock} && {!_externalSprintLock} && {!_isLateralHeld} && {_isForwardHeld} && {!_isBackHeld} && {time <= _shiftReleaseTaperActiveUntil}) then {
            private _holdDuration = _activeCoastHold;
            private _taperDuration = _activeCoastDuration;
            private _elapsedSinceShift = (time - _lastShiftReleaseTime) max 0;
            private _taperKeep = 1;
            if (_elapsedSinceShift <= _holdDuration) then {
                _shiftReleaseTaperHoldActiveNow = true;
            } else {
                private _taperRaw = ((_elapsedSinceShift - _holdDuration) / _taperDuration) max 0 min 1;
                private _taperCurve = (_shiftReleaseRunTaperCurve max 0.25) min 5.0;
                _taperKeep = (1 - _taperRaw) ^ _taperCurve;
            };
            private _taperStart = _shiftReleaseTaperStartSpeed max _targetSpeed;
            _targetSpeed = _targetSpeed max (_targetSpeed + ((_taperStart - _targetSpeed) * _taperKeep));
            _shiftReleaseTaperActiveNow = true;
            _shiftReleaseTaperKeepNow = _taperKeep;
            _shiftReleaseTaperTargetKmhNow = _actualSpeedKmh; // measured speed
        } else {
            if (!_isForwardHeld || {_isBackHeld} || {_isLateralHeld} || {_isSprinting} || {!_movementEligible} || {_externalWalkLock} || {_externalSprintLock}) then {
                _shiftReleaseTaperActiveUntil = -999;
            };
        };
    """),
    # Retained snapshot/ownership integration from alpha4, refined by alpha5.
    # Original tier-relief selection and base launch duration remain protected.
    # Every original RC4 digest remains the comparison target.
    ("initial_tuning_and_momentum_state", "alpha4 snapshot load-scaled coast windows", """
        private _shiftReleaseTaperStartSpeed = _normalSpeed;
        private _activeCoastHold = 0;
        private _activeCoastDuration = 0.05;
        private _lastForwardReleaseSerial = -1;
    """, "private _shiftReleaseTaperStartSpeed = _normalSpeed;"),
    ("preset_and_reset_state", "alpha4 reset coast ownership", """
        _lastResetRequestHandled = _resetRequest;
        _uphillBrakeState = [];
        missionNamespace setVariable ["GAIT_uphillBrakeActive", false];
        missionNamespace setVariable ["GAIT_uphillBrakeEndTime", -1];
        missionNamespace setVariable ["GAIT_uphillBrakeReadyUntil", -1];
        missionNamespace setVariable ["GAIT_uphillBrakeUnit", objNull];
        missionNamespace setVariable ["GAIT_coastUnit", objNull];
        missionNamespace setVariable ["GAIT_coastActive", false];
        missionNamespace setVariable ["GAIT_coastReadyUntil", -1];
    """, """
        _lastResetRequestHandled = _resetRequest;
        _uphillBrakeState = [];
        missionNamespace setVariable ["GAIT_uphillBrakeActive", false];
        missionNamespace setVariable ["GAIT_uphillBrakeEndTime", -1];
        missionNamespace setVariable ["GAIT_uphillBrakeReadyUntil", -1];
        missionNamespace setVariable ["GAIT_uphillBrakeUnit", objNull];
    """),
    ("step_off_brace_and_sprint_end", "alpha4 snapshot coast duration at sprint release", """
        private _coastWindow = [_shiftReleaseRunTaperHoldDuration, _shiftReleaseRunTaperDuration, _coastScale] call GAIT_fnc_gearCoastWindow;
        _activeCoastHold = _coastWindow select 0;
        _activeCoastDuration = _coastWindow select 1;
        _shiftReleaseTaperActiveUntil = time + _activeCoastHold + _activeCoastDuration;
    """, """
        _shiftReleaseTaperActiveUntil = time + ((_shiftReleaseRunTaperHoldDuration max 0) min 3.0) + ((_shiftReleaseRunTaperDuration max 0.05) min 4.0);
    """),
    ("shift_release_hold_and_taper", "alpha4 consume unchanged release-time coast snapshot", """
        private _holdDuration = _activeCoastHold;
        private _taperDuration = _activeCoastDuration;
    """, """
        private _holdDuration = (_shiftReleaseRunTaperHoldDuration max 0) min 3.0;
        private _taperDuration = (_shiftReleaseRunTaperDuration max 0.05) min 4.0;
    """),
    ("brace_or_momentum_speed_ramp", "alpha5 mild sprint acceleration and direct release response", """
        if (!_isAceCarrying && {_isSprinting} && {!_uphillBrakeActive} && {_sprintBraceEndTime <= time} && {_rampTarget > _currentSpeed}) then {
            _ramp = [_ramp, _accelerationScale] call GAIT_fnc_scaleInertiaRamp;
        };
        if (_shiftReleaseTaperActiveNow && {!_uphillBrakeActive} && {!_isAceCarrying}) then {
            _currentSpeed = _rampTarget;
        } else {
            _currentSpeed = [_currentSpeed, _rampTarget, _ramp, _dt] call GAIT_fnc_stepSpeedCoefficient;
        };
    """, """
        _currentSpeed = [_currentSpeed, _rampTarget, _ramp, _dt] call GAIT_fnc_stepSpeedCoefficient;
    """),
    # Reverse alpha3 first so the unchanged alpha2 reverse fragments below
    # still describe exactly what was previously reviewed.
    ("preset_and_reset_state", "alpha3 reset uphill brake ownership", """
        _lastResetRequestHandled = _resetRequest;
        _uphillBrakeState = [];
        missionNamespace setVariable ["GAIT_uphillBrakeActive", false];
        missionNamespace setVariable ["GAIT_uphillBrakeEndTime", -1];
        missionNamespace setVariable ["GAIT_uphillBrakeReadyUntil", -1];
        missionNamespace setVariable ["GAIT_uphillBrakeUnit", objNull];
    """, "_lastResetRequestHandled = _resetRequest;"),
    ("step_off_brace_and_sprint_end", "alpha3 sprint resume cancels release brake without new launch brace", """
        private _canBrace = [_sprintStartBraceEnabled, _hasRetainedSprintMomentum || {_uphillBrakeResumed},
            _isCrouched, _braceArmedFromCrouch, _normalBraceReady, _zeroMomentumBraceReady, _slopeBraceReady]
            call GAIT_fnc_shouldBrace;
    """, """
        private _canBrace = [_sprintStartBraceEnabled, _hasRetainedSprintMomentum,
            _isCrouched, _braceArmedFromCrouch, _normalBraceReady, _zeroMomentumBraceReady, _slopeBraceReady]
            call GAIT_fnc_shouldBrace;
    """),
    ("brace_or_momentum_speed_ramp", "alpha3 uphill release target and slope-dependent braking ramp", """
        private _ramp = if (_uphillBrakeActive) then {_uphillBrakeRamp} else {
            if (_isSprinting && {_sprintBraceEndTime > time}) then {_sprintStartBraceLerp} else {_speedLerp}
        };
        private _rampTarget = if (_uphillBrakeActive) then {_uphillBrakeTarget min _currentSpeed} else {
            if (_isSprinting && {_sprintBraceEndTime > time}) then {_activeBraceSpeed min _targetSpeed} else {_targetSpeed}
        };
    """, """
        private _ramp = if (_isSprinting && {_sprintBraceEndTime > time}) then {_sprintStartBraceLerp} else {_speedLerp};
        private _rampTarget = if (_isSprinting && {_sprintBraceEndTime > time}) then {_activeBraceSpeed min _targetSpeed} else {_targetSpeed};
    """),
    ("preset_and_reset_state", "reset new momentum state", """
        _lastResetRequestHandled = _resetRequest;
        _braceMomentumState = [false, -999, 0, 0];
        _downhillMomentum = 0;
        missionNamespace setVariable ["GAIT_braceActive", false];
        missionNamespace setVariable ["GAIT_braceEndTime", -1];
    """, "_lastResetRequestHandled = _resetRequest;"),
    ("directional_grade_trips_and_walk_pace", "sustained load-aware downhill bonus", """
        private _sustainedBonus = missionNamespace getVariable ["GAIT_ss_downhillSustainedExtraBoost", 0.12];
        _slopeSpeedMultiplier = _slopeSpeedMultiplier * ([_slopeDegrees, _gearLbs, _downhillMomentum,
            _downhillBoostStartDegrees, _downhillBoostMaxDegSafe, _downhillMaxBoost + _sustainedBonus]
            call GAIT_fnc_downhillPaceMultiplier);
    """, """
        private _downhillDegForBoost = abs _slopeDegrees;
        private _downhillBoost = linearConversion [_downhillBoostStartDegrees, _downhillBoostMaxDegSafe, _downhillDegForBoost, 0, _downhillMaxBoost, true];
        _slopeSpeedMultiplier = _slopeSpeedMultiplier * (1 + (_downhillBoost max 0 min 0.35));
    """),
    ("step_off_brace_and_sprint_end", "physical stop and retained-momentum readiness", """
        private _hasNoSprintMomentum = !_hasRetainedSprintMomentum && {
            (_currentSpeed <= (_effectiveNormalSpeed + _braceNoMomentumThreshold)) ||
            {_horizontalSpeedMS <= 0.25} || {_forwardReleasedLongEnough}
        };
    """, """
        private _hasNoSprintMomentum =
            (_currentSpeed <= (_effectiveNormalSpeed + _braceNoMomentumThreshold)) ||
            {_forwardReleasedLongEnough};
    """),
    ("step_off_brace_and_sprint_end", "shared momentum veto for every brace trigger", """
        private _canBrace = [_sprintStartBraceEnabled, _hasRetainedSprintMomentum,
            _isCrouched, _braceArmedFromCrouch, _normalBraceReady, _zeroMomentumBraceReady, _slopeBraceReady]
            call GAIT_fnc_shouldBrace;
    """, """
        private _canBrace = _sprintStartBraceEnabled &&
            (_isCrouched || _braceArmedFromCrouch || _normalBraceReady || _zeroMomentumBraceReady || _slopeBraceReady);
    """),
]

AUTHORIZED_SETTINGS_DELTAS = [('alpha7 retire sway category',
  'private _categoryBrace = ["GAIT", "06 Brace Step and Momentum"];\n'
  'private _categoryAudio = ["GAIT", "08 Audio and Hearing"];',
  'private _categoryBrace = ["GAIT", "06 Brace Step and Momentum"];\n'
  'private _categorySway = ["GAIT", "07 Weapon Sway"];\n'
  'private _categoryAudio = ["GAIT", "08 Audio and Hearing"];'),
 ('alpha7 vignette category',
  'private _categoryVisual = ["GAIT", "09 Fatigue Vignette"];',
  'private _categoryVisual = ["GAIT", "09 Tunnel Vision Visuals"];'),
 ('alpha7 master scope without sway',
  '["GAIT_ss_enabled", "Enable GAIT", "Master switch for GAIT\'s sprint, brace, momentum, audio, and visual '
  'systems. Turn off to release GAIT runtime control. The addon terrainSpeedCoef config remains until the '
  'addon is unloaded.", _categoryGeneral, true] call _addCheckbox;',
  '["GAIT_ss_enabled", "Enable GAIT", "Master switch for GAIT\'s sprint, brace, momentum, sway, audio, and '
  'visual systems. Turn off to release GAIT runtime control. The addon terrainSpeedCoef config remains until '
  'the addon is unloaded.", _categoryGeneral, true] call _addCheckbox;'),
 ('alpha7 vignette threshold description',
  '["GAIT_ss_tunnelStartExhaustion", "Visuals start at exhaustion", "Exhaustion level where intermittent '
  'vignette pulses begin. Default: 0.18.", _categoryVisual, 0.00, 1.00, 0.18, 2] call _addSlider;',
  '["GAIT_ss_tunnelStartExhaustion", "Visuals start at exhaustion", "Exhaustion level where tunnel vision '
  'begins. Default: 0.18.", _categoryVisual, 0.00, 1.00, 0.18, 2] call _addSlider;'),
 ('alpha7 bounded vignette strength description',
  '["GAIT_ss_tunnelMaxStrength", "Maximum visual strength", "Scales fatigue vignette pulses; peak edge '
  'opacity is always capped at 14%. Default: 1.0.", _categoryVisual, 0.00, 2.00, 1.00, 2] call _addSlider;',
  '["GAIT_ss_tunnelMaxStrength", "Maximum visual strength", "Overall cap for exhaustion visual strength. '
  'Default: 1.0.", _categoryVisual, 0.00, 2.00, 1.00, 2] call _addSlider;'),
 ('alpha7 reset scope without sway',
  '["GAIT_ss_resetOnRespawn", "Reset effects on respawn", "Automatically clears GAIT movement speed, '
  'hearing, tinnitus, and visual effects when the local player respawns or changes player object. '
  'Recommended: enabled.", _categoryQoL, true] call _addCheckbox;',
  '["GAIT_ss_resetOnRespawn", "Reset effects on respawn", "Automatically clears GAIT movement speed, sway, '
  'hearing, tinnitus, and visual effects when the local player respawns or changes player object. '
  'Recommended: enabled.", _categoryQoL, true] call _addCheckbox;'),
 ('alpha7 compatibility scope without sway',
  '    "Controls how aggressively GAIT overrides movement. Full/Hybrid are intended modes. Minimal keeps '
  'fatigue effects but avoids movement control. Visuals Only avoids movement and hearing changes. Disabled '
  'safely resets GAIT effects.",',
  '    "Controls how aggressively GAIT overrides movement. Full/Hybrid are intended modes. Minimal keeps '
  'fatigue effects but avoids movement control. Visuals Only avoids movement, sway, and hearing changes. '
  'Disabled safely resets GAIT effects.",'),
 ('alpha7 retire native fatigue value sliders',
  '["GAIT_ss_unarmedSprintNormalizer", "Unarmed sprint normalizer", "Multiplier applied when sprinting with '
  'no weapon out so holstering does not create an unrealistic speed boost. Default: 0.725.", _categoryMove, '
  '0.30, 1.20, 0.725, 3] call _addSlider;',
  '["GAIT_ss_unarmedSprintNormalizer", "Unarmed sprint normalizer", "Multiplier applied when sprinting with '
  'no weapon out so holstering does not create an unrealistic speed boost. Default: 0.725.", _categoryMove, '
  '0.30, 1.20, 0.725, 3] call _addSlider;\n'
  '["GAIT_ss_freshFatigue", "Rested visual fatigue", "Lowest vanilla fatigue value used when ACE Advanced '
  'Fatigue is not active. Default: 0.05.", _categoryMove, 0.00, 0.50, 0.05, 2] call _addSlider;\n'
  '["GAIT_ss_exhaustedFatigue", "Exhausted visual fatigue", "Highest vanilla fatigue value used when ACE '
  'Advanced Fatigue is not active. Default: 0.85.", _categoryMove, 0.10, 1.00, 0.85, 2] call _addSlider;'),
 ('alpha7 retire six sway registrations and describe heartbeat patch',
  '["GAIT_ss_tinnitusEnabled", "Enable tinnitus loop", "Enables GAIT tinnitus at high exhaustion. ACE '
  'Medical Feedback owns heartbeat audio; GAIT halves its sample volume.", _categoryAudio, true] call '
  '_addCheckbox;',
  '["GAIT_ss_swayEnabled", "Enable GAIT weapon sway", "Lets GAIT control sprint sway, walking steadiness, '
  'and recovery. Turn off to leave custom aim coefficient at vanilla.", _categorySway, true] call '
  '_addCheckbox;\n'
  '["GAIT_ss_restingAimCoef", "Rested aim coefficient", "Aim sway coefficient when fully recovered and not '
  'moving. Lower is steadier. Default: 0.02.", _categorySway, 0.00, 2.00, 0.02, 2] call _addSlider;\n'
  '["GAIT_ss_walkingAimCoef", "Walking aim coefficient", "Aim sway coefficient while moving but not '
  'sprinting. Default: 0.01.", _categorySway, 0.00, 2.00, 0.01, 2] call _addSlider;\n'
  '["GAIT_ss_runningAimCoef", "Sprint aim penalty", "Aim sway coefficient while sprinting. Higher is more '
  'sway. Default: 2.0.", _categorySway, 0.00, 10.00, 2.00, 2] call _addSlider;\n'
  '["GAIT_ss_swayRecoveryTime", "Sway recovery time", "Seconds for sway to recover after sprinting. Default: '
  '6.", _categorySway, 0.10, 30.00, 6.00, 1] call _addSlider;\n'
  '["GAIT_ss_walkingSpeedThreshold", "Walking sway speed threshold", "Minimum movement speed needed to use '
  'the walking aim coefficient. Default: 0.6.", _categorySway, 0.00, 5.00, 0.60, 2] call _addSlider;\n'
  '["GAIT_ss_tinnitusEnabled", "Enable tinnitus loop", "Enables GAIT tinnitus at high exhaustion. ACE '
  'Advanced Fatigue already owns heartbeat/pulse audio.", _categoryAudio, true] call _addCheckbox;'),
 ('alpha7 replace retired visual toggle with intermittent vignette',
  '["GAIT_ss_fatigueVignetteEnabled", "Intermittent fatigue vignette", "Brief, subtle edge darkening when '
  'tired, separated by fully clear intervals. Replaces only ACE Advanced Fatigue blackout while active. '
  'Clears on recovery, disable or lost updates. Default: enabled.", _categoryVisual, true] call '
  '_addCheckbox;',
  '["GAIT_ss_visualFxEnabled", "Enable tunnel vision visuals", "v1.6.0: GAIT post-process FX (tunnel vision, '
  'blur, chromatic aberration, color correction) are removed; ACE Advanced Fatigue owns visual fatigue. This '
  'toggle no longer applies any screen effect. Default: disabled.", _categoryVisual, false] call '
  '_addCheckbox;'),
 ('alpha7 retire native uphill fatigue slider',
  '["GAIT_ss_uphillFatigueDrainMaxMultiplier", "Uphill max drain multiplier", "Maximum multiplier applied to '
  'sprint stamina drain on steep uphill terrain. 1.75 means 75% faster drain. Default: 1.75.", '
  '_categorySlope, 1.00, 4.00, 1.75, 2] call _addSlider;',
  '["GAIT_ss_uphillFatigueDrainMaxMultiplier", "Uphill max drain multiplier", "Maximum multiplier applied to '
  'sprint stamina drain on steep uphill terrain. 1.75 means 75% faster drain. Default: 1.75.", '
  '_categorySlope, 1.00, 4.00, 1.75, 2] call _addSlider;\n'
  '["GAIT_ss_uphillVanillaFatigueExtraPerSecond", "Uphill visual fatigue gain", "Extra vanilla/visual '
  'fatigue added per second at max uphill drain severity. Default: 0.018.", _categorySlope, 0.00, 0.20, '
  '0.018, 3] call _addSlider;')] + [
    ("alpha6 shorter forward release description", '["GAIT_ss_shiftReleaseRunTaperDuration", "Shift-release taper duration", "Scale for the short forward slowdown. Effective duration is 0.35 times this value and a small load factor, bounded to 0.15-0.45 seconds. Default 0.85 gives about 0.27-0.34 seconds.", _categoryMove, 0.05, 4.00, 0.85, 2] call _addSlider;',
     '["GAIT_ss_shiftReleaseRunTaperDuration", "Shift-release taper duration", "Scale for the short forward slowdown. Effective duration is half this value times a small load factor, bounded to 0.20-0.65 seconds. Default 0.85 gives about 0.38-0.49 seconds.", _categoryMove, 0.05, 4.00, 0.85, 2] call _addSlider;'),
    ("alpha6 light shared-brace description", '["GAIT_ss_lightBraceRelief", "Light kit brace relief", "Small reduction of the shared brace dip for light kits. Applied at 20% strength so every tier keeps a brace. 0 = full dip; 1 = 20% relief. Default: 0.55.", _categoryWeight, 0.00, 1.00, 0.55, 2] call _addSlider;',
     '["GAIT_ss_lightBraceRelief", "Light kit brace relief", "How much the brace-step slowdown is softened for light kits. 0 = full brace; 1 = almost no brace dip. Default: 0.55.", _categoryWeight, 0.00, 1.00, 0.55, 2] call _addSlider;'),
    ("alpha6 medium shared-brace description", '["GAIT_ss_mediumBraceRelief", "Medium kit brace relief", "Small reduction of the shared brace dip for medium kits, applied at 20% strength. Default: 0.35.", _categoryWeight, 0.00, 1.00, 0.35, 2] call _addSlider;',
     '["GAIT_ss_mediumBraceRelief", "Medium kit brace relief", "How much the brace-step slowdown is softened for medium kits. Default: 0.35.", _categoryWeight, 0.00, 1.00, 0.35, 2] call _addSlider;'),
    ("alpha6 moderate shared-brace description", '["GAIT_ss_moderateBraceRelief", "Moderate kit brace relief", "Small reduction of the shared brace dip for moderate kits, applied at 20% strength. Default: 0.18.", _categoryWeight, 0.00, 1.00, 0.18, 2] call _addSlider;',
     '["GAIT_ss_moderateBraceRelief", "Moderate kit brace relief", "How much the brace-step slowdown is softened for moderate kits. Default: 0.18.", _categoryWeight, 0.00, 1.00, 0.18, 2] call _addSlider;'),
    ("alpha6 heavy shared-brace description", '["GAIT_ss_heavyBraceRelief", "Heavy kit brace relief", "Small reduction of the shared brace dip for heavy kits, applied at 20% strength. Default: 0.00.", _categoryWeight, 0.00, 1.00, 0.00, 2] call _addSlider;',
     '["GAIT_ss_heavyBraceRelief", "Heavy kit brace relief", "How much the brace-step slowdown is softened for heavy kits. Default: 0.00.", _categoryWeight, 0.00, 1.00, 0.00, 2] call _addSlider;'),
    ("alpha5 release Enabled label/description", '["GAIT_ss_shiftReleaseRunTaperEnabled", "Smooth Shift-release taper", "Release Shift while holding W to slow smoothly over a short bounded interval. Releasing W cancels the coast; forward diagonals remain responsive. Default: enabled.", _categoryMove, true] call _addCheckbox;',
     '["GAIT_ss_shiftReleaseRunTaperEnabled", "Smooth Shift-release taper", "When Shift is released but W remains held, GAIT keeps current running speed briefly and smoothly tapers to normal W movement instead of snapping down. Default: enabled.", _categoryMove, true] call _addCheckbox;'),
    ("alpha5 release Duration label/description", '["GAIT_ss_shiftReleaseRunTaperDuration", "Shift-release taper duration", "Scale for the short forward slowdown. Effective duration is half this value times a small load factor, bounded to 0.20-0.65 seconds. Default 0.85 gives about 0.38-0.49 seconds.", _categoryMove, 0.05, 4.00, 0.85, 2] call _addSlider;',
     '["GAIT_ss_shiftReleaseRunTaperDuration", "Shift-release taper duration", "Seconds used to taper from sustained run speed to W-only speed after releasing Shift while holding W. Default: 0.85 sec.", _categoryMove, 0.05, 4.00, 0.85, 2] call _addSlider;'),
    ("alpha5 release HoldDuration label/description", '["GAIT_ss_shiftReleaseRunTaperHoldDuration", "Shift-release sustain (inactive)", "Legacy setting retained for saved profiles. Slowdown now begins immediately, so this value no longer changes movement.", _categoryMove, 0.00, 3.00, 1.00, 2] call _addSlider;',
     '["GAIT_ss_shiftReleaseRunTaperHoldDuration", "Shift-release sustain", "Seconds to hold the previous running speed after releasing Shift while W remains held before tapering down. Default: 1.00 sec.", _categoryMove, 0.00, 3.00, 1.00, 2] call _addSlider;'),
    ("alpha5 release Curve label/description", '["GAIT_ss_shiftReleaseRunTaperCurve", "Shift-release taper curve", "Shapes the smooth release curve: higher values lose pace sooner. Effective range is 1-3. The slowdown still reaches its endpoint within the bounded duration. Default: 1.45.", _categoryMove, 0.25, 5.00, 1.45, 2] call _addSlider;',
     '["GAIT_ss_shiftReleaseRunTaperCurve", "Shift-release taper curve", "Higher values hold speed briefly then brake later; lower values taper more linearly. Default: 1.45.", _categoryMove, 0.25, 5.00, 1.45, 2] call _addSlider;'),
    ("alpha3 uphill release checkbox", '''
        ["GAIT_ss_uphillReleaseBraceEnabled", "Uphill sprint-release brace", "Dig-in braking when releasing a moving uphill sprint. Uses the slope brace start/max angles, duration and dip; steeper slopes brake harder. Flat/downhill momentum is preserved. Default: enabled.", _categoryBrace, true] call _addCheckbox;
    ''', ""),
    ("brace description", '\"Coefficient margin used to detect settled walking. Established moving sprint momentum overrides all brace triggers until a real stop or settled recovery. Default: 0.04.\"',
     '\"If current speed is within this amount of normal speed, next sprint start is treated as zero momentum and braces. Default: 0.04.\"'),
    ("downhill description and label", '\"Downhill base speed boost\", \"Base unloaded downhill bonus at full momentum, added to the sustained bonus below. Both scale down with kit weight and extreme descent angle. Default: 0.06.\"',
     '\"Downhill max speed boost\", \"Maximum sprint speed increase when running downhill. 0.06 means up to 6% faster. Default: 0.06.\"'),
    ("sustained bonus slider", '''
        ["GAIT_ss_downhillSustainedExtraBoost", "Sustained downhill bonus", "Additional unloaded downhill bonus built by actual sprint travel. Combined bonus is capped at 35%, reduced by kit weight, and tapered above 35 degrees. Zero removes this extra bonus. Default: 0.12.", _categorySlope, 0.00, 0.25, 0.12, 2] call _addSlider;
    ''', ""),
    ("momentum build slider", '''
        ["GAIT_ss_downhillMomentumBuildSeconds", "Downhill momentum build time", "Seconds of actual sprint travel to build 95% of downhill momentum. Moving sprint releases retain it; a real stop clears it. Default: 2.5 seconds.", _categorySlope, 0.50, 8.00, 2.50, 2] call _addSlider;
    ''', ""),
]

# Exact original preset bytes are retained as the comparison target.
AUTHORIZED_PRESET_DELTAS = [('alpha7 retired preset entries group 1',
  b'    ["GAIT_ss_hearingMinVolume", 0.20],\n',
  b'    ["GAIT_ss_hearingMinVolume", 0.20],\n    ["GAIT_ss_runningAimCoef", 2.00],\n    ["GAIT_ss_swayReco'
  b'veryTime", 6.00],\n'),
 ('alpha7 retired preset entries group 2',
  b'            ["GAIT_ss_tunnelMaxStrength", 1.10],\n',
  b'            ["GAIT_ss_tunnelMaxStrength", 1.10],\n            ["GAIT_ss_runningAimCoef", 2.35],\n'),
 ('alpha7 retired preset entries group 3',
  b'            ["GAIT_ss_hearingMinVolume", 0.60],\n',
  b'            ["GAIT_ss_hearingMinVolume", 0.60],\n            ["GAIT_ss_runningAimCoef", 1.25],\n      '
  b'      ["GAIT_ss_swayRecoveryTime", 3.00],\n'),
 ('alpha7 retired preset entries group 4',
  b'            ["GAIT_ss_heavyBraceRelief", 0.00],\n',
  b'            ["GAIT_ss_heavyBraceRelief", 0.00],\n            ["GAIT_ss_runningAimCoef", 2.50],\n'),
 ('alpha7 retired preset entries group 5',
  b'    ["GAIT_ss_uphillFatigueDrainMaxMultiplier", 1.75],\n',
  b'    ["GAIT_ss_uphillFatigueDrainMaxMultiplier", 1.75],\n    ["GAIT_ss_uphillVanillaFatigueExtraPerSecond"'
  b', 0.018],\n'),
 ('alpha7 retired Training sway final entry',
  b'            ["GAIT_ss_hearingMinVolume", 0.15]\n',
  b'            ["GAIT_ss_hearingMinVolume", 0.15],\n            ["GAIT_ss_runningAimCoef", 2.20]\n')]

# Source integration complements the mocked engine boundary in the stamina
# lifecycle suite. It protects ordering and cleanup, not Arma's runtime result.
NATIVE_STAMINA_INTEGRATION = [
    (MAIN_FILE, "native stamina acquisition before active-context and permission gates", """
        [player] call GAIT_fnc_updateNativeStaminaOwnership;
        if (alive player && {call GAIT_fnc_modeIsActive} && {!(call GAIT_fnc_isSuspendedContext)}) then {
    """),
    (MAIN_FILE, "native stamina release before trip ownership", """
        [] call GAIT_fnc_releaseNativeStaminaOwnership;
        [] call GAIT_fnc_releaseNativeMovement;
        player setVariable ["GAIT_isTripping", true, false];
    """),
    (MAIN_FILE, "native stamina release on player replacement", """
        if (!isNull player && {player != _lastPlayer}) then {
            [] call GAIT_fnc_releaseFatigueVisuals;
            [] call GAIT_fnc_releaseNativeStaminaOwnership;
            [] call GAIT_fnc_releaseNativeMovement;
            _lastPlayer = player;
    """),
    ("addons/gait/functions/fn_resetEffects.sqf", "native stamina release on reset", """
        if (!isNil "GAIT_fnc_releaseNativeStaminaOwnership") then {
            [] call GAIT_fnc_releaseNativeStaminaOwnership;
        };
    """),
]



# Runtime call sites complement engine-adapter behavioral suites.
FATIGUE_VISUAL_INTEGRATION = [
    ("addons/gait/functions/fn_fatigueVisuals.sqf", "medical and trip context reject fatigue vignette", 'if (_unit getVariable ["ACE_isUnconscious", false] || {(lifeState _unit) isEqualTo "INCAPACITATED"} || {_unit getVariable ["GAIT_isTripping", false]}) exitWith {false};'),('addons/gait/functions/fn_initSprintSystem.sqf',
  'compile fatigue bridge and vignette helpers before controller installation',
  'call compile preprocessFileLineNumbers "\\gait\\functions\\fn_aceFatigueVisualBridge.sqf";\n'
  'call compile preprocessFileLineNumbers "\\gait\\functions\\fn_fatigueVisuals.sqf";\n'
  '[] call GAIT_fnc_installLocomotionController;'),
 ('addons/gait/functions/fn_initSprintSystem.sqf',
  'start independent visual watchdog after legacy cleanup',
  '[0, true] call GAIT_fnc_setTunnelVisionFX;\n[] call GAIT_fnc_startFatigueVisualWatchdog;'),
 ('addons/gait/functions/fn_initSprintSystem.sqf',
  'refresh visual lease unconditionally after strength calculation',
  'private _tunnelStrength = 0;\n'
  'if (_gaitEffectsEnabled && {missionNamespace getVariable ["GAIT_ss_fatigueVignetteEnabled", true]} && '
  '{_exhaustion > _tunnelStartExhaustion}) then {\n'
  '_tunnelStrength = linearConversion [_tunnelStartExhaustion, 1, _exhaustion, 0, _tunnelMaxStrength, '
  'true];\n'
  '};\n'
  '[player, _tunnelStrength] call GAIT_fnc_updateFatigueVisuals;'),
 ('addons/gait/functions/fn_initSprintSystem.sqf',
  'release fatigue visuals before trip',
  '[] call GAIT_fnc_releaseFatigueVisuals;\n'
  '[] call GAIT_fnc_releaseNativeStaminaOwnership;\n'
  '[] call GAIT_fnc_releaseNativeMovement;\n'
  'player setVariable ["GAIT_isTripping", true, false];'),
 ('addons/gait/functions/fn_initSprintSystem.sqf',
  'release fatigue visuals on player replacement',
  'if (!isNull player && {player != _lastPlayer}) then {\n'
  '[] call GAIT_fnc_releaseFatigueVisuals;\n'
  '[] call GAIT_fnc_releaseNativeStaminaOwnership;'),
 ('addons/gait/functions/fn_initSprintSystem.sqf',
  'release fatigue visuals on disabled or suspended context',
  '[] call GAIT_fnc_releaseFatigueVisuals;\n'
  '[0, true] call GAIT_fnc_setTunnelVisionFX;\n'
  '_lastHearingVolume = 1;'),
 ('addons/gait/functions/fn_resetEffects.sqf',
  'release fatigue visuals on safety reset',
  'if (!isNil "GAIT_fnc_releaseFatigueVisuals") then {[] call GAIT_fnc_releaseFatigueVisuals;};'),
 ('addons/gait/functions/fn_fatigueVisuals.sqf',
  'restore owned ACE visual feedback when releasing GAIT',
  'if (!isNil "GAIT_fnc_releaseACEFatigueVisualOwnership") then {\n'
  '[] call GAIT_fnc_releaseACEFatigueVisualOwnership;\n'
  '};')]

# Alpha7 explicitly removes GAIT's aim/fatigue writers. Inspect executable
# tokens in every shipped function so a second writer cannot reappear outside
# the historical blocks. ACE's own physiology remains outside GAIT ownership.
FORBIDDEN_WEAPON_WRITES = {"setcustomaimcoef", "setfatigue", "setunitrecoilcoefficient"}


def reverse_exact_bytes(data: bytes, current: bytes, old: bytes,
                        label: str, failures: list[str]) -> bytes:
    count = data.count(current)
    if not current or count != 1:
        failures.append(f"Authorized delta {label}: expected one exact current byte fragment, found {count}")
        return data
    return data.replace(current, old, 1)


def reverse_exact_delta(values: list[str], current: str, old: str,
                        label: str, failures: list[str]) -> list[str]:
    needle = tokenize(current)
    matches = [i for i in range(len(values) - len(needle) + 1)
               if values[i:i + len(needle)] == needle]
    if len(matches) != 1:
        failures.append(f"Authorized delta {label}: expected one exact current fragment, found {len(matches)}")
        return values
    start = matches[0]
    return values[:start] + tokenize(old) + values[start + len(needle):]


def verify(root: Path) -> tuple[list[str], dict[str, str]]:
    failures: list[str] = []
    locations: dict[str, str] = {}
    for relative, expected in BYTE_FILES.items():
        path = root / relative
        if not path.is_file():
            failures.append(f"Missing unchanged tuning file: {relative}")
        elif relative == SETTINGS_FILE:
            settings = tokenize(path.read_text(encoding="utf-8-sig"))
            for label, current, old in AUTHORIZED_SETTINGS_DELTAS:
                settings = reverse_exact_delta(settings, current, old,
                                               f"{SETTINGS_FILE}: {label}", failures)
            if token_digest(settings) != SETTINGS_RC4_TOKEN_SHA256:
                failures.append(f"Registration code differs beyond exact authorized settings deltas through alpha7: {relative}")
        else:
            data = path.read_bytes()
            if relative == PRESETS_FILE:
                for label, current, old in AUTHORIZED_PRESET_DELTAS:
                    data = reverse_exact_bytes(data, current, old, f"{PRESETS_FILE}: {label}", failures)
            if hashlib.sha256(data).hexdigest() != expected:
                failures.append(f"Tuning file bytes differ beyond authorized removals from RC4: {relative}")
    sources = {}
    for path in sorted((root / "addons/gait/functions").glob("*.sqf")):
        sources[str(path.relative_to(root))] = tokenize(path.read_text(encoding="utf-8-sig"))
    for relative, values in sources.items():
        forbidden = FORBIDDEN_WEAPON_WRITES.intersection(value.lower() for value in values)
        if forbidden:
            failures.append(f"Weapon handling ownership: forbidden GAIT writer {sorted(forbidden)} in {relative}")
    for relative, label, current in NATIVE_STAMINA_INTEGRATION + FATIGUE_VISUAL_INTEGRATION:
        values = sources.get(relative, [])
        needle = tokenize(current)
        matches = sum(values[i:i + len(needle)] == needle
                      for i in range(len(values) - len(needle) + 1))
        if matches != 1:
            failures.append(f"Integration {label}: expected one exact executable fragment, found {matches}")
    if MAIN_FILE in sources:
        for feature, label, current, old in AUTHORIZED_BLOCK_DELTAS:
            sources[MAIN_FILE] = reverse_exact_delta(sources[MAIN_FILE], current, old,
                                                     f"{feature}: {label}", failures)
    for block in BLOCKS:
        matches = []
        width = block["token_count"]
        prefix = block["prefix"]
        for relative, values in sources.items():
            for index, value in enumerate(values):
                if value != prefix[0] or values[index:index + len(prefix)] != prefix:
                    continue
                if token_digest(values[index:index + width]) == block["sha256"]:
                    matches.append(relative)
        if len(matches) == 1:
            locations[block["name"]] = matches[0]
        else:
            line_ref = ":".join(map(str, block["baseline_lines"]))
            failures.append(
                f"Protected block {block['name']}: expected one intact executable copy, "
                f"found {len(matches)} (RC4 {block['baseline_file']}:{line_ref})"
            )
    return failures, locations


def self_test(root: Path) -> None:
    """Prove real regressions fail, and harmless formatting cannot fail a block."""
    assert tokenize('a = "// retained /* text */"; // removed\nb = 1;') == [
        "a", "=", '"// retained /* text */"', ";", "b", "=", "1", ";"
    ]
    assert tokenize('a/* note */=1;') == tokenize('a = 1;')
    baseline_failures, locations = verify(root)
    if baseline_failures:
        raise AssertionError("Mutation self-test requires a passing project first")
    mutations = [
        ("step_off_brace_and_sprint_end", "max 0.08", "max 0.10"),
        ("step_off_brace_and_sprint_end", "_reserveRatioForBrace >= _braceMinReserveRatio", "_reserveRatioForBrace > _braceMinReserveRatio"),
        ("shift_release_hold_and_taper", "_targetSpeed = (_releaseCurve select 0) min _currentSpeed;", "_targetSpeed = (_releaseCurve select 0) max _currentSpeed;"),
        ("sprint_pace_gate", "_turboHeld && {_isForwardHeld}", "_turboHeld && {_isForwardHeld || {_isLateralHeld}}"),
        ("frame_rate_independent_ramp", "(_dt max 0 min 0.20) / 0.05", "(_dt max 0 min 0.20) / 0.10"),
        ("step_off_brace_and_sprint_end", "private _canBrace = [_sprintStartBraceEnabled, _hasRetainedSprintMomentum || {_uphillBrakeResumed},", "private _canBrace = [_sprintStartBraceEnabled, false,"),
        ("step_off_brace_and_sprint_end", "_hasRetainedSprintMomentum || {_uphillBrakeResumed}", "_hasRetainedSprintMomentum || {false}"),
        ("brace_or_momentum_speed_ramp", "_uphillBrakeTarget min _currentSpeed", "_uphillBrakeTarget max _currentSpeed"),
        ("directional_grade_trips_and_walk_pace", "_downhillMaxBoost + _sustainedBonus", "_downhillMaxBoost + 0.35"),
        ("step_off_brace_and_sprint_end", "_sprintStartBraceDuration +", "(_sprintStartBraceDuration * 1.28) +"),
        ("gear_weight_and_brace_relief", "_braceRelief = _lightBraceRelief;", "_braceRelief = _heavyBraceRelief;"),
        ("gear_weight_and_brace_relief", "(_braceRelief max 0 min 1) * 0.20", "(_braceRelief max 0 min 1) * 0.25"),
        ("shift_release_hold_and_taper", "&& {_isForwardHeld} && {!_isBackHeld} && {_shiftReleaseTaperActiveUntil >= 0}", "&& {!_isBackHeld} && {_shiftReleaseTaperActiveUntil >= 0}"),
        ("shift_release_hold_and_taper", "if !(_releaseCurve select 2) then {_shiftReleaseTaperActiveUntil = -999;};", "if !(_releaseCurve select 2) then {_shiftReleaseTaperActiveUntil = time + 6;};"),
        ("brace_or_momentum_speed_ramp", "_currentSpeed = _rampTarget;", "_currentSpeed = [_currentSpeed, _rampTarget, _ramp, _dt] call GAIT_fnc_stepSpeedCoefficient;"),
    ]
    with tempfile.TemporaryDirectory(prefix="gait-feature-preservation-") as directory:
        copy = Path(directory)
        shutil.copytree(root / "addons/gait/functions", copy / "addons/gait/functions")
        for feature, before, after in mutations:
            path = copy / locations[feature]
            original = path.read_text(encoding="utf-8-sig")
            if before not in original:
                raise AssertionError(f"Mutation anchor unavailable: {feature}")
            path.write_text(original.replace(before, after, 1), encoding="utf-8")
            failures, _ = verify(copy)
            assert any(feature in failure for failure in failures), feature
            path.write_text(original, encoding="utf-8")
        for relative, label, before in [
            (MAIN_FILE, "native stamina acquisition", "[player] call GAIT_fnc_updateNativeStaminaOwnership;"),
            ("addons/gait/functions/fn_resetEffects.sqf", "native stamina release on reset", "[] call GAIT_fnc_releaseNativeStaminaOwnership;"),
            (MAIN_FILE, "start independent visual watchdog", "[] call GAIT_fnc_startFatigueVisualWatchdog;"),
            (MAIN_FILE, "refresh visual lease", "[player, _tunnelStrength] call GAIT_fnc_updateFatigueVisuals;"),
            ("addons/gait/functions/fn_resetEffects.sqf", "release fatigue visuals on safety reset", "[] call GAIT_fnc_releaseFatigueVisuals;"),
            ("addons/gait/functions/fn_fatigueVisuals.sqf", "restore owned ACE visual feedback", "[] call GAIT_fnc_releaseACEFatigueVisualOwnership;"),
            ("addons/gait/functions/fn_fatigueVisuals.sqf", "medical and trip context", 'if (_unit getVariable ["ACE_isUnconscious", false] || {(lifeState _unit) isEqualTo "INCAPACITATED"} || {_unit getVariable ["GAIT_isTripping", false]}) exitWith {false};'),
        ]:
            path = copy / relative
            original = path.read_text(encoding="utf-8-sig")
            assert original.count(before) == 1, label
            path.write_text(original.replace(before, "", 1), encoding="utf-8")
            assert any(label in failure for failure in verify(copy)[0]), label
            path.write_text(original, encoding="utf-8")
        # No file outside the legacy sway block may reclaim aim or native
        # fatigue. These are executable mutations, not comments/string matches.
        writer_probe = copy / "addons/gait/functions/fn_weaponWriterProbe.sqf"
        for command in ("setCustomAimCoef", "setFatigue", "setUnitRecoilCoefficient"):
            writer_probe.write_text(f"player {command} 0.1;\n", encoding="utf-8")
            assert any("Weapon handling ownership" in failure for failure in verify(copy)[0]), command
        writer_probe.unlink()
        settings = copy / "addons/gait/functions/fn_registerSettings.sqf"
        original_bytes = settings.read_bytes()
        settings.write_bytes(original_bytes.replace(b"0.00, 0.50, 0.04, 2", b"0.00, 0.50, 0.05, 2", 1))
        failures, _ = verify(copy)
        assert any("fn_registerSettings.sqf" in failure for failure in failures)
        settings.write_bytes(original_bytes)
        # Moving an intact feature block to a helper remains valid, while a
        # commented-out copy does not count as executable preservation.
        feature = next(b for b in BLOCKS if b["name"] == "frame_rate_independent_ramp")
        original_path = copy / locations[feature["name"]]
        original_text = original_path.read_text(encoding="utf-8-sig")
        start = original_text.index("GAIT_fnc_stepSpeedCoefficient = {")
        end = original_text.index("\n};", start) + len("\n};")
        extracted = original_text[start:end]
        original_path.write_text(original_text[:start] + original_text[end:], encoding="utf-8")
        extracted_path = copy / "addons/gait/functions/fn_preservationExtractionProbe.sqf"
        extracted_path.write_text(extracted, encoding="utf-8")
        assert not verify(copy)[0], "Intact extraction should preserve the feature"
        extracted_path.write_text("/*\n" + extracted + "\n*/", encoding="utf-8")
        assert any(feature["name"] in f for f in verify(copy)[0]), "A comment cannot preserve executable code"
    print("PASS mutation checks: unauthorized brace dip/duration, gear-relief anchors/scale, reserve gate, forward release target/gate/endpoint, sprint gate, ramp timing/direct response, momentum veto, release-resume veto, brake target direction, downhill integration, setting default, missing stamina acquisition/reset, missing vignette watchdog/update/cleanup, and reintroduced aim/fatigue/recoil writers are rejected; intact extraction is accepted")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    failures, locations = verify(root)
    if failures:
        for failure in failures:
            print("FAIL " + failure)
        return 1
    changed_blocks = {delta[0] for delta in AUTHORIZED_BLOCK_DELTAS}
    print("PASS original slope pace bytes; preset bytes match after eight exact retired-entry restorations; original registrations match after exact reviewed deltas through alpha7")
    print(f"PASS {len(BLOCKS) - len(changed_blocks)} intact RC4 feature blocks; {len(changed_blocks)} blocks with {len(AUTHORIZED_BLOCK_DELTAS)} exact authorized deltas; all historical hashes retained")
    print(f"PASS {len(NATIVE_STAMINA_INTEGRATION)} stamina and {len(FATIGUE_VISUAL_INTEGRATION)} visual lifecycle source integrations; no GAIT aim/fatigue/recoil writers")
    for feature, relative in locations.items():
        print(f"  {feature}: {relative}")
    if args.self_test:
        self_test(root)
    print("This checks source preservation; run the SQF behavioral tests and in-game acceptance separately.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
