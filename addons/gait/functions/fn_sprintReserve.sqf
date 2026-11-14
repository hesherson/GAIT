// Sprint drain follows allowed effort. Velocity only distinguishes rest from a coast.
GAIT_fnc_sprintReserveActivity = {
    params ["_input", "_speed", "_canSprint", "_isGrounded"];
    if (!_isGrounded) exitWith {"hold"};
    private _forward = _input select 0;
    if (_canSprint && {_input select 2} && {_forward > 0.05}) exitWith {"sprint"};
    if (_speed <= 0.15 && {abs _forward <= 0.05} && {abs (_input select 1) <= 0.05}) exitWith {"rest"};
    "hold"
};

GAIT_fnc_sprintReserveDrainRate = {
    params ["_gearLbs", "_gradeMultiplier", ["_loadFactor", 1], ["_terrainFactor", 1]];
    private _mass = _gearLbs max 0;
    private _moderateLoad = ((_mass - 60) / 60) max 0 min 1;
    private _extraHeavyLoad = (_mass - 120) max 0;
    private _loadCost = (0.0005 * _mass) + (0.13 * _moderateLoad ^ 2) +
        (0.26 * _extraHeavyLoad / 60) + (0.00825 * _extraHeavyLoad ^ 2 / (_extraHeavyLoad + 15));
    private _gradeInfluence = (_terrainFactor max 0) min ([1, 5] select (_gradeMultiplier >= 1));
    (1 + (_loadCost * (_loadFactor max 0 min 5))) * (1 + ((_gradeMultiplier - 1) * _gradeInfluence))
};

GAIT_fnc_sprintReserveGradeMultiplier = {
    params ["_degrees", "_uphillEnabled", "_startDegrees", "_fullDegrees", "_maximum"];
    if (_degrees < 0) exitWith {
        // Easy descents save effort. Steep downhill braking takes it back.
        private _descent = -_degrees;
        private _relief = ((_descent / 20) min 1) * (((45 - _descent) / 25) max 0 min 1);
        1 - (0.15 * _relief)
    };
    if (!_uphillEnabled) exitWith {1};
    private _start = _startDegrees max 0 min 60;
    private _full = (_fullDegrees max (_start + 0.1)) min 80;
    private _severity = ((_degrees - _start) / (_full - _start)) max 0 min 1;
    1 + (((_maximum max 1 min 4) - 1) * _severity)
};

// The spent fraction at weighted time t is 0.75t + 0.25t². Invert the
// current fraction before adding this interval so varying frame rates and
// grade/load changes consume the same reserve for the same total effort.
GAIT_fnc_spendSprintReserve = {
    params ["_reserve", "_maximum", "_effortFraction"];
    if (_reserve <= 0 || {_effortFraction <= 0}) exitWith {_reserve max 0};
    private _spent = (1 - (_reserve / _maximum)) max 0 min 1;
    private _elapsed = 2 * (sqrt (0.5625 + _spent) - 0.75);
    private _progress = (_elapsed + _effortFraction) min 1;
    private _remaining = 1 - ((0.75 * _progress) + (0.25 * _progress ^ 2));
    // Exact empty at the budget, within FLOAT precision over many samples.
    if (_remaining < 0.000001) exitWith {0};
    _maximum * _remaining
};

GAIT_fnc_stepFallbackSprintReserve = {
    params ["_reserve", "_activity", "_dt", "_maximum", "_recoverTime", "_drainRate"];
    switch (_activity) do {
        case "sprint": {[_reserve, _maximum, _dt * _drainRate / _maximum] call GAIT_fnc_spendSprintReserve};
        case "rest": {(_reserve + ((_maximum / _recoverTime) * _dt)) min _maximum};
        default {_reserve};
    }
};

// ACE defines player VO2Max as 35 + 20 * Performance Factor (0..10).
// Forty seconds at the default factor of one, scaled by the resolved unit value.
GAIT_fnc_aceSprintCapacitySeconds = {
    params ["_vo2Max"];
    40 * ((_vo2Max max 35 min 235) / 55)
};

GAIT_fnc_aceSprintReserveDelta = {
    params ["_before", "_after", "_exertion", "_restSeconds", "_sampleSeconds", "_capacitySeconds"];
    private _maximum = 2300;
    private _remaining = [_before, _maximum, _exertion / _capacitySeconds] call GAIT_fnc_spendSprintReserve;
    if (_sampleSeconds <= 0 || {_restSeconds <= 0}) exitWith {_remaining};
    // Native gain already includes ACE Recovery Factor and its aerobic state.
    private _recovery = ((_after - _before) max 0) * ((_restSeconds / _sampleSeconds) min 1);
    (_remaining + _recovery) min _maximum
};

GAIT_fnc_clearAceSprintEffort = {
    missionNamespace setVariable ["GAIT_pendingAceSprintEffort", [objNull, 0, 0, 0]];
};

// Accumulate between ACE's one-second samples so brief sprints are charged
// for the time actually spent in them, even if Shift is already up at publication.
GAIT_fnc_accumulateAceSprintEffort = {
    params ["_unit", "_activity", "_dt", "_degrees"];
    if (_dt <= 0) exitWith {};
    private _exertion = 0;
    if (_activity isEqualTo "sprint") then {
        private _mass = _unit getVariable "ace_movement_totalLoad";
        if (isNil "_mass") then {_mass = loadAbs _unit;};
        private _gearLbs = _mass / ((missionNamespace getVariable ["GAIT_ss_loadAbsPerLb", 10]) max 0.01);
        private _grade = [_degrees,
            missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainEnabled", true],
            missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainStartDegrees", 4],
            missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainMaxDegrees", 35],
            missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainMaxMultiplier", 2.10]]
            call GAIT_fnc_sprintReserveGradeMultiplier;
        private _drain = [_gearLbs, _grade,
            missionNamespace getVariable ["ace_advanced_fatigue_loadFactor", 1],
            missionNamespace getVariable ["ace_advanced_fatigue_terrainGradientFactor", 1]]
            call GAIT_fnc_sprintReserveDrainRate;
        _exertion = _dt * _drain;
    };
    isNil {
        private _pending = missionNamespace getVariable ["GAIT_pendingAceSprintEffort", [_unit, 0, 0, 0]];
        _pending params ["_owner", "_pastExertion", "_restSeconds", "_sampleSeconds"];
        if (_owner isNotEqualTo _unit) then {
            _pastExertion = 0;
            _restSeconds = 0;
            _sampleSeconds = 0;
        };
        missionNamespace setVariable ["GAIT_pendingAceSprintEffort", [_unit, _pastExertion + _exertion,
            _restSeconds + ([0, _dt] select (_activity isEqualTo "rest")), _sampleSeconds + _dt]];
    };
};

GAIT_fnc_filterAceSprintReserve = {
    params ["_before", "_after", "_unit"];
    private _pending = [];
    isNil {
        _pending = missionNamespace getVariable ["GAIT_pendingAceSprintEffort", [objNull, 0, 0, 0]];
        if ((_pending select 0) isEqualTo _unit) then {[] call GAIT_fnc_clearAceSprintEffort;};
    };
    if (!(call GAIT_fnc_modeAllowsMovement) || {!(call GAIT_fnc_aceAdvancedFatigueActive)} ||
        {!(missionNamespace getVariable ["GAIT_ss_useAceReserveModel", true])} ||
        {!([_unit] call GAIT_fnc_fatigueMovementContextEligible)}) exitWith {_after};

    _pending params ["_owner", "_exertion", "_restSeconds", "_sampleSeconds"];
    if (_owner isNotEqualTo _unit) exitWith {_before};
    private _capacity = [missionNamespace getVariable ["ace_advanced_fatigue_VO2Max", 55]]
        call GAIT_fnc_aceSprintCapacitySeconds;
    [_before, _after, _exertion, _restSeconds, _sampleSeconds, _capacity] call GAIT_fnc_aceSprintReserveDelta
};
