/*
    GAIT locomotion foundation.
    The tuned feature loop submits intent; one Draw3D handler owns animation
    entry. Arma chooses direction inside the family. Input edges can change
    gait, and an eligible uphill sprint can recover its graph once if it exits.
    Lateral motion retains ownership while Turbo remains held. A deliberate
    stop returns to native idle immediately; coefficient inertia never supplies
    movement input. Release follows live keys while speed tapers separately.
    The original numerical brace acts inside the run/sprint clip immediately.
    Entry and sprint-to-walk use graph interpolation. Full stops blend into
    native action maps so the next input can take effect immediately.
*/


// Engine boundary kept behind one adapter so pure dispatcher regressions can
// exercise ownership/order without requiring SQF-VM to implement animationState.
GAIT_fnc_readLocomotionAnimation = {
    params [["_unit", objNull, [objNull]]];
    animationState _unit
};

GAIT_fnc_readLocomotionStance = {
    params [["_unit", objNull, [objNull]]];
    stance _unit
};

GAIT_fnc_readLocomotionForcedWalk = {
    params [["_unit", objNull, [objNull]]];
    isForcedWalk _unit
};

GAIT_fnc_readLocomotionWalkToggle = {
    params [["_unit", objNull, [objNull]]];
    isWalking _unit
};

GAIT_fnc_readLocomotionSprintAllowed = {
    params [["_unit", objNull, [objNull]]];
    isSprintAllowed _unit
};

// Pure directional selection shared by entry, release and regression tests.
GAIT_fnc_slopeDirection = {
    params [["_forward", 0, [0]], ["_right", 0, [0]]];
    if (abs _forward <= 0.05 && {abs _right <= 0.05}) exitWith {"Dnon"};
    private _angle = _right atan2 _forward;
    private _index = floor (((_angle + 382.5) mod 360) / 45);
    ["Df", "Dfr", "Dr", "Dbr", "Db", "Dbl", "Dl", "Dfl"] select _index
};

GAIT_fnc_slopeStateName = {
    params ["_family", "_direction", ["_sprinting", true, [false]], ["_pose", "Perc"], ["_walk", false], ["_combat", false]];
    private _pace = "Mrun";
    if (_direction isEqualTo "Dnon") then {
        _pace = "Mstp";
    } else {
        if (_walk) then {_pace = "Mwlk";};
        if (_combat) then {_pace = "Mtac";};
        if (_sprinting && {_direction in ["Df", "Dfl", "Dfr"]} &&
            {!(_pose isEqualTo "Pknl" && {_family isEqualTo "SlowWpst"})}) then {_pace = "Meva";};
    };
    private _suffix = "_GAIT";
    // Lateral/back sprint uses the same native Mrun clip as ordinary jogging,
    // but it MUST retain sprint-owned actions so the next A/D/W direction
    // change cannot fall into the jog map while Shift is still held.
    if (_sprinting && {_pace isEqualTo "Mrun"}) then {
        _suffix = "_GAITSprint";
    };
    "Amov" + _pose + _pace + _family + _direction + _suffix
};

GAIT_fnc_nativeOrdinaryMoveName = {
    params ["_family", "_direction", "_walkSelected", ["_pose", "Perc"], ["_combat", false]];
    private _pace = ["Mrun", "Mwlk"] select _walkSelected;
    if (_combat) then {_pace = "Mtac";};
    private _variant = ["", "_ver2"] select (_combat && {_pose isEqualTo "Perc"} && {_family isEqualTo "SlowWrfl"} &&
        {!(missionNamespace getVariable ["GAIT_animateWalkLoaded", false])});
    "Amov" + _pose + _pace + _family + _direction + _variant
};

GAIT_fnc_movingAimTarget = {
    params ["_animation", "_direction", ["_fireRelease",false]];
    private _name = toLower _animation;
    private _pace = _name select [8, 4];
    if (!((_name select [0, 8]) in ["amovperc", "amovpknl"]) || {!(_pace in ["mwlk", "mrun", "mtac"] || {_fireRelease && {_pace in ["mstp","meva","mspr"]}})} ||
        {(_name find "_amov") >= 0} || {_direction isEqualTo "Dnon" && {!_fireRelease}}) exitWith {""};
    private _family = switch (_name select [12, 8]) do {
        case "sraswrfl";
        case "slowwrfl": {"SrasWrfl"};
        case "sraswpst";
        case "slowwpst": {"SrasWpst"};
        case "sraswlnr";
        case "slowwlnr": {"SrasWlnr"};
        default {""};
    };
    if (_family isEqualTo "") exitWith {""};
    private _pose = ["Perc", "Pknl"] select ((_name select [4, 4]) isEqualTo "pknl");
    if (_direction isEqualTo "Dnon") exitWith {"Amov" + _pose + "Mstp" + _family + "Dnon"};
    [_family, _direction, _pace isEqualTo "mwlk", _pose, _pace isNotEqualTo "mwlk"]
        call GAIT_fnc_nativeOrdinaryMoveName
};

GAIT_fnc_yieldMovingOptics = {
    params ["_unit", "_input"];
    if (_input select 2) exitWith {false};
    private _direction = [_input select 0, _input select 1] call GAIT_fnc_slopeDirection;
    private _fire = [_unit] call GAIT_fnc_readFireInput;
    if (_direction isEqualTo "Dnon" && {!_fire}) exitWith {false};
    private _animation = [_unit] call GAIT_fnc_readLocomotionAnimation;
    // Only GAIT's own body or carry can authorize a fire handoff. A custom
    // slope jog can persist after the deceleration timer has already ended.
    private _fireRelease = _fire && {([_animation] call GAIT_fnc_isSlopeLocomotionState) ||
        {(toLower _animation find "_gaitsprintstop") >= 0} || {(toLower gestureState _unit find "gait_riflerun_") == 0}};
    private _target = [_animation, _direction, _fireRelease] call GAIT_fnc_movingAimTarget;
    if (_target isEqualTo "") exitWith {false};
    if (diag_tickTime > (_unit getVariable ["GAIT_movingAimUntil", -1])) then {
        _unit setVariable ["GAIT_movingAimIssued", false];
    };
    if (call GAIT_fnc_readAimInput || {_fireRelease}) then {
        _unit setVariable ["GAIT_movingAimUntil", diag_tickTime + 0.25];
    };
    if (diag_tickTime > (_unit getVariable ["GAIT_movingAimUntil", -1])) exitWith {false};
    if (!(call GAIT_fnc_modeAllowsMovement) || {call GAIT_fnc_isSuspendedContext}) exitWith {false};
    private _name = toLower _animation;
    private _aimingPose = (_name select [8, 4]) + (_name select [12, 8]);
    private _targetPose = (toLower _target select [8, 4]) + (toLower _target select [12, 8]);
    private _customMove = ([_animation] call GAIT_fnc_slopeAnimationFamily) isNotEqualTo "";
    if (_fireRelease && {[_unit] call GAIT_fnc_readWeaponSwitching || {[_unit] call GAIT_fnc_hasProtectedLocomotionGesture}}) exitWith {false};
    if (_fireRelease && {(toLower gestureState _unit find "gait_riflerun_") == 0}) then {
        [_unit,false] call GAIT_fnc_updateRifleRun;
    };
    if ((_customMove || {_fireRelease} || {_aimingPose isNotEqualTo _targetPose}) &&
        {!(_unit getVariable ["GAIT_movingAimIssued", false])} &&
        {isClass (configFile >> "CfgMovesMaleSdr" >> "States" >> _target)} &&
        {[_unit, false] call GAIT_fnc_nativeMovementEligible}) then {
        if (_customMove || {_unit getVariable ["GAIT_sprintReleaseJog", false]}) then {
            private _releasePace = _unit getVariable ["GAIT_sprintReleasePace", []];
            [_unit] call GAIT_fnc_beginNativeReleaseDirection;
            _unit setVariable ["GAIT_sprintReleasePace", _releasePace];
            if (_releasePace isNotEqualTo []) then {
                _unit setVariable ["GAIT_sprintReleaseMode", ["combat", "walk"] select ((_name select [8, 4]) isEqualTo "mwlk")];
            };
        };
        _unit setVariable ["GAIT_movingAimIssued", true];
        private _progress = ([_unit] call GAIT_fnc_readPaceMoveInfo) param [0, 0, [0]];
        if (missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false]) then {
            diag_log format ["[GAIT_LOCOMOTION] %1 handoff %2 -> %3", ["optics","fire"] select _fireRelease, _animation, _target];
        };
        [_unit, _target, (_progress max 0 min 1) mod 1, 0.25] call GAIT_fnc_blendNativeLocomotion;
    };
    true
};

GAIT_fnc_locomotionPoseSnapshot = {
    params ["_weapon", "_animation", "_previous", ["_walkSelected", false]];
    private _prior = if (_previous isNotEqualTo [] && {(_previous select 0) isEqualTo _weapon}) then {_previous} else {[]};
    private _name = [_animation] call GAIT_fnc_compatibleIdleName;
    if (!((_name select [0, 8]) in ["amovperc", "amovpknl"]) ||
        {(_name find "_amov") >= 0} || {"gaitsprint" in (_name splitString "_")}) exitWith {_prior};
    private _stanceFamily = _name select [12, 8];
    private _families = ["SrasWrfl", "SlowWrfl", "SrasWpst", "SlowWpst", "SnonWnon", "SrasWlnr"];
    private _familyIndex = ["sraswrfl", "slowwrfl", "sraswpst", "slowwpst", "snonwnon", "sraswlnr"] find _stanceFamily;
    private _pace = ["mrun", "mwlk", "mtac", "mstp"] find (_name select [8, 4]);
    if (_familyIndex < 0 || {_pace < 0}) exitWith {_prior};
    private _mode = ["jog", "walk", "combat", _prior param [2, "jog"]] select _pace;
    if (_pace isEqualTo 3) then {_walkSelected = _walkSelected || {_prior param [3, false]};};
    [_weapon, _families select _familyIndex, _mode, _walkSelected]
};

GAIT_fnc_sprintReturnFamily = {
    params ["_unit", "_fallback"];
    private _snapshot = _unit getVariable ["GAIT_preSprintPose", []];
    if (_snapshot isEqualTo [] || {_fallback isEqualTo ""} ||
        {(_snapshot select 0) isNotEqualTo (currentWeapon _unit)}) exitWith {_fallback};
    _snapshot select 1
};

GAIT_fnc_sprintReturnMode = {
    params ["_walk", "_combatMode", "_recordedMode", "_family", ["_walkWasSelected", false]];
    if (_walk) exitWith {"walk"};
    if (_combatMode in ["Timer", "Toggle"]) exitWith {["combat", "walk"] select (_family isEqualTo "SnonWnon")};
    if (_recordedMode isEqualTo "walk" && {!_walkWasSelected}) exitWith {"walk"};
    ["jog", "combat"] select (_combatMode isEqualTo "" && {_recordedMode isEqualTo "combat"})
};

GAIT_fnc_liveSprintReturnMode = {
    params ["_unit", "_walk", "_family"];
    private _snapshot = _unit getVariable ["GAIT_preSprintPose", []];
    private _mode = if (isNil "GAIT_fnc_readCombatPace") then {""} else {[_unit] call GAIT_fnc_readCombatPace};
    private _previousMode = "jog";
    private _walkWasSelected = false;
    if (_snapshot isNotEqualTo [] && {(_snapshot select 0) isEqualTo (currentWeapon _unit)}) then {
        _previousMode = _snapshot select 2;
        _walkWasSelected = _snapshot select 3;
    };
    [_walk, _mode, _previousMode, _family, _walkWasSelected] call GAIT_fnc_sprintReturnMode
};

GAIT_fnc_sprintReturnClip = {
    params ["_family", "_direction", "_pose", "_mode"];
    [_family, _direction, false, _pose, _mode isEqualTo "walk", _mode isEqualTo "combat"] call GAIT_fnc_slopeStateName
};

GAIT_fnc_ordinarySlopeJogIntent = {
    params [
        ["_input", [], [[]]],
        ["_slopeDegrees", 0, [0]],
        ["_aceMovementLock", false, [false]],
        ["_nativeForcedWalk", false, [false]],
        ["_walkToggled", false, [false]],
        ["_alreadyJogging", false, [false]]
    ];
    (count _input) >= 3 && {!_aceMovementLock} &&
        {!_nativeForcedWalk} && {!_walkToggled} &&
        {(_input select 0) > 0.05} && {!(_input select 2)} &&
        {abs _slopeDegrees > ([0.25, 0.05] select _alreadyJogging)}
};

// Locomotion entry and live direction redirects use the interpolation graph.
// https://community.bistudio.com/wiki/playMoveNow
GAIT_fnc_requestLocomotionMove = {
    params ["_unit", "_target"];
    _unit playMoveNow _target;
};

// Give the native idle action map control as soon as the last movement key
// is released. Keep a short outgoing blend for the braking stride.
GAIT_fnc_requestLocomotionStop = {
    params ["_unit", "_target"];
    [] call GAIT_fnc_releaseSpeedCoefficient;
    // Standing idle uses native actions. A fresh movement key can act
    // immediately, including on the next render frame after the stop.
    [_unit] call GAIT_fnc_clearSlopeLocomotionState;
    [_unit, _target] call GAIT_fnc_switchToLocomotionIdle;
};

GAIT_fnc_stopAnimationTarget = {
    params ["_idle", "_animation", "_releaseAge", ["_protectedGesture", false]];
    private _name = toLower _animation;
    private _pace = _name select [8, 4];
    private _sprintStop = _pace in ["meva", "mspr"] ||
        {_releaseAge >= 0 && {_releaseAge <= 0.20} && {_pace in ["mrun", "mtac", "mwlk", "mstp"]}};
    private _shoulder = !_protectedGesture && {((toLower _idle) select [12, 8]) isEqualTo "sraswrfl"} &&
        {(_name select [12, 8]) in ["sraswrfl", "slowwrfl"]} && {_sprintStop};
    _idle + (["", "_GAITSprintStop"] select _shoulder)
};

GAIT_fnc_stopReleaseAge = {
    params ["_unit"];
    private _release = _unit getVariable ["GAIT_sprintReleasePace", []];
    private _lastTurboRelease = _unit getVariable ["GAIT_lastMovingTurboRelease", -999];
    diag_tickTime - ((_release param [0, -999]) max _lastTurboRelease)
};

GAIT_fnc_switchToLocomotionIdle = {
    params ["_unit", "_target"];
    // Begin at the outgoing stride and let it brake into native idle.
    [_unit, _target, 0, 0] call GAIT_fnc_blendNativeLocomotion;
};

GAIT_fnc_blendNativeLocomotion = {
    params ["_unit", "_target", "_progress", "_blend"];
    if ([_unit] call GAIT_fnc_hasProtectedLocomotionGesture) exitWith {
        // Use the state graph so a body handoff does not reset the gesture.
        [_unit, _target] call GAIT_fnc_requestLocomotionMove;
    };
    _unit switchMove [_target, _progress, _blend, false];
};

GAIT_fnc_hasProtectedLocomotionGesture = {
    params ["_unit"];
    private _gesture = toLower gestureState _unit;
    (!([_gesture] call GAIT_fnc_rifleGestureFree) && {_gesture find "gait_riflerun_" != 0}) ||
        {[_unit getVariable ["NAVSPECWARGRU2_CQB_ReadyAnim", ""]] call GAIT_fnc_preserveLocomotionGesture}
};

// A release can interrupt the exact entry blend or an internal direction
// blend. Accept only its recorded source endpoints leading to its recorded
// target. A near match, unknown source or unrelated full-body action fails.
GAIT_fnc_isLocomotionHandoffBlend = {
    params ["_animation", "_source", "_target"];
    if ([_animation, _source, _target] call GAIT_fnc_isStandingLocomotionBlend) exitWith {true};
    private _divider = (toLower _source) find "_amov";
    if (_divider < 0) exitWith {false};
    private _left = _source select [0, _divider];
    private _right = _source select [_divider + 1];
    // Validate that the recorded source is itself an exact standing blend.
    if !([_source, _left, _right] call GAIT_fnc_isStandingLocomotionBlend) exitWith {false};
    ([_animation, _left, _target] call GAIT_fnc_isStandingLocomotionBlend) ||
        {[_animation, _right, _target] call GAIT_fnc_isStandingLocomotionBlend}
};

// During one replacement request Arma may still report the exact prior
// standing blend for a frame. This grace ends at the entry deadline and does
// not authorize arbitrary transitions or an indefinite unobserved entry.
GAIT_fnc_isLocomotionHandoffSource = {
    params ["_animation", "_source", "_beforeDeadline"];
    if (!_beforeDeadline || {(toLower _animation) isNotEqualTo (toLower _source)}) exitWith {false};
    private _divider = (toLower _source) find "_amov";
    if (_divider < 0) exitWith {false};
    [_source, _source select [0, _divider], _source select [_divider + 1]] call GAIT_fnc_isStandingLocomotionBlend
};

// Draw3D sees a W release even when W is pressed again before the slower
// feature loop runs. Preserve the serial across animation cleanup so that
// loop can discard its old forward coast instead of reviving it on re-press.
// A cancelled numerical brace likewise cannot survive a release that happened
// entirely between two scheduled feature updates.
GAIT_fnc_clearLocomotionInputHistory = {
    params [["_unit", objNull, [objNull]]];
    if (isNull _unit) exitWith {};
    [_unit] call GAIT_fnc_endBurst;
    _unit setVariable ["GAIT_burstFirstTap", -1];
    _unit setVariable ["GAIT_burstRequest", []];
    {
        _unit setVariable [_x, false];
    } forEach [
        "GAIT_movementReleasedThisFrame",
        "GAIT_movementInputHeld",
        "GAIT_directionChangedThisFrame",
        "GAIT_turboPressedThisFrame",
        "GAIT_turboReleasedThisFrame",
        "GAIT_turboInputHeld",
        "GAIT_uphillSprintRecoveryUsed",
        "GAIT_slopeJogIntent",
        "GAIT_forwardInputHeld",
        "GAIT_releaseSinceFeatureTick",
        "GAIT_nativeReleaseOwnsDirection",
        "GAIT_sprintReleaseJog",
        "GAIT_stanceInputHeld"
    ];
    {
        _unit setVariable [_x, []];
    } forEach [
        "GAIT_nativeStopPaceLease",
        "GAIT_forwardPressSnapshot",
        "GAIT_sprintReleaseSample",
        "GAIT_stanceCarryCoefficient",
        "GAIT_stanceSpeedBeforeInput",
        "GAIT_stanceSpeedLimit",
        "GAIT_stanceTravel",
        "GAIT_releasePacePlan",
        "GAIT_paceObservation",
        "GAIT_preSprintPose"
    ];
    _unit setVariable ["GAIT_liveInputDirection", "Dnon"];
    _unit setVariable ["GAIT_turboPressSerial", 0];
    _unit setVariable ["GAIT_movingAimUntil", -1];
    _unit setVariable ["GAIT_movingAimIssued", false];
    _unit setVariable ["GAIT_firePressedAt", -1];
    _unit setVariable ["GAIT_stanceYieldUntil", -1];
    _unit setVariable ["GAIT_stanceYieldFrom", ""];
    _unit setVariable ["GAIT_stanceBeforeInput", ""];
    _unit setVariable ["GAIT_sprintReleasePace", []];
    _unit setVariable ["GAIT_sprintReleaseMode", ""];
    _unit setVariable ["GAIT_lastMovingTurboRelease", -999];
    _unit setVariable ["GAIT_weaponYieldUntil", -1];
    _unit setVariable ["GAIT_stanceYieldStarted", -1];
    _unit setVariable ["GAIT_slopeCanceledBraceEndTime", -2];
    _unit setVariable ["GAIT_uphillSprintGroundedAt", -1];
    _unit setVariable ["GAIT_paceNextSample", 0];
};

GAIT_fnc_observeLocomotionInput = {
    params ["_unit", "_input", ["_tapTime", diag_tickTime]];
    private _forwardHeld = (_input select 0) > 0.05;
    private _movingHeld = abs (_input select 0) > 0.05 || {abs (_input select 1) > 0.05};
    // Preserve the old startup release semantics while separately detecting
    // the first real forward press for the ordinary walk-start brace.
    private _previousForwardForPress = _unit getVariable ["GAIT_forwardInputHeld", false];
    private _previousForwardForRelease = _unit getVariable ["GAIT_forwardInputHeld", true];
    _unit setVariable ["GAIT_movementReleasedThisFrame", !_movingHeld && {_unit getVariable ["GAIT_movementInputHeld", false]}];
    _unit setVariable ["GAIT_movementInputHeld", _movingHeld];
    private _direction = [_input select 0, _input select 1] call GAIT_fnc_slopeDirection;
    private _previousDirection = _unit getVariable ["GAIT_liveInputDirection", "Dnon"];
    _unit setVariable ["GAIT_directionChangedThisFrame",
        _movingHeld && {_direction isNotEqualTo _previousDirection}];
    _unit setVariable ["GAIT_liveInputDirection", _direction];
    if (_movingHeld) then {_unit setVariable ["GAIT_nativeStopPaceLease", []];};
    private _turbo = _input select 2;
    private _previousTurbo = _unit getVariable ["GAIT_turboInputHeld", false];
    if ((!_turbo || {!_forwardHeld}) && {_unit getVariable ["GAIT_uphillSprintRecoveryUsed", false]}) then {
        _unit setVariable ["GAIT_uphillSprintRecoveryUsed", false];
    };
    if (_forwardHeld && {!_previousForwardForPress}) then {
        private _velocity = velocity _unit;
        private _speedMS = sqrt (((_velocity select 0) ^ 2) + ((_velocity select 1) ^ 2));
        private _serial = (_unit getVariable ["GAIT_forwardPressSerial", 0]) + 1;
        _unit setVariable ["GAIT_forwardPressSerial", _serial];
        _unit setVariable ["GAIT_forwardPressSnapshot", [_serial, diag_tickTime, _speedMS, _turbo]];
    };
    _unit setVariable ["GAIT_turboPressedThisFrame", _turbo && {!_previousTurbo}];
    if (_turbo && {!_previousTurbo}) then {
        private _press = (_unit getVariable ["GAIT_turboPressSerial", 0]) + 1;
        _unit setVariable ["GAIT_turboPressSerial", _press];
        private _pair = [_unit getVariable ["GAIT_burstFirstTap", -1], _tapTime] call GAIT_fnc_burstTapPair;
        _unit setVariable ["GAIT_burstFirstTap", [_tapTime, -1] select _pair];
        if (_pair) then {_unit setVariable ["GAIT_burstRequest", [_press, time + 0.25]];};
    };
    if (!_turbo && {_previousTurbo} || {!_forwardHeld && {_previousForwardForPress}}) then {
        _unit setVariable ["GAIT_burstRequest", []];
        [_unit] call GAIT_fnc_endBurst;
    };
    _unit setVariable ["GAIT_turboReleasedThisFrame", !_turbo && {_previousTurbo}];
    _unit setVariable ["GAIT_turboInputHeld", _turbo];
    private _resume = _unit getVariable ["GAIT_burstResumeKeys", []];
    if (_resume isNotEqualTo []) then {
        if (_tapTime > (_resume select 0)) then {
            _unit setVariable ["GAIT_burstResumeKeys", []];
        } else {
            if (_turbo && {_forwardHeld}) then {
                private _request = [_unit getVariable ["GAIT_turboPressSerial", 0], time + ((_resume select 0) - _tapTime)];
                if (_resume param [2,false]) then {_request pushBack true;};
                _unit setVariable ["GAIT_burstRequest", _request];
                _unit setVariable ["GAIT_burstResumeKeys", []];
            };
        };
    };
    if (_previousTurbo && {!_turbo}) then {
        _unit setVariable ["GAIT_releaseSinceFeatureTick", true];
        if (_previousForwardForPress && {_unit getVariable ["GAIT_slopeAttemptLatched", false]}) then {
            _unit setVariable ["GAIT_lastMovingTurboRelease", diag_tickTime];
        };
    };
    if (!_forwardHeld && {_previousForwardForRelease}) then {
        _unit setVariable ["GAIT_forwardReleaseSerial", (_unit getVariable ["GAIT_forwardReleaseSerial", 0]) + 1];
        if (!_movingHeld) then {_unit setVariable ["GAIT_sprintReleaseSample", []];};
    };
    _unit setVariable ["GAIT_forwardInputHeld", _forwardHeld];

    private _end = missionNamespace getVariable ["GAIT_braceEndTime", -1];
    private _active = (missionNamespace getVariable ["GAIT_braceActive", false]) && {time < _end};
    private _live = _active && {_forwardHeld} && {_turbo};
    if (_active && {!_live}) then {_unit setVariable ["GAIT_slopeCanceledBraceEndTime", _end];};
    _live && {_end isNotEqualTo (_unit getVariable ["GAIT_slopeCanceledBraceEndTime", -2])}
};

GAIT_fnc_slopeWeaponFamily = {
    params ["_unit"];
    private _weapon = currentWeapon _unit;
    private _families = [];
    private _fallback = "";
    if (_weapon isEqualTo "") then {
        _families = ["SnonWnon"];
        _fallback = "SnonWnon";
    } else {
        if (_weapon isEqualTo (handgunWeapon _unit)) then {
            _families = ["SlowWpst", "SrasWpst"];
            private _pistolAnim = toLower ([_unit] call GAIT_fnc_readLocomotionAnimation);
            _fallback = if ((_pistolAnim find "slowwpst") >= 0) then {
                "SlowWpst"
            } else {
                if ((_pistolAnim find "sraswpst") >= 0) then {
                    "SrasWpst"
                } else {
                    ["SrasWpst", "SlowWpst"] select (weaponLowered _unit)
                }
            };
        } else {
            if (_weapon isEqualTo (primaryWeapon _unit)) then {
                _families = ["SlowWrfl", "SrasWrfl"];
                _fallback = ["SrasWrfl", "SlowWrfl"] select (weaponLowered _unit);
            };
        };
    };
    if (_weapon isNotEqualTo "" && {_weapon isEqualTo (secondaryWeapon _unit)}) exitWith {"SrasWlnr"};
    // Binocular and mod-specific poses keep their own maps.
    if (_families isEqualTo []) exitWith {""};
    private _animation = [_unit] call GAIT_fnc_readLocomotionAnimation;
    private _stateFamily = getText (configFile >> "CfgMovesMaleSdr" >> "States" >> _animation >> "GAIT_slopeFamily");
    if (_stateFamily in _families) exitWith {_stateFamily};
    if ("SrasWrfl" in _families &&
        {([_animation] call GAIT_fnc_compatibleIdleName) isNotEqualTo (toLower _animation)}) exitWith {"SrasWrfl"};

    // Sprint clips can lower the weapon themselves. That pose change must not
    // be mistaken for an equipped-weapon change during entry or active sprint.
    private _attemptFamily = _unit getVariable ["GAIT_slopeAttemptFamily", ""];
    if ((_unit getVariable ["GAIT_slopeAttemptLatched", false]) && {(_unit getVariable ["GAIT_slopeAttemptWeapon", ""]) isEqualTo _weapon} && {_attemptFamily in _families}) exitWith {
        [_animation, _attemptFamily, _families] call GAIT_fnc_locomotionObservedWeaponPose
    };
    _fallback
};

// A settled native moving pose is authoritative after an engine handoff.
// Keep the latched family through blends and idle, where sprint's own weapon
// pose can transiently disagree with the engine's weaponLowered flag.
GAIT_fnc_locomotionObservedWeaponPose = {
    params ["_animation", "_attemptFamily", "_families"];
    private _parts = (toLower _animation) splitString "_";
    private _state = _parts param [0, ""];
    if (!((_state select [0, 8]) in ["amovperc", "amovpknl"]) ||
        {!((_state select [20]) in ["df", "dfl", "dfr", "dl", "dbr", "db", "dbl", "dr"])}) exitWith {_attemptFamily};
    private _pace = _state select [8, 4];
    private _family = _state select [12, 8];
    if !(_pace in ["mwlk", "mrun", "mtac"]) exitWith {_attemptFamily};
    private _variant = (_parts isEqualTo [_state, "ver2"]) && {_family isEqualTo "slowwrfl"} && {_pace in ["mwlk", "mtac"]};
    if ((count _parts) isNotEqualTo 1 && {!_variant}) exitWith {_attemptFamily};
    private _index = _families findIf {(toLower _x) isEqualTo _family};
    if (_index < 0) exitWith {_attemptFamily};
    _families select _index
};

GAIT_fnc_isSlopeLocomotionState = {
    params ["_state"];
    (getNumber (configFile >> "CfgMovesMaleSdr" >> "States" >> _state >> "GAIT_slopeState")) isEqualTo 1
};

// Both endpoints must be registered GAIT states of the same stance.
GAIT_fnc_splitSlopeBlend = {
    params [["_animation", "", [""]]];
    private _parts = (toLower _animation) splitString "_";
    if ((count _parts) isNotEqualTo 4) exitWith {[]};
    if !((_parts select 1) in ["gait", "gaitsprint"]) exitWith {[]};
    if !((_parts select 3) in ["gait", "gaitsprint"]) exitWith {[]};
    if (((_parts select 0) select [4, 4]) isNotEqualTo ((_parts select 2) select [4, 4])) exitWith {[]};
    [(_parts select 0) + "_" + (_parts select 1),
     (_parts select 2) + "_" + (_parts select 3)]
};

GAIT_fnc_riflePoseBlendTarget = {
    params ["_animation", "_pace"];
    private _name = toLower _animation;
    private _divider = _name find "_amov";
    if (_divider < 0) exitWith {""};
    private _left = _name select [0, _divider];
    private _right = _name select [_divider + 1];
    private _rifles = ["sraswrfl", "slowwrfl"];
    private _from = _rifles find (_left select [12, 8]);
    private _to = _rifles find (_right select [12, 8]);
    if (_from < 0 || {_to < 0} || {_from isEqualTo _to} ||
        {(_left select [8, 4]) isNotEqualTo _pace} || {(_right select [8, 4]) isNotEqualTo _pace}) exitWith {""};
    if !([_name, _left, _right] call GAIT_fnc_isStandingLocomotionBlend) exitWith {""};
    ["SrasWrfl", "SlowWrfl"] select _to
};

GAIT_fnc_slopeAnimationFamily = {
    params [["_animation", "", [""]]];
    private _name = toLower _animation;
    private _cache = missionNamespace getVariable ["GAIT_locomotionFamilyCache", createHashMap];
    private _cached = _cache getOrDefault [_name, "?"];
    if (_cached isNotEqualTo "?") exitWith {_cached};
    private _states = configFile >> "CfgMovesMaleSdr" >> "States";
    private _family = "";
    if ((getNumber (_states >> _name >> "GAIT_slopeState")) isEqualTo 1) then {
        _family = getText (_states >> _name >> "GAIT_slopeFamily");
    } else {
        private _ends = [_name] call GAIT_fnc_splitSlopeBlend;
        if ((count _ends) isEqualTo 2) then {
            private _left = _states >> (_ends select 0);
            private _right = _states >> (_ends select 1);
            if ((getNumber (_left >> "GAIT_slopeState")) isEqualTo 1 && {(getNumber (_right >> "GAIT_slopeState")) isEqualTo 1}) then {
                private _firstFamily = getText (_left >> "GAIT_slopeFamily");
                if (_firstFamily isEqualTo (getText (_right >> "GAIT_slopeFamily"))) then {
                    _family = _firstFamily;
                } else {
                    _family = [_name, "meva"] call GAIT_fnc_riflePoseBlendTarget;
                };
            };
        };
    };
    _cache set [_name, _family];
    missionNamespace setVariable ["GAIT_locomotionFamilyCache", _cache];
    _family
};

GAIT_fnc_isSlopeLocomotionBlend = {
    params [["_animation", "", [""]]];
    (([_animation] call GAIT_fnc_splitSlopeBlend) isNotEqualTo []) &&
    {([_animation] call GAIT_fnc_slopeAnimationFamily) isNotEqualTo ""}
};

GAIT_fnc_slopeFamilyAvailable = {
    params ["_family", ["_pose", "Perc"]];
    private _cacheName = "GAIT_slopeFamilyAvailable_" + _pose + _family;
    private _cached = missionNamespace getVariable [_cacheName, -1];
    if (_cached >= 0) exitWith {_cached isEqualTo 1};
    private _states = configFile >> "CfgMovesMaleSdr" >> "States";
    private _available = _family in ["SrasWrfl", "SlowWrfl", "SrasWpst", "SlowWpst", "SnonWnon", "SrasWlnr"];
    private _required = [[_family, "Dnon", false, _pose] call GAIT_fnc_slopeStateName];
    {
        _required pushBack ([_family, _x, false, _pose] call GAIT_fnc_slopeStateName);
        _required pushBack ([_family, _x, true, _pose] call GAIT_fnc_slopeStateName);
        _required pushBack ([_family, _x, false, _pose, true] call GAIT_fnc_slopeStateName);
        if (_family isNotEqualTo "SnonWnon") then {
            _required pushBack ([_family, _x, false, _pose, false, true] call GAIT_fnc_slopeStateName);
        };
    } forEach ["Df", "Dfl", "Dl", "Dbl", "Db", "Dbr", "Dr", "Dfr"];
    _required = _required arrayIntersect _required;
    {
        private _state = _states >> _x;
        private _native = getText (_state >> "GAIT_nativeState");
        private _actions = getText (_state >> "actions");
        if (!isClass _state || {(getNumber (_state >> "GAIT_slopeState")) isNotEqualTo 1} ||
            {!isClass (_states >> _native)} || {(getText (_states >> _native >> "file")) isEqualTo ""} ||
            {!isClass (configFile >> "CfgMovesBasic" >> "Actions" >> _actions)}) exitWith {_available = false;};
    } forEach _required;
    missionNamespace setVariable [_cacheName, parseNumber _available];
    if (!_available) then {
        if (missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false]) then {
            diag_log format ["[GAIT] Incomplete locomotion family %1 %2; entry disabled.", _pose, _family];
        };
    };
    _available
};

// Pure state policy shared by the live controller and sequence regression tests.
// An escape is reported and latched. The render controller can grant one
// recovery from an exact native locomotion state during an uphill sprint.
GAIT_fnc_locomotionDecision = {
    params ["_phase", "_requested", "_eligible", "_inside", "_entryBlend", "_expired", "_moving",
        ["_compatibleBlend", false, [false]]];
    if (_phase isEqualTo "exiting") exitWith {["clear", "hold"] select (_inside || {_entryBlend})};
    if (!_requested) exitWith {
        ["clear", "release"] select (_inside || {_entryBlend} || {_phase in ["entering", "active"]})
    };
    // A compatible blend or native lateral fallback can temporarily sit
    // outside the custom family. Live locks and raw release still win.
    if (_compatibleBlend && {_phase in ["entering", "active"]}) exitWith {"hold"};
    if (_phase isEqualTo "blocked") exitWith {"hold"};
    if (!_eligible) exitWith {
        ["clear", "release"] select (_inside || {_entryBlend} || {_phase in ["entering", "active"]})
    };
    if (_inside) exitWith {"active"};
    if (_phase isEqualTo "active") exitWith {"escape"};
    if (_phase isEqualTo "entering") exitWith {["hold", "escape"] select (_expired && {!_entryBlend})};
    ["hold", "enter"] select _moving
};

// Detect a real standing movement blend with at least one GAIT endpoint.
// Reject idle, arbitrary native transitions, and medical/stance actions.
GAIT_fnc_locomotionCompatibleMoveBlend = {
    params ["_animation", "_family"];
    private _name = toLower _animation;
    private _divider = _name find "_amov";
    if (_divider < 0 || {_family isEqualTo ""}) exitWith {false};
    private _left = _name select [0, _divider];
    private _right = _name select [_divider + 1];
    if ((_left find "_gait") < 0 && {(_right find "_gait") < 0}) exitWith {false};
    if (!((_left select [8, 4]) in ["mwlk", "mrun", "mtac", "meva", "mspr"]) ||
        {!((_right select [8, 4]) in ["mwlk", "mrun", "mtac", "meva", "mspr"])}) exitWith {false};
    if ((_left select [12, 8]) isNotEqualTo toLower _family &&
        {(_right select [12, 8]) isNotEqualTo toLower _family}) exitWith {false};
    [_name, _left, _right] call GAIT_fnc_isStandingLocomotionBlend
};

GAIT_fnc_locomotionMayFinishMoveBlend = {
    params ["_unit", "_animation"];
    private _safe = isTouchingGround _unit && {([_unit] call GAIT_fnc_readLocomotionStance) in ["STAND", "CROUCH"]} &&
        {[_unit] call GAIT_fnc_fatigueMovementContextEligible};
    if (!_safe) exitWith {false};
    private _gesture = toLower gestureState _unit;
    (["reload", "melee", "throw"] findIf {(_gesture find _x) >= 0}) < 0 &&
        {[_animation, [_unit] call GAIT_fnc_slopeWeaponFamily] call GAIT_fnc_locomotionCompatibleMoveBlend}
};

GAIT_fnc_locomotionExitOwnsMoveBlend = {
    params ["_unit", "_animation"];
    [_animation, _unit getVariable ["GAIT_slopeAttemptFamily", ""]]
        call GAIT_fnc_locomotionCompatibleMoveBlend
};

// Momentary contact loss on rough uphill terrain can occur inside the same
// standing sprint clip. Keep its existing ownership briefly without issuing
// a move or writing a new coefficient while airborne.
GAIT_fnc_uphillSprintContactGrace = {
    params ["_phase", "_requested", "_safe", "_ordinary", "_input", "_now", "_lastGrounded"];
    (_phase in ["entering", "active"]) && {_requested} && {_safe} && {_ordinary} &&
        {_input select 2} && {(_input select 0) > 0.05} &&
        {_lastGrounded >= 0} && {_now - _lastGrounded <= 0.15}
};

GAIT_fnc_uphillSprintContactPending = {
    params ["_unit", "_input", "_locked"];
    private _lastGrounded = _unit getVariable ["GAIT_uphillSprintGroundedAt", -1];
    if (_locked || {_lastGrounded < 0} || {isTouchingGround _unit} ||
        {_unit isNotEqualTo (missionNamespace getVariable ["GAIT_slopeOwner", objNull])}) exitWith {false};
    private _safe = ([_unit] call GAIT_fnc_readLocomotionStance) in ["STAND", "CROUCH"] &&
        {[_unit] call GAIT_fnc_fatigueMovementContextEligible} &&
        {currentWeapon _unit isEqualTo (_unit getVariable ["GAIT_slopeAttemptWeapon", ""])};
    if (!_safe) exitWith {false};
    private _gesture = toLower gestureState _unit;
    if ((["reload", "melee", "throw"] findIf {(_gesture find _x) >= 0}) >= 0) exitWith {false};
    private _animation = [_unit] call GAIT_fnc_readLocomotionAnimation;
    private _ordinary = ([_animation] call GAIT_fnc_slopeAnimationFamily) isNotEqualTo "";
    [_unit getVariable ["GAIT_locomotionPhase", "native"], true, _safe, _ordinary,
        _input, diag_tickTime, _lastGrounded] call GAIT_fnc_uphillSprintContactGrace
};

// A one-shot entry may still be in its ordinary source state when the player
// releases the keys. Keep ownership until that pending command is cancelled;
// discarding it here lets a late custom sprint land after the release.
GAIT_fnc_locomotionExitOwnsObservation = {
    params ["_inside", "_entryBlend", "_cancelEntry", "_atEntrySource", "_beforeDeadline"];
    _inside || {_entryBlend} || {_cancelEntry && {_atEntrySource} && {_beforeDeadline}}
};

// Stance changes outrank every GAIT locomotion phase. The yield clears only
// GAIT ownership and coefficient/release plans; it deliberately sends no
// standing exit animation. The inherited Arma action graph receives the
// original crouch/prone input and can preserve whatever movement it supports.
GAIT_fnc_observeStanceInput = {
    params [["_unit", objNull, [objNull]], ["_held", false, [false]]];
    if (isNull _unit) exitWith {false};
    private _previous = _unit getVariable ["GAIT_stanceInputHeld", false];
    _unit setVariable ["GAIT_stanceInputHeld", _held];
    _held && {!_previous}
};

GAIT_fnc_crouchInputTarget = {
    params ["_before", "_current"];
    if (_before isEqualTo "") then {_before = _current;};
    if !(_before in ["STAND", "CROUCH"]) exitWith {""};
    ["CROUCH", "STAND"] select (_before isEqualTo "CROUCH")
};

GAIT_fnc_stanceYieldActive = {
    params [["_unit", objNull, [objNull]]];
    if (isNull _unit) exitWith {false};
    private _until = _unit getVariable ["GAIT_stanceYieldUntil", -1];
    private _anim = toLower ([_unit] call GAIT_fnc_readLocomotionAnimation);
    if (([_anim] call GAIT_fnc_stanceAnimationDepth) > 0) exitWith {true};
    if ((_anim select [0, 4]) isEqualTo "aadj" &&
        {(([_unit] call GAIT_fnc_readPaceMoveInfo) param [3, 1]) < 0.995} &&
        {([_anim, true] call GAIT_fnc_stanceAnimationDepth) > 0}) exitWith {true};
    private _startingStance = _unit getVariable ["GAIT_stanceYieldFrom", ""];
    private _stance = [_unit] call GAIT_fnc_readLocomotionStance;
    private _stanceBlend = (_anim find "_amov") >= 0 ||
        {(_anim find "_ainv") >= 0} || {(_anim find "_acin") >= 0};
    private _movingBlend = (_unit getVariable ["GAIT_stanceTravel", []]) isNotEqualTo [] &&
        {(([_unit] call GAIT_fnc_readPaceMoveInfo) param [3, 1]) < 0.995};
    private _stanceSettled = _startingStance isNotEqualTo _stance && {!_stanceBlend} && {!_movingBlend};
    // Keep a minimum render grace so the original input reaches Arma, then
    // hold the carried coefficient until the native low-stance state itself
    // has settled, rather than releasing midway through its transition name.
    private _started = _unit getVariable ["GAIT_stanceYieldStarted", -1];
    private _minimumGrace = _started >= 0 && {diag_tickTime - _started < 0.12};
    _minimumGrace || {!_stanceSettled && {diag_tickTime <= _until}}
};

GAIT_fnc_beginStanceYield = {
    params [["_unit", objNull, [objNull]], ["_fromStance", "", [""]], ["_moving", false, [false]]];
    if (isNull _unit) exitWith {false};
    if (_fromStance isEqualTo "") then {_fromStance = [_unit] call GAIT_fnc_readLocomotionStance;};
    _unit setVariable ["GAIT_stanceYieldFrom", _fromStance];
    _unit setVariable ["GAIT_stanceYieldUntil", diag_tickTime + 0.45];
    _unit setVariable ["GAIT_stanceYieldStarted", diag_tickTime];
    // Preserve the coefficient that is physically on the character. Vanilla
    // running-to-crouch keeps translating while the torso/legs bend; restoring
    // GAIT_nativePreviousCoef here caused the visible speed/pose discontinuity.
    private _carryCoef = getAnimSpeedCoef _unit;
    private _owned = _unit isEqualTo (missionNamespace getVariable ["GAIT_nativeOwner", objNull]) &&
        {abs (_carryCoef - (missionNamespace getVariable ["GAIT_nativeLastWritten", -1])) < 0.001};
    _unit setVariable ["GAIT_stanceCarryCoefficient", [_carryCoef, _owned]];
    if (!_moving) then {
        _unit setVariable ["GAIT_slopeCanceledBraceEndTime",
            missionNamespace getVariable ["GAIT_braceEndTime", -1]];
        missionNamespace setVariable ["GAIT_locomotionRequest", []];
        missionNamespace setVariable ["GAIT_braceActive", false];
        missionNamespace setVariable ["GAIT_braceEndTime", -1];
    };
    // Clear standing animation ownership only. Do NOT release the current
    // coefficient until the stance-yield lease is over.
    [_unit] call GAIT_fnc_clearSlopeLocomotionState;
    true
};

GAIT_fnc_clearSlopeLocomotionState = {
    params [["_unit", objNull, [objNull]]];
    if (!isNull _unit) then {
        {
            _unit setVariable [_x, false];
        } forEach ["GAIT_slopeAttemptLatched", "GAIT_slopeExitPending", "GAIT_slopeFailureReported", "GAIT_slopeLocomotionActive", "GAIT_slopeExitIssued", "GAIT_slopeExitFailureReported", "GAIT_slopeCancelEntry"];
        {
            _unit setVariable [_x, ""];
        } forEach ["GAIT_slopeAttemptFamily", "GAIT_slopeAttemptWeapon", "GAIT_slopeEntrySource", "GAIT_slopeEntryTarget", "GAIT_slopeExitSource", "GAIT_slopeExitTarget"];
        _unit setVariable ["GAIT_slopeEntryDeadline", -1];
        _unit setVariable ["GAIT_slopeCancelDeadline", -1];
        _unit setVariable ["GAIT_slopeExitDeadline", -1];
        _unit setVariable ["GAIT_uphillSprintGroundedAt", -1];
        _unit setVariable ["GAIT_sprintReleaseJog", false];
        _unit setVariable ["GAIT_sprintReleasePace", []];
        _unit setVariable ["GAIT_sprintReleaseMode", ""];
        _unit setVariable ["GAIT_releasePacePlan", []];
        _unit setVariable ["GAIT_locomotionPhase", "native"];
    };
    private _owner = missionNamespace getVariable ["GAIT_slopeOwner", objNull];
    if (isNull _unit || {_owner isEqualTo _unit}) then {
        missionNamespace setVariable ["GAIT_slopeOwner", objNull];
        missionNamespace setVariable ["GAIT_slopeLocomotionActive", false];
        missionNamespace setVariable ["GAIT_locomotionPhase", "native"];
    };
};

GAIT_fnc_releaseSlopeLocomotion = {
    params [
        ["_unit", missionNamespace getVariable ["GAIT_slopeOwner", objNull], [objNull]],
        ["_movementInput", [], [[]]],
        ["_walkOnly", false, [false]]
    ];
    // Cancel intent atomically. Only Draw3D may issue the eventual body exit.
    // Retain cleanup ownership while a reload/ground/weapon handoff defers it.
    isNil {
        missionNamespace setVariable ["GAIT_locomotionRequest", []];
        if (isNull _unit) exitWith {[objNull] call GAIT_fnc_clearSlopeLocomotionState;};
        if (!alive _unit || {!local _unit} || {_unit isNotEqualTo player}) exitWith {
            [_unit] call GAIT_fnc_clearSlopeLocomotionState;
        };
        if ((_unit getVariable ["GAIT_locomotionPhase", "native"]) isEqualTo "exiting") exitWith {};
        private _animation = [_unit] call GAIT_fnc_readLocomotionAnimation;
        private _inside = ([_animation] call GAIT_fnc_slopeAnimationFamily) isNotEqualTo "" ||
            {[_unit, _animation] call GAIT_fnc_locomotionExitOwnsMoveBlend};
        private _source = _unit getVariable ["GAIT_slopeEntrySource", ""];
        private _entryBlend = [_animation, _source, _unit getVariable ["GAIT_slopeEntryTarget", ""]] call GAIT_fnc_isLocomotionHandoffBlend;
        private _cancelEntry = (_unit getVariable ["GAIT_locomotionPhase", "native"]) isEqualTo "entering";
        private _cancelDeadline = _unit getVariable ["GAIT_slopeEntryDeadline", -1];
        if !([_inside, _entryBlend, _cancelEntry, (toLower _animation) isEqualTo (toLower _source), diag_tickTime <= _cancelDeadline] call GAIT_fnc_locomotionExitOwnsObservation) exitWith {
            [_unit] call GAIT_fnc_clearSlopeLocomotionState;
        };
        if !(_unit getVariable ["GAIT_slopeAttemptLatched", false]) then {
            private _observedFamily = [[_unit] call GAIT_fnc_readLocomotionAnimation] call GAIT_fnc_slopeAnimationFamily;
            if (_observedFamily isEqualTo ([_unit] call GAIT_fnc_slopeWeaponFamily)) then {
                // Adopt an orphan only when its pose matches the equipped
                // weapon. An empty weapon is a valid unarmed entry value.
                _unit setVariable ["GAIT_slopeAttemptFamily", _observedFamily];
                _unit setVariable ["GAIT_slopeAttemptWeapon", currentWeapon _unit];
                _unit setVariable ["GAIT_slopeAttemptLatched", true];
            };
        };
        missionNamespace setVariable ["GAIT_slopeOwner", _unit];
        missionNamespace setVariable ["GAIT_locomotionPhase", "exiting"];
        missionNamespace setVariable ["GAIT_slopeLocomotionActive", false];
        _unit setVariable ["GAIT_locomotionPhase", "exiting"];
        _unit setVariable ["GAIT_slopeExitPending", true];
        _unit setVariable ["GAIT_slopeExitIssued", false];
        _unit setVariable ["GAIT_slopeExitFailureReported", false];
        _unit setVariable ["GAIT_slopeExitWalkOnly", _walkOnly];
        _unit setVariable ["GAIT_slopeLocomotionActive", false];
        _unit setVariable ["GAIT_slopeCancelEntry", _cancelEntry];
        _unit setVariable ["GAIT_slopeCancelDeadline", _cancelDeadline];
    };
};

GAIT_fnc_beginNativeReleaseDirection = {
    params ["_unit"];
    [_unit] call GAIT_fnc_clearSlopeLocomotionState;
    _unit setVariable ["GAIT_nativeReleaseOwnsDirection", true];
};

GAIT_fnc_requestMovingLocomotionRelease = {
    params ["_unit", "_family", "_direction", "_walk", "_animation", ["_combat", false]];
    private _pose = ["Perc", "Pknl"] select (([_unit] call GAIT_fnc_readLocomotionStance) isEqualTo "CROUCH");
    private _target = [_family, _direction, _walk, _pose, _combat] call GAIT_fnc_nativeOrdinaryMoveName;
    if (!isClass (configFile >> "CfgMovesMaleSdr" >> "States" >> _target)) exitWith {false};
    // An explicit playMoveNow jog can keep its requested direction even
    // after animationState reports the native target. Hand over to the
    // native action map and keep the outgoing pose in the initial blend.
    private _progress = ([_unit] call GAIT_fnc_readPaceMoveInfo) param [0, 0, [0]];
    [_unit] call GAIT_fnc_beginNativeReleaseDirection;
    if (missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false]) then {
        diag_log format ["[GAIT_LOCOMOTION] native release handoff Draw3D %1 -> %2", _animation, _target];
    };
    [_unit, _target, (_progress max 0 min 1) mod 1, 0.25] call GAIT_fnc_blendNativeLocomotion;
    true
};

// Native sprint can still be visible before custom entry, after a native
// animation fallback, or when the dedicated sprint graph is disabled.
GAIT_fnc_isNativeStandingSprint = {
    params ["_animation", "_family"];
    private _state = toLower _animation;
    private _nativeFamily = ["slowwlnr", toLower _family] select (_family isNotEqualTo "SrasWlnr");
    (_state select [0, 8]) in ["amovperc", "amovpknl"] &&
        {(_state select [8, 4]) in ["meva", "mspr"]} &&
        {(_state select [12, 8]) isEqualTo _nativeFamily} &&
        {(_state select [20]) in ["df", "dfl", "dfr"]}
};

// An actual rifle pose change during sprint updates the return pose while
// retaining the walk/jog/combat mode recorded before sprint.
GAIT_fnc_observeSprintRiflePose = {
    params ["_unit", "_animation", "_activeFamily"];
    private _rifles = ["SrasWrfl", "SlowWrfl"];
    private _oldFamily = _unit getVariable ["GAIT_slopeAttemptFamily", ""];
    if !(_oldFamily in _rifles) exitWith {""};
    private _name = toLower _animation;
    if !((_name select [8, 4]) in ["meva", "mspr"]) exitWith {""};
    private _family = _activeFamily;
    if (_family isEqualTo "") then {
        private _other = _rifles select (_oldFamily isEqualTo "SrasWrfl");
        if ([_name, _other] call GAIT_fnc_isNativeStandingSprint) then {_family = _other;};
    };
    if !(_family in _rifles && {_family isNotEqualTo _oldFamily}) exitWith {""};
    private _weapon = currentWeapon _unit;
    private _snapshot = _unit getVariable ["GAIT_preSprintPose", []];
    if ((_snapshot param [0, ""]) isNotEqualTo _weapon) then {_snapshot = [_weapon, _oldFamily, "jog", false];};
    _snapshot set [1, _family];
    _unit setVariable ["GAIT_preSprintPose", _snapshot];
    _unit setVariable ["GAIT_slopeAttemptFamily", _family];
    _family
};

GAIT_fnc_isNativeStandingSprintBlend = {
    params ["_animation", "_family"];
    private _divider = (toLower _animation) find "_amov";
    if (_divider < 0) exitWith {false};
    private _left = _animation select [0, _divider];
    private _right = _animation select [_divider + 1];
    if ((toLower _animation find "_gait") >= 0 ||
        {!([_animation, _left, _right] call GAIT_fnc_isStandingLocomotionBlend)}) exitWith {false};
    ([_left, _family] call GAIT_fnc_isNativeStandingSprint) ||
        {[_right, _family] call GAIT_fnc_isNativeStandingSprint}
};

GAIT_fnc_nativeLocomotionHandoffSafe = {
    params ["_unit"];
    if (!([_unit] call GAIT_fnc_fatigueMovementContextEligible) || {!isTouchingGround _unit} ||
        {!(([_unit] call GAIT_fnc_readLocomotionStance) in ["STAND", "CROUCH"])}) exitWith {false};
    private _gesture = toLower gestureState _unit;
    (["reload", "melee", "throw", "medic", "bandage", "salute"] findIf {(_gesture find _x) >= 0}) < 0
};

GAIT_fnc_weaponYieldActive = {
    params ["_unit"];
    private _until = _unit getVariable ["GAIT_weaponYieldUntil", -1];
    _until >= 0 && {diag_tickTime <= _until || {[_unit] call GAIT_fnc_readWeaponSwitching}}
};

GAIT_fnc_movingStanceRifleFamily = {
    params ["_animation", "_fallback"];
    private _observed = toLower _animation;
    private _pace = _observed select [8, 4];
    private _blendFamily = [_animation, _pace] call GAIT_fnc_riflePoseBlendTarget;
    if (_blendFamily isNotEqualTo "") exitWith {_blendFamily};
    private _index = ["sraswrfl", "slowwrfl"] find (_observed select [12, 8]);
    if (_index < 0 || {(_observed find "_amov") >= 0} || {!(_pace in ["mrun", "mwlk", "mtac"])}) exitWith {_fallback};
    ["SrasWrfl", "SlowWrfl"] select _index
};

GAIT_fnc_movingStanceMode = {
    params ["_pace", "_nativeWalk", "_returnMode"];
    if (_pace isEqualTo "mtac") exitWith {"combat"};
    if (_nativeWalk || {_pace isEqualTo "mwlk"}) exitWith {"walk"};
    ["jog", "combat"] select (_returnMode isEqualTo "combat")
};

// A live stance or weapon action ends the custom body handoff. Reuse the
// native pace and the current stride so the original action can continue.
GAIT_fnc_yieldWindDownAnimation = {
    params ["_unit", "_input", "_nativeWalk", ["_crouchStance", ""], ["_travel", []]];
    private _crouchToggle = _crouchStance isNotEqualTo "";
    if !([_unit] call GAIT_fnc_nativeLocomotionHandoffSafe) exitWith {""};
    private _animation = [_unit] call GAIT_fnc_readLocomotionAnimation;
    private _state = ([_animation] call GAIT_fnc_splitSlopeBlend) param [1, _animation];
    private _knownStanceBlend = _travel isNotEqualTo [] &&
        {toLower _animation isEqualTo toLower format ["%1_%2", _travel select 0, _travel select 1]};
    if (_knownStanceBlend) then {_state = _travel select 1;};
    private _entry = _unit getVariable ["GAIT_slopeEntryTarget", ""];
    if ([_animation, _unit getVariable ["GAIT_slopeEntrySource", ""], _entry] call GAIT_fnc_isLocomotionHandoffBlend) then {
        _state = _entry;
    };
    private _states = configFile >> "CfgMovesMaleSdr" >> "States";
    private _config = _states >> _state;
    private _custom = (getNumber (_config >> "GAIT_slopeState")) isEqualTo 1;
    private _pace = toLower _state select [8, 4];
    if (!_custom && {!(_crouchToggle && {_pace in ["mstp", "mrun", "mwlk", "mtac", "meva", "mspr"]} &&
        {[_unit, false, _knownStanceBlend] call GAIT_fnc_nativeMovementEligible})}) exitWith {""};
    private _family = getText (_config >> "GAIT_slopeFamily");
    if (!_custom) then {_family = [_unit] call GAIT_fnc_slopeWeaponFamily;};
    private _pose = ["Perc", "Pknl"] select (([_unit] call GAIT_fnc_readLocomotionStance) isEqualTo "CROUCH");
    if (_family isEqualTo "" || {!_knownStanceBlend && {(toLower _state select [4, 4]) isNotEqualTo toLower _pose}}) exitWith {""};
    private _crouchPose = ["Perc", "Pknl"] select (_crouchStance isEqualTo "CROUCH");
    private _direction = [_input select 0, _input select 1] call GAIT_fnc_slopeDirection;
    private _crouchSprint = _crouchToggle && {(_input select 2)} && {(_input select 0) > 0.05} &&
        {[_unit] call GAIT_fnc_readLocomotionSprintAllowed} &&
        {!([_unit] call GAIT_fnc_readLocomotionForcedWalk)} &&
        {(_unit getVariable ["ace_common_effect_blockSprint", 0]) <= 0} &&
        {(_unit getVariable ["ace_common_effect_forceWalk", 0]) <= 0};
    private _alreadySprinting = _pace in ["meva", "mspr"] || {"gaitsprint" in (toLower _state splitString "_")};
    if (_crouchToggle && {(toLower _state select [4, 4]) isEqualTo toLower _crouchPose} && {_pace isNotEqualTo "mstp"} &&
        {_crouchSprint isEqualTo _alreadySprinting} &&
        {([_state] call GAIT_fnc_locomotionTargetDirection) isEqualTo toLower _direction}) exitWith {
        // MoveUp can already have changed the native stance this frame.
        if (missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false]) then {
            diag_log format ["[GAIT_LOCOMOTION] crouch input already in %1 (%2)", _crouchStance, _state];
        };
        _state
    };
    private _walk = _nativeWalk || {_pace isEqualTo "mwlk"};
    private _combat = _pace isEqualTo "mtac";
    if (_crouchToggle) then {
        _pose = _crouchPose;
        if (_family in ["SrasWrfl", "SlowWrfl"]) then {
            _family = [_animation, [_unit, _family] call GAIT_fnc_sprintReturnFamily]
                call GAIT_fnc_movingStanceRifleFamily;
        };
        private _mode = [_pace, _nativeWalk, [_unit, _nativeWalk, _family] call GAIT_fnc_liveSprintReturnMode]
            call GAIT_fnc_movingStanceMode;
        _walk = _mode isEqualTo "walk";
        _combat = _mode isEqualTo "combat";
    };
    private _target = if (_direction isEqualTo "Dnon") then {
        "Amov" + _pose + "Mstp" + _family + "Dnon"
    } else {
        [_family, _direction, _walk, _pose, _combat] call GAIT_fnc_nativeOrdinaryMoveName
    };
    if (_crouchSprint && {[_family, _pose] call GAIT_fnc_slopeFamilyAvailable}) then {
        _target = [_family, _direction, true, _pose] call GAIT_fnc_slopeStateName;
    };
    if (!isClass (_states >> _target)) exitWith {""};
    private _progress = ([_unit] call GAIT_fnc_readPaceMoveInfo) param [0, 0, [0]];
    if (_crouchToggle) exitWith {
        // Keep the stride phase and give the destination's action map
        // control immediately. Queued native clips hold their old direction.
        if (missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false]) then {
            diag_log format ["[GAIT_LOCOMOTION] crouch blend %1 -> %2", _animation, _target];
        };
        [_unit, _target, (_progress max 0 min 1) mod 1, 0.22] call GAIT_fnc_blendNativeLocomotion;
        _target
    };
    if (missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false]) then {
        diag_log format ["[GAIT_LOCOMOTION] action handoff %1 -> %2", _animation, _target];
    };
    [_unit, _target, (_progress max 0 min 1) mod 1, 0.25] call GAIT_fnc_blendNativeLocomotion;
    _target
};

GAIT_fnc_beginMovingStanceRelease = {
    params ["_unit", "_input", "_release", "_target", "_speed", "_now"];
    private _pace = toLower _target select [8, 4];
    private _mode = ["mrun", "mwlk", "mtac"] find _pace;
    if (_mode < 0) exitWith {};
    if (_release isEqualTo []) then {
        private _grade = [_unit, 2, _input] call GAIT_fnc_getTravelSlopeDegrees;
        _release = [_now, 0, [_grade] call GAIT_fnc_sprintReleaseSlopeScale];
    };
    private _crouched = (toLower _target select [4, 4]) isEqualTo "pknl";
    private _rebased = [_release, _now, _speed, _crouched] call GAIT_fnc_rebaseSprintRelease;
    _unit setVariable ["GAIT_sprintReleasePace", _rebased];
    _unit setVariable ["GAIT_sprintReleaseMode", ["jog", "walk", "combat"] select _mode];
    _unit setVariable ["GAIT_nativeReleaseOwnsDirection", true];
};

GAIT_fnc_continueMovingStance = {
    params ["_unit", "_input", "_nativeWalk", "_stanceYield", "_now"];
    if !(_unit getVariable ["GAIT_movementInputHeld", false]) exitWith {false};
    private _directionEdge = _unit getVariable ["GAIT_directionChangedThisFrame", false];
    private _shiftReleased = _unit getVariable ["GAIT_turboReleasedThisFrame", false];
    if (!_directionEdge && {!_shiftReleased}) exitWith {false};
    private _travel = _unit getVariable ["GAIT_stanceTravel", []];
    private _blending = _stanceYield && {_travel isNotEqualTo []} &&
        {_now <= (_unit getVariable ["GAIT_stanceYieldUntil", -1])} &&
        {(_travel select 3) isEqualTo currentWeapon _unit};
    private _release = _unit getVariable ["GAIT_sprintReleasePace", []];
    private _taper = !_stanceYield && {!(_input select 2)} && {(_release param [3, -1]) >= 0};
    if (!_blending && {!_taper}) exitWith {false};
    if ([_unit] call GAIT_fnc_readWeaponSwitching) exitWith {false};
    private _pose = [_unit] call GAIT_fnc_readLocomotionStance;
    if (_blending) then {
        _pose = ["STAND", "CROUCH"] select ((toLower (_travel select 1) select [4, 4]) isEqualTo "pknl");
    };
    if !(_pose in ["STAND", "CROUCH"]) exitWith {false};
    private _source = [_unit] call GAIT_fnc_readLocomotionAnimation;
    private _expectedTravel = [[], _travel] select _blending;
    private _target = [_unit, _input, _nativeWalk, _pose, _expectedTravel] call GAIT_fnc_yieldWindDownAnimation;
    if (_target isEqualTo "") exitWith {false};
    if (_blending) then {
        if (toLower _target isNotEqualTo toLower (_travel select 1)) then {
            _travel set [0, _source];
            _travel set [1, _target];
            _unit setVariable ["GAIT_stanceTravel", _travel];
        };
        if (_shiftReleased) then {
            [_unit, _input, _release, _target, _travel select 2, _now] call GAIT_fnc_beginMovingStanceRelease;
        };
    };
    true
};

GAIT_fnc_releaseNativeSprint = {
    params ["_unit", "_input", "_walk"];
    if (isNull _unit || {!(_unit getVariable ["GAIT_turboReleasedThisFrame", false])} ||
        {(_unit getVariable ["GAIT_locomotionPhase", "native"]) isEqualTo "exiting"} ||
        {!(call GAIT_fnc_modeAllowsMovement)}) exitWith {false};
    private _direction = [_input select 0, _input select 1] call GAIT_fnc_slopeDirection;
    if (_direction isEqualTo "Dnon") exitWith {false};
    private _animation = [_unit] call GAIT_fnc_readLocomotionAnimation;
    private _family = [_unit] call GAIT_fnc_slopeWeaponFamily;
    private _nativeBlend = [_animation, _family] call GAIT_fnc_isNativeStandingSprintBlend;
    if (!_nativeBlend && {!([_animation, _family] call GAIT_fnc_isNativeStandingSprint)}) exitWith {false};
    if !([_unit] call GAIT_fnc_nativeLocomotionHandoffSafe) exitWith {false};
    if (_unit getVariable ["GAIT_slopeAttemptLatched", false] &&
        {(_unit getVariable ["GAIT_slopeAttemptWeapon", ""]) isNotEqualTo (currentWeapon _unit)}) exitWith {false};
    // A native sprint can still be visible before our graph entry lands.
    // Leave an owned entry to the same moving-release path as a full sprint.
    if (_unit getVariable ["GAIT_slopeAttemptLatched", false] &&
        {(_unit getVariable ["GAIT_locomotionPhase", "native"]) in ["entering", "active"]} &&
        {call GAIT_fnc_modeAllowsMovement} &&
        {[_unit] call GAIT_fnc_readLocomotionSprintAllowed} &&
        {!([_unit] call GAIT_fnc_readLocomotionForcedWalk)} &&
        {(_unit getVariable ["ace_common_effect_blockSprint", 0]) <= 0} &&
        {(_unit getVariable ["ace_common_effect_forceWalk", 0]) <= 0}) exitWith {false};
    _family = [_unit, _family] call GAIT_fnc_sprintReturnFamily;
    private _mode = [_unit, _walk, _family] call GAIT_fnc_liveSprintReturnMode;
    private _combat = _mode isEqualTo "combat";
    private _walkMode = _mode isEqualTo "walk";
    if (_nativeBlend && {[_animation, _family, _direction, _walkMode, _combat] call GAIT_fnc_nativeSprintBlendTargetsRelease}) exitWith {
        [_unit] call GAIT_fnc_beginNativeReleaseDirection;
        true
    };
    [_unit, _family, _direction, _walkMode, _animation, _combat] call GAIT_fnc_requestMovingLocomotionRelease
};

GAIT_fnc_nativeSprintBlendTargetsRelease = {
    params ["_animation", "_family", "_direction", "_walk", ["_combat", false]];
    private _name = toLower _animation;
    private _divider = _name find "_amov";
    private _pose = ["Perc", "Pknl"] select ((_name select [4, 4]) isEqualTo "pknl");
    _divider >= 0 && {(_name select [_divider + 1]) isEqualTo
        toLower ([_family, _direction, _walk, _pose, _combat] call GAIT_fnc_nativeOrdinaryMoveName)}
};

// Returns true only on the frame a single native exit was issued. The caller
// then stops, so a fast Turbo retap cannot issue exit and entry in one frame.
GAIT_fnc_serviceLocomotionExit = {
    params [["_unit", objNull, [objNull]]];
    if (isNull _unit || {(_unit getVariable ["GAIT_locomotionPhase", "native"]) isNotEqualTo "exiting"}) exitWith {false};
    private _animation = [_unit] call GAIT_fnc_readLocomotionAnimation;
    private _source = _unit getVariable ["GAIT_slopeEntrySource", ""];
    private _inside = ([_animation] call GAIT_fnc_slopeAnimationFamily) isNotEqualTo "" ||
        {[_unit, _animation] call GAIT_fnc_locomotionExitOwnsMoveBlend};
    private _entryBlend = [_animation, _source, _unit getVariable ["GAIT_slopeEntryTarget", ""]] call GAIT_fnc_isLocomotionHandoffBlend;
    private _exitSource = _unit getVariable ["GAIT_slopeExitSource", ""];
    private _exitTarget = _unit getVariable ["GAIT_slopeExitTarget", ""];
    private _exitBlend = [_animation, _exitSource, _exitTarget] call GAIT_fnc_isLocomotionHandoffBlend;
    private _cancelEntry = (_unit getVariable ["GAIT_slopeCancelEntry", false]) && {!(_unit getVariable ["GAIT_slopeExitIssued", false])};
    private _ownsObservation = [_inside, _entryBlend, _cancelEntry, (toLower _animation) isEqualTo (toLower _source), diag_tickTime <= (_unit getVariable ["GAIT_slopeCancelDeadline", -1])] call GAIT_fnc_locomotionExitOwnsObservation;
    _ownsObservation = _ownsObservation || {[_unit, _animation] call GAIT_fnc_isPendingLocomotionExitSource};
    if ((!_ownsObservation && {!_exitBlend}) || {!alive _unit} || {!local _unit} || {_unit isNotEqualTo player}) exitWith {
        // A native or full-body action already owns the character. Discard the
        // pending request without sending an animation after that handoff.
        [_unit] call GAIT_fnc_clearSlopeLocomotionState;
        false
    };
    private _input = [] call GAIT_fnc_getMovementInput;
    private _direction = [_input select 0, _input select 1] call GAIT_fnc_slopeDirection;
    private _exitIssued = _unit getVariable ["GAIT_slopeExitIssued", false];
    private _walk = (_unit getVariable ["GAIT_slopeExitWalkOnly", false]) ||
        {[_unit, _input select 2] call GAIT_fnc_nativeWalkRequested};
    private _redirect = _exitIssued && {[_exitTarget, _direction, _walk] call GAIT_fnc_locomotionExitRedirect};
    if (_exitIssued && {!_redirect}) exitWith {
        if (diag_tickTime > (_unit getVariable ["GAIT_slopeExitDeadline", -1]) && {!(_unit getVariable ["GAIT_slopeExitFailureReported", false])}) then {
            _unit setVariable ["GAIT_slopeExitFailureReported", true];
            if (missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false]) then {
                diag_log format ["[GAIT_LOCOMOTION] native exit not observed from %1; cleanup ownership retained, no repeated animation request.", _animation];
            };
        };
        false
    };
    if !([_unit] call GAIT_fnc_nativeLocomotionHandoffSafe) exitWith {false};
    private _entryWeapon = _unit getVariable ["GAIT_slopeAttemptWeapon", currentWeapon _unit];
    // Let the inherited weapon transition take the body. Do not cut from an
    // old rifle state into a pistol run merely because selection changed first.
    if (_entryWeapon isNotEqualTo (currentWeapon _unit)) exitWith {false};
    private _family = [_unit] call GAIT_fnc_slopeWeaponFamily;
    if (_family isEqualTo "") exitWith {false};
    private _blendFamily = [_animation, _family] call GAIT_fnc_locomotionExitBlendPose;
    if (_blendFamily isNotEqualTo "") then {_family = _blendFamily;};
    if !(_input select 2) then {_family = [_unit, _family] call GAIT_fnc_sprintReturnFamily;};
    private _sprint = (_input select 2) && {_direction in ["Df", "Dfl", "Dfr"]} &&
        {[_unit] call GAIT_fnc_readLocomotionSprintAllowed} && {(_unit getVariable ["ace_common_effect_blockSprint", 0]) <= 0};
    if (_direction isNotEqualTo "Dnon" && {_walk || {!_sprint}}) exitWith {
        private _mode = [_unit, _walk, _family] call GAIT_fnc_liveSprintReturnMode;
        [_unit, _family, _direction, _mode isEqualTo "walk", _animation, _mode isEqualTo "combat"] call GAIT_fnc_requestMovingLocomotionRelease
    };
    private _stop = _direction isEqualTo "Dnon";
    private _states = configFile >> "CfgMovesMaleSdr" >> "States";
    private _prefix = ["AmovPerc", "AmovPknl"] select (([_unit] call GAIT_fnc_readLocomotionStance) isEqualTo "CROUCH");
    private _idle = _prefix + "Mstp" + _family + "Dnon";
    private _nativeSprintFamily = ["SlowWlnr", _family] select (_family isNotEqualTo "SrasWlnr");
    private _target = _prefix + "Meva" + _nativeSprintFamily + _direction;
    if (_stop) then {
        private _age = [_unit] call GAIT_fnc_stopReleaseAge;
        _target = [_idle, _animation, _age, [_unit] call GAIT_fnc_hasProtectedLocomotionGesture] call GAIT_fnc_stopAnimationTarget;
        if (!isClass (_states >> _target)) then {_target = _idle;};
    };
    if (!_stop && {!isClass (_states >> _target)}) exitWith {
        [_unit, _family, _direction, false, _animation] call GAIT_fnc_requestMovingLocomotionRelease
    };
    if (!isClass (_states >> _target)) exitWith {false};
    if (_stop) exitWith {
        if (missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false]) then {
            diag_log format ["[GAIT_LOCOMOTION] stop Draw3D %1 -> %2", _animation, _target];
        };
        [_unit, _target] call GAIT_fnc_requestLocomotionStop;
        true
    };
    _unit setVariable ["GAIT_slopeExitIssued", true];
    _unit setVariable ["GAIT_slopeExitSource", _animation];
    _unit setVariable ["GAIT_slopeExitTarget", _target];
    _unit setVariable ["GAIT_slopeExitDeadline", diag_tickTime + 1.5];
    if (missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false]) then {
        diag_log format ["[GAIT_LOCOMOTION] exit Draw3D %1 -> %2", _animation, _target];
    };
    [_unit, _target] call GAIT_fnc_requestLocomotionMove;
    true
};

// A correct native jog already supplies W-only slope pace. Acquire its custom
// graph only if the terrain selected a walking clip that needs overriding.
GAIT_fnc_locomotionNativeJogNeedsOverride = {
    params ["_animation"];
    private _state = toLower _animation;
    private _parts = _state splitString "_";
    private _base = _parts select 0;
    if (!((_base select [0, 12]) in ["amovpercmwlk", "amovpknlmwlk"]) || {(count _parts) > 2}) exitWith {false};
    private _suffix = _parts param [1, ""];
    _suffix isEqualTo "" || {_suffix isEqualTo "ver2" && {(_base select [12, 8]) isEqualTo "slowwrfl"}}
};

// A changed live direction or walk selection may replace a still-blending
// exit. Once the queued target matches the input it is not repeated.
GAIT_fnc_locomotionTargetDirection = {
    params [["_target", "", [""]]];
    private _base = ((toLower _target) splitString "_") param [0, ""];
    if ((count _base) < 21) exitWith {""};
    private _direction = _base select [20];
    ["", _direction] select (_direction in ["dnon", "df", "dfl", "dl", "dbl", "db", "dbr", "dr", "dfr"])
};

GAIT_fnc_locomotionDirectionRedirectNeeded = {
    params ["_target", "_direction"];
    private _oldDirection = [_target] call GAIT_fnc_locomotionTargetDirection;
    _oldDirection isNotEqualTo "" && {_oldDirection isNotEqualTo (toLower _direction)}
};

GAIT_fnc_locomotionStopRedirect = {
    _this call GAIT_fnc_locomotionDirectionRedirectNeeded
};

GAIT_fnc_locomotionExitRedirect = {
    params ["_target", "_direction", "_walk"];
    if ([_target, _direction] call GAIT_fnc_locomotionStopRedirect) exitWith {true};
    private _pace = (toLower _target) select [8, 4];
    (_pace in ["mwlk", "mrun", "meva"]) && {_walk isNotEqualTo (_pace isEqualTo "mwlk")}
};

GAIT_fnc_isPendingLocomotionExitSource = {
    params ["_unit", "_animation"];
    private _source = _unit getVariable ["GAIT_slopeExitSource", ""];
    (_unit getVariable ["GAIT_slopeExitIssued", false]) && {_source isNotEqualTo ""} &&
        {diag_tickTime <= (_unit getVariable ["GAIT_slopeExitDeadline", -1])} &&
        {(toLower _animation) isEqualTo (toLower _source)}
};

// A real rifle pose blend should finish in its selected raised/lowered pose
// even if sprint release replaces the movement destination in the same frame.
GAIT_fnc_locomotionExitBlendPose = {
    params ["_animation", "_family"];
    if !([_animation, _family] call GAIT_fnc_locomotionCompatibleMoveBlend) exitWith {""};
    private _name = toLower _animation;
    private _target = _name select [(_name find "_amov") + 1];
    switch (_target select [12, 8]) do {
        case "sraswrfl": {"SrasWrfl"};
        case "slowwrfl": {"SlowWrfl"};
        default {""};
    }
};

// A pending entry may still report its exact native source for a few rendered
// frames before Arma exposes the custom blend. Lateral input must already be
// able to retarget in that window; unrelated observations remain rejected.
GAIT_fnc_locomotionEntryRedirectKnown = {
    params [
        ["_animation", "", [""]],
        ["_source", "", [""]],
        ["_beforeDeadline", false, [false]],
        ["_insideFamily", false, [false]],
        ["_handoffBlend", false, [false]],
        ["_handoffSource", false, [false]]
    ];
    _insideFamily || {_handoffBlend} || {_handoffSource} ||
        {_beforeDeadline && {_source isNotEqualTo ""} &&
            {(toLower _animation) isEqualTo (toLower _source)}}
};

GAIT_fnc_nativeStopDecision = {
    params ["_releaseEdge", "_ownedPace", "_nativePhase", "_ordinaryMove", "_eligible"];
    _releaseEdge && {_ownedPace} && {_nativePhase} && {_ordinaryMove} && {_eligible}
};

GAIT_fnc_nativeStopLeaseValid = {
    params ["_lease", "_now", "_weapon", "_coefficient"];
    (count _lease) isEqualTo 3 && {_now <= (_lease select 0)} &&
        {_weapon isEqualTo (_lease select 1)} && {abs (_coefficient - (_lease select 2)) < 0.001}
};

// The same idle handoff also covers a stop after the sprint handoff
// has already finished. This is one input-edge request for an eligible native
// move whose coefficient GAIT currently owns, never an idle watchdog.
GAIT_fnc_beginNativeLocomotionStop = {
    params ["_unit"];
    if (isNull _unit || {!(_unit getVariable ["GAIT_movementReleasedThisFrame", false])} ||
        {(_unit getVariable ["GAIT_locomotionPhase", "native"]) isNotEqualTo "native"}) exitWith {false};
    if !(call GAIT_fnc_modeAllowsMovement) exitWith {false};
    private _owns = _unit isEqualTo (missionNamespace getVariable ["GAIT_nativeOwner", objNull]) &&
        {abs ((getAnimSpeedCoef _unit) - (missionNamespace getVariable ["GAIT_nativeLastWritten", -1])) < 0.001};
    private _lease = _unit getVariable ["GAIT_nativeStopPaceLease", []];
    _unit setVariable ["GAIT_nativeStopPaceLease", []];
    _owns = _owns || {[_lease, diag_tickTime, currentWeapon _unit, getAnimSpeedCoef _unit]
        call GAIT_fnc_nativeStopLeaseValid};
    private _animation = [_unit] call GAIT_fnc_readLocomotionAnimation;
    private _name = toLower _animation;
    private _ordinary = (_name select [0, 8]) in ["amovperc", "amovpknl"] &&
        {(_name select [8, 4]) in ["mrun", "mwlk", "mtac", "meva", "mspr"]} &&
        {([_animation] call GAIT_fnc_slopeAnimationFamily) isEqualTo ""};
    if !([true, _owns, true, _ordinary,
        ([_unit] call GAIT_fnc_nativeLocomotionHandoffSafe) && {[_unit, false] call GAIT_fnc_nativeMovementEligible}]
        call GAIT_fnc_nativeStopDecision) exitWith {false};
    private _family = [_unit] call GAIT_fnc_slopeWeaponFamily;
    if (_family isEqualTo "" || {(_name select [12, 8]) isNotEqualTo (toLower _family) &&
        {!([_animation, _family] call GAIT_fnc_isNativeStandingSprint)}}) exitWith {false};
    // An unowned native blend can be changing stance, weapon or action.
    if ((_name find "_amov") >= 0 && {!([_animation, _family] call GAIT_fnc_isNativeStandingSprintBlend)}) exitWith {false};
    private _prefix = ["AmovPerc", "AmovPknl"] select (([_unit] call GAIT_fnc_readLocomotionStance) isEqualTo "CROUCH");
    private _idle = _prefix + "Mstp" + ([_unit, _family] call GAIT_fnc_sprintReturnFamily) + "Dnon";
    private _age = [_unit] call GAIT_fnc_stopReleaseAge;
    private _target = [_idle, _animation, _age, [_unit] call GAIT_fnc_hasProtectedLocomotionGesture] call GAIT_fnc_stopAnimationTarget;
    if (!isClass (configFile >> "CfgMovesMaleSdr" >> "States" >> _target)) exitWith {false};
    if (missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false]) then {
        diag_log format ["[GAIT_LOCOMOTION] native stop Draw3D %1 -> %2", _animation, _target];
    };
    [_unit, _target] call GAIT_fnc_requestLocomotionStop;
    true
};

GAIT_fnc_updateSlopeLocomotion = {
    params [["_unit", player, [objNull]], ["_fastMoveIntent", false, [false]], ["_movementInput", [], [[]]], ["_externalLock", false, [false]]];
    // No animation command here. The feature loop may be scheduled and has
    // already calculated the original step-off/brace/momentum coefficients.
    missionNamespace setVariable ["GAIT_locomotionRequest", [_unit, _fastMoveIntent, _externalLock, diag_tickTime]];
    missionNamespace getVariable ["GAIT_slopeLocomotionActive", false]
};

// Turbo starts/resumes immediately. Jog release follows live input while
// the independent coefficient controller handles any remaining speed taper.
GAIT_fnc_locomotionIntent = {
    params ["_featureRequest", "_turbo", "_moving", ["_ordinarySlopeJog", false, [false]]];
    _featureRequest && {_moving} && {_turbo || {_ordinarySlopeJog}}
};

GAIT_fnc_ownsNativeReleaseDirection = {
    params ["_prior", "_input"];
    _prior && {!(_input select 2)} && {abs (_input select 0) > 0.05 || {abs (_input select 1) > 0.05}}
};

GAIT_fnc_locomotionResumeDecision = {
    params ["_phase", "_pressEdge", "_exitIssued", "_requested", "_eligible", "_knownObservation"];
    _phase isEqualTo "exiting" && {_pressEdge} && {_exitIssued} &&
        {_requested} && {_eligible} && {_knownObservation}
};

GAIT_fnc_beginLocomotionEntry = {
    params ["_unit", "_family", "_input", "_animation", ["_returnMode", ""]];
    private _pose = ["Perc", "Pknl"] select (([_unit] call GAIT_fnc_readLocomotionStance) isEqualTo "CROUCH");
    private _direction = [_input select 0, _input select 1] call GAIT_fnc_slopeDirection;
    private _target = if (_returnMode isEqualTo "") then {
        [_family, _direction, _input select 2, _pose] call GAIT_fnc_slopeStateName
    } else {
        [_family, _direction, _pose, _returnMode] call GAIT_fnc_sprintReturnClip
    };
    missionNamespace setVariable ["GAIT_slopeOwner", _unit];
    missionNamespace setVariable ["GAIT_locomotionPhase", "entering"];
    _unit setVariable ["GAIT_locomotionPhase", "entering"];
    _unit setVariable ["GAIT_slopeAttemptLatched", true];
    _unit setVariable ["GAIT_slopeAttemptFamily", _family];
    _unit setVariable ["GAIT_slopeAttemptWeapon", currentWeapon _unit];
    _unit setVariable ["GAIT_slopeEntrySource", _animation];
    _unit setVariable ["GAIT_slopeEntryTarget", _target];
    _unit setVariable ["GAIT_slopeEntryDeadline", diag_tickTime + 1.5];
    _unit setVariable ["GAIT_slopeExitPending", false];
    _unit setVariable ["GAIT_slopeExitIssued", false];
    _unit setVariable ["GAIT_slopeFailureReported", false];
    if (missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false]) then {
        diag_log format ["[GAIT_LOCOMOTION] entry graph request %1 -> %2", _animation, _target];
    };
    [_unit, _target] call GAIT_fnc_requestLocomotionMove;
};

GAIT_fnc_locomotionGaitIntent = {
    params ["_phase", "_turbo", "_animation", "_entryTarget"];
    private _observed = toLower _animation;
    private _wanted = _observed;
    if (_phase isEqualTo "entering" && {_entryTarget isNotEqualTo ""}) then {
        _wanted = toLower _entryTarget;
    };
    // An exact mixed blend may already be leaving GAIT sprint when Turbo is
    // released. Its native endpoint must not hide the still-observed sprint.
    private _divider = _wanted find "_amov";
    if (!_turbo && {_divider >= 0}) exitWith {
        private _left = _wanted select [0, _divider];
        private _right = _wanted select [_divider + 1];
        if !([_wanted, _left, _right] call GAIT_fnc_isStandingLocomotionBlend) exitWith {""};
        private _sprintEndpoint = [_left, _right] findIf {
            private _parts = _x splitString "_";
            private _marker = _parts param [1, ""];
            _marker isEqualTo "gaitsprint" || {_marker isEqualTo "gait" && {(_x select [8, 4]) isEqualTo "meva"}}
        };
        ["", "release"] select (_sprintEndpoint >= 0)
    };
    // Idle and non-GAIT animations do not establish an owned gait. Neutral
    // state selectors already choose the right moving family from live input.
    private _states = [_wanted] call GAIT_fnc_splitSlopeBlend;
    private _state = _states param [1, _wanted];
    private _parts = _state splitString "_";
    private _marker = _parts param [1, ""];
    if !(_marker in ["gait", "gaitsprint"]) exitWith {""};
    private _pace = _state select [8, 4];
    if (_turbo && {_pace in ["mrun", "mwlk", "mtac"]} && {_marker isNotEqualTo "gaitsprint"}) exitWith {"sprint"};
    if (!_turbo && {_pace isEqualTo "meva" || {_marker isEqualTo "gaitsprint"}}) exitWith {"release"};
    ""
};

GAIT_fnc_locomotionEntryStillInJog = {
    params ["_phase", "_animation", "_entryTarget"];
    if (_phase isNotEqualTo "entering") exitWith {false};
    private _target = toLower _entryTarget;
    private _targetsSprint = ((_target select [8, 4]) isEqualTo "meva") || {"gaitsprint" in (_target splitString "_")};
    _targetsSprint && {(["active", true, _animation, ""] call GAIT_fnc_locomotionGaitIntent) isEqualTo "sprint"}
};

// Movement stays in the jog action map after Shift release, with direct
// interpolation edges between all eight directions.
GAIT_fnc_sprintReleaseJogIntent = {
    params ["_allowed", "_moving", "_turbo", "_alreadyJogging", "_gaitIntent"];
    _allowed && {_moving} && {!_turbo} && {_alreadyJogging || {_gaitIntent isEqualTo "release"}}
};

GAIT_fnc_releaseJogRedirectNeeded = {
    params ["_animation", "_source", "_oldTarget", "_beforeDeadline", "_target"];
    private _observed = toLower _animation;
    private _destination = ([_observed] call GAIT_fnc_splitSlopeBlend) param [1, _observed];
    // Arma can still report the previous direction before the requested
    // blend starts. A reversal must replace that request even if it leads
    // back to the direction currently visible.
    if (_beforeDeadline && {_oldTarget isNotEqualTo ""} && {_observed isEqualTo toLower _source}) then {
        _destination = toLower _oldTarget;
    };
    _destination isNotEqualTo toLower _target
};

// Input changes outrank both pending entry and active acceleration. Held
// direction or Turbo never replays a graph request.
GAIT_fnc_redirectLocomotionEntryDirection = {
    params [["_unit", objNull, [objNull]], ["_input", [], [[]]], ["_gaitIntent", "", [""]],
        ["_returnMode", ""], ["_modeChanged", false]];
    if (isNull _unit || {(count _input) < 3}) exitWith {false};
    private _phase = _unit getVariable ["GAIT_locomotionPhase", "native"];
    if (!(_phase in ["entering", "active"]) ||
        {!(_unit getVariable ["GAIT_directionChangedThisFrame", false]) && {_gaitIntent isNotEqualTo "sprint"} && {!_modeChanged}}) exitWith {false};
    private _moving = abs (_input select 0) > 0.05 || {abs (_input select 1) > 0.05};
    private _stance = [_unit] call GAIT_fnc_readLocomotionStance;
    if (!_moving || {!isTouchingGround _unit} || {!(_stance in ["STAND", "CROUCH"])} ||
        {!([_unit, false] call GAIT_fnc_nativeMovementEligible)}) exitWith {false};
    private _direction = [_input select 0, _input select 1] call GAIT_fnc_slopeDirection;
    private _family = [_unit] call GAIT_fnc_slopeWeaponFamily;
    if (_family isEqualTo "" ||
        {currentWeapon _unit isNotEqualTo (_unit getVariable ["GAIT_slopeAttemptWeapon", currentWeapon _unit])}) exitWith {false};
    private _pose = ["Perc", "Pknl"] select (_stance isEqualTo "CROUCH");
    private _target = if (_returnMode isEqualTo "") then {
        [_family, _direction, _input select 2, _pose] call GAIT_fnc_slopeStateName
    } else {
        _family = [_unit, _family] call GAIT_fnc_sprintReturnFamily;
        [_family, _direction, _pose, _returnMode] call GAIT_fnc_sprintReturnClip
    };
    private _oldTarget = _unit getVariable ["GAIT_slopeEntryTarget", ""];
    private _releaseJog = _unit getVariable ["GAIT_sprintReleaseJog", false];
    if (!_releaseJog && {_phase isEqualTo "entering"} && {(toLower _oldTarget) isEqualTo (toLower _target)}) exitWith {false};
    if (!isClass (configFile >> "CfgMovesMaleSdr" >> "States" >> _target)) exitWith {false};

    private _animation = [_unit] call GAIT_fnc_readLocomotionAnimation;
    private _source = _unit getVariable ["GAIT_slopeEntrySource", ""];
    private _beforeDeadline = diag_tickTime <= (_unit getVariable ["GAIT_slopeEntryDeadline", -1]);
    private _insideFamily = ([_animation] call GAIT_fnc_slopeAnimationFamily) isNotEqualTo "";
    private _handoffBlend = [_animation, _source, _oldTarget] call GAIT_fnc_isLocomotionHandoffBlend;
    private _handoffSource = [_animation, _source, _beforeDeadline] call GAIT_fnc_isLocomotionHandoffSource;
    private _known = [_animation, _source, _beforeDeadline, _insideFamily, _handoffBlend, _handoffSource]
        call GAIT_fnc_locomotionEntryRedirectKnown;
    if (!_known) exitWith {false};
    private _redirectNeeded = if (_releaseJog) then {
        [_animation, _source, _oldTarget, _beforeDeadline, _target] call GAIT_fnc_releaseJogRedirectNeeded
    } else {
        (toLower _animation) isNotEqualTo (toLower _target)
    };
    if (!_redirectNeeded) exitWith {false};

    if (_gaitIntent isEqualTo "sprint") then {
        _unit setVariable ["GAIT_locomotionPhase", "entering"];
        missionNamespace setVariable ["GAIT_locomotionPhase", "entering"];
    };
    _unit setVariable ["GAIT_slopeEntrySource", _animation];
    _unit setVariable ["GAIT_slopeEntryTarget", _target];
    _unit setVariable ["GAIT_slopeEntryDeadline", diag_tickTime + 1.5];
    if (missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false]) then {
        diag_log format ["[GAIT_LOCOMOTION] live input redirect %1 -> %2", _animation, _target];
    };
    [_unit, _target] call GAIT_fnc_requestLocomotionMove;
    true
};

GAIT_fnc_uphillSprintRecoveryDecision = {
    params ["_phase", "_requested", "_eligible", "_used", "_input", "_grade", "_animation", "_family"];
    if (!(_phase in ["active", "blocked"]) || {!_requested} || {!_eligible} || {_used} ||
        {_grade <= 0.01} || {!(_input select 2)} || {(_input select 0) <= 0.05} || {_family isEqualTo ""}) exitWith {false};
    if !(([_input select 0, _input select 1] call GAIT_fnc_slopeDirection) in ["Df", "Dfl", "Dfr"]) exitWith {false};
    private _state = toLower _animation;
    private _familyLower = toLower _family;
    if (!((_state select [0, 8]) in ["amovperc", "amovpknl"]) ||
        {(_state select [12, 8]) isNotEqualTo _familyLower}) exitWith {false};
    private _pace = _state select [8, 4];
    private _direction = _state select [20];
    if (_pace isEqualTo "mstp") exitWith {_direction isEqualTo "dnon"};
    if !(_pace in ["mrun", "mwlk", "mtac"]) exitWith {false};
    private _directions = ["df", "dfl", "dfr", "dl", "dbr", "db", "dbl", "dr"];
    if (_pace in ["mwlk", "mtac"] && {_familyLower isEqualTo "slowwrfl"}) then {
        _directions append (_directions apply {_x + "_ver2"});
    };
    _direction in _directions
};

GAIT_fnc_ownedNativeLateralSprint = {
    params ["_phase", "_animation", "_family", "_entryTarget"];
    if !(_phase in ["entering", "active"]) exitWith {false};
    if ((["active", false, _entryTarget, ""] call GAIT_fnc_locomotionGaitIntent) isNotEqualTo "release") exitWith {false};
    private _name = toLower _animation;
    (_name select [0, 12]) in ["amovpercmrun", "amovpknlmrun"] &&
        {(_name select [12, 8]) isEqualTo toLower _family} &&
        {(_name select [20]) in ["dl", "dbr", "db", "dbl", "dr"]}
};

// A new Turbo press can replace an issued ordinary release before it finishes.
// One edge produces one graph request. Held Turbo, an unissued/deferred exit,
// unrelated animation, lost input, stale envelope or unsafe context cannot.
GAIT_fnc_resumeLocomotionExit = {
    params ["_unit", "_input"];
    if (isNull _unit || {(_unit getVariable ["GAIT_locomotionPhase", "native"]) isNotEqualTo "exiting"}) exitWith {false};
    private _aceSlopeLock = (_unit getVariable ["ace_common_effect_blockSprint", 0]) > 0 ||
        {(_unit getVariable ["ace_common_effect_forceWalk", 0]) > 0};
    private _forcedWalk = [_unit] call GAIT_fnc_readLocomotionForcedWalk;
    private _turbo = _input select 2;
    private _nativeWalk = [_unit, _turbo] call GAIT_fnc_nativeWalkRequested;
    private _ordinarySlopeJog = _unit getVariable ["GAIT_slopeJogIntent", false] &&
        {!_aceSlopeLock} && {!_nativeWalk} &&
        {(_input select 0) > 0.05} && {!_turbo};
    // A short stop blend can be interrupted by a new movement input.
    private _exitTarget = toLower (_unit getVariable ["GAIT_slopeExitTarget", ""]);
    private _resumeInput = (_unit getVariable ["GAIT_turboPressedThisFrame", false]) ||
        {_ordinarySlopeJog && {(_exitTarget select [8, 4]) isEqualTo "mstp"}};
    if (!_resumeInput) exitWith {false};
    private _request = missionNamespace getVariable ["GAIT_locomotionRequest", []];
    private _lease = 1;
    if ((count _request) isNotEqualTo 4 || {(_request select 0) isNotEqualTo _unit} ||
        {diag_tickTime - (_request select 3) > _lease}) exitWith {false};
    private _moving = abs (_input select 0) > 0.05 || {abs (_input select 1) > 0.05};
    private _featureRequest = (_request select 1) && {!(_request select 2)};
    private _requested = !_nativeWalk && {[_featureRequest, _turbo, _moving, _ordinarySlopeJog]
        call GAIT_fnc_locomotionIntent};
    private _enabled = call GAIT_fnc_modeAllowsMovement;
    private _nativeLock = !([_unit] call GAIT_fnc_readLocomotionSprintAllowed) || {_forcedWalk};
    private _locked = _nativeLock || {_aceSlopeLock};
    private _stance = [_unit] call GAIT_fnc_readLocomotionStance;
    private _eligible = _enabled && {!_locked} && {_stance in ["STAND", "CROUCH"]} &&
        {(_unit getVariable ["GAIT_slopeAttemptWeapon", ""]) isEqualTo (currentWeapon _unit)} &&
        {[_unit, false] call GAIT_fnc_nativeMovementEligible};
    private _animation = [_unit] call GAIT_fnc_readLocomotionAnimation;
    private _known = ([_animation] call GAIT_fnc_slopeAnimationFamily) isNotEqualTo "" ||
        {[_unit, _animation] call GAIT_fnc_isPendingLocomotionExitSource} ||
        {[_animation, _unit getVariable ["GAIT_slopeExitSource", ""],
            _unit getVariable ["GAIT_slopeExitTarget", ""]] call GAIT_fnc_isLocomotionHandoffBlend};
    if !(["exiting", true, _unit getVariable ["GAIT_slopeExitIssued", false], _requested, _eligible, _known] call GAIT_fnc_locomotionResumeDecision) exitWith {false};
    private _family = [_unit] call GAIT_fnc_slopeWeaponFamily;
    private _pose = ["Perc", "Pknl"] select (_stance isEqualTo "CROUCH");
    if (_family isEqualTo "" || {!([_family, _pose] call GAIT_fnc_slopeFamilyAvailable)}) exitWith {false};
    [_unit, _family, _input, _animation] call GAIT_fnc_beginLocomotionEntry;
    true
};

GAIT_fnc_yieldLocomotionInput = {
    params ["_unit", "_suspended"];
    private _wasSuspended = missionNamespace getVariable ["GAIT_locomotionInputWasSuspended", false];
    if (_wasSuspended isEqualTo _suspended) exitWith {_suspended};
    missionNamespace setVariable ["GAIT_locomotionInputWasSuspended", _suspended];
    [_unit] call GAIT_fnc_clearLocomotionInputHistory;
    if (_suspended) then {
        [] call GAIT_fnc_releaseNativeMovement;
    } else {
        // A request from before the dialog has stale input. Give the current
        // body animation and fresh gameplay input first say after resuming.
        missionNamespace setVariable ["GAIT_locomotionRequest", []];
        if (!isNull _unit && {_unit isEqualTo (missionNamespace getVariable ["GAIT_slopeOwner", objNull])} &&
            {_unit getVariable ["GAIT_slopeExitIssued", false]}) then {
            [_unit] call GAIT_fnc_clearSlopeLocomotionState;
        };
    };
    _suspended
};

GAIT_fnc_tickLocomotion = {
    if ([player, call GAIT_fnc_locomotionInputSuspended] call GAIT_fnc_yieldLocomotionInput) exitWith {};

    // Observe edges while cleanup is deferred too. Recording intent never
    // authorizes an entry or body command to overtake that cleanup.
    private _input = [] call GAIT_fnc_getMovementInput;
    private _stanceYieldNow = false;
    private _weaponYieldNow = false;
    private _nativeWalk = false;
    if (!isNull player) then {
        [player, _input] call GAIT_fnc_observeLocomotionInput;
        if (player getVariable ["GAIT_nativeReleaseOwnsDirection", false]) then {
            private _nativeDirection = [true, _input] call GAIT_fnc_ownsNativeReleaseDirection;
            if (!_nativeDirection) then {player setVariable ["GAIT_nativeReleaseOwnsDirection", false];};
            private _releasePace = player getVariable ["GAIT_sprintReleasePace", []];
            if (_releasePace isNotEqualTo [] && {!_nativeDirection ||
                {([_releasePace select 0, diag_tickTime, _releasePace param [2, 1]] call GAIT_fnc_sprintWalkProgress) >= 1}}) then {
                player setVariable ["GAIT_sprintReleasePace", []];
                player setVariable ["GAIT_sprintReleaseMode", ""];
            };
        };
        _nativeWalk = !(player getVariable ["ace_dragging_isCarrying", false]) &&
            {[player, _input select 2] call GAIT_fnc_nativeWalkRequested};
        private _windDown = !(_input select 2) && {
            player getVariable ["GAIT_sprintReleaseJog", false] ||
            {(player getVariable ["GAIT_sprintReleasePace", []]) isNotEqualTo []} ||
            {player getVariable ["GAIT_turboReleasedThisFrame", false] &&
                {player getVariable ["GAIT_slopeAttemptLatched", false]}}
        };
        _weaponYieldNow = [player] call GAIT_fnc_weaponYieldActive;
        if (!_weaponYieldNow && {(player getVariable ["GAIT_weaponYieldUntil", -1]) >= 0}) then {
            player setVariable ["GAIT_weaponYieldUntil", -1];
        };
        if (_windDown && {!_weaponYieldNow}) then {
            private _switching = [player] call GAIT_fnc_readWeaponSwitching;
            if (_switching || {call GAIT_fnc_getWeaponSlotInput}) then {
                if (!_switching) then {[player, _input, _nativeWalk] call GAIT_fnc_yieldWindDownAnimation;};
                [player] call GAIT_fnc_beginNativeReleaseDirection;
                [] call GAIT_fnc_releaseSpeedCoefficient;
                player setVariable ["GAIT_weaponYieldUntil", diag_tickTime + 0.45];
                _weaponYieldNow = true;
            };
        };
        private _stanceHeld = call GAIT_fnc_getStanceInput;
        private _stanceEdge = [player, _stanceHeld] call GAIT_fnc_observeStanceInput;
        private _observedStance = [player] call GAIT_fnc_readLocomotionStance;
        private _moving = abs (_input select 0) > 0.05 || {abs (_input select 1) > 0.05};
        private _now = diag_tickTime;
        private _travelSample = [];
        if (_moving && {!_weaponYieldNow} && {(!_stanceHeld || {_stanceEdge})} && {_observedStance in ["STAND", "CROUCH"]}) then {
            private _v = velocity player;
            private _speed = vectorMagnitude [_v select 0, _v select 1, 0];
            if (_speed > 0.15 || {_stanceEdge && {(player getVariable ["GAIT_stanceSpeedBeforeInput", []]) isNotEqualTo []}}) then {
                private _drag = missionNamespace getVariable ["GAIT_vegDragFactor", 0];
                _travelSample = [_now, currentWeapon player, [player] call GAIT_fnc_readLocomotionAnimation,
                    _speed / (1 - (_drag max 0 min 0.25))];
            };
        };
        if (!_moving) then {player setVariable ["GAIT_stanceSpeedLimit", []];};
        if (!_stanceHeld) then {
            player setVariable ["GAIT_stanceBeforeInput", _observedStance];
            player setVariable ["GAIT_stanceSpeedBeforeInput", _travelSample];
        };
        if (_stanceEdge) then {
            private _fromStance = _observedStance;
            if (_fromStance in ["STAND", "CROUCH", "PRONE"]) then {
                private _crouch = !_weaponYieldNow && {_fromStance in ["STAND", "CROUCH"]} &&
                    {_moving} &&
                    {call GAIT_fnc_crouchToggleHeld};
                private _handoff = [];
                private _release = player getVariable ["GAIT_sprintReleasePace", []];
                private _crouchTarget = "";
                if (_crouch) then {
                    private _before = player getVariable ["GAIT_stanceBeforeInput", ""];
                    _crouchTarget = [_before, _observedStance] call GAIT_fnc_crouchInputTarget;
                    if (_crouchTarget isNotEqualTo "" && {_before isNotEqualTo ""}) then {_fromStance = _before;};
                };
                if (_crouchTarget isNotEqualTo "") then {
                    private _target = [player, _input, _nativeWalk, _crouchTarget] call GAIT_fnc_yieldWindDownAnimation;
                    if (_travelSample isNotEqualTo [] && {_target isNotEqualTo ""} &&
                        {(toLower _target select [8, 4]) in ["mrun", "mwlk", "mtac", "meva", "mspr"]}) then {
                        _travelSample params ["_sampleTime", "_weapon", "_source", "_travelSpeed"];
                        private _before = player getVariable ["GAIT_stanceSpeedBeforeInput", []];
                        // The native action can change the root motion before Draw3D sees the input.
                        if (_before isNotEqualTo [] && {_sampleTime - (_before select 0) <= 0.20} && {(_before select 1) isEqualTo _weapon}) then {
                            _source = _before select 2;
                            _travelSpeed = _before select 3;
                        };
                        if (_travelSpeed > 0.15) then {
                            // An observed idle clip has no stride to use as a reference.
                            if ((toLower _source select [8, 4]) isEqualTo "mstp") then {_source = _target;};
                            private _limit = player getVariable ["GAIT_stanceSpeedLimit", []];
                            _travelSpeed = [_now, _weapon, _travelSpeed, _limit] call GAIT_fnc_limitStanceTravelSpeed;
                            player setVariable ["GAIT_stanceSpeedLimit", [_now + 0.65, _weapon, _travelSpeed]];
                            _handoff = [_source, _target, _travelSpeed, _weapon];
                        };
                    };
                };
                [player, _fromStance, _handoff isNotEqualTo []] call GAIT_fnc_beginStanceYield;
                player setVariable ["GAIT_stanceTravel", _handoff];
                if (_handoff isNotEqualTo []) then {
                    player setVariable ["GAIT_stanceYieldUntil", diag_tickTime + 1];
                };
                if (_windDown && {_handoff isNotEqualTo []}) then {
                    [player, _input, _release, _handoff select 1, _handoff select 2, _now]
                        call GAIT_fnc_beginMovingStanceRelease;
                };
            };
            if (_windDown) then {player setVariable ["GAIT_nativeReleaseOwnsDirection", true];};
        };
        _stanceYieldNow = [player] call GAIT_fnc_stanceYieldActive;
        if (!_stanceEdge && {!_weaponYieldNow} &&
            {[player, _input, _nativeWalk, _stanceYieldNow, _now] call GAIT_fnc_continueMovingStance}) then {
            _stanceYieldNow = true;
        };
        if (!_stanceYieldNow && {!_weaponYieldNow}) then {
            if (!(_input select 2) && {!(player getVariable ["GAIT_turboReleasedThisFrame", false])} &&
                {(player getVariable ["GAIT_locomotionPhase", "native"]) isNotEqualTo "exiting"}) then {
                private _before = player getVariable ["GAIT_preSprintPose", []];
                private _observed = [player] call GAIT_fnc_readLocomotionAnimation;
                private _inRelease = player getVariable ["GAIT_sprintReleaseJog", false];
                // The custom release clips are output. A later native pose
                // change from raise/lower input can replace the remembered pose.
                if (!_inRelease || {(toLower _observed find "_gait") < 0}) then {
                    private _snapshot = [currentWeapon player, _observed, _before, _nativeWalk] call GAIT_fnc_locomotionPoseSnapshot;
                    if (!_inRelease || {(_snapshot param [1, ""]) isNotEqualTo (_before param [1, ""])}) then {
                        if (_snapshot isNotEqualTo _before) then {player setVariable ["GAIT_preSprintPose", _snapshot];};
                    };
                };
            };
            if (!isNil "GAIT_fnc_observePaceCalibration") then {[player, _input] call GAIT_fnc_observePaceCalibration;};
        };
    };
    // This must exit the whole render controller. Continuing into native-stop
    // or exit service here is the abrupt stop-before-crouch regression.
    private _burstRequest = player getVariable ["GAIT_burstRequest", []];
    if (_burstRequest param [3,false] && {!_weaponYieldNow} && {_input select 2} &&
        {(_input select 0) > 0.05} && {time <= (_burstRequest select 1)} &&
        {stance player in ["STAND","CROUCH"]} && {isSprintAllowed player} && {!isForcedWalk player} &&
        {!(call GAIT_fnc_getStanceInput)} && {!(call GAIT_fnc_getWeaponSlotInput)} &&
        {!(call GAIT_fnc_readAimInput)} && {!([player] call GAIT_fnc_readWeaponSwitching)} &&
        {[player] call GAIT_fnc_fatigueMovementContextEligible} &&
        {((toLower animationState player) select [0,4]) isEqualTo "amov"} &&
        {[player,false,true] call GAIT_fnc_nativeMovementEligible}) exitWith {
        _burstRequest set [3,false];
        player setVariable ["GAIT_burstRequest", _burstRequest];
        private _family = [player] call GAIT_fnc_slopeWeaponFamily;
        if (_family isNotEqualTo "") then {
            player setVariable ["GAIT_stanceYieldUntil", -1];
            player setVariable ["GAIT_stanceYieldStarted", -1];
            player setVariable ["GAIT_stanceTravel", []];
            player setVariable ["GAIT_sprintReleasePace", []];
            player setVariable ["GAIT_sprintReleaseJog", false];
            [player, _family, _input, animationState player] call GAIT_fnc_beginLocomotionEntry;
        };
    };
    if (_stanceYieldNow || {_weaponYieldNow}) exitWith {};
    if (!isNull player && {[player, _input] call GAIT_fnc_yieldMovingOptics}) exitWith {};
    if ([player, _input, _nativeWalk] call GAIT_fnc_releaseNativeSprint) exitWith {};
    if ([player] call GAIT_fnc_beginNativeLocomotionStop) exitWith {};
    private _owner = missionNamespace getVariable ["GAIT_slopeOwner", objNull];
    if ([_owner, _input] call GAIT_fnc_resumeLocomotionExit) exitWith {};
    if ([_owner] call GAIT_fnc_serviceLocomotionExit) exitWith {};
    _owner = missionNamespace getVariable ["GAIT_slopeOwner", objNull];
    // Exit service is the sole observer of pending cancellation. It may be
    // waiting safely on ground contact while an issued entry still reports
    // its native source. Do not let the generic state policy clear that lease
    // or let a held key overtake a safely deferred body handoff. A fresh
    // press can reverse only an issued, ordinary exit in the helper above.
    if (!isNull _owner && {(_owner getVariable ["GAIT_locomotionPhase", "native"]) isEqualTo "exiting"}) exitWith {};
    private _request = missionNamespace getVariable ["GAIT_locomotionRequest", []];
    private _lease = 1;
    private _fresh = (count _request) isEqualTo 4 && {diag_tickTime - (_request select 3) <= _lease};
    private _unit = if (_fresh) then {_request param [0, objNull, [objNull]]} else {objNull};
    if (isNull _unit || {_unit isNotEqualTo player} || {!local _unit}) exitWith {
        if (!isNull _owner) then {[_owner] call GAIT_fnc_releaseSlopeLocomotion;};
    };
    if (!isNull _owner && {_owner isNotEqualTo _unit}) then {
        [_owner] call GAIT_fnc_releaseSlopeLocomotion;
        // The replacement player's fresh submission is still valid.
        missionNamespace setVariable ["GAIT_locomotionRequest", _request];
    };
    private _moving = abs (_input select 0) > 0.05 || {abs (_input select 1) > 0.05};
    private _enabled = call GAIT_fnc_modeAllowsMovement;
    private _aceSlopeLock = (_unit getVariable ["ace_common_effect_blockSprint", 0]) > 0 ||
        {(_unit getVariable ["ace_common_effect_forceWalk", 0]) > 0};
    private _forcedWalk = [_unit] call GAIT_fnc_readLocomotionForcedWalk;
    private _turbo = _input select 2;
    private _ordinarySlopeJog = _unit getVariable ["GAIT_slopeJogIntent", false] &&
        {!(_unit getVariable ["GAIT_nativeReleaseOwnsDirection", false])} &&
        {!_aceSlopeLock} && {!_nativeWalk} &&
        {(_input select 0) > 0.05} && {!_turbo};
    private _nativeSlopeLock = !([_unit] call GAIT_fnc_readLocomotionSprintAllowed) || {_forcedWalk};
    private _locked = (_request select 2) || {_nativeSlopeLock} || {_aceSlopeLock};
    private _allowed = _enabled && {!_locked} && {_request select 1};
    private _requested = _allowed && {!_nativeWalk} && {[_request select 1, _turbo, _moving, _ordinarySlopeJog]
        call GAIT_fnc_locomotionIntent};
    private _stance = [_unit] call GAIT_fnc_readLocomotionStance;
    private _animation = [_unit] call GAIT_fnc_readLocomotionAnimation;
    private _pose = ["Perc", "Pknl"] select (_stance isEqualTo "CROUCH");
    private _eligible = _stance in ["STAND", "CROUCH"] &&
        {((toLower _animation) select [4, 4]) isEqualTo toLower _pose} &&
        {[_unit, false] call GAIT_fnc_nativeMovementEligible};
    private _activeFamily = [_animation] call GAIT_fnc_slopeAnimationFamily;
    private _family = [_unit] call GAIT_fnc_slopeWeaponFamily;
    private _phase = _unit getVariable ["GAIT_locomotionPhase", "native"];
    private _oldWeapon = _unit getVariable ["GAIT_slopeAttemptWeapon", ""];
    if (_phase isNotEqualTo "native" && {_oldWeapon isNotEqualTo (currentWeapon _unit)}) exitWith {
        [_unit, _input] call GAIT_fnc_releaseSlopeLocomotion;
    };
    private _riflePose = "";
    if (_phase isEqualTo "active" && {_eligible} && {_allowed} && {_moving} &&
        {_turbo || {_unit getVariable ["GAIT_turboReleasedThisFrame", false]}}) then {
        _riflePose = [_unit, _animation, _activeFamily] call GAIT_fnc_observeSprintRiflePose;
    };
    if (_requested && {_turbo} && {(_input select 0) > 0.05} && {_activeFamily isEqualTo ""} &&
        {_riflePose isNotEqualTo ""} && {[_riflePose, _pose] call GAIT_fnc_slopeFamilyAvailable}) exitWith {
        // Some weapon actions first expose the corresponding native sprint.
        [_unit, _riflePose, _input, _animation] call GAIT_fnc_beginLocomotionEntry;
    };
    if (_turbo) then {_family = [_unit, _family] call GAIT_fnc_sprintReturnFamily;};
    private _entryTarget = _unit getVariable ["GAIT_slopeEntryTarget", ""];
    private _rawGrade = missionNamespace getVariable ["GAIT_rawSlopeDegrees", 0];
    if (_eligible) then {
        private _uphillSprint = _requested && {_turbo} && {(_input select 0) > 0.05} &&
            {_rawGrade > 18} && {_activeFamily isNotEqualTo ""} &&
            {(["active", false, _animation, ""] call GAIT_fnc_locomotionGaitIntent) isEqualTo "release"};
        _unit setVariable ["GAIT_uphillSprintGroundedAt", [-1, diag_tickTime] select _uphillSprint];
    };
    if (!_eligible && {_requested} && {[_unit, _input, _locked] call GAIT_fnc_uphillSprintContactPending}) exitWith {};
    private _gaitIntent = "";
    private _releasedAfterStance = _phase isEqualTo "native" && {_activeFamily isNotEqualTo ""} &&
        {_unit getVariable ["GAIT_turboReleasedThisFrame", false]};
    if (_allowed && {_phase in ["active", "entering"] || {_releasedAfterStance}}) then {
        _gaitIntent = [_phase, _turbo, _animation, _entryTarget]
            call GAIT_fnc_locomotionGaitIntent;
        if (!_turbo && {_gaitIntent isEqualTo ""} && {_unit getVariable ["GAIT_turboReleasedThisFrame", false]} &&
            {[_animation, _family] call GAIT_fnc_isNativeStandingSprint}) then {_gaitIntent = "release";};
    };
    private _releaseJog = _unit getVariable ["GAIT_sprintReleaseJog", false];
    private _keepReleaseJog = [_allowed, _moving, _turbo, _releaseJog, _gaitIntent]
        call GAIT_fnc_sprintReleaseJogIntent;
    if (_keepReleaseJog && {!_releaseJog} && {_eligible} && {_family isNotEqualTo ""} &&
        {[_family, _pose] call GAIT_fnc_slopeFamilyAvailable}) exitWith {
        private _now = diag_tickTime;
        private _speed = [_unit getVariable ["GAIT_sprintReleaseSample", []],
            _unit getVariable ["GAIT_turboPressSerial", 0], _now] call GAIT_fnc_sprintReleaseStartSpeed;
        private _returnFamily = [_unit, _family] call GAIT_fnc_sprintReturnFamily;
        private _returnMode = [_unit, _nativeWalk, _returnFamily] call GAIT_fnc_liveSprintReturnMode;
        private _releaseGrade = [_unit, 2, _input] call GAIT_fnc_getTravelSlopeDegrees;
        private _slopeScale = [_releaseGrade] call GAIT_fnc_sprintReleaseSlopeScale;
        private _initialMode = [_returnMode, "jog"] select ([_returnMode, _speed, _slopeScale] call GAIT_fnc_sprintReleaseInterimJog);
        _unit setVariable ["GAIT_sprintReleaseJog", true];
        _unit setVariable ["GAIT_sprintReleasePace", [_now, _speed, _slopeScale]];
        _unit setVariable ["GAIT_sprintReleaseMode", _returnMode];
        if (missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false]) then {
            diag_log format ["[GAIT_LOCOMOTION] sprint release restores %1 %2 (grade %3, carry %4 m/s)",
                _returnFamily, _returnMode, _releaseGrade, _speed];
        };
        [_unit, _returnFamily, _input, _animation, _initialMode] call GAIT_fnc_beginLocomotionEntry;
    };
    // The stop handoff can use the immediately preceding release to choose
    // the shoulder animation even if the sprint-to-jog clip already started.
    if (_releaseJog && {!_keepReleaseJog} && {_moving || {_turbo}}) then {
        _unit setVariable ["GAIT_sprintReleaseJog", false];
        _unit setVariable ["GAIT_sprintReleasePace", []];
        _unit setVariable ["GAIT_sprintReleaseMode", ""];
    };
    _requested = _requested || {_releaseJog && {_keepReleaseJog}};
    private _returnMode = "";
    private _modeChanged = false;
    if (_releaseJog && {_keepReleaseJog}) then {
        private _returnFamily = [_unit, _family] call GAIT_fnc_sprintReturnFamily;
        _returnMode = [_unit, _nativeWalk, _returnFamily] call GAIT_fnc_liveSprintReturnMode;
        _unit setVariable ["GAIT_sprintReleaseMode", _returnMode];
        private _releasePace = _unit getVariable ["GAIT_sprintReleasePace", []];
        private _slopeScale = _releasePace param [2, 1];
        if ([_returnMode, _releasePace param [1, 0], _slopeScale] call GAIT_fnc_sprintReleaseInterimJog) then {
            private _progress = [_releasePace select 0, diag_tickTime, _slopeScale] call GAIT_fnc_sprintWalkProgress;
            private _destination = ["mwlk", "mtac"] select (_returnMode isEqualTo "combat");
            private _travel = velocity _unit;
            private _speedMS = vectorMagnitude [_travel select 0, _travel select 1, 0];
            private _destinationReference = -1;
            if (!isNil "GAIT_fnc_releaseClipReference") then {
                private _destinationClip = [_returnFamily,
                    [_input select 0, _input select 1] call GAIT_fnc_slopeDirection, _pose, _returnMode]
                    call GAIT_fnc_sprintReturnClip;
                _destinationReference = [_unit, _destinationClip, _rawGrade] call GAIT_fnc_releaseClipReference;
                private _plan = _unit getVariable ["GAIT_releasePacePlan", []];
                if ([_plan, diag_tickTime, _releasePace select 0, currentWeapon _unit, _destinationClip]
                    call GAIT_fnc_releasePlanValid) then {
                    _speedMS = _plan select 4;
                    _destinationReference = _plan select 5;
                } else {
                    // Before the next scheduled plan, keep the same release
                    // curve with the conservative native endpoint.
                    _speedMS = [_releasePace, _destinationReference, _progress] call GAIT_fnc_sprintReleaseSpeed;
                };
            };
            if !([_progress, _entryTarget, _animation, getAnimSpeedCoef _unit, _destination,
                _speedMS, _destinationReference] call GAIT_fnc_sprintReleaseUsesSlowerPace) then {
                _returnMode = "jog";
            };
        };
        private _pace = ["mrun", "mwlk", "mtac"] select (["jog", "walk", "combat"] find _returnMode);
        _modeChanged = (toLower _entryTarget select [8, 4]) isNotEqualTo _pace;
    };
    private _nativeLateralSprint = _requested && {_eligible} && {_turbo} &&
        {[_phase, _animation, _family, _entryTarget] call GAIT_fnc_ownedNativeLateralSprint};
    if (_nativeLateralSprint && {(_input select 0) > 0.05} && {_phase isEqualTo "active"} &&
        {[_family, _pose] call GAIT_fnc_slopeFamilyAvailable}) exitWith {
        // This also handles W arriving during the last frame of a blend.
        // beginLocomotionEntry latches entering, so this cannot reissue.
        [_unit, _family, _input, _animation] call GAIT_fnc_beginLocomotionEntry;
    };
    // Live locks take priority. An eligible direction edge can redirect
    // both the sprint-to-jog blend and the established jog.
    if (_requested && {_eligible} &&
        {[_unit, _input, _gaitIntent, _returnMode, _modeChanged] call GAIT_fnc_redirectLocomotionEntryDirection}) exitWith {};
    if (([_phase, _requested, _eligible, _unit getVariable ["GAIT_uphillSprintRecoveryUsed", false],
        _input, _rawGrade, _animation, _family]
        call GAIT_fnc_uphillSprintRecoveryDecision) && {[_family, _pose] call GAIT_fnc_slopeFamilyAvailable}) exitWith {
        _unit setVariable ["GAIT_uphillSprintRecoveryUsed", true];
        [_unit, _family, _input, _animation] call GAIT_fnc_beginLocomotionEntry;
    };
    private _expectedBlend = [_animation, _unit getVariable ["GAIT_slopeEntrySource", ""], _entryTarget]
        call GAIT_fnc_isLocomotionHandoffBlend;
    _expectedBlend = _expectedBlend || {[_animation, _unit getVariable ["GAIT_slopeEntrySource", ""],
        diag_tickTime <= (_unit getVariable ["GAIT_slopeEntryDeadline", -1])] call GAIT_fnc_isLocomotionHandoffSource};
    // During a pace redirect the engine may report the old GAIT jog for a
    // frame. It cannot satisfy the pending sprint request merely by belonging
    // to the same weapon family, or held Turbo would replay the redirect.
    private _sprintStillInJog = [_phase, _animation, _entryTarget]
        call GAIT_fnc_locomotionEntryStillInJog;
    private _jogStillInSprint = _phase isEqualTo "entering" && {_releaseJog} && {_keepReleaseJog} &&
        {(["active", false, _animation, ""] call GAIT_fnc_locomotionGaitIntent) isEqualTo "release"};
    private _insideTarget = (_activeFamily isNotEqualTo "" && {!_sprintStillInJog} && {!_jogStillInSprint}) ||
        {_nativeLateralSprint && {(_input select 0) <= 0.05}};
    private _compatibleBlend = _activeFamily isEqualTo "" && {_requested} && {_phase in ["active", "entering"]} &&
        {[_unit, _animation] call GAIT_fnc_locomotionMayFinishMoveBlend};
    private _action = [_phase, _requested, _eligible, _insideTarget, _expectedBlend,
        diag_tickTime > (_unit getVariable ["GAIT_slopeEntryDeadline", -1]), _moving, _compatibleBlend]
        call GAIT_fnc_locomotionDecision;
    switch (_action) do {
        case "release": {
            [_unit, _input] call GAIT_fnc_releaseSlopeLocomotion;
            // Ordinary key release cancels body intent, not the still-valid
            // movement-context envelope needed for a render-frame re-press.
            if (_enabled && {!_locked} && {_eligible}) then {
                missionNamespace setVariable ["GAIT_locomotionRequest", _request];
            };
            // The player's current stop/strafe intent does not wait another
            // render frame or scheduled speed tick for its safe native exit.
            [_unit] call GAIT_fnc_serviceLocomotionExit;
        };
        case "clear": {
            if !(_phase isEqualTo "native" && {_unit getVariable ["GAIT_nativeReleaseOwnsDirection", false]}) then {
                [_unit] call GAIT_fnc_clearSlopeLocomotionState;
            };
        };
        case "active": {
            if (_phase isEqualTo "native") then {
                _unit setVariable ["GAIT_slopeAttemptFamily", _activeFamily];
                _unit setVariable ["GAIT_slopeAttemptWeapon", currentWeapon _unit];
                _unit setVariable ["GAIT_slopeAttemptLatched", true];
            };
            _unit setVariable ["GAIT_locomotionPhase", "active"];
            _unit setVariable ["GAIT_slopeLocomotionActive", true];
            missionNamespace setVariable ["GAIT_slopeOwner", _unit];
            missionNamespace setVariable ["GAIT_locomotionPhase", "active"];
            missionNamespace setVariable ["GAIT_slopeLocomotionActive", true];
        };
        case "escape": {
            _unit setVariable ["GAIT_locomotionPhase", "blocked"];
            _unit setVariable ["GAIT_slopeFailureReported", true];
            _unit setVariable ["GAIT_slopeLocomotionActive", false];
            missionNamespace setVariable ["GAIT_locomotionPhase", "blocked"];
            missionNamespace setVariable ["GAIT_slopeLocomotionActive", false];
            if (missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false]) then {
                diag_log format ["[GAIT_LOCOMOTION] graph escaped to %1; no reassertion; release Turbo to rearm.", _animation];
            };
        };
        case "enter": {
            if (_family isEqualTo "" || {!([_family, _pose] call GAIT_fnc_slopeFamilyAvailable)}) exitWith {};
            if (!_turbo && {!([_animation] call GAIT_fnc_locomotionNativeJogNeedsOverride)}) exitWith {};
            [_unit, _family, _input, _animation] call GAIT_fnc_beginLocomotionEntry;
        };
    };
};

GAIT_fnc_installLocomotionController = {
    if (!hasInterface) exitWith {};
    if ((missionNamespace getVariable ["GAIT_locomotionDrawHandler", -1]) >= 0) exitWith {};
    isNil {
        // Remember very short presses until the render controller observes them.
        // These passive action listeners also follow keyboard/controller rebinds.
        {
            addUserActionEventHandler [_x,"Activate",{
                if (!isNull player && {!dialog} && {!visibleMap}) then {
                    player setVariable ["GAIT_firePressedAt",diag_tickTime];
                };
            }];
        } forEach ["DefaultAction","Fire"];
        private _id = addMissionEventHandler ["Draw3D", {[] call GAIT_fnc_tickLocomotion;}];
        missionNamespace setVariable ["GAIT_locomotionDrawHandler", _id];
    };
};
