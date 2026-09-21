/*
    Motion history for brace eligibility. Coefficients are not metres/second:
    an uphill sprint can have a lower coefficient than a flat walk. A prior
    moving sprint therefore protects every brace cause until the player has
    actually stopped, or has settled at walking pace after the grace period.
    State: [establishedSprint, lastMovingSprintTime, settledTime, stoppedTime].
    This helper has no animation, velocity, fatigue or namespace side effects.
*/
GAIT_fnc_stepBraceMomentum = {
    params [
        ["_state", [false, -999, 0, 0], [[]]],
        ["_continuingSprint", false, [false]],
        ["_contextOk", false, [false]],
        ["_actualSpeedMS", 0, [0]],
        ["_currentCoefficient", 1, [0]],
        ["_walkCoefficient", 1, [0]],
        ["_now", 0, [0]],
        ["_dt", 0.05, [0]],
        ["_graceSeconds", 3, [0]],
        ["_settleSeconds", 2, [0]],
        ["_coefficientMargin", 0.04, [0]]
    ];
    if (!_contextOk) exitWith {[[false, -999, 0, 0], false]};
    private _established = _state param [0, false, [false]];
    private _lastMovingSprint = _state param [1, -999, [0]];
    private _settled = _state param [2, 0, [0]];
    private _stopped = _state param [3, 0, [0]];
    private _step = _dt max 0 min 0.20;
    private _moving = _actualSpeedMS > 0.25;

    _stopped = [0, _stopped + _step] select (!_moving);
    if (_stopped >= 0.15) exitWith {[[false, -999, 0, _stopped min 0.15], false]};
    // Never acquire momentum from the first press or during its brace. The
    // caller requires a continuing sprint and an expired/inactive brace.
    if (_continuingSprint && {_moving}) then {
        _established = true;
        _lastMovingSprint = _now;
        _settled = 0;
    } else {
        // W-only movement can be a native jog above 2 m/s, especially with
        // light gear. Rearm against the intended non-sprint coefficient after
        // the original grace/settle windows, not an absolute walking speed.
        // The finite release taper finishes well before that grace expires.
        // Continuing sprint always takes the branch above, so a low uphill
        // sprint coefficient cannot rearm its brace while sprint stays held.
        private _atWalkPace =
            _currentCoefficient <= ((_walkCoefficient max 0.01) + (_coefficientMargin max 0));
        if (_established && {_atWalkPace} && {(_now - _lastMovingSprint) >= (_graceSeconds max 0)}) then {
            _settled = _settled + _step;
            if (_settled >= (_settleSeconds max 0.05)) then {
                _established = false;
                _lastMovingSprint = -999;
                _settled = 0;
            };
        } else {_settled = 0;};
    };
    [[_established, _lastMovingSprint, _settled, _stopped], _established]
};

// One veto applies to standing, crouch and remembered slope-stop triggers.
GAIT_fnc_shouldBrace = {
    params ["_enabled", "_momentumProtected", "_crouched", "_crouchArmed", "_normalReady", "_zeroReady", "_slopeReady"];
    _enabled && {!_momentumProtected} && {_crouched || {_crouchArmed} || {_normalReady} || {_zeroReady} || {_slopeReady}}
};

// Small ordinary-movement step from a true stop. This is deliberately much
// shallower than the sprint brace. Weight classes use the configured tier
// thresholds, while the curve itself is fixed so the settings surface stays
// compact. Return: [duration, lowPaceFactor, holdFraction, tier].
GAIT_fnc_walkStartBraceProfile = {
    params [
        ["_gearLbs", 0, [0]],
        ["_thresholds", [35, 55, 75], [[]]]
    ];
    if ((count _thresholds) < 3) then {_thresholds = [35, 55, 75];};
    private _lightMax = (_thresholds param [0, 35, [0]]) max 1;
    private _mediumMax = (_thresholds param [1, 55, [0]]) max (_lightMax + 1);
    private _moderateMax = (_thresholds param [2, 75, [0]]) max (_mediumMax + 1);
    private _tier = 3;
    if (_gearLbs <= _lightMax) then {_tier = 0;} else {
        if (_gearLbs <= _mediumMax) then {_tier = 1;} else {
            if (_gearLbs <= _moderateMax) then {_tier = 2;};
        };
    };
    private _profile = +([
        [0.28, 0.86, 0.20],
        [0.32, 0.82, 0.20],
        [0.36, 0.78, 0.22],
        [0.40, 0.74, 0.24]
    ] select _tier);
    _profile pushBack _tier;
    _profile
};

// Plan is an immutable snapshot so changing inventory mid-step cannot restart
// or deepen the step. [startTime, duration, lowPaceFactor, holdFraction, tier].
GAIT_fnc_walkStartBracePlan = {
    params [
        ["_startTime", 0, [0]],
        ["_gearLbs", 0, [0]],
        ["_thresholds", [35, 55, 75], [[]]]
    ];
    private _profile = [_gearLbs, _thresholds] call GAIT_fnc_walkStartBraceProfile;
    [_startTime, _profile select 0, _profile select 1, _profile select 2, _profile select 3]
};

// Returns [paceFactor, active, tier]. The first part of the first step stays
// slightly planted, then a smoothstep reaches exactly 1.0 at the finite end.
GAIT_fnc_walkStartBraceSample = {
    params [["_plan", [], [[]]], ["_now", 0, [0]]];
    if ((count _plan) isNotEqualTo 5 || {(_plan findIf {!(_x isEqualType 0)}) >= 0}) exitWith {[1, false, -1]};
    _plan params ["_startTime", "_duration", "_lowFactor", "_holdFraction", "_tier"];
    if (_now < _startTime || {_duration < 0.05 || {_duration > 1}} ||
        {_lowFactor < 0.5 || {_lowFactor >= 1}} ||
        {_holdFraction < 0 || {_holdFraction >= 0.5}} ||
        {_tier < 0 || {_tier > 3}}) exitWith {[1, false, -1]};
    private _t = ((_now - _startTime) / _duration) max 0 min 1;
    if (_t >= 1) exitWith {[1, false, _tier]};
    private _factor = _lowFactor;
    if (_t > _holdFraction) then {
        private _p = ((_t - _holdFraction) / ((1 - _holdFraction) max 0.01)) max 0 min 1;
        private _ease = _p * _p * (3 - (2 * _p));
        _factor = _lowFactor + ((1 - _lowFactor) * _ease);
    };
    [_factor, true, _tier]
};
