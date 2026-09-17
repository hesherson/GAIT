/*
    Local Arma acceptance capture. Copy this file into the test mission folder.

    Start or restart from the LOCAL debug console:
      [] execVM "slope_runtime_capture.sqf";

    Before each pass, give the capture a useful label:
      GAIT_runtimeCaptureLabel = "walk_75lb_same_hill";
      GAIT_runtimeCaptureLabel = "sprint_75lb_same_hill";
      GAIT_runtimeCaptureLabel = "strafe_reversals_75lb_same_hill";

    Stop without restarting the mission:
      GAIT_runtimeCaptureEnabled = false;

    RPT lines begin [GAIT_CAPTURE]. The recorder adds one local EachFrame
    handler, samples at 10 Hz, and only reads movement/physiology. It never
    changes the player, controls, animation, velocity or ACE state.

    Compare walking and sprinting on the same unobstructed terrain strip,
    heading, weapon posture, load and fatigue level. Wait until the launch
    brace and acceleration settle before comparing surfaceMS, then repeat
    above and below the old native walk threshold. Check that A/D reversals
    change inputR immediately and actualR follows without forward-only stalls.
    Test W+A -> W+D, release A while D remains held, pure A/D, and Shift release.
    Repeat with heavy kit above 75 lb and with depleted sprint reserve.

    surfaceMS is velocity projected onto the local terrain tangent. Use open
    terrain for comparison; terrain normals do not describe bridges/rooftops.
    A model ratio or animation name alone is not proof of physical pace.
*/

if (!hasInterface) exitWith {};
private _oldHandler = missionNamespace getVariable ["GAIT_runtimeCaptureHandler", -1];
if (_oldHandler >= 0) then {removeMissionEventHandler ["EachFrame", _oldHandler];};
missionNamespace setVariable ["GAIT_runtimeCaptureEnabled", true];
missionNamespace setVariable ["GAIT_runtimeCaptureNextSample", -1];
if (isNil "GAIT_runtimeCaptureLabel") then {GAIT_runtimeCaptureLabel = "unlabelled";};

diag_log "[GAIT_CAPTURE] START";
diag_log "[GAIT_CAPTURE] time;label;inputF;inputR;turbo;rawLeft;rawRight;grade;coef;animation;actions;horizontalMS;surfaceMS;actualF;actualR;gearLbs;sprintAllowed;forcedWalk;aceBlockSprint;aceForceWalk;grounded;stance;reserveRatio;customState;fps;walkTarget;sprintTarget;loadFactor";

private _handler = addMissionEventHandler ["EachFrame", {
    if !(missionNamespace getVariable ["GAIT_runtimeCaptureEnabled", false]) exitWith {
        removeMissionEventHandler ["EachFrame", missionNamespace getVariable ["GAIT_runtimeCaptureHandler", -1]];
        missionNamespace setVariable ["GAIT_runtimeCaptureHandler", -1];
        diag_log "[GAIT_CAPTURE] STOP";
    };
    if (diag_tickTime < (missionNamespace getVariable ["GAIT_runtimeCaptureNextSample", -1])) exitWith {};
    missionNamespace setVariable ["GAIT_runtimeCaptureNextSample", diag_tickTime + 0.1];
    private _unit = player;
    if (isNull _unit || {!local _unit}) exitWith {};

    private _input = if (isNil "GAIT_fnc_getMovementInput") then {
        [(inputAction "MoveForward") - (inputAction "MoveBack"), (inputAction "TurnRight") - (inputAction "TurnLeft"), (inputAction "Turbo") > 0]
    } else {
        call GAIT_fnc_getMovementInput
    };
    private _grade = if (isNil "GAIT_fnc_getTravelSlopeDegrees") then {0} else {
        [_unit, missionNamespace getVariable ["GAIT_ss_slopeSampleDistance", 2], _input] call GAIT_fnc_getTravelSlopeDegrees
    };
    private _velocity = velocity _unit;
    private _normal = surfaceNormal (getPosWorld _unit);
    private _surfaceVelocity = _velocity vectorDiff (_normal vectorMultiply (_velocity vectorDotProduct _normal));
    private _direction = vectorDir _unit;
    _direction set [2, 0];
    private _dirMagnitude = vectorMagnitude _direction;
    if (_dirMagnitude < 0.001) then {_direction = [sin (getDir _unit), cos (getDir _unit), 0];} else {
        _direction = _direction vectorMultiply (1 / _dirMagnitude);
    };
    private _right = [_direction select 1, -(_direction select 0), 0];
    private _animation = animationState _unit;
    private _actions = getText (configFile >> "CfgMovesMaleSdr" >> "States" >> _animation >> "actions");
    private _customState = (((toLower _animation) find "gait") >= 0) || {((toLower _actions) find "gait") >= 0};
    private _exhaustion = missionNamespace getVariable ["GAIT_exhaustionLevel", -1];
    private _row = [
        diag_tickTime,
        missionNamespace getVariable ["GAIT_runtimeCaptureLabel", "unlabelled"],
        _input select 0, _input select 1, _input select 2,
        inputAction "TurnLeft", inputAction "TurnRight",
        _grade, getAnimSpeedCoef _unit, _animation, _actions,
        sqrt (((_velocity select 0) ^ 2) + ((_velocity select 1) ^ 2)),
        vectorMagnitude _surfaceVelocity,
        _velocity vectorDotProduct _direction,
        _velocity vectorDotProduct _right,
        (loadAbs _unit) / ((missionNamespace getVariable ["GAIT_ss_loadAbsPerLb", 10]) max 0.01),
        isSprintAllowed _unit, isForcedWalk _unit,
        _unit getVariable ["ace_common_effect_blockSprint", 0],
        _unit getVariable ["ace_common_effect_forceWalk", 0],
        isTouchingGround _unit, stance _unit,
        if (_exhaustion < 0) then {-1} else {1 - _exhaustion},
        _customState, diag_fps,
        missionNamespace getVariable ["GAIT_walkPaceTarget", -1],
        missionNamespace getVariable ["GAIT_sprintPaceTarget", -1],
        missionNamespace getVariable ["GAIT_loadPaceMultiplier", -1]
    ];
    diag_log ("[GAIT_CAPTURE] " + ((_row apply {str _x}) joinString ";"));
}];
missionNamespace setVariable ["GAIT_runtimeCaptureHandler", _handler];
