/*
    GAIT sprint locomotion family owner.

    The engine chooses directions inside the custom Actions family. Script
    changes the body animation only when entering or leaving that family. No
    key-up handler, animation watchdog, velocity write or per-tick playMove is
    used. The same family is used on flat and sloped terrain, so crossing the
    engine's normal walk threshold does not itself switch animation families.
    CfgMoves behavior still requires an Arma 3 runtime test.
*/

// Pure directional selection shared by entry, release and regression tests.
GAIT_fnc_slopeDirection = {
    params [["_forward", 0, [0]], ["_right", 0, [0]]];
    if (abs _forward <= 0.05 && {abs _right <= 0.05}) exitWith {"Dnon"};
    private _angle = _right atan2 _forward;
    private _index = floor (((_angle + 382.5) mod 360) / 45);
    ["Df", "Dfr", "Dr", "Dbr", "Db", "Dbl", "Dl", "Dfl"] select _index
};

GAIT_fnc_slopeWeaponFamily = {
    params ["_unit"];
    private _weapon = currentWeapon _unit;
    if (_weapon isEqualTo "") exitWith {"SnonWnon"};
    if (_weapon isEqualTo (handgunWeapon _unit)) exitWith {"SrasWpst"};
    if (_weapon isEqualTo (primaryWeapon _unit)) exitWith {
        if (weaponLowered _unit) then {"SlowWrfl"} else {"SrasWrfl"}
    };
    // Launcher, binocular and mod-specific weapon poses keep their own maps.
    ""
};

GAIT_fnc_isSlopeLocomotionState = {
    params ["_state"];
    (getNumber (configFile >> "CfgMovesMaleSdr" >> "States" >> _state >> "GAIT_slopeState")) isEqualTo 1
};

GAIT_fnc_slopeFamilyAvailable = {
    params ["_family"];
    private _cacheName = "GAIT_slopeFamilyAvailable_" + _family;
    private _cached = missionNamespace getVariable [_cacheName, -1];
    if (_cached >= 0) exitWith {_cached isEqualTo 1};
    private _states = configFile >> "CfgMovesMaleSdr" >> "States";
    private _available = true;
    {
        private _name = "AmovPercMrun" + _family + _x + "_GAIT";
        private _state = _states >> _name;
        private _actions = getText (_state >> "actions");
        private _native = getText (_state >> "GAIT_nativeState");
        if (!isClass _state || {!(getNumber (_state >> "GAIT_slopeState") isEqualTo 1)} || {!isClass (_states >> _native)} || {(getText (_states >> _native >> "file")) isEqualTo ""} || {!isClass (configFile >> "CfgMovesBasic" >> "Actions" >> _actions)}) exitWith {
            _available = false;
        };
    } forEach ["Df", "Dfl", "Dl", "Dbl", "Db", "Dbr", "Dr", "Dfr"];
    missionNamespace setVariable [_cacheName, if (_available) then {1} else {0}];
    if (!_available) then {
        diag_log format ["[GAIT] Slope locomotion family %1 is incomplete. Its custom entry is disabled.", _family];
    };
    _available
};

GAIT_fnc_releaseSlopeLocomotion = {
    params [
        ["_unit", missionNamespace getVariable ["GAIT_slopeOwner", objNull], [objNull]],
        ["_movementInput", [], [[]]],
        ["_walkOnly", false, [false]]
    ];
    private _keepAttempt = false;
    if (!isNull _unit) then {
        if ((count _movementInput) < 3) then {
            _movementInput = if (_unit isEqualTo player) then {call GAIT_fnc_getMovementInput} else {[0, 0, false]};
        };
        private _enabled = (missionNamespace getVariable ["GAIT_ss_slopeLocomotionEnabled", true]) && {missionNamespace getVariable ["GAIT_ss_slopeHandlingEnabled", true]} && {call GAIT_fnc_modeAllowsMovement};
        private _familyNow = [_unit] call GAIT_fnc_slopeWeaponFamily;
        private _familyBefore = _unit getVariable ["GAIT_slopeAttemptFamily", ""];
        _keepAttempt = _enabled && {_movementInput select 2} && {(_movementInput select 0) > 0.05} && {_familyNow isEqualTo _familyBefore};
        private _animation = animationState _unit;
        private _insideFamily = [_animation] call GAIT_fnc_isSlopeLocomotionState;
        // A medical, vehicle, climbing or other full-body action which already
        // left our family is never replaced. An upper-body reload gesture over
        // our family can safely return its body state to the native parent.
        private _ordinaryBody = local _unit && {alive _unit} && {isNull (objectParent _unit)} && {isNull (attachedTo _unit)} && {!((lifeState _unit) isEqualTo "INCAPACITATED")} && {!(_unit getVariable ["ACE_isUnconscious", false])} && {!(_unit getVariable ["GAIT_isTripping", false])};
        if (_insideFamily && {_ordinaryBody}) then {
            private _states = configFile >> "CfgMovesMaleSdr" >> "States";
            private _parent = getText (_states >> _animation >> "GAIT_nativeState");
            private _family = [_unit] call GAIT_fnc_slopeWeaponFamily;
            if (_family isEqualTo "") then {_family = _parent select [12, 8];};
            private _direction = [_movementInput select 0, _movementInput select 1] call GAIT_fnc_slopeDirection;
            private _posture = switch (stance _unit) do {
                case "CROUCH": {"Pknl"};
                case "PRONE": {"Ppne"};
                default {"Perc"};
            };
            private _pace = if (_direction isEqualTo "Dnon") then {"Mstp"} else {if (_walkOnly) then {"Mwlk"} else {"Mrun"}};
            private _target = "Amov" + _posture + _pace + _family + _direction;
            // Some stances have no directional run class for a given weapon.
            // Use their native idle first, then the known native parent.
            if (!isClass (_states >> _target)) then {_target = "Amov" + _posture + "Mstp" + _family + "Dnon";};
            if (!isClass (_states >> _target)) then {_target = _parent;};
            if (isClass (_states >> _target)) then {
                // switchMove is immediate and has no queue to drain after a
                // direction reversal. This is a single family-exit boundary.
                _unit switchMove _target;
            };
        };
        // A transient native transition or reload must not re-arm entry while
        // Turbo + forward remain held. Root's coefficient-owner release also
        // calls here, so preserving this latch prevents a hidden retry loop.
        if (!_keepAttempt) then {
            _unit setVariable ["GAIT_slopeAttemptLatched", false];
            _unit setVariable ["GAIT_slopeAttemptFamily", ""];
            _unit setVariable ["GAIT_slopeEntryDeadline", -1];
            _unit setVariable ["GAIT_slopeFailureReported", false];
        };
        _unit setVariable ["GAIT_slopeLocomotionActive", false];
    };
    private _owner = missionNamespace getVariable ["GAIT_slopeOwner", objNull];
    if (isNull _unit || {_owner isEqualTo _unit}) then {
        missionNamespace setVariable ["GAIT_slopeOwner", if (_keepAttempt) then {_unit} else {objNull}];
        missionNamespace setVariable ["GAIT_slopeLocomotionActive", false];
    };
};

GAIT_fnc_updateSlopeLocomotion = {
    params [
        ["_unit", player, [objNull]],
        ["_sprintIntent", false, [false]],
        ["_movementInput", [], [[]]],
        ["_externalLock", false, [false]]
    ];
    private _owner = missionNamespace getVariable ["GAIT_slopeOwner", objNull];
    if (!isNull _owner && {!(_owner isEqualTo _unit)}) then {[_owner] call GAIT_fnc_releaseSlopeLocomotion;};
    if (isNull _unit || {!local _unit} || {!(_unit isEqualTo player)}) exitWith {
        [_unit] call GAIT_fnc_releaseSlopeLocomotion;
        false
    };
    if ((count _movementInput) < 3) then {_movementInput = call GAIT_fnc_getMovementInput;};
    private _forward = _movementInput select 0;
    private _right = _movementInput select 1;
    private _enabled = (missionNamespace getVariable ["GAIT_ss_slopeLocomotionEnabled", true]) && {missionNamespace getVariable ["GAIT_ss_slopeHandlingEnabled", true]};
    private _wantsSprint = _enabled && {_sprintIntent} && {_movementInput select 2} && {_forward > 0.05} && {!_externalLock};
    private _eligible = _wantsSprint && {(stance _unit) isEqualTo "STAND"} && {[_unit, false] call GAIT_fnc_nativeMovementEligible};
    if (!_eligible) exitWith {
        [_unit, _movementInput, _externalLock] call GAIT_fnc_releaseSlopeLocomotion;
        false
    };

    // Grade affects pace only. Using one run family for the entire standing
    // sprint avoids an abrupt root-motion change at a fixed terrain angle.
    private _family = [_unit] call GAIT_fnc_slopeWeaponFamily;
    private _oldFamily = _unit getVariable ["GAIT_slopeAttemptFamily", ""];
    if (!(_oldFamily isEqualTo "") && {!(_oldFamily isEqualTo _family)}) exitWith {
        [_unit, _movementInput] call GAIT_fnc_releaseSlopeLocomotion;
        false
    };
    private _attempted = _unit getVariable ["GAIT_slopeAttemptLatched", false];
    private _animation = animationState _unit;
    private _insideFamily = [_animation] call GAIT_fnc_isSlopeLocomotionState;
    missionNamespace setVariable ["GAIT_slopeOwner", _unit];
    if (_insideFamily) exitWith {
        _unit setVariable ["GAIT_slopeLocomotionActive", true];
        missionNamespace setVariable ["GAIT_slopeLocomotionActive", true];
        true
    };

    _unit setVariable ["GAIT_slopeLocomotionActive", false];
    missionNamespace setVariable ["GAIT_slopeLocomotionActive", false];
    if (_attempted) exitWith {
        // If the engine rejects the graph or a third-party animation replaces
        // it, never turn that disagreement into a repeating switchMove loop.
        if (diag_tickTime > (_unit getVariable ["GAIT_slopeEntryDeadline", -1]) && {!(_unit getVariable ["GAIT_slopeFailureReported", false])}) then {
            _unit setVariable ["GAIT_slopeFailureReported", true];
            diag_log format ["[GAIT] Sprint locomotion family is no longer active (%1). Entry is paused until sprint is released or the weapon family changes.", _animation];
        };
        false
    };

    if (_family isEqualTo "") exitWith {false};
    if !([_family] call GAIT_fnc_slopeFamilyAvailable) exitWith {false};
    private _direction = [_forward, _right] call GAIT_fnc_slopeDirection;
    private _target = "AmovPercMrun" + _family + _direction + "_GAIT";
    _unit setVariable ["GAIT_slopeAttemptLatched", true];
    _unit setVariable ["GAIT_slopeAttemptFamily", _family];
    _unit setVariable ["GAIT_slopeEntryDeadline", diag_tickTime + 0.35];
    _unit setVariable ["GAIT_slopeFailureReported", false];
    // A single immediate entry avoids the queue and repeated directional
    // animation commands which caused the old A/D reversal latency.
    _unit switchMove _target;
    _insideFamily = [animationState _unit] call GAIT_fnc_isSlopeLocomotionState;
    _unit setVariable ["GAIT_slopeLocomotionActive", _insideFamily];
    missionNamespace setVariable ["GAIT_slopeLocomotionActive", _insideFamily];
    _insideFamily
};
