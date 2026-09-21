/*
    GAIT locomotion foundation.
    The tuned feature loop submits intent; one Draw3D handler owns animation
    entry. Arma chooses direction inside the family. No direction reassertion,
    velocity writes, terrain-angle switch or automatic failed-entry retry.
    Lateral motion retains ownership while Turbo remains held. A deliberate
    stop returns to native idle immediately; coefficient inertia never supplies
    movement input. Release follows live keys while speed tapers separately.
    The original numerical brace acts inside the run/sprint clip immediately.
    Entry and release use the movement graph for interpolation, never a
    switchMove reset or a separate walking-animation stage.
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
    params ["_family", "_direction", ["_sprinting", true, [false]]];
    private _pace = "Mrun";
    if (_direction isEqualTo "Dnon") then {
        _pace = "Mstp";
    } else {
        if (_sprinting && {_direction in ["Df", "Dfl", "Dfr"]}) then {_pace = "Meva";};
    };
    "AmovPerc" + _pace + _family + _direction + "_GAIT"
};

GAIT_fnc_ordinarySlopeJogIntent = {
    params [
        ["_input", [], [[]]],
        ["_slopeDegrees", 0, [0]],
        ["_aceMovementLock", false, [false]],
        ["_nativeForcedWalk", false, [false]]
    ];
    (count _input) >= 3 && {!_aceMovementLock} &&
        {(_input select 0) > 0.05} && {!(_input select 2)} &&
        {_nativeForcedWalk || {abs _slopeDegrees > 0.01}}
};

// playMoveNow replaces the pending movement request and follows the explicit
// InterpolateFrom/To graph. switchMove's blendFactor is a pose weight, not a
// timed transition; it must not be used as sprint-key interpolation.
// This boundary is called once per entry/exit, never as a held-key watchdog.
// https://community.bistudio.com/wiki/playMoveNow
GAIT_fnc_requestLocomotionMove = {
    params ["_unit", "_target"];
    _unit playMoveNow _target;
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
GAIT_fnc_observeLocomotionInput = {
    params ["_unit", "_input"];
    private _forwardHeld = (_input select 0) > 0.05;
    private _movingHeld = abs (_input select 0) > 0.05 || {abs (_input select 1) > 0.05};
    // Preserve the old startup release semantics while separately detecting
    // the first real forward press for the ordinary walk-start brace.
    private _previousForwardForPress = _unit getVariable ["GAIT_forwardInputHeld", false];
    private _previousForwardForRelease = _unit getVariable ["GAIT_forwardInputHeld", true];
    _unit setVariable ["GAIT_movementReleasedThisFrame", !_movingHeld && {_unit getVariable ["GAIT_movementInputHeld", false]}];
    _unit setVariable ["GAIT_movementInputHeld", _movingHeld];
    if (_movingHeld) then {_unit setVariable ["GAIT_nativeStopPaceLease", []];};
    private _turbo = _input select 2;
    private _previousTurbo = _unit getVariable ["GAIT_turboInputHeld", false];
    if (_forwardHeld && {!_previousForwardForPress}) then {
        private _velocity = velocity _unit;
        private _speedMS = sqrt (((_velocity select 0) ^ 2) + ((_velocity select 1) ^ 2));
        private _serial = (_unit getVariable ["GAIT_forwardPressSerial", 0]) + 1;
        _unit setVariable ["GAIT_forwardPressSerial", _serial];
        _unit setVariable ["GAIT_forwardPressSnapshot", [_serial, diag_tickTime, _speedMS, _turbo]];
    };
    _unit setVariable ["GAIT_turboPressedThisFrame", _turbo && {!_previousTurbo}];
    _unit setVariable ["GAIT_turboInputHeld", _turbo];
    if (_turbo && {!_previousTurbo || {_forwardHeld && {!_previousForwardForRelease}}}) then {
        _unit setVariable ["GAIT_sprintReleaseHandled", false];
    };
    if (_previousTurbo && {!_turbo} && {_forwardHeld} &&
        {!(_unit getVariable ["GAIT_sprintReleaseHandled", false])} &&
        {_unit isEqualTo (missionNamespace getVariable ["GAIT_nativeOwner", objNull])}) then {
        private _applied = getAnimSpeedCoef _unit;
        if (abs (_applied - (missionNamespace getVariable ["GAIT_nativeLastWritten", -1])) < 0.001) then {
            private _velocity = velocity _unit;
            private _speedMS = sqrt (((_velocity select 0) ^ 2) + ((_velocity select 1) ^ 2));
            _unit setVariable ["GAIT_sprintReleaseSnapshot", [time, _applied, _speedMS,
                missionNamespace getVariable ["GAIT_vegDragFactor", 0]]];
        };
    };
    if (!_forwardHeld || {_turbo && {!_previousTurbo}}) then {
        _unit setVariable ["GAIT_sprintReleaseSnapshot", []];
    };
    if (!_forwardHeld && {_previousForwardForRelease}) then {
        _unit setVariable ["GAIT_forwardReleaseSerial", (_unit getVariable ["GAIT_forwardReleaseSerial", 0]) + 1];
    };
    _unit setVariable ["GAIT_forwardInputHeld", _forwardHeld];

    private _end = missionNamespace getVariable ["GAIT_braceEndTime", -1];
    private _active = (missionNamespace getVariable ["GAIT_braceActive", false]) && {time < _end};
    private _braking = _unit isEqualTo (missionNamespace getVariable ["GAIT_uphillBrakeUnit", objNull]) &&
        {missionNamespace getVariable ["GAIT_uphillBrakeActive", false]} &&
        {_end isEqualTo (missionNamespace getVariable ["GAIT_uphillBrakeEndTime", -1])};
    private _live = _active && {_forwardHeld} && {[_turbo, !_turbo] select _braking};
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
    private _required = [[_family, "Dnon", false] call GAIT_fnc_slopeStateName];
    {
        _required pushBack ([_family, _x, false] call GAIT_fnc_slopeStateName);
        if (_x in ["Df", "Dfl", "Dfr"]) then {
            _required pushBack ([_family, _x, true] call GAIT_fnc_slopeStateName);
        };
    } forEach ["Df", "Dfl", "Dl", "Dbl", "Db", "Dbr", "Dr", "Dfr"];
    {
        private _state = _states >> _x;
        private _native = getText (_state >> "GAIT_nativeState");
        private _actions = getText (_state >> "actions");
        if (!isClass _state || {(getNumber (_state >> "GAIT_slopeState")) isNotEqualTo 1} ||
            {!isClass (_states >> _native)} || {(getText (_states >> _native >> "file")) isEqualTo ""} ||
            {!isClass (configFile >> "CfgMovesBasic" >> "Actions" >> _actions)}) exitWith {_available = false;};
    } forEach _required;
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

GAIT_fnc_stanceYieldActive = {
    params [["_unit", objNull, [objNull]]];
    !isNull _unit && {
        (_unit getVariable ["GAIT_stanceInputHeld", false]) ||
        {diag_tickTime <= (_unit getVariable ["GAIT_stanceYieldUntil", -1])}
    }
};

GAIT_fnc_beginStanceYield = {
    params [["_unit", objNull, [objNull]]];
    if (isNull _unit) exitWith {false};
    _unit setVariable ["GAIT_stanceYieldUntil", diag_tickTime + 0.45];
    _unit setVariable ["GAIT_slopeCanceledBraceEndTime",
        missionNamespace getVariable ["GAIT_braceEndTime", -1]];
    missionNamespace setVariable ["GAIT_locomotionRequest", []];
    missionNamespace setVariable ["GAIT_braceActive", false];
    missionNamespace setVariable ["GAIT_braceEndTime", -1];
    if (!isNil "GAIT_fnc_clearReleaseMomentum") then {[_unit] call GAIT_fnc_clearReleaseMomentum;};
    _unit setVariable ["GAIT_paceHandoff", []];
    _unit setVariable ["GAIT_paceHandoffCandidate", []];
    _unit setVariable ["GAIT_releasePendingCoefficient", -1];
    _unit setVariable ["GAIT_releaseResume", []];
    [] call GAIT_fnc_releaseSpeedCoefficient;
    [_unit] call GAIT_fnc_clearSlopeLocomotionState;
    true
};

GAIT_fnc_clearSlopeLocomotionState = {
    params [["_unit", objNull, [objNull]]];
    if (!isNull _unit) then {
        {
            _unit setVariable [_x, false];
        } forEach ["GAIT_slopeAttemptLatched", "GAIT_slopeExitPending", "GAIT_slopeFailureReported", "GAIT_slopeLocomotionActive", "GAIT_slopeExitIssued", "GAIT_slopeExitFailureReported", "GAIT_slopeCancelEntry", "GAIT_nativeStopPending"];
        {
            _unit setVariable [_x, ""];
        } forEach ["GAIT_slopeAttemptFamily", "GAIT_slopeAttemptWeapon", "GAIT_slopeEntrySource", "GAIT_slopeEntryTarget", "GAIT_slopeExitSource", "GAIT_slopeExitTarget"];
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
    if (!isNil "GAIT_fnc_clearReleaseMomentum") then {[_unit] call GAIT_fnc_clearReleaseMomentum;};
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
        private _entryBlend = [_animation, _source, _unit getVariable ["GAIT_slopeEntryTarget", ""]] call GAIT_fnc_isLocomotionHandoffBlend;
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
    private _entryBlend = [_animation, _source, _unit getVariable ["GAIT_slopeEntryTarget", ""]] call GAIT_fnc_isLocomotionHandoffBlend;
    private _exitBlend = [_animation, _unit getVariable ["GAIT_slopeExitSource", ""],
        _unit getVariable ["GAIT_slopeExitTarget", ""]] call GAIT_fnc_isLocomotionHandoffBlend;
    private _cancelEntry = (_unit getVariable ["GAIT_slopeCancelEntry", false]) && {!(_unit getVariable ["GAIT_slopeExitIssued", false])};
    private _ownsObservation = [_inside, _entryBlend, _cancelEntry, (toLower _animation) isEqualTo (toLower _source), diag_tickTime <= (_unit getVariable ["GAIT_slopeCancelDeadline", -1])] call GAIT_fnc_locomotionExitOwnsObservation;
    _ownsObservation = _ownsObservation || {(_unit getVariable ["GAIT_nativeStopPending", false]) &&
        {(toLower _animation) isEqualTo (toLower (_unit getVariable ["GAIT_slopeExitSource", ""]))} &&
        {diag_tickTime <= (_unit getVariable ["GAIT_slopeExitDeadline", -1])}};
    if ((!_ownsObservation && {!_exitBlend}) || {!alive _unit} || {!local _unit} || {_unit isNotEqualTo player}) exitWith {
        // A native or full-body action already owns the character. Discard the
        // pending request without sending an animation after that handoff.
        [_unit] call GAIT_fnc_clearSlopeLocomotionState;
        false
    };
    private _input = [] call GAIT_fnc_getMovementInput;
    private _direction = [_input select 0, _input select 1] call GAIT_fnc_slopeDirection;
    private _exitIssued = _unit getVariable ["GAIT_slopeExitIssued", false];
    private _redirect = _exitIssued && {[_unit getVariable ["GAIT_slopeExitTarget", ""], _direction]
        call GAIT_fnc_locomotionStopRedirect};
    if (_exitIssued && {!_redirect}) exitWith {
        if (diag_tickTime > (_unit getVariable ["GAIT_slopeExitDeadline", -1]) && {!(_unit getVariable ["GAIT_slopeExitFailureReported", false])}) then {
            _unit setVariable ["GAIT_slopeExitFailureReported", true];
            diag_log format ["[GAIT_LOCOMOTION] native exit not observed from %1; cleanup ownership retained, no repeated animation request.", _animation];
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
    private _family = [_unit] call GAIT_fnc_slopeWeaponFamily;
    if (_family isEqualTo "") exitWith {false};
    private _walk = (_unit getVariable ["GAIT_slopeExitWalkOnly", false]) || {isForcedWalk _unit} || {(_unit getVariable ["ace_common_effect_forceWalk", 0]) > 0};
    private _pace = ["Mrun", "Mwlk"] select _walk;
    if (!_walk && {isSprintAllowed _unit} && {(_unit getVariable ["ace_common_effect_blockSprint", 0]) <= 0} &&
        {_input select 2} && {_direction in ["Df", "Dfl", "Dfr"]}) then {_pace = "Meva";};
    if (_direction isEqualTo "Dnon") then {_pace = "Mstp";};
    private _target = "AmovPerc" + _pace + _family + _direction;
    if (_direction isEqualTo "Dnon") then {_target = _target + "_GAITStop";};
    private _states = configFile >> "CfgMovesMaleSdr" >> "States";
    if (!isClass (_states >> _target)) then {_target = "AmovPercMstp" + _family + "Dnon";};
    if (!isClass (_states >> _target)) exitWith {false};
    _unit setVariable ["GAIT_slopeExitIssued", true];
    _unit setVariable ["GAIT_slopeExitSource", _animation];
    _unit setVariable ["GAIT_slopeExitTarget", _target];
    _unit setVariable ["GAIT_slopeExitDeadline", diag_tickTime + 1.5];
    if (!isNil "GAIT_fnc_beginPaceHandoff") then {[_unit, _animation, _target] call GAIT_fnc_beginPaceHandoff;};
    diag_log format ["[GAIT_LOCOMOTION] exit Draw3D %1 -> %2", _animation, _target];
    [_unit, _target] call GAIT_fnc_requestLocomotionMove;
    true
};

// A changed live direction may replace a still-blending exit, including a
// stop after releasing W midway through a jog handoff. Each new target
// consumes that edge; held input never repeatedly authorizes itself.
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

// The same shortened idle blend also covers a stop after the sprint handoff
// has already finished. This is one input-edge request for an eligible native
// move whose coefficient GAIT currently owns, never an idle watchdog.
GAIT_fnc_beginNativeLocomotionStop = {
    params ["_unit"];
    if (isNull _unit || {!(_unit getVariable ["GAIT_movementReleasedThisFrame", false])} ||
        {(_unit getVariable ["GAIT_locomotionPhase", "native"]) isNotEqualTo "native"}) exitWith {false};
    if (!(missionNamespace getVariable ["GAIT_ss_slopeLocomotionEnabled", true]) ||
        {!(missionNamespace getVariable ["GAIT_ss_slopeHandlingEnabled", true])} ||
        {!(call GAIT_fnc_modeAllowsMovement)}) exitWith {false};
    private _owns = _unit isEqualTo (missionNamespace getVariable ["GAIT_nativeOwner", objNull]) &&
        {abs ((getAnimSpeedCoef _unit) - (missionNamespace getVariable ["GAIT_nativeLastWritten", -1])) < 0.001};
    private _lease = _unit getVariable ["GAIT_nativeStopPaceLease", []];
    _unit setVariable ["GAIT_nativeStopPaceLease", []];
    _owns = _owns || {[_lease, diag_tickTime, currentWeapon _unit, getAnimSpeedCoef _unit]
        call GAIT_fnc_nativeStopLeaseValid};
    private _animation = animationState _unit;
    private _name = toLower _animation;
    private _ordinary = (_name select [0, 8]) isEqualTo "amovperc" &&
        {(_name select [8, 4]) in ["mrun", "mwlk", "mtac", "meva", "mspr"]} &&
        {([_animation] call GAIT_fnc_slopeAnimationFamily) isEqualTo ""};
    if !([true, _owns, true, _ordinary,
        (stance _unit) isEqualTo "STAND" && {[_unit, false] call GAIT_fnc_nativeMovementEligible}]
        call GAIT_fnc_nativeStopDecision) exitWith {false};
    private _family = [_unit] call GAIT_fnc_slopeWeaponFamily;
    if (_family isEqualTo "" || {(_name select [12, 8]) isNotEqualTo (toLower _family)}) exitWith {false};
    private _target = "AmovPercMstp" + _family + "Dnon_GAITStop";
    if (!isClass (configFile >> "CfgMovesMaleSdr" >> "States" >> _target)) exitWith {false};
    _unit setVariable ["GAIT_slopeAttemptLatched", true];
    _unit setVariable ["GAIT_slopeAttemptFamily", _family];
    _unit setVariable ["GAIT_slopeAttemptWeapon", currentWeapon _unit];
    _unit setVariable ["GAIT_locomotionPhase", "exiting"];
    _unit setVariable ["GAIT_slopeExitPending", true];
    _unit setVariable ["GAIT_slopeExitIssued", true];
    _unit setVariable ["GAIT_slopeExitFailureReported", false];
    _unit setVariable ["GAIT_slopeExitWalkOnly", isForcedWalk _unit];
    _unit setVariable ["GAIT_slopeExitSource", _animation];
    _unit setVariable ["GAIT_slopeExitTarget", _target];
    _unit setVariable ["GAIT_slopeExitDeadline", diag_tickTime + 1.5];
    _unit setVariable ["GAIT_nativeStopPending", true];
    missionNamespace setVariable ["GAIT_slopeOwner", _unit];
    missionNamespace setVariable ["GAIT_locomotionPhase", "exiting"];
    missionNamespace setVariable ["GAIT_slopeLocomotionActive", false];
    [] call GAIT_fnc_releaseSpeedCoefficient;
    [_unit, _target] call GAIT_fnc_requestLocomotionMove;
    true
};

GAIT_fnc_updateSlopeLocomotion = {
    params [["_unit", player, [objNull]], ["_fastMoveIntent", false, [false]], ["_movementInput", [], [[]]], ["_externalLock", false, [false]]];
    // No animation command here. The feature loop may be scheduled and has
    // already calculated the original step-off/brace/momentum coefficients.
    missionNamespace setVariable ["GAIT_locomotionRequest", [_unit, _fastMoveIntent, _externalLock, diag_tickTime]];
    missionNamespace getVariable ["GAIT_slopeLocomotionActive", false]
};

// Turbo starts/resumes immediately. A live finite W-held release may retain
// its current clip until the single ordinary graph handoff is due.
GAIT_fnc_locomotionIntent = {
    params ["_featureRequest", "_turbo", "_moving", ["_ordinarySlopeJog", false, [false]]];
    _featureRequest && {_moving} && {_turbo || {_ordinarySlopeJog}}
};

GAIT_fnc_locomotionResumeDecision = {
    params ["_phase", "_pressEdge", "_exitIssued", "_requested", "_eligible", "_knownObservation"];
    _phase isEqualTo "exiting" && {_pressEdge} && {_exitIssued} &&
        {_requested} && {_eligible} && {_knownObservation}
};

GAIT_fnc_beginLocomotionEntry = {
    params ["_unit", "_family", "_input", "_animation"];
    private _direction = [_input select 0, _input select 1] call GAIT_fnc_slopeDirection;
    private _target = [_family, _direction, _input select 2] call GAIT_fnc_slopeStateName;
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
    _unit setVariable ["GAIT_nativeStopPending", false];
    diag_log format ["[GAIT_LOCOMOTION] entry graph request %1 -> %2", _animation, _target];
    [_unit, _target] call GAIT_fnc_requestLocomotionMove;
};

// Pending entry never owns lateral intent. A/D can replace the pending target
// before the old entry blend completes, including on steep grades.
GAIT_fnc_redirectLocomotionEntryDirection = {
    params [["_unit", objNull, [objNull]], ["_input", [], [[]]]];
    if (isNull _unit || {(_unit getVariable ["GAIT_locomotionPhase", "native"]) isNotEqualTo "entering"} ||
        {(count _input) < 3} || {!(_input select 2)}) exitWith {false};
    private _moving = abs (_input select 0) > 0.05 || {abs (_input select 1) > 0.05};
    if (!_moving || {!isTouchingGround _unit} || {(stance _unit) isNotEqualTo "STAND"} ||
        {!([_unit, false] call GAIT_fnc_nativeMovementEligible)}) exitWith {false};
    private _direction = [_input select 0, _input select 1] call GAIT_fnc_slopeDirection;
    private _oldTarget = _unit getVariable ["GAIT_slopeEntryTarget", ""];
    if (([_oldTarget, _direction] call GAIT_fnc_locomotionDirectionRedirectNeeded) isEqualTo false) exitWith {false};
    private _family = [_unit] call GAIT_fnc_slopeWeaponFamily;
    if (_family isEqualTo "" ||
        {currentWeapon _unit isNotEqualTo (_unit getVariable ["GAIT_slopeAttemptWeapon", currentWeapon _unit])}) exitWith {false};
    private _animation = animationState _unit;
    private _source = _unit getVariable ["GAIT_slopeEntrySource", ""];
    private _beforeDeadline = diag_tickTime <= (_unit getVariable ["GAIT_slopeEntryDeadline", -1]);
    private _insideFamily = ([_animation] call GAIT_fnc_slopeAnimationFamily) isNotEqualTo "";
    private _handoffBlend = [_animation, _source, _oldTarget] call GAIT_fnc_isLocomotionHandoffBlend;
    private _handoffSource = [_animation, _source, _beforeDeadline] call GAIT_fnc_isLocomotionHandoffSource;
    private _known = [_animation, _source, _beforeDeadline, _insideFamily, _handoffBlend, _handoffSource]
        call GAIT_fnc_locomotionEntryRedirectKnown;
    if (!_known) exitWith {false};
    private _target = [_family, _direction, _input select 2] call GAIT_fnc_slopeStateName;
    if (!isClass (configFile >> "CfgMovesMaleSdr" >> "States" >> _target)) exitWith {false};
    _unit setVariable ["GAIT_slopeEntrySource", _animation];
    _unit setVariable ["GAIT_slopeEntryTarget", _target];
    _unit setVariable ["GAIT_slopeEntryDeadline", diag_tickTime + 1.5];
    diag_log format ["[GAIT_LOCOMOTION] entry direction redirect %1 -> %2", _animation, _target];
    [_unit, _target] call GAIT_fnc_requestLocomotionMove;
    true
};

// A new Turbo press can replace an issued ordinary release before it finishes.
// One edge produces one graph request. Held Turbo, an unissued/deferred exit,
// unrelated animation, lost input, stale envelope or unsafe context cannot.
GAIT_fnc_resumeLocomotionExit = {
    params ["_unit", "_input"];
    if (isNull _unit || {(_unit getVariable ["GAIT_locomotionPhase", "native"]) isNotEqualTo "exiting"} ||
        {!(_unit getVariable ["GAIT_turboPressedThisFrame", false])}) exitWith {false};
    private _request = missionNamespace getVariable ["GAIT_locomotionRequest", []];
    private _lease = (4 * (missionNamespace getVariable ["GAIT_ss_tickRate", 0.05])) max 1;
    if ((count _request) isNotEqualTo 4 || {(_request select 0) isNotEqualTo _unit} ||
        {diag_tickTime - (_request select 3) > _lease}) exitWith {false};
    private _moving = abs (_input select 0) > 0.05 || {abs (_input select 1) > 0.05};
    private _requested = [(_request select 1) && {!(_request select 2)}, _input select 2, _moving] call GAIT_fnc_locomotionIntent;
    private _enabled = (missionNamespace getVariable ["GAIT_ss_slopeLocomotionEnabled", true]) &&
        {missionNamespace getVariable ["GAIT_ss_slopeHandlingEnabled", true]} && {call GAIT_fnc_modeAllowsMovement};
    private _locked = !isSprintAllowed _unit || {isForcedWalk _unit} ||
        {(_unit getVariable ["ace_common_effect_blockSprint", 0]) > 0} || {(_unit getVariable ["ace_common_effect_forceWalk", 0]) > 0};
    private _eligible = _enabled && {!_locked} && {(stance _unit) isEqualTo "STAND"} &&
        {(_unit getVariable ["GAIT_slopeAttemptWeapon", ""]) isEqualTo (currentWeapon _unit)} &&
        {[_unit, false] call GAIT_fnc_nativeMovementEligible};
    private _animation = animationState _unit;
    private _known = ([_animation] call GAIT_fnc_slopeAnimationFamily) isNotEqualTo "" ||
        {[_animation, _unit getVariable ["GAIT_slopeExitSource", ""],
            _unit getVariable ["GAIT_slopeExitTarget", ""]] call GAIT_fnc_isLocomotionHandoffBlend};
    if !(["exiting", true, _unit getVariable ["GAIT_slopeExitIssued", false], _requested, _eligible, _known] call GAIT_fnc_locomotionResumeDecision) exitWith {false};
    private _family = [_unit] call GAIT_fnc_slopeWeaponFamily;
    if (_family isEqualTo "" || {!([_family] call GAIT_fnc_slopeFamilyAvailable)}) exitWith {false};
    [_unit, _family, _input, _animation] call GAIT_fnc_beginLocomotionEntry;
    true
};

GAIT_fnc_tickLocomotion = {
    // Observe edges while cleanup is deferred too. Recording intent never
    // authorizes an entry or body command to overtake that cleanup.
    private _input = [] call GAIT_fnc_getMovementInput;
    private _stanceYieldNow = false;
    if (!isNull player) then {
        [player, _input] call GAIT_fnc_observeLocomotionInput;
        private _stanceHeld = call GAIT_fnc_getStanceInput;
        private _stanceEdge = [player, _stanceHeld] call GAIT_fnc_observeStanceInput;
        if (_stanceEdge && {(stance player) isEqualTo "STAND"}) then {
            [player] call GAIT_fnc_beginStanceYield;
        };
        _stanceYieldNow = [player] call GAIT_fnc_stanceYieldActive;
        if (!_stanceYieldNow) then {
            if (!isNil "GAIT_fnc_observePaceCalibration") then {[player, _input] call GAIT_fnc_observePaceCalibration;};
            [player, _input] call GAIT_fnc_observeReleaseMomentum;
            if ((player getVariable ["GAIT_releaseMomentumState", []]) isNotEqualTo [] ||
                {(player getVariable ["GAIT_releasePendingCoefficient", -1]) >= 0} ||
                {(player getVariable ["GAIT_paceHandoff", []]) isNotEqualTo []}) then {
                [player, missionNamespace getVariable ["GAIT_nativeLastPreVegetation", 1], false]
                    call GAIT_fnc_applyNativeMovement;
            };
        };
    };
    // This must exit the whole render controller. Continuing into native-stop
    // or exit service here is the abrupt stop-before-crouch regression.
    if (_stanceYieldNow) exitWith {};
    // Direction changes outrank completion of a pending sprint-entry blend.
    if ([player, _input] call GAIT_fnc_redirectLocomotionEntryDirection) exitWith {};
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
    private _moving = abs (_input select 0) > 0.05 || {abs (_input select 1) > 0.05};
    private _enabled = (missionNamespace getVariable ["GAIT_ss_slopeLocomotionEnabled", true]) &&
        {missionNamespace getVariable ["GAIT_ss_slopeHandlingEnabled", true]} && {call GAIT_fnc_modeAllowsMovement};
    private _aceSlopeLock = (_unit getVariable ["ace_common_effect_blockSprint", 0]) > 0 ||
        {(_unit getVariable ["ace_common_effect_forceWalk", 0]) > 0};
    private _ordinarySlopeJog = [_input,
        missionNamespace getVariable ["GAIT_lastKnownSlopeDegrees", 0],
        _aceSlopeLock, isForcedWalk _unit] call GAIT_fnc_ordinarySlopeJogIntent;
    private _nativeSlopeLock = (!isSprintAllowed _unit || {isForcedWalk _unit}) && {!_ordinarySlopeJog};
    private _requestLock = (_request select 2) && {!_ordinarySlopeJog};
    private _locked = _requestLock || {_nativeSlopeLock} ||
        {(_unit getVariable ["ace_common_effect_blockSprint", 0]) > 0} || {(_unit getVariable ["ace_common_effect_forceWalk", 0]) > 0};
    private _requested = _enabled && {!_locked} && {[
        _request select 1, _input select 2, _moving, _ordinarySlopeJog
    ] call GAIT_fnc_locomotionIntent};
    // No repeated animation command: this only keeps existing graph ownership
    // until the finite speed plan or existing uphill brake completes.
    private _releaseHeld = (_unit getVariable ["GAIT_releaseMomentumState", []]) isNotEqualTo [] ||
        {(_unit getVariable ["GAIT_releaseBrakeHold", []]) isNotEqualTo []};
    _requested = _requested || {_enabled && {!_locked} && {_releaseHeld}};
    private _eligible = (stance _unit) isEqualTo "STAND" && {[_unit, false] call GAIT_fnc_nativeMovementEligible};
    private _animation = animationState _unit;
    private _activeFamily = [_animation] call GAIT_fnc_slopeAnimationFamily;
    private _family = [_unit] call GAIT_fnc_slopeWeaponFamily;
    private _phase = _unit getVariable ["GAIT_locomotionPhase", "native"];
    private _oldWeapon = _unit getVariable ["GAIT_slopeAttemptWeapon", ""];
    if (_phase isNotEqualTo "native" && {_oldWeapon isNotEqualTo (currentWeapon _unit)}) exitWith {
        [_unit, _input, isForcedWalk _unit] call GAIT_fnc_releaseSlopeLocomotion;
    };
    private _expectedBlend = [_animation, _unit getVariable ["GAIT_slopeEntrySource", ""], _unit getVariable ["GAIT_slopeEntryTarget", ""]] call GAIT_fnc_isLocomotionHandoffBlend;
    _expectedBlend = _expectedBlend || {[_animation, _unit getVariable ["GAIT_slopeEntrySource", ""],
        diag_tickTime <= (_unit getVariable ["GAIT_slopeEntryDeadline", -1])] call GAIT_fnc_isLocomotionHandoffSource};
    private _action = [_phase, _requested, _eligible, _activeFamily isNotEqualTo "", _expectedBlend,
        diag_tickTime > (_unit getVariable ["GAIT_slopeEntryDeadline", -1]), _moving] call GAIT_fnc_locomotionDecision;
    switch (_action) do {
        case "release": {
            [_unit, _input, isForcedWalk _unit] call GAIT_fnc_releaseSlopeLocomotion;
            // Ordinary key release cancels body intent, not the still-valid
            // movement-context envelope needed for a render-frame re-press.
            if (_enabled && {!_locked} && {_eligible}) then {
                missionNamespace setVariable ["GAIT_locomotionRequest", _request];
            };
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
            [_unit, _family, _input, _animation] call GAIT_fnc_beginLocomotionEntry;
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
