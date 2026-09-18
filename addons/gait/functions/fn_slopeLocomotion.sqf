/*
    GAIT locomotion foundation.
    The tuned feature loop submits intent; one Draw3D handler owns animation
    entry. Arma chooses direction inside the family. No direction reassertion,
    velocity writes, terrain-angle switch or automatic failed-entry retry.
    Lateral motion retains ownership while Turbo remains held. A deliberate
    stop returns to native idle immediately; coefficient inertia never supplies
    movement input. Forward coasting retains the sprint clip through re-taps.
    Genuine low-momentum starts use one short walk-clip brace stage before
    the existing sprint family. Retained momentum never enters that stage.
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
    params ["_family", "_direction", ["_brace", false, [false]]];
    private _pace = ["Mrun", "Meva"] select (_direction in ["Df", "Dfl", "Dfr"]);
    if (_brace) then {_pace = "Mwlk";};
    private _suffix = "";
    if (_direction isEqualTo "Dnon") then {
        _pace = "Mstp";
        if (_brace) then {_suffix = "Brace";};
    };
    "AmovPerc" + _pace + _family + _direction + _suffix + "_GAIT"
};

// Pure command arguments: blendFactor is a pose weight, NOT a duration.
// Start from the existing pose and preserve aim/head offsets. Phase can only
// be reused for an identical RTM; matching feet across different RTMs would
// require authored phase mapping, not a blind copy of the walking phase.
// Arma 3 2.18: https://community.bistudio.com/wiki/switchMove
// https://community.bistudio.com/wiki/getUnitMovesInfo
GAIT_fnc_locomotionSwitchArguments = {
    params ["_target", "_sameClip", ["_progress", 0, [0]]];
    private _phase = 0;
    if (_sameClip && {_progress >= 0} && {_progress <= 1}) then {_phase = _progress;};
    [_target, _phase, 0, false]
};

GAIT_fnc_switchLocomotionSmooth = {
    params ["_unit", "_target"];
    private _states = configFile >> "CfgMovesMaleSdr" >> "States";
    private _sourceFile = toLower (getText (_states >> (animationState _unit) >> "file"));
    private _targetFile = toLower (getText (_states >> _target >> "file"));
    private _sameClip = _sourceFile isNotEqualTo "" && {_sourceFile isEqualTo _targetFile};
    private _info = getUnitMovesInfo _unit;
    private _progress = _info param [0, 0, [0]];
    _unit switchMove ([_target, _sameClip, _progress] call GAIT_fnc_locomotionSwitchArguments);
};

// A brace is entered at most once per activation. Its single promotion may
// be observed, pending or failed, but never becomes an animation watchdog.
GAIT_fnc_braceLocomotionDecision = {
    params ["_stage", "_braceActive", "_beforeEnd", "_role", "_blend", "_expired", ["_newBrace", false, [false]]];
    if (_stage isEqualTo "complete" && {_newBrace} && {_braceActive} && {_beforeEnd}) exitWith {"brace";};
    if (_stage isEqualTo "brace") exitWith {
        ["promote", "hold"] select (_braceActive && {_beforeEnd})
    };
    if (_stage isEqualTo "promoting") exitWith {
        if (_role in ["move", "idle"]) exitWith {"complete"};
        ["hold", "failed"] select (_expired && {!_blend})
    };
    "hold"
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
        private _brace = _x;
        {
            private _name = [_family, _x, _brace] call GAIT_fnc_slopeStateName;
            private _state = _states >> _name;
            private _native = getText (_state >> "GAIT_nativeState");
            private _actions = getText (_state >> "actions");
            if (!isClass _state || {(getNumber (_state >> "GAIT_slopeState")) isNotEqualTo 1} ||
                {!isClass (_states >> _native)} || {(getText (_states >> _native >> "file")) isEqualTo ""} ||
                {!isClass (configFile >> "CfgMovesBasic" >> "Actions" >> _actions)}) exitWith {_available = false;};
        } forEach ["Dnon", "Df", "Dfl", "Dl", "Dbl", "Db", "Dbr", "Dr", "Dfr"];
    } forEach [false, true];
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

// A one-shot entry may still be in its ordinary source state when the player
// releases the keys. Keep ownership until that pending command is cancelled;
// discarding it here lets a late custom sprint land after the release.
GAIT_fnc_locomotionExitOwnsObservation = {
    params ["_inside", "_entryBlend", "_cancelEntry", "_atEntrySource", "_beforeDeadline"];
    _inside || {_entryBlend} || {_cancelEntry && {_atEntrySource} && {_beforeDeadline}}
};

GAIT_fnc_clearSlopeLocomotionState = {
    params [["_unit", objNull, [objNull]]];
    if (!isNull _unit) then {
        {
            _unit setVariable [_x, false];
        } forEach ["GAIT_slopeAttemptLatched", "GAIT_slopeExitPending", "GAIT_slopeFailureReported", "GAIT_slopeLocomotionActive", "GAIT_slopeExitIssued", "GAIT_slopeExitFailureReported", "GAIT_slopeCancelEntry"];
        {
            _unit setVariable [_x, ""];
        } forEach ["GAIT_slopeAttemptFamily", "GAIT_slopeAttemptWeapon", "GAIT_slopeEntrySource", "GAIT_slopeEntryTarget", "GAIT_slopeBraceStage"];
        _unit setVariable ["GAIT_slopeEntryDeadline", -1];
        _unit setVariable ["GAIT_slopeBracePromoteDeadline", -1];
        _unit setVariable ["GAIT_slopeBraceSeenEndTime", -1];
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
        if (!alive _unit || {!local _unit} || {_unit isNotEqualTo player}) exitWith {
            [_unit] call GAIT_fnc_clearSlopeLocomotionState;
        };
        if ((_unit getVariable ["GAIT_locomotionPhase", "native"]) isEqualTo "exiting") exitWith {};
        private _animation = animationState _unit;
        private _inside = ([_animation] call GAIT_fnc_slopeAnimationFamily) isNotEqualTo "";
        private _source = _unit getVariable ["GAIT_slopeEntrySource", ""];
        private _entryBlend = [_animation, _source, _unit getVariable ["GAIT_slopeEntryTarget", ""]] call GAIT_fnc_isStandingLocomotionBlend;
        private _cancelEntry = (_unit getVariable ["GAIT_locomotionPhase", "native"]) isEqualTo "entering";
        private _cancelDeadline = _unit getVariable ["GAIT_slopeEntryDeadline", -1];
        if !([_inside, _entryBlend, _cancelEntry, (toLower _animation) isEqualTo (toLower _source), diag_tickTime <= _cancelDeadline] call GAIT_fnc_locomotionExitOwnsObservation) exitWith {
            [_unit] call GAIT_fnc_clearSlopeLocomotionState;
        };
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
        _unit setVariable ["GAIT_slopeCancelEntry", _cancelEntry];
        _unit setVariable ["GAIT_slopeCancelDeadline", _cancelDeadline];
    };
};

// Returns true only on the frame a single native exit was issued. The caller
// then stops, so a fast Turbo retap cannot issue exit and entry in one frame.
GAIT_fnc_serviceLocomotionExit = {
    params [["_unit", objNull, [objNull]]];
    if (isNull _unit || {(_unit getVariable ["GAIT_locomotionPhase", "native"]) isNotEqualTo "exiting"}) exitWith {false};
    private _animation = animationState _unit;
    private _source = _unit getVariable ["GAIT_slopeEntrySource", ""];
    private _inside = ([_animation] call GAIT_fnc_slopeAnimationFamily) isNotEqualTo "";
    private _entryBlend = [_animation, _source, _unit getVariable ["GAIT_slopeEntryTarget", ""]] call GAIT_fnc_isStandingLocomotionBlend;
    private _cancelEntry = (_unit getVariable ["GAIT_slopeCancelEntry", false]) && {!(_unit getVariable ["GAIT_slopeExitIssued", false])};
    private _ownsObservation = [_inside, _entryBlend, _cancelEntry, (toLower _animation) isEqualTo (toLower _source), diag_tickTime <= (_unit getVariable ["GAIT_slopeCancelDeadline", -1])] call GAIT_fnc_locomotionExitOwnsObservation;
    if (!_ownsObservation || {!alive _unit} || {!local _unit} || {_unit isNotEqualTo player}) exitWith {
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
    [_unit, _target] call GAIT_fnc_switchLocomotionSmooth;
    true
};

GAIT_fnc_updateSlopeLocomotion = {
    params [["_unit", player, [objNull]], ["_fastMoveIntent", false, [false]], ["_movementInput", [], [[]]], ["_externalLock", false, [false]]];
    // No animation command here. The feature loop may be scheduled and has
    // already calculated the original step-off/brace/momentum coefficients.
    missionNamespace setVariable ["GAIT_locomotionRequest", [_unit, _fastMoveIntent, _externalLock, diag_tickTime]];
    missionNamespace getVariable ["GAIT_slopeLocomotionActive", false]
};

// A bounded pre-arm prevents raw Turbo release from beating the scheduled
// uphill-brake calculation to the render controller. Only an existing owner
// may use that grace; the ordinary safety/lease gates still apply afterward.
GAIT_fnc_uphillBrakeKeepsFamily = {
    params ["_phase", "_sameUnit", "_active", "_beforeEnd", "_prearmFresh"];
    _sameUnit && {(_active && {_beforeEnd}) || {_phase in ["entering", "active"] && {_prearmFresh}}}
};

// Render input wins over the slower feature loop. The short prearm bridges
// only the first raw Turbo-release frame, before the taper is published.
// Neither old-player metadata nor a release-to-stop/sideways request can use it.
GAIT_fnc_coastKeepsFamily = {
    params ["_phase", "_sameUnit", "_active", "_prearmFresh", "_forward"];
    _sameUnit && {_forward > 0.05} && {_phase in ["entering", "active"]} && {_active || {_prearmFresh}}
};

GAIT_fnc_locomotionIntent = {
    params ["_featureRequest", "_turbo", "_moving", "_forward", "_brake", "_coast"];
    _featureRequest && {_moving} && {_turbo || {_forward > 0.05 && {_brake || {_coast}}}}
};

GAIT_fnc_tickLocomotion = {
    private _owner = missionNamespace getVariable ["GAIT_slopeOwner", objNull];
    if ([_owner] call GAIT_fnc_serviceLocomotionExit) exitWith {};
    _owner = missionNamespace getVariable ["GAIT_slopeOwner", objNull];
    // Exit service is the sole observer of pending cancellation. It may be
    // waiting safely on ground contact while an issued entry still reports
    // its native source. Do not let the generic state policy clear that lease
    // or let a newer sprint request overtake an uncompleted body handoff.
    if (!isNull _owner && {(_owner getVariable ["GAIT_locomotionPhase", "native"]) isEqualTo "exiting"}) exitWith {};
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
    private _brakeKeepsFamily = [
        _unit getVariable ["GAIT_locomotionPhase", "native"],
        _unit isEqualTo (missionNamespace getVariable ["GAIT_uphillBrakeUnit", objNull]),
        missionNamespace getVariable ["GAIT_uphillBrakeActive", false],
        time < (missionNamespace getVariable ["GAIT_uphillBrakeEndTime", -1]),
        diag_tickTime < (missionNamespace getVariable ["GAIT_uphillBrakeReadyUntil", -1])
    ] call GAIT_fnc_uphillBrakeKeepsFamily;
    private _coastKeepsFamily = [
        _unit getVariable ["GAIT_locomotionPhase", "native"],
        _unit isEqualTo (missionNamespace getVariable ["GAIT_coastUnit", objNull]),
        missionNamespace getVariable ["GAIT_coastActive", false],
        diag_tickTime < (missionNamespace getVariable ["GAIT_coastReadyUntil", -1]),
        _input select 0
    ] call GAIT_fnc_coastKeepsFamily;
    private _requested = _enabled && {!_locked} && {[
        _request select 1, _input select 2, _moving, _input select 0,
        _brakeKeepsFamily, _coastKeepsFamily
    ] call GAIT_fnc_locomotionIntent};
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
        case "release": {
            [_unit, _input, isForcedWalk _unit] call GAIT_fnc_releaseSlopeLocomotion;
            // The player's current stop/strafe intent does not wait another
            // render frame or scheduled speed tick for its safe native exit.
            [_unit] call GAIT_fnc_serviceLocomotionExit;
        };
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
            private _role = getText (configFile >> "CfgMovesMaleSdr" >> "States" >> _animation >> "GAIT_locomotionRole");
            private _braceEnd = missionNamespace getVariable ["GAIT_braceEndTime", -1];
            if (_phase isEqualTo "native") then {
                _unit setVariable ["GAIT_slopeBraceStage", ["complete", "brace"] select (_role isEqualTo "brace")];
            };
            private _braceAction = [
                _unit getVariable ["GAIT_slopeBraceStage", "complete"],
                missionNamespace getVariable ["GAIT_braceActive", false],
                time < _braceEnd,
                _role, [_animation] call GAIT_fnc_isSlopeLocomotionBlend,
                diag_tickTime > (_unit getVariable ["GAIT_slopeBracePromoteDeadline", -1]),
                _braceEnd isNotEqualTo (_unit getVariable ["GAIT_slopeBraceSeenEndTime", -1])
            ] call GAIT_fnc_braceLocomotionDecision;
            if ((_unit getVariable ["GAIT_slopeBraceStage", "complete"]) isEqualTo "brace") then {
                _unit setVariable ["GAIT_slopeBraceSeenEndTime", _braceEnd];
            };
            if (_braceAction isEqualTo "brace") then {
                // A real stop can create a fresh brace while Turbo and custom
                // idle remain owned. The end-time token consumes it only once.
                private _direction = [_input select 0, _input select 1] call GAIT_fnc_slopeDirection;
                private _target = [_activeFamily, _direction, true] call GAIT_fnc_slopeStateName;
                _unit setVariable ["GAIT_slopeBraceStage", "brace"];
                _unit setVariable ["GAIT_slopeBraceSeenEndTime", _braceEnd];
                diag_log format ["[GAIT_LOCOMOTION] new brace Draw3D %1 -> %2", _animation, _target];
                [_unit, _target] call GAIT_fnc_switchLocomotionSmooth;
            };
            if (_braceAction isEqualTo "complete") then {_unit setVariable ["GAIT_slopeBraceStage", "complete"];};
            if (_braceAction isEqualTo "failed") then {
                _unit setVariable ["GAIT_locomotionPhase", "blocked"];
                _unit setVariable ["GAIT_slopeLocomotionActive", false];
                missionNamespace setVariable ["GAIT_locomotionPhase", "blocked"];
                missionNamespace setVariable ["GAIT_slopeLocomotionActive", false];
                diag_log format ["[GAIT_LOCOMOTION] brace promotion not observed from %1; release Turbo to rearm, no reassertion.", _animation];
            };
            if (_braceAction isEqualTo "promote") then {
                private _direction = [_input select 0, _input select 1] call GAIT_fnc_slopeDirection;
                private _target = [_activeFamily, _direction] call GAIT_fnc_slopeStateName;
                // Latch before the one body command. Safety and live intent
                // were checked above; direction remains engine-driven.
                _unit setVariable ["GAIT_slopeBraceStage", "promoting"];
                _unit setVariable ["GAIT_slopeBracePromoteDeadline", diag_tickTime + 1.5];
                diag_log format ["[GAIT_LOCOMOTION] brace handoff Draw3D %1 -> %2", _animation, _target];
                [_unit, _target] call GAIT_fnc_switchLocomotionSmooth;
            };
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
            private _brace = (missionNamespace getVariable ["GAIT_braceActive", false]) &&
                {time < (missionNamespace getVariable ["GAIT_braceEndTime", -1])};
            private _target = [_family, _direction, _brace] call GAIT_fnc_slopeStateName;
            _unit setVariable ["GAIT_slopeBraceStage", ["complete", "brace"] select _brace];
            _unit setVariable ["GAIT_slopeBraceSeenEndTime", missionNamespace getVariable ["GAIT_braceEndTime", -1]];
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
            // One aim-preserving blend request, executed only by Draw3D.
            // The engine owns directional selection after this handoff.
            [_unit, _target] call GAIT_fnc_switchLocomotionSmooth;
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
