/*
    GAIT sprint locomotion family owner.

    Forward and forward-diagonal states inherit the real Meva sprint clips.
    The engine chooses directions inside the Actions family. Script submits one
    blended playMoveNow at entry and one at exit, with no animation watchdog,
    repeated direction commands or velocity writes. Grade changes pace only.
*/

// Pure directional selection shared by entry, release and regression tests.
GAIT_fnc_slopeDirection = {
    params [["_forward", 0, [0]], ["_right", 0, [0]]];
    if (abs _forward <= 0.05 && {abs _right <= 0.05}) exitWith {"Dnon"};
    private _angle = _right atan2 _forward;
    private _index = floor (((_angle + 382.5) mod 360) / 45);
    ["Df", "Dfr", "Dr", "Dbr", "Db", "Dbl", "Dl", "Dfl"] select _index
};

GAIT_fnc_slopeStateName = {
    params ["_family", "_direction"];
    private _pace = ["Mrun", "Meva"] select (_direction in ["Df", "Dfl", "Dfr"]);
    "AmovPerc" + _pace + _family + _direction + "_GAIT"
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
            _families = ["SrasWpst"];
            _fallback = "SrasWpst";
        } else {
            if (_weapon isEqualTo (primaryWeapon _unit)) then {
                _families = ["SlowWrfl", "SrasWrfl"];
                _fallback = ["SrasWrfl", "SlowWrfl"] select (weaponLowered _unit);
            };
        };
    };
    // Launcher, binocular and mod-specific weapon poses keep their own maps.
    if (_families isEqualTo []) exitWith {""};
    private _animation = animationState _unit;
    private _stateFamily = getText (configFile >> "CfgMovesMaleSdr" >> "States" >> _animation >> "GAIT_slopeFamily");
    if (_stateFamily in _families) exitWith {_stateFamily};

    // Sprint clips can lower the weapon themselves. That pose change must not
    // be mistaken for an equipped-weapon change during entry or active sprint.
    private _attemptFamily = _unit getVariable ["GAIT_slopeAttemptFamily", ""];
    if ((_unit getVariable ["GAIT_slopeAttemptLatched", false]) && {(_unit getVariable ["GAIT_slopeAttemptWeapon", ""]) isEqualTo _weapon} && {_attemptFamily in _families}) exitWith {_attemptFamily};
    _fallback
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
        private _name = [_family, _x] call GAIT_fnc_slopeStateName;
        private _state = _states >> _name;
        private _actions = getText (_state >> "actions");
        private _native = getText (_state >> "GAIT_nativeState");
        if (!isClass _state || {(getNumber (_state >> "GAIT_slopeState")) isNotEqualTo 1} || {!isClass (_states >> _native)} || {(getText (_states >> _native >> "file")) isEqualTo ""} || {!isClass (configFile >> "CfgMovesBasic" >> "Actions" >> _actions)}) exitWith {
            _available = false;
        };
    } forEach ["Df", "Dfl", "Dl", "Dbl", "Db", "Dbr", "Dr", "Dfr"];
    missionNamespace setVariable [_cacheName, parseNumber _available];
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
    private _keepOwner = false;
    if (!isNull _unit) then {
        if ((count _movementInput) < 3) then {
            _movementInput = if (_unit isEqualTo player) then {[] call GAIT_fnc_getMovementInput} else {[0, 0, false]};
        };
        private _animation = animationState _unit;
        private _insideFamily = [_animation] call GAIT_fnc_isSlopeLocomotionState;
        private _exitPending = _unit getVariable ["GAIT_slopeExitPending", false];
        private _bodyTransition = ((toLower _animation) find "_amov") >= 0;
        private _entryDeadline = _unit getVariable ["GAIT_slopeEntryDeadline", -1];
        private _expectedEntryBlend = [_animation, _unit getVariable ["GAIT_slopeEntrySource", ""], _unit getVariable ["GAIT_slopeEntryTarget", ""]] call GAIT_fnc_isStandingLocomotionBlend;
        private _pendingEntry = !_insideFamily && {_unit getVariable ["GAIT_slopeAttemptLatched", false]} && {!(_unit getVariable ["GAIT_slopeFailureReported", false])} && {(_entryDeadline > diag_tickTime) || {_expectedEntryBlend}};
        if (_pendingEntry) then {
            _unit setVariable ["GAIT_slopeCancelDeadline", _entryDeadline];
        };
        // Releasing Turbo can race the first entry blend. Keep ownership while
        // that entry could still arrive, even if the body is still native.
        _keepOwner = ((_unit getVariable ["GAIT_slopeCancelDeadline", -1]) > diag_tickTime) || {_expectedEntryBlend} || {_exitPending && {_bodyTransition}};
        // Never replace a medical, vehicle, climbing or other full-body action
        // which has already left our family. A reload gesture retains its own
        // upper-body animation while our body returns to a native parent.
        private _ordinaryBody = local _unit && {alive _unit} && {isNull (objectParent _unit)} && {isNull (attachedTo _unit)} && {(lifeState _unit) isNotEqualTo "INCAPACITATED"} && {!(_unit getVariable ["ACE_isUnconscious", false])} && {!(_unit getVariable ["GAIT_isTripping", false])};
        private _cancelOrdinaryEntry = _pendingEntry && {[_unit, false] call GAIT_fnc_nativeMovementEligible};
        if ((_insideFamily || {_cancelOrdinaryEntry}) && {_ordinaryBody}) then {
            _keepOwner = true;
            if (!_exitPending) then {
                private _states = configFile >> "CfgMovesMaleSdr" >> "States";
                private _parent = getText (_states >> _animation >> "GAIT_nativeState");
                if (_parent isEqualTo "") then {
                    private _entryTarget = _unit getVariable ["GAIT_slopeEntryTarget", ""];
                    _parent = getText (_states >> _entryTarget >> "GAIT_nativeState");
                };
                private _family = [_unit] call GAIT_fnc_slopeWeaponFamily;
                if (_family isEqualTo "") then {_family = _parent select [12, 8];};
                private _direction = [_movementInput select 0, _movementInput select 1] call GAIT_fnc_slopeDirection;
                private _posture = switch (stance _unit) do {
                    case "CROUCH": {"Pknl"};
                    case "PRONE": {"Ppne"};
                    default {"Perc"};
                };
                // Full cleanup also reaches this function without explicit
                // lock arguments. Recheck the remaining restrictions before
                // choosing a native sprint exit or ordinary walking exit.
                private _restrictedWalk = _walkOnly || {isForcedWalk _unit} || {(_unit getVariable ["ace_common_effect_forceWalk", 0]) > 0};
                private _nativeSprintAllowed = !_restrictedWalk && {isSprintAllowed _unit} && {(_unit getVariable ["ace_common_effect_blockSprint", 0]) <= 0} && {[_unit, false] call GAIT_fnc_nativeMovementEligible};
                private _pace = ["Mrun", "Mwlk"] select _restrictedWalk;
                if (_nativeSprintAllowed && {_posture isEqualTo "Perc"} && {_movementInput select 2} && {(_movementInput select 0) > 0.05} && {_direction in ["Df", "Dfl", "Dfr"]}) then {_pace = "Meva";};
                if (_direction isEqualTo "Dnon") then {_pace = "Mstp";};
                private _target = "Amov" + _posture + _pace + _family + _direction;
                // Some stances have no directional run class for a given pose.
                if (!isClass (_states >> _target)) then {_target = "Amov" + _posture + "Mstp" + _family + "Dnon";};
                if (!isClass (_states >> _target)) then {_target = _parent;};
                if (isClass (_states >> _target)) then {
                    _unit setVariable ["GAIT_slopeExitPending", true];
                    // One native target also cancels a pending ordinary entry.
                    // Unrelated full-body actions are never replaced here.
                    _unit playMoveNow _target;
                };
            };
        } else {
            if (!_bodyTransition) then {_unit setVariable ["GAIT_slopeExitPending", false];};
        };

        // Preserve only an actual rejected-entry latch while the same ordinary
        // sprint request remains held. A real context interruption may re-enter
        // after it ends; it must not disable sprint until Turbo is released.
        private _enabled = (missionNamespace getVariable ["GAIT_ss_slopeLocomotionEnabled", true]) && {missionNamespace getVariable ["GAIT_ss_slopeHandlingEnabled", true]} && {[] call GAIT_fnc_modeAllowsMovement};
        private _keepAttempt = _enabled && {!_walkOnly} && {_movementInput select 2} && {(_movementInput select 0) > 0.05} && {_unit getVariable ["GAIT_slopeFailureReported", false]} && {(_unit getVariable ["GAIT_slopeAttemptWeapon", ""]) isEqualTo (currentWeapon _unit)} && {[_unit, false] call GAIT_fnc_nativeMovementEligible};
        if (!_keepAttempt) then {
            _unit setVariable ["GAIT_slopeAttemptLatched", false];
            _unit setVariable ["GAIT_slopeAttemptFamily", ""];
            _unit setVariable ["GAIT_slopeAttemptWeapon", ""];
            _unit setVariable ["GAIT_slopeEntryDeadline", -1];
            // Keep the expected endpoints while a cancelled blend could still
            // finish; the attempt flag is already false, so this cannot admit
            // a new entry or relax the movement-context guard.
            if (!_pendingEntry && {!_expectedEntryBlend}) then {
                _unit setVariable ["GAIT_slopeEntrySource", ""];
                _unit setVariable ["GAIT_slopeEntryTarget", ""];
            };
            _unit setVariable ["GAIT_slopeFailureReported", false];
        };
        _keepOwner = _keepOwner || {_keepAttempt};
        _unit setVariable ["GAIT_slopeLocomotionActive", false];
    };
    private _owner = missionNamespace getVariable ["GAIT_slopeOwner", objNull];
    if (isNull _unit || {_owner isEqualTo _unit}) then {
        missionNamespace setVariable ["GAIT_slopeOwner", if (_keepOwner) then {_unit} else {objNull}];
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
    if (!isNull _owner && {_owner isNotEqualTo _unit}) then {[_owner] call GAIT_fnc_releaseSlopeLocomotion;};
    if (isNull _unit || {!local _unit} || {_unit isNotEqualTo player}) exitWith {
        [_unit] call GAIT_fnc_releaseSlopeLocomotion;
        false
    };
    if ((count _movementInput) < 3) then {_movementInput = [] call GAIT_fnc_getMovementInput;};
    private _forward = _movementInput select 0;
    private _right = _movementInput select 1;
    private _enabled = (missionNamespace getVariable ["GAIT_ss_slopeLocomotionEnabled", true]) && {missionNamespace getVariable ["GAIT_ss_slopeHandlingEnabled", true]};
    private _wantsSprint = _enabled && {_sprintIntent} && {_movementInput select 2} && {_forward > 0.05} && {!_externalLock};
    private _eligible = _wantsSprint && {(stance _unit) isEqualTo "STAND"} && {[_unit, false] call GAIT_fnc_nativeMovementEligible};
    if (!_eligible) exitWith {
        [_unit, _movementInput, _externalLock] call GAIT_fnc_releaseSlopeLocomotion;
        false
    };

    private _animation = animationState _unit;
    private _insideFamily = [_animation] call GAIT_fnc_isSlopeLocomotionState;
    // Finish a requested exit before admitting a new entry. Fast Turbo taps
    // cannot replace an exit blend with another entry on the next polling tick.
    if (_unit getVariable ["GAIT_slopeExitPending", false]) exitWith {
        if (!_insideFamily && {((toLower _animation) find "_amov") < 0}) then {_unit setVariable ["GAIT_slopeExitPending", false];};
        false
    };
    private _family = [_unit] call GAIT_fnc_slopeWeaponFamily;
    private _oldFamily = _unit getVariable ["GAIT_slopeAttemptFamily", ""];
    private _oldWeapon = _unit getVariable ["GAIT_slopeAttemptWeapon", ""];
    if (_oldFamily isNotEqualTo "" && {(_oldFamily isNotEqualTo _family) || {_oldWeapon isNotEqualTo (currentWeapon _unit)}}) exitWith {
        [_unit, _movementInput] call GAIT_fnc_releaseSlopeLocomotion;
        false
    };
    private _attempted = _unit getVariable ["GAIT_slopeAttemptLatched", false];
    missionNamespace setVariable ["GAIT_slopeOwner", _unit];
    if (_insideFamily) exitWith {
        _unit setVariable ["GAIT_slopeLocomotionActive", true];
        missionNamespace setVariable ["GAIT_slopeLocomotionActive", true];
        true
    };

    _unit setVariable ["GAIT_slopeLocomotionActive", false];
    missionNamespace setVariable ["GAIT_slopeLocomotionActive", false];
    if (_attempted) exitWith {
        // A pending graph transition gets time to complete, never a second
        // command. Rejected or replaced entries latch until intent/context ends.
        private _expectedBlend = [_animation, _unit getVariable ["GAIT_slopeEntrySource", ""], _unit getVariable ["GAIT_slopeEntryTarget", ""]] call GAIT_fnc_isStandingLocomotionBlend;
        if (!_expectedBlend && {diag_tickTime > (_unit getVariable ["GAIT_slopeEntryDeadline", -1])} && {!(_unit getVariable ["GAIT_slopeFailureReported", false])}) then {
            _unit setVariable ["GAIT_slopeFailureReported", true];
            diag_log format ["[GAIT] Sprint locomotion entry was rejected or replaced (%1). Entry is paused until the sprint request or context changes.", _animation];
        };
        false
    };

    if (_family isEqualTo "") exitWith {false};
    if !([_family] call GAIT_fnc_slopeFamilyAvailable) exitWith {false};
    private _direction = [_forward, _right] call GAIT_fnc_slopeDirection;
    private _target = [_family, _direction] call GAIT_fnc_slopeStateName;
    _unit setVariable ["GAIT_slopeAttemptLatched", true];
    _unit setVariable ["GAIT_slopeAttemptFamily", _family];
    _unit setVariable ["GAIT_slopeAttemptWeapon", currentWeapon _unit];
    private _entryGrace = (0.8 / ((getAnimSpeedCoef _unit) max 0.1)) max 0.8 min 8;
    _unit setVariable ["GAIT_slopeEntryDeadline", diag_tickTime + _entryGrace];
    _unit setVariable ["GAIT_slopeEntrySource", _animation];
    _unit setVariable ["GAIT_slopeEntryTarget", _target];
    _unit setVariable ["GAIT_slopeFailureReported", false];
    _unit setVariable ["GAIT_slopeExitPending", false];
    _unit setVariable ["GAIT_slopeCancelDeadline", -1];
    _unit playMoveNow _target;
    _insideFamily = [animationState _unit] call GAIT_fnc_isSlopeLocomotionState;
    _unit setVariable ["GAIT_slopeLocomotionActive", _insideFamily];
    missionNamespace setVariable ["GAIT_slopeLocomotionActive", _insideFamily];
    _insideFamily
};
