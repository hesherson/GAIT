/*
    GAIT traversal helpers.
    Compile once after the legacy helper declarations in fn_initSprintSystem.
    These helpers never force an animation, velocity, stamina or ACE status.
*/

// Pure input resolver, shared by live polling and the regression tests.
GAIT_fnc_resolveMovementInput = {
    params ["_forwardAction", "_backAction", "_leftAction", "_rightAction", "_turboAction"];
    private _forward = (_forwardAction max 0 min 1) - (_backAction max 0 min 1);
    private _right = (_rightAction max 0 min 1) - (_leftAction max 0 min 1);
    if (abs _forward <= 0.05) then {_forward = 0;};
    if (abs _right <= 0.05) then {_right = 0;};
    private _magnitude = sqrt ((_forward * _forward) + (_right * _right));
    if (_magnitude > 1) then {
        _forward = _forward / _magnitude;
        _right = _right / _magnitude;
    };
    [_forward, _right, _turboAction > 0]
};

GAIT_fnc_getMovementInput = {
    // Bohemia's action table: TurnLeft/Right strafe; MoveLeft/Right rotate.
    // Preserve the existing held-Turbo contract, including remapped bindings.
    [inputAction "MoveForward", inputAction "MoveBack", inputAction "TurnLeft", inputAction "TurnRight", inputAction "Turbo"] call GAIT_fnc_resolveMovementInput
};

GAIT_fnc_stepSpeedCoefficient = {
    params ["_current", "_target", "_ramp", "_dt"];
    private _alpha = 1 - ((1 - (_ramp max 0.001 min 1)) ^ ((_dt max 0 min 0.20) / 0.05));
    _current + ((_target - _current) * _alpha)
};

GAIT_fnc_isSuspendedContext = {
    if (isNull player || {!local player} || {!alive player}) exitWith {true};
    if ((missionNamespace getVariable ["GAIT_ss_suspendWhileUnconscious", true]) && {player getVariable ["ACE_isUnconscious", false]}) exitWith {true};
    if (!isNull (findDisplay 312)) exitWith {true};
    if (!isNull (player getVariable ["bis_fnc_moduleRemoteControl_unit", objNull])) exitWith {true};

    // Keep exitWith at function scope. Inside a nested then-block its return
    // value was discarded and a spectator camera incorrectly returned false.
    private _camera = cameraOn;
    private _foreignCamera = !isNull _camera && {_camera != player} && {_camera != vehicle player};
    if ((missionNamespace getVariable ["GAIT_ss_suspendInSpectator", true]) && {_foreignCamera}) exitWith {true};
    false
};

GAIT_fnc_nativeMovementEligible = {
    params [
        ["_unit", player, [objNull]],
        ["_allowCarry", false, [false]]
    ];
    if (isNull _unit || {!local _unit} || {_unit != player} || {!alive _unit}) exitWith {false};
    if !(call GAIT_fnc_modeAllowsMovement) exitWith {false};
    if (call GAIT_fnc_isSuspendedContext) exitWith {false};
    if (!isNull (objectParent _unit) || {!isNull (attachedTo _unit)} || {!isTouchingGround _unit}) exitWith {false};
    if ((lifeState _unit) isEqualTo "INCAPACITATED") exitWith {false};
    if (_unit getVariable ["ACE_isUnconscious", false]) exitWith {false};
    if (_unit getVariable ["GAIT_isTripping", false]) exitWith {false};
    if (_unit getVariable ["MAV_fastCarry_pickupActive", false]) exitWith {false};
    if (_unit getVariable ["ace_dragging_isDragging", false]) exitWith {false};
    if (_unit getVariable ["ace_dragging_isDragged", false]) exitWith {false};
    if (_unit getVariable ["ace_dragging_isCarried", false]) exitWith {false};
    private _carrying = _unit getVariable ["ace_dragging_isCarrying", false];
    if (_carrying && {!_allowCarry}) exitWith {false};
    if ((_unit getVariable ["ace_common_isClimbing", false]) isEqualTo true) exitWith {false};
    if ((missionNamespace getVariable ["ace_common_isClimbing", false]) isEqualTo true) exitWith {false};
    if ((_unit getVariable ["ace_medical_treatment_inProgress", false]) isEqualTo true) exitWith {false};
    if ((missionNamespace getVariable ["ace_medical_treatment_inProgress", false]) isEqualTo true) exitWith {false};

    // Accept ordinary locomotion and idle states only. A transition can still
    // report the old stance, so a name joining two animation states must not
    // qualify. Preserve suffix variants such as injured locomotion instead of
    // rejecting every underscore. Full-body actions remain outside the list.
    private _animation = toLower (animationState _unit);
    private _transition = ["_amov", "_acin", "_ainv", "_acts", "_aadj", "_adth", "_awop", "_aswm", "_aovr", "_acrg"] findIf {(_animation find _x) >= 0};
    if (_transition >= 0) exitWith {false};
    private _action = ["reload", "medic", "melee", "throw", "climb", "ladder", "putdown", "getin", "getout", "vault", "dive", "diving", "roll", "salute", "surrender", "gear"] findIf {(_animation find _x) >= 0};
    if (_action >= 0) exitWith {false};
    private _nativePrefix = (_animation select [0, 4]) isEqualTo "amov";
    private _carryPrefix = _allowCarry && {_carrying} && {(_animation select [0, 4]) isEqualTo "acin"};
    if (!_nativePrefix && {!_carryPrefix}) exitWith {false};
    if !((_animation select [4, 4]) in ["perc", "pknl", "ppne"]) exitWith {false};
    if !((_animation select [8, 4]) in ["mstp", "mwlk", "mrun", "mtac", "meva", "mspr"]) exitWith {false};
    // Reloading can be a gesture over an ordinary Amov body state. Avoid
    // speeding the upper-body action just because locomotion still qualifies.
    // gestureState was introduced in Arma 3 2.06 (GAIT requires 2.14 or later).
    private _gesture = toLower (gestureState _unit);
    if ((_gesture find "reload") >= 0 || {(_gesture find "melee") >= 0} || {(_gesture find "throw") >= 0}) exitWith {false};

    // Context only: the caller clears the ACE AF source first, then respects
    // any remaining ACE forceWalk/blockSprint owners. Testing those masks here
    // would prevent releasing GAIT's intended AF movement override.
    true
};

GAIT_fnc_getTravelSlopeDegrees = {
    params [
        ["_unit", player, [objNull]],
        ["_sampleDistance", 2.0, [0]],
        ["_movementInput", [], [[]]]
    ];
    if (isNull _unit) exitWith {0};
    private _position = getPosASL _unit;
    // Terrain elevation is not a bridge, stair, rooftop or platform surface.
    // Leave those surfaces to native locomotion instead of sampling the hill
    // beneath the structure. This is intentionally a conservative terrain test.
    if (((_position select 2) - (getTerrainHeightASL _position)) > 0.6) exitWith {0};

    if ((count _movementInput) < 2) then {
        _movementInput = if (_unit isEqualTo player) then {call GAIT_fnc_getMovementInput} else {[0, 0, false]};
    };
    private _forward = _movementInput param [0, 0, [0]];
    private _right = _movementInput param [1, 0, [0]];
    private _facing = vectorDir _unit;
    _facing set [2, 0];
    private _faceMagnitude = vectorMagnitude _facing;
    if (_faceMagnitude < 0.001) then {
        _facing = [sin (getDir _unit), cos (getDir _unit), 0];
    } else {
        _facing = _facing vectorMultiply (1 / _faceMagnitude);
    };

    // Arma world axes: forward north [0,1] has right east [1,0].
    private _direction = [
        ((_facing select 0) * _forward) + ((_facing select 1) * _right),
        ((_facing select 1) * _forward) - ((_facing select 0) * _right),
        0
    ];
    private _magnitude = vectorMagnitude _direction;
    if (_magnitude < 0.001) then {
        private _velocity = velocity _unit;
        _direction = [_velocity select 0, _velocity select 1, 0];
        _magnitude = vectorMagnitude _direction;
        if (_magnitude < 0.1) then {
            _direction = +_facing;
            _magnitude = 1;
        };
    };
    _direction = _direction vectorMultiply (1 / _magnitude);
    _sampleDistance = (_sampleDistance max 0.25) min 10;
    private _offset = _direction vectorMultiply _sampleDistance;
    private _ahead = _position vectorAdd _offset;
    private _behind = _position vectorDiff _offset;
    private _rise = (getTerrainHeightASL _ahead) - (getTerrainHeightASL _behind);
    atan (_rise / (2 * _sampleDistance))
};
