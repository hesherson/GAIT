/*
    GAIT locomotion foundation.
    The tuned feature loop submits intent; one Draw3D handler owns animation
    entry. Arma chooses direction inside the family. No direction reassertion,
    velocity writes, terrain-angle switch or automatic failed-entry retry.
    Stop/idle and lateral motion retain ownership while Turbo remains held.
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
    if (_direction isEqualTo "Dnon") then {_pace = "Mstp";};
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

// A custom-to-custom blend is ordinary movement only when BOTH endpoints
// belong to the same registered family. Medical/native/stance transitions do
// not gain eligibility merely because their names contain an Amov fragment.
GAIT_fnc_splitSlopeBlend = {
    params [["_animation", "", [""]]];
    private _parts = (toLower _animation) splitString "_";
    if ((count _parts) isNotEqualTo 4) exitWith {[]};
    if ((_parts select 1) isNotEqualTo "gait" || {(_parts select 3) isNotEqualTo "gait"}) exitWith {[]};
    [(_parts select 0) + "_gait", (_parts select 2) + "_gait"]
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
                if (_firstFamily isEqualTo (getText (_right >> "GAIT_slopeFamily"))) then {_family = _firstFamily;};
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
    params ["_family"];
    private _cacheName = "GAIT_slopeFamilyAvailable_" + _family;
    private _cached = missionNamespace getVariable [_cacheName, -1];
    if (_cached >= 0) exitWith {_cached isEqualTo 1};
    private _states = configFile >> "CfgMovesMaleSdr" >> "States";
    private _available = _family in ["SrasWrfl", "SlowWrfl", "SrasWpst", "SnonWnon"];
    {
        private _name = [_family, _x] call GAIT_fnc_slopeStateName;
        private _state = _states >> _name;
        private _native = getText (_state >> "GAIT_nativeState");
        private _actions = getText (_state >> "actions");
        if (!isClass _state || {(getNumber (_state >> "GAIT_slopeState")) isNotEqualTo 1} ||
            {!isClass (_states >> _native)} || {(getText (_states >> _native >> "file")) isEqualTo ""} ||
            {!isClass (configFile >> "CfgMovesBasic" >> "Actions" >> _actions)}) exitWith {_available = false;};
    } forEach ["Dnon", "Df", "Dfl", "Dl", "Dbl", "Db", "Dbr", "Dr", "Dfr"];
    missionNamespace setVariable [_cacheName, parseNumber _available];
    if (!_available) then {diag_log format ["[GAIT] Incomplete locomotion family %1; entry disabled.", _family];};
    _available
};

// Pure state policy shared by the live controller and sequence regression tests.
// An escape is reported and latched. A held key never becomes an animation
// watchdog that masks the failure by restarting the same clip every frame.
GAIT_fnc_locomotionDecision = {
    params ["_phase", "_requested", "_eligible", "_inside", "_entryBlend", "_expired", "_moving"];
    if (_phase isEqualTo "exiting") exitWith {["clear", "hold"] select (_inside || {_entryBlend})};
    if (!_requested || {!_eligible}) exitWith {
        ["clear", "release"] select (_inside || {_entryBlend} || {_phase in ["entering", "active"]})
    };
    if (_phase isEqualTo "blocked") exitWith {"hold"};
    if (_inside) exitWith {"active"};
    if (_phase isEqualTo "active") exitWith {"escape"};
    if (_phase isEqualTo "entering") exitWith {["hold", "escape"] select (_expired && {!_entryBlend})};
    ["hold", "enter"] select _moving
};

GAIT_fnc_clearSlopeLocomotionState = {
    params [["_unit", objNull, [objNull]]];
    if (!isNull _unit) then {
        {
            _unit setVariable [_x, false];
        } forEach ["GAIT_slopeAttemptLatched", "GAIT_slopeExitPending", "GAIT_slopeFailureReported", "GAIT_slopeLocomotionActive", "GAIT_slopeExitIssued", "GAIT_slopeExitFailureReported"];
        {
            _unit setVariable [_x, ""];
        } forEach ["GAIT_slopeAttemptFamily", "GAIT_slopeAttemptWeapon", "GAIT_slopeEntrySource", "GAIT_slopeEntryTarget"];
        _unit setVariable ["GAIT_slopeEntryDeadline", -1];
        _unit setVariable ["GAIT_slopeCancelDeadline", -1];
        _unit setVariable ["GAIT_slopeExitDeadline", -1];
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
        private _inside = ([animationState _unit] call GAIT_fnc_slopeAnimationFamily) isNotEqualTo "";
        if (!_inside || {!alive _unit} || {!local _unit} || {_unit isNotEqualTo player}) exitWith {
            [_unit] call GAIT_fnc_clearSlopeLocomotionState;
        };
        if ((_unit getVariable ["GAIT_locomotionPhase", "native"]) isEqualTo "exiting") exitWith {};
        if !(_unit getVariable ["GAIT_slopeAttemptLatched", false]) then {
            private _observedFamily = [animationState _unit] call GAIT_fnc_slopeAnimationFamily;
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
    };
};

// Returns true only on the frame a single native exit was issued. The caller
// then stops, so a fast Turbo retap cannot issue exit and entry in one frame.
GAIT_fnc_serviceLocomotionExit = {
    params [["_unit", objNull, [objNull]]];
    if (isNull _unit || {(_unit getVariable ["GAIT_locomotionPhase", "native"]) isNotEqualTo "exiting"}) exitWith {false};
    private _animation = animationState _unit;
    if (([_animation] call GAIT_fnc_slopeAnimationFamily) isEqualTo "" || {!alive _unit} || {!local _unit} || {_unit isNotEqualTo player}) exitWith {
        // A native or full-body action already owns the character. Discard the
        // pending request without sending an animation after that handoff.
        [_unit] call GAIT_fnc_clearSlopeLocomotionState;
        false
    };
    if (_unit getVariable ["GAIT_slopeExitIssued", false]) exitWith {
        if (diag_tickTime > (_unit getVariable ["GAIT_slopeExitDeadline", -1]) && {!(_unit getVariable ["GAIT_slopeExitFailureReported", false])}) then {
            _unit setVariable ["GAIT_slopeExitFailureReported", true];
            diag_log format ["[GAIT_LOCOMOTION] native exit not observed from %1; cleanup ownership retained, no repeated switch.", _animation];
        };
        false
    };
    if !([_unit] call GAIT_fnc_fatigueMovementContextEligible) exitWith {false};
    if (!isTouchingGround _unit || {(stance _unit) isNotEqualTo "STAND"}) exitWith {false};
    private _gesture = toLower (gestureState _unit);
    if ((["reload", "melee", "throw"] findIf {(_gesture find _x) >= 0}) >= 0) exitWith {false};
    private _entryWeapon = _unit getVariable ["GAIT_slopeAttemptWeapon", currentWeapon _unit];
    // Let the inherited weapon transition take the body. Do not cut from an
    // old rifle state into a pistol run merely because selection changed first.
    if (_entryWeapon isNotEqualTo (currentWeapon _unit)) exitWith {false};
    private _input = [] call GAIT_fnc_getMovementInput;
    private _family = [_unit] call GAIT_fnc_slopeWeaponFamily;
    if (_family isEqualTo "") exitWith {false};
    private _direction = [_input select 0, _input select 1] call GAIT_fnc_slopeDirection;
    private _walk = (_unit getVariable ["GAIT_slopeExitWalkOnly", false]) || {isForcedWalk _unit} || {(_unit getVariable ["ace_common_effect_forceWalk", 0]) > 0};
    private _pace = ["Mrun", "Mwlk"] select _walk;
    if (!_walk && {isSprintAllowed _unit} && {(_unit getVariable ["ace_common_effect_blockSprint", 0]) <= 0} &&
        {_input select 2} && {_direction in ["Df", "Dfl", "Dfr"]}) then {_pace = "Meva";};
    if (_direction isEqualTo "Dnon") then {_pace = "Mstp";};
    private _target = "AmovPerc" + _pace + _family + _direction;
    private _states = configFile >> "CfgMovesMaleSdr" >> "States";
    if (!isClass (_states >> _target)) then {_target = "AmovPercMstp" + _family + "Dnon";};
    if (!isClass (_states >> _target)) exitWith {false};
    _unit setVariable ["GAIT_slopeExitIssued", true];
    _unit setVariable ["GAIT_slopeExitDeadline", diag_tickTime + 1.5];
    diag_log format ["[GAIT_LOCOMOTION] exit Draw3D %1 -> %2", _animation, _target];
    _unit switchMove _target;
    true
};

GAIT_fnc_updateSlopeLocomotion = {
    params [["_unit", player, [objNull]], ["_fastMoveIntent", false, [false]], ["_movementInput", [], [[]]], ["_externalLock", false, [false]]];
    // No animation command here. The feature loop may be scheduled and has
    // already calculated the original step-off/brace/momentum coefficients.
    missionNamespace setVariable ["GAIT_locomotionRequest", [_unit, _fastMoveIntent, _externalLock, diag_tickTime]];
    missionNamespace getVariable ["GAIT_slopeLocomotionActive", false]
};

GAIT_fnc_tickLocomotion = {
    private _owner = missionNamespace getVariable ["GAIT_slopeOwner", objNull];
    if ([_owner] call GAIT_fnc_serviceLocomotionExit) exitWith {};
    _owner = missionNamespace getVariable ["GAIT_slopeOwner", objNull];
    private _request = missionNamespace getVariable ["GAIT_locomotionRequest", []];
    private _unit = _request param [0, objNull, [objNull]];
    private _lease = (4 * (missionNamespace getVariable ["GAIT_ss_tickRate", 0.05])) max 1;
    private _fresh = (count _request) isEqualTo 4 && {diag_tickTime - (_request select 3) <= _lease};
    if (!_fresh || {isNull _unit} || {_unit isNotEqualTo player} || {!local _unit}) exitWith {
        if (!isNull _owner) then {[_owner] call GAIT_fnc_releaseSlopeLocomotion;};
    };
    if (!isNull _owner && {_owner isNotEqualTo _unit}) then {
        [_owner] call GAIT_fnc_releaseSlopeLocomotion;
        // The replacement player's fresh submission is still valid.
        missionNamespace setVariable ["GAIT_locomotionRequest", _request];
    };
    private _input = [] call GAIT_fnc_getMovementInput;
    private _moving = abs (_input select 0) > 0.05 || {abs (_input select 1) > 0.05};
    private _enabled = (missionNamespace getVariable ["GAIT_ss_slopeLocomotionEnabled", true]) &&
        {missionNamespace getVariable ["GAIT_ss_slopeHandlingEnabled", true]} && {call GAIT_fnc_modeAllowsMovement};
    private _locked = (_request select 2) || {!isSprintAllowed _unit} || {isForcedWalk _unit} ||
        {(_unit getVariable ["ace_common_effect_blockSprint", 0]) > 0} || {(_unit getVariable ["ace_common_effect_forceWalk", 0]) > 0};
    private _requested = _enabled && {_request select 1} && {_input select 2} && {!_locked};
    private _eligible = (stance _unit) isEqualTo "STAND" && {[_unit, false] call GAIT_fnc_nativeMovementEligible};
    private _animation = animationState _unit;
    private _activeFamily = [_animation] call GAIT_fnc_slopeAnimationFamily;
    private _family = [_unit] call GAIT_fnc_slopeWeaponFamily;
    private _phase = _unit getVariable ["GAIT_locomotionPhase", "native"];
    private _oldWeapon = _unit getVariable ["GAIT_slopeAttemptWeapon", ""];
    if (_phase isNotEqualTo "native" && {_oldWeapon isNotEqualTo (currentWeapon _unit)}) exitWith {
        [_unit, _input, isForcedWalk _unit] call GAIT_fnc_releaseSlopeLocomotion;
    };
    private _expectedBlend = [_animation, _unit getVariable ["GAIT_slopeEntrySource", ""], _unit getVariable ["GAIT_slopeEntryTarget", ""]] call GAIT_fnc_isStandingLocomotionBlend;
    private _action = [_phase, _requested, _eligible, _activeFamily isNotEqualTo "", _expectedBlend,
        diag_tickTime > (_unit getVariable ["GAIT_slopeEntryDeadline", -1]), _moving] call GAIT_fnc_locomotionDecision;
    switch (_action) do {
        case "release": {[_unit, _input, isForcedWalk _unit] call GAIT_fnc_releaseSlopeLocomotion;};
        case "clear": {[_unit] call GAIT_fnc_clearSlopeLocomotionState;};
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
            diag_log format ["[GAIT_LOCOMOTION] graph escaped to %1; no reassertion; release Turbo to rearm.", _animation];
        };
        case "enter": {
            if (_family isEqualTo "" || {!([_family] call GAIT_fnc_slopeFamilyAvailable)}) exitWith {};
            private _direction = [_input select 0, _input select 1] call GAIT_fnc_slopeDirection;
            private _target = [_family, _direction] call GAIT_fnc_slopeStateName;
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
            _unit setVariable ["GAIT_slopeFailureReported", false];
            diag_log format ["[GAIT_LOCOMOTION] entry Draw3D %1 -> %2", _animation, _target];
            // One STRING switch, executed only by Draw3D. This avoids using
            // playMoveNow's scripted sequence as persistent locomotion control.
            // Phase/aim may reset at entry; actual camera behavior needs Arma.
            _unit switchMove _target;
        };
    };
};

GAIT_fnc_installLocomotionController = {
    if (!hasInterface) exitWith {};
    if ((missionNamespace getVariable ["GAIT_locomotionDrawHandler", -1]) >= 0) exitWith {};
    isNil {
        private _id = addMissionEventHandler ["Draw3D", {[] call GAIT_fnc_tickLocomotion;}];
        missionNamespace setVariable ["GAIT_locomotionDrawHandler", _id];
    };
};
