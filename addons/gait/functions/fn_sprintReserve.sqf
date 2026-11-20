// Sprint drain follows allowed effort. Velocity only distinguishes rest from a coast.
GAIT_fnc_sprintReserveActivity = {
    params ["_input", "_speed", "_canSprint", "_isGrounded", ["_stanceActivity", ""], ["_walking", false]];
    if (!_isGrounded) exitWith {"hold"};
    if (_stanceActivity isEqualTo "stance") exitWith {_stanceActivity};
    private _forward = _input select 0;
    if (_canSprint && {_input select 2} && {_forward > 0.05}) exitWith {"sprint"};
    if (_stanceActivity in ["crouch", "crawl"] && {_speed > 0.15}) exitWith {_stanceActivity};
    if (_speed <= 0.15 && {abs _forward <= 0.05} && {abs (_input select 1) <= 0.05}) exitWith {"rest"};
    if (_walking && {_speed > 0.15} && {!(_input select 2)} &&
        {abs _forward > 0.05 || {abs (_input select 1) > 0.05}}) exitWith {"walk"};
    "hold"
};

GAIT_fnc_walkRecoveryShare = {
    params ["_gearLbs", ["_carryingPatient", false]];
    private _load = (_gearLbs / 150) max 0 min 1;
    (0.19 - 0.15 * _load) * ([1, 0.5] select _carryingPatient)
};

GAIT_fnc_stanceReserveDrainRate = {
    params ["_activity", "_gearLbs", "_depth"];
    private _load = ((_gearLbs / 150) max 0 min 1) ^ 1.2;
    switch (_activity) do {
        case "stance": {(0.45 + 1.15 * _load) * _depth};
        case "crouch": {0.24 + 0.42 * _load};
        case "crawl": {0.30 + 0.50 * _load};
        default {0};
    }
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
    params ["_degrees", ["_uphillEnabled", true], ["_startDegrees", 4], ["_fullDegrees", 35], ["_maximum", 2.10]];
    if (_degrees < 0) exitWith {
        // Gravity assists on moderate descents. Braking and ground control
        // gradually take that saving back on steeper slopes.
        private _descent = -_degrees;
        private _assist = (_descent / 13) min 1;
        private _braking = ((_descent - 18) / 27) max 0 min 1;
        private _relief = (_assist ^ 2 * (3 - 2 * _assist)) * (1 - (_braking ^ 2 * (3 - 2 * _braking)));
        1 - (0.20 * _relief)
    };
    if (!_uphillEnabled) exitWith {1};
    private _start = _startDegrees max 0 min 60;
    private _full = (_fullDegrees max (_start + 0.1)) min 80;
    private _severity = ((_degrees - _start) / (_full - _start)) max 0 min 1;
    1 + (((_maximum max 1 min 4) - 1) * _severity ^ 1.5)
};

// The spent fraction at weighted time t is 0.75t + 0.25t². Derive its
// current rate from the reserve and integrate the cost over this interval.
// This preserves the curve across sample rates and grade/load changes.
GAIT_fnc_spendSprintReserve = {
    params ["_reserve", "_maximum", "_effortFraction"];
    if (_reserve <= 0 || {_effortFraction <= 0}) exitWith {_reserve max 0};
    private _spent = (1 - (_reserve / _maximum)) max 0 min 1;
    private _rate = sqrt (0.5625 + _spent);
    private _cost = _maximum * (_effortFraction * (_rate + 0.25 * _effortFraction));
    private _remaining = _reserve - _cost;
    if (_remaining < 0.00001 * _maximum) exitWith {0};
    _remaining
};

GAIT_fnc_stepFallbackSprintReserve = {
    params ["_reserve", "_activity", "_dt", "_maximum", "_recoverTime", "_drainRate", ["_walkRecoveryShare", 0]];
    switch (_activity) do {
        case "drag";
        case "stance";
        case "crouch";
        case "crawl";
        case "sprint": {[_reserve, _maximum, _dt * _drainRate / _maximum] call GAIT_fnc_spendSprintReserve};
        case "rest";
        case "walk": {
            private _share = [_walkRecoveryShare, 1] select (_activity isEqualTo "rest");
            (_reserve + ((_maximum / _recoverTime) * _dt * _share)) min _maximum
        };
        default {_reserve};
    }
};

// ACE defines player VO2Max as 35 + 20 * Performance Factor (0..10).
// Sixty seconds at the default factor of one, scaled by the resolved unit value.
GAIT_fnc_aceSprintCapacitySeconds = {
    params ["_vo2Max"];
    60 * ((_vo2Max max 35 min 235) / 55)
};

GAIT_fnc_aceSprintReserveDelta = {
    params ["_before", "_after", "_exertion", "_recoverySeconds", "_sampleSeconds", "_capacitySeconds",
        ["_weightedWalkSeconds",0], ["_recoveryFactor",1]];
    private _maximum = 2300;
    private _remaining = [_before, _maximum, _exertion / _capacitySeconds] call GAIT_fnc_spendSprintReserve;
    if (_sampleSeconds <= 0 || {_recoverySeconds <= 0}) exitWith {_remaining};
    // Native gain already includes ACE Recovery Factor and its aerobic state.
    private _recovery = ((_after - _before) max 0) * ((_recoverySeconds / _sampleSeconds) min 1);
    // ACE can report zero aerobic surplus even at a walk. Credit only the
    // missing portion of a modest floor, and only for time actually walking.
    private _nativeRate = ((_after - _before) max 0) / _sampleSeconds;
    _recovery = _recovery + (_weightedWalkSeconds * ((8 * (_recoveryFactor max 0) - _nativeRate) max 0));
    (_remaining + _recovery) min _maximum
};

GAIT_fnc_clearAceSprintEffort = {
    missionNamespace setVariable ["GAIT_pendingAceSprintEffort", [objNull, 0, 0, 0, 0]];
};

// Accumulate between ACE's one-second samples so brief sprints are charged
// for the time actually spent in them, even if Shift is already up at publication.
GAIT_fnc_accumulateAceSprintEffort = {
    params ["_unit", "_activity", "_dt", "_degrees", ["_stanceRate", 0], ["_walkRecoveryShare", 0], ["_normalShare", 1], ["_gearLbs", -1]];
    if (_dt <= 0) exitWith {};
    private _exertion = _dt * _stanceRate;
    if (_activity isEqualTo "sprint") then {
        if (_gearLbs < 0) then {
            private _mass = _unit getVariable "ace_movement_totalLoad";
            if (isNil "_mass") then {_mass = loadAbs _unit;};
            _gearLbs = _mass / 10;
        };
        private _grade = [_degrees] call GAIT_fnc_sprintReserveGradeMultiplier;
        private _drain = [_gearLbs, _grade,
            missionNamespace getVariable ["ace_advanced_fatigue_loadFactor", 1],
            missionNamespace getVariable ["ace_advanced_fatigue_terrainGradientFactor", 1]]
            call GAIT_fnc_sprintReserveDrainRate;
        _exertion = _dt * _drain;
    };
    private _recoveryShare = [0, _walkRecoveryShare] select (_activity isEqualTo "walk");
    if (_activity isEqualTo "rest") then {_recoveryShare = 1;};
    isNil {
        private _pending = missionNamespace getVariable ["GAIT_pendingAceSprintEffort", [_unit, 0, 0, 0]];
        _pending params ["_owner", "_pastExertion", "_recoverySeconds", "_sampleSeconds", ["_walkSeconds",0]];
        if (_owner isNotEqualTo _unit) then {
            _pastExertion = 0;
            _recoverySeconds = 0;
            _sampleSeconds = 0;
            _walkSeconds = 0;
        };
        private _credit = _dt * _recoveryShare * _normalShare;
        if (_activity isEqualTo "walk") then {_walkSeconds = _walkSeconds + _credit};
        missionNamespace setVariable ["GAIT_pendingAceSprintEffort", [_unit, _pastExertion + _exertion * _normalShare,
            _recoverySeconds + _credit, _sampleSeconds + _dt, _walkSeconds]];
    };
};

GAIT_fnc_filterAceSprintReserve = {
    params ["_before", "_after", "_unit"];
    private _burstCost = 2300 * ([_unit] call GAIT_fnc_takeBurstCost);
    private _pending = [];
    isNil {
        _pending = missionNamespace getVariable ["GAIT_pendingAceSprintEffort", [objNull, 0, 0, 0]];
        if ((_pending select 0) isEqualTo _unit) then {[] call GAIT_fnc_clearAceSprintEffort;};
    };
    if (!(call GAIT_fnc_modeAllowsMovement) || {!(call GAIT_fnc_aceAdvancedFatigueActive)} ||
        {!([_unit, true, true] call GAIT_fnc_fatigueMovementContextEligible)}) exitWith {(_after - _burstCost) max 0};

    _pending params ["_owner", "_exertion", "_recoverySeconds", "_sampleSeconds", ["_walkSeconds",0]];
    if (_owner isNotEqualTo _unit) exitWith {(_before - _burstCost) max 0};
    private _capacity = [missionNamespace getVariable ["ace_advanced_fatigue_VO2Max", 55]]
        call GAIT_fnc_aceSprintCapacitySeconds;
    private _remaining = [_before, _after, _exertion, _recoverySeconds, _sampleSeconds, _capacity,
        _walkSeconds,missionNamespace getVariable ["ace_advanced_fatigue_recoveryFactor",1]] call GAIT_fnc_aceSprintReserveDelta;
    (_remaining - _burstCost) max 0
};
