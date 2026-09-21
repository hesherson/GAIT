/*
    Finite release motion in the CURRENT clip only. The pure planner and
    sampler below perform no animation, input, coefficient or velocity writes.

    Capture horizontal velocity and the applied pre-vegetation coefficient
    together, before leaving the sprint clip. Their ratio is a local sample
    of that clip on the current terrain. It is not a native jog/walk reference
    and must not be reused after a clip, direction or weapon change.

    Measured metres per second to shed determine duration. Release always begins
    at the exact measured running velocity, then consumes 75-100% of the gear
    coast window while easing toward ordinary jog pace. The gear window remains
    the ceiling, preserving load ordering across every weight tier.
    No subsequent velocity feedback accelerates against a wall or obstacle.

    Plan: [startTime, duration, startMS, targetMS,
           startCoefficient, targetCoefficient, curve].
    Sample: [coefficient, plannedMS, remainingFraction, active].
    Caller retains the current clip only while the plan and live W input are
    valid, then makes one normal blended handoff. W release cancels immediately.
*/

GAIT_fnc_releaseMomentumPlan = {
    params [
        ["_now", 0, [0]], ["_startMS", 0, [0]],
        ["_startCoefficient", 0, [0]], ["_ordinaryCoefficient", 0, [0]],
        ["_baseWindow", 0.85, [0]], ["_curve", 1.45, [0]]
    ];
    if (!(_now >= 0 && {_now < 1e10}) ||
        {!(_startMS > 0.05 && {_startMS <= 2500})} ||
        {!(_startCoefficient > 0.000001 && {_startCoefficient <= 100})} ||
        {!(_ordinaryCoefficient >= 0 && {_ordinaryCoefficient <= 100})} ||
        {!(_baseWindow > 0 && {_baseWindow <= 4})} ||
        {!(_curve >= 0 && {_curve <= 100})}) exitWith {[]};
    private _targetCoefficient = _ordinaryCoefficient min _startCoefficient;
    private _targetMS = _startMS * (_targetCoefficient / _startCoefficient);
    private _excessMS = _startMS - _targetMS;
    // Releasing during a low-speed brace must not create a speed hold.
    if (_excessMS <= 0.025 ||
        {_startCoefficient - _targetCoefficient <= 0.00001}) exitWith {[]};
    private _ceiling = _baseWindow max 0.15 min 1.20;
    // Never snap directly toward jog pace. Even a small excess gets most of
    // the tier-specific release window; larger excess approaches the ceiling.
    private _response = 0.75 + (0.25 * (1 - exp (-_excessMS / 2)));
    private _duration = (_ceiling * _response) max 0.12 min _ceiling;
    [_now, _duration, _startMS, _targetMS, _startCoefficient,
        _targetCoefficient, _curve max 1 min 3]
};

GAIT_fnc_releaseMomentumSample = {
    params [["_plan", [], [[]]], ["_now", 0, [0]]];
    if ((count _plan) isNotEqualTo 7 ||
        {(_plan findIf {!(_x isEqualType 0)}) >= 0}) exitWith {[0, 0, 0, false]};
    _plan params ["_startTime", "_duration", "_startMS", "_targetMS",
        "_startCoefficient", "_targetCoefficient", "_curve"];
    if (!(_now >= _startTime && {_now < 1e10}) ||
        {!(_startTime >= 0 && {_startTime < 1e10})} ||
        {!(_duration >= 0.12 && {_duration <= 1.20})} ||
        {!(_startMS > 0.05 && {_startMS <= 2500})} ||
        {!(_targetMS >= 0 && {_targetMS < _startMS})} ||
        {!(_startCoefficient > 0.000001 && {_startCoefficient <= 100})} ||
        {!(_targetCoefficient >= 0 && {_targetCoefficient < _startCoefficient})} ||
        {!(_curve >= 1 && {_curve <= 3})}) exitWith {[0, 0, 0, false]};
    private _t = ((_now - _startTime) / _duration) max 0 min 1;
    private _ease = _t * _t * (3 - (2 * _t));
    private _keep = (1 - _ease) ^ _curve;
    private _plannedMS = _targetMS + ((_startMS - _targetMS) * _keep);
    private _coefficient = _startCoefficient * (_plannedMS / _startMS);
    // Clamp roundoff only. No live target can grow or restart this snapshot.
    [_coefficient max _targetCoefficient min _startCoefficient,
        _plannedMS, _keep, _t < 1]
};


GAIT_fnc_releaseMomentumRequestValid = {
    params ["_request", "_unit", "_now"];
    (count _request) isEqualTo 6 && {(_request select 0) isEqualTo _unit} &&
        {_now <= (_request select 5)} && {_request select 4}
};

// Direction is never owned by the release-speed plan. A live A/D change must
// be able to escape the old forward/diagonal clip immediately while carrying
// only the exact current speed sample into ordinary locomotion.
GAIT_fnc_releaseDirectionChanged = {
    params [
        ["_state", [], [[]]],
        ["_weapon", "", [""]],
        ["_family", "", [""]],
        ["_direction", "", [""]]
    ];
    if ((count _state) isNotEqualTo 2) exitWith {false};
    private _identity = _state select 1;
    (count _identity) isEqualTo 4 &&
        {(_identity select 0) isEqualTo _weapon} &&
        {(_identity select 1) isEqualTo _family} &&
        {(_identity select 2) isNotEqualTo _direction}
};

// The main loop publishes only ordinary pace and a bounded permission lease.
// Both schedulers observe the SAME raw edge before either changes pace/body.
GAIT_fnc_releaseMomentumContext = {
    params ["_unit", "_input", "_now"];
    private _request = missionNamespace getVariable ["GAIT_releaseMomentumRequest", []];
    private _fresh = [_request, _unit, _now] call GAIT_fnc_releaseMomentumRequestValid;
    private _owns = _unit isEqualTo (missionNamespace getVariable ["GAIT_nativeOwner", objNull]) &&
        {abs ((getAnimSpeedCoef _unit) - (missionNamespace getVariable ["GAIT_nativeLastWritten", -1])) < 0.001};
    private _animation = animationState _unit;
    private _family = [_animation] call GAIT_fnc_slopeAnimationFamily;
    private _eligible = _fresh && {_request select 4} && {call GAIT_fnc_modeAllowsMovement} &&
        {missionNamespace getVariable ["GAIT_ss_slopeLocomotionEnabled", true]} &&
        {missionNamespace getVariable ["GAIT_ss_slopeHandlingEnabled", true]} &&
        {_unit isEqualTo player} && {local _unit} && {alive _unit} &&
        {(stance _unit) isEqualTo "STAND"} && {isTouchingGround _unit} &&
        {[_unit] call GAIT_fnc_fatigueMovementContextEligible} &&
        {[_unit, false] call GAIT_fnc_nativeMovementEligible} &&
        {isSprintAllowed _unit} && {!isForcedWalk _unit} &&
        {(_unit getVariable ["ace_common_effect_blockSprint", 0]) <= 0} &&
        {(_unit getVariable ["ace_common_effect_forceWalk", 0]) <= 0} &&
        {_unit isEqualTo (missionNamespace getVariable ["GAIT_slopeOwner", objNull])} &&
        {(_unit getVariable ["GAIT_locomotionPhase", "native"]) in ["entering", "active"]} &&
        {_family isNotEqualTo ""} && {_family isEqualTo ([_unit] call GAIT_fnc_slopeWeaponFamily)};
    private _velocity = velocity _unit;
    private _speed = sqrt (((_velocity select 0) ^ 2) + ((_velocity select 1) ^ 2));
    private _coefficient = missionNamespace getVariable ["GAIT_nativeLastPreVegetation", -1];
    if (_coefficient < 0) then {
        _coefficient = (getAnimSpeedCoef _unit) / ((1 - (missionNamespace getVariable ["GAIT_vegDragFactor", 0])) max 0.001);
    };
    private _brake = _unit isEqualTo (missionNamespace getVariable ["GAIT_uphillBrakeUnit", objNull]) && {
        ((missionNamespace getVariable ["GAIT_uphillBrakeActive", false]) &&
            {time < (missionNamespace getVariable ["GAIT_uphillBrakeEndTime", -1])}) ||
        {_now <= (missionNamespace getVariable ["GAIT_uphillBrakeReadyUntil", -1])}
    };
    [_eligible, _owns, currentWeapon _unit, _family, _animation, _coefficient, _speed, _brake,
        _request param [1, 1], _request param [2, 0.85], _request param [3, 1.45],
        [_animation] call GAIT_fnc_isSlopeLocomotionState]
};

GAIT_fnc_clearReleaseMomentum = {
    params [["_unit", missionNamespace getVariable ["GAIT_nativeOwner", objNull], [objNull]]];
    if (!isNull _unit) then {
        _unit setVariable ["GAIT_releaseMomentumState", []];
        _unit setVariable ["GAIT_releasePaceMatch", []];
        _unit setVariable ["GAIT_releaseBrakeHold", []];
        _unit setVariable ["GAIT_releasePendingCoefficient", -1];
        _unit setVariable ["GAIT_releaseResume", []];
        _unit setVariable ["GAIT_releaseInputPrevious", []];
        _unit setVariable ["GAIT_releaseMomentumActive", false];
    };
    private _request = missionNamespace getVariable ["GAIT_releaseMomentumRequest", []];
    if (isNull _unit || {(_request param [0, objNull]) isEqualTo _unit}) then {
        missionNamespace setVariable ["GAIT_releaseMomentumRequest", []];
        missionNamespace setVariable ["GAIT_releaseMomentumActive", false];
        missionNamespace setVariable ["GAIT_shiftReleaseRunTaperActive", false];
        missionNamespace setVariable ["GAIT_shiftReleaseRunTaperKeep", 0];
    };
};

GAIT_fnc_observeReleaseMomentum = {
    params ["_unit", "_input", ["_now", diag_tickTime, [0]]];
    if (isNull _unit) exitWith {false};
    private _previous = _unit getVariable ["GAIT_releaseInputPrevious", []];
    private _forward = (_input select 0) > 0.05;
    private _turbo = _input select 2;
    private _moving = _forward || {(_input select 0) < -0.05} || {abs (_input select 1) > 0.05};
    if (!_moving && {(_unit getVariable ["GAIT_paceHandoff", []]) isNotEqualTo []}) then {
        [_unit] call GAIT_fnc_clearPaceHandoff;
        [] call GAIT_fnc_releaseSpeedCoefficient;
    };
    private _direction = [_input select 0, _input select 1] call GAIT_fnc_slopeDirection;
    private _release = (count _previous) isEqualTo 2 && {_previous select 0} && {!_turbo} &&
        {_previous select 1} && {_forward};
    // Consume the edge before entering any helper; a main/render call at the
    // same timestamp can never capture two different launch speeds.
    _unit setVariable ["GAIT_releaseInputPrevious", [_turbo, _forward]];
    private _context = [_unit, _input, _now] call GAIT_fnc_releaseMomentumContext;
    _context params ["_eligible", "_owns", "_weapon", "_family", "_animation", "_applied", "_speed", "_brake", "_ordinary", "_window", "_curve", "_singleClip"];
    private _identity = [_weapon, _family, _direction, toLower _animation];
    private _state = _unit getVariable ["GAIT_releaseMomentumState", []];
    private _brakeHold = _unit getVariable ["GAIT_releaseBrakeHold", []];
    private _live = _eligible && {_owns} && {_forward};
    private _same = (count _state) isEqualTo 2 && {(_state select 1) isEqualTo _identity};
    private _directionChanged = [_state, _weapon, _family, _direction] call GAIT_fnc_releaseDirectionChanged;

    // A/D is control input, not a reason to finish the old directional
    // animation first. Keep the exact current speed sample, retire only the
    // old directional release identity, and let the graph redirect this frame.
    if (_state isNotEqualTo [] && {_live} && {_directionChanged} && {!_brake} && {!_turbo}) then {
        private _sample = [_state select 0, _now] call GAIT_fnc_releaseMomentumSample;
        private _carryCoefficient = _sample select 0;
        _unit setVariable ["GAIT_releaseMomentumState", []];
        _unit setVariable ["GAIT_releasePaceMatch", []];
        _unit setVariable ["GAIT_paceHandoffCandidate", []];
        _unit setVariable ["GAIT_releaseResume", []];
        _unit setVariable ["GAIT_releasePendingCoefficient", _carryCoefficient max 0];
        missionNamespace setVariable ["GAIT_releaseDirectionalEscape", true];
        missionNamespace setVariable ["GAIT_releaseDirectionalEscapeCoefficient", _carryCoefficient];
        _state = [];
    };

    if (_state isNotEqualTo []) then {
        if (!_live || {!_same} || {_brake} || {!(missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperEnabled", true])}) then {
            _unit setVariable ["GAIT_releaseMomentumState", []];
            _unit setVariable ["GAIT_releasePaceMatch", []];
            _unit setVariable ["GAIT_releasePendingCoefficient", -1];
            _unit setVariable ["GAIT_releaseResume", []];
            if (_live && {_brake} && {_same}) then {
                _unit setVariable ["GAIT_releaseBrakeHold", _identity];
            } else {
                // Non-directional identity loss is not allowed to carry a
                // sprint boost into an unrelated movement/action state.
                if (_eligible && {_owns} && {_moving}) then {
                    _unit setVariable ["GAIT_releasePendingCoefficient", _applied min _ordinary];
                };
            };
        } else {
            if (_turbo) then {
                private _sample = [_state select 0, _now] call GAIT_fnc_releaseMomentumSample;
                _unit setVariable ["GAIT_releasePendingCoefficient", _sample select 0];
                _unit setVariable ["GAIT_releaseResume", [_sample select 0, _now]];
                _unit setVariable ["GAIT_releaseMomentumState", []];
                _unit setVariable ["GAIT_releasePaceMatch", []];
            };
        };
    };
    if (_brakeHold isNotEqualTo [] && {!_live || {_turbo} || {!_brake} || {_brakeHold isNotEqualTo _identity}}) then {
        _unit setVariable ["GAIT_releaseBrakeHold", []];
    };
    if (_release) then {_unit setVariable ["GAIT_releaseSinceFeatureTick", true];};
    if (_release && {_live} && {_singleClip}) then {
        if (_brake) then {
            _unit setVariable ["GAIT_releaseBrakeHold", _identity];
        } else {
            if (missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperEnabled", true]) then {
                private _match = [];
                if (!isNil "GAIT_fnc_releasePaceMatch") then {
                    _match = [_unit, _animation, _family, _direction, _speed, _applied, _ordinary] call GAIT_fnc_releasePaceMatch;
                };
                private _releaseTarget = if (_match isEqualTo []) then {_ordinary} else {_match select 0};
                private _plan = [_now, _speed, _applied, _releaseTarget, _window, _curve] call GAIT_fnc_releaseMomentumPlan;
                if (_plan isNotEqualTo []) then {
                    _unit setVariable ["GAIT_releaseMomentumState", [_plan, _identity]];
                    _unit setVariable ["GAIT_releasePaceMatch", _match];
                    missionNamespace setVariable ["GAIT_releasePaceMatched", _match isNotEqualTo []];
                    _unit setVariable ["GAIT_releasePendingCoefficient", -1];
                    missionNamespace setVariable ["GAIT_releaseStartMS", _plan select 2];
                    missionNamespace setVariable ["GAIT_releaseTargetMS", _plan select 3];
                    missionNamespace setVariable ["GAIT_releaseDuration", _plan select 1];
                };
            };
        };
    };
    private _active = (_unit getVariable ["GAIT_releaseMomentumState", []]) isNotEqualTo [];
    _unit setVariable ["GAIT_releaseMomentumActive", _active];
    missionNamespace setVariable ["GAIT_releaseMomentumActive", _active];
    missionNamespace setVariable ["GAIT_shiftReleaseRunTaperActive", _active];
    if (!_active) then {missionNamespace setVariable ["GAIT_shiftReleaseRunTaperKeep", 0];};
    // Unsafe/stale ownership can never be revived by a later render write.
    if (!_eligible || {!_owns} || {!_moving}) then {
        _unit setVariable ["GAIT_releasePendingCoefficient", -1];
        if ((_unit getVariable ["GAIT_paceHandoff", []]) isEqualTo [] || {!_forward} || {!_owns}) then {
            _unit setVariable ["GAIT_releaseResume", []];
        };
    };
    if (_state isNotEqualTo [] && {_owns} && {!_eligible || {!_moving}}) then {
        [] call GAIT_fnc_releaseSpeedCoefficient;
    };
    _active || {(_unit getVariable ["GAIT_releaseBrakeHold", []]) isNotEqualTo []}
};

// Called ONLY by the existing coefficient writer. Endpoints are applied once
// before the graph is allowed to hand off; nativePreviousCoef is untouched.
GAIT_fnc_sampleReleaseCoefficient = {
    params ["_unit", "_coefficient", ["_now", diag_tickTime, [0]]];
    private _pending = _unit getVariable ["GAIT_releasePendingCoefficient", -1];
    if (_pending >= 0) then {
        _coefficient = _pending;
        _unit setVariable ["GAIT_releasePendingCoefficient", -1];
    };
    private _state = _unit getVariable ["GAIT_releaseMomentumState", []];
    if ((count _state) isEqualTo 2) then {
        private _sample = [_state select 0, _now] call GAIT_fnc_releaseMomentumSample;
        if ((_sample select 0) > 0) then {_coefficient = _sample select 0;};
        private _active = _sample select 3;
        _unit setVariable ["GAIT_releaseMomentumActive", _active];
        missionNamespace setVariable ["GAIT_releaseMomentumActive", _active];
        missionNamespace setVariable ["GAIT_shiftReleaseRunTaperActive", _active];
        missionNamespace setVariable ["GAIT_shiftReleaseRunTaperKeep", _sample select 2];
        missionNamespace setVariable ["GAIT_shiftReleaseRunTaperTargetKmh", (_sample select 1) * 3.6];
        if (!_active) then {
            private _match = _unit getVariable ["GAIT_releasePaceMatch", []];
            if (_match isNotEqualTo []) then {
                _unit setVariable ["GAIT_paceHandoffCandidate", [_match select 1, _now + 0.15]];
            };
            _unit setVariable ["GAIT_releaseMomentumState", []];
            _unit setVariable ["GAIT_releasePaceMatch", []];
        };
    };
    _coefficient
};
