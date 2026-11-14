// Both reserve models distinguish a moving sprint, an actual rest and a hold.
GAIT_fnc_sprintReserveActivity = {
    params ["_input", "_speed", "_animation", "_canSprint", "_isGrounded"];
    if (!_isGrounded) exitWith {"hold"};
    private _moving = _speed > 0.15;
    private _forward = _input select 0;
    if (_canSprint && {_moving} && {_input select 2} && {_forward > 0.05} &&
        {((toLower _animation) select [8, 4]) in ["meva", "mspr"]}) exitWith {"sprint"};
    if (!_moving && {abs _forward <= 0.05} && {abs (_input select 1) <= 0.05}) exitWith {"rest"};
    "hold"
};

GAIT_fnc_sprintReserveDrainRate = {
    params ["_gearLbs", "_gradeMultiplier"];
    private _mass = _gearLbs max 0;
    private _moderateLoad = ((_mass - 60) / 60) max 0 min 1;
    private _extraHeavyLoad = (_mass - 120) max 0;
    private _loadMultiplier = 1 + (0.0005 * _mass) + (0.13 * _moderateLoad ^ 2) +
        (0.26 * _extraHeavyLoad / 60) + (0.00825 * _extraHeavyLoad ^ 2 / (_extraHeavyLoad + 15));
    _loadMultiplier * _gradeMultiplier
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

GAIT_fnc_stepFallbackSprintReserve = {
    params ["_reserve", "_activity", "_dt", "_maximum", "_recoverTime", "_drainRate"];
    switch (_activity) do {
        case "sprint": {(_reserve - (_dt * _drainRate)) max 0};
        case "rest": {(_reserve + ((_maximum / _recoverTime) * _dt)) min _maximum};
        default {_reserve};
    }
};

GAIT_fnc_aceSprintReserveDelta = {
    params ["_before", "_after", "_debit", "_activity", "_drainRate", ["_adjustedDebit", -1, [0]]];
    switch (_activity) do {
        case "sprint": {
            // ACE floors the raw debit before recovery. Undo that floor to
            // keep a debit proportional all the way down to an empty bar.
            private _tickRecovery = (_after - ((_before - _debit) max 0)) max 0;
            if (_adjustedDebit < 0) then {_adjustedDebit = _debit;};
            private _spent = 0.65 * _drainRate * ((_adjustedDebit - _tickRecovery) max 0);
            (_before - _spent) max 0
        };
        case "rest": {_before max _after};
        default {_before};
    }
};

GAIT_fnc_aceSprintReserveAdjustedDebit = {
    params ["_debit", "_workInputs"];
    _workInputs params ["_work", "_gearKg", "_gradient", "_terrainFactor", "_speed", "_wattsPerATP"];
    if (_debit <= 0 || {_gearKg <= 0} || {_wattsPerATP <= 0}) exitWith {_debit};

    // ACE 3.21.2's additive workload terms, before its common efficiency and
    // duty multipliers. Retain 15% of ACE's effective load in the displayed
    // reserve debit so moderate rucks do not pay the full native penalty on
    // top of GAIT's mass curve. ACE still uses the real work for physiology.
    private _running = _speed > 2;
    private _baseline = [73.5, 147] select _running;
    private _loadTerm = [2, 4] select _running;
    private _strideTerm = [1.15, 0.9] select _running;
    private _paceTerm = _terrainFactor * ((_strideTerm * _speed ^ 2) + (0.66 * _speed * _gradient));
    private _workScale = {
        params ["_massKg"];
        _baseline + ((70 + _massKg) * (_loadTerm * (_massKg / 70) ^ 2 + _paceTerm))
    };
    private _stockWork = [_gearKg] call _workScale;
    private _reserveWork = [0.15 * _gearKg] call _workScale;
    private _cargoDebit = _work * (1 - (_reserveWork / _stockWork)) / _wattsPerATP;
    (_debit - _cargoDebit) max 0
};

GAIT_fnc_filterAceSprintReserve = {
    params ["_before", "_after", "_unit", "_debit", "_degrees", "_workInputs"];
    if (!(call GAIT_fnc_modeAllowsMovement) || {!(call GAIT_fnc_aceAdvancedFatigueActive)} ||
        {!(missionNamespace getVariable ["GAIT_ss_useAceReserveModel", true])} ||
        {!([_unit] call GAIT_fnc_fatigueMovementContextEligible)}) exitWith {_after};

    // Sample live intent into the ACE tick rather than trusting the last
    // scheduled GAIT update when the player has just let go of Shift.
    private _canSprint = isSprintAllowed _unit && {!isForcedWalk _unit} &&
        {(_unit getVariable ["ace_common_effect_blockSprint", 0]) <= 0} &&
        {(_unit getVariable ["ace_common_effect_forceWalk", 0]) <= 0};
    private _velocity = velocity _unit;
    private _horizontalSpeed = vectorMagnitude [_velocity select 0, _velocity select 1, 0];
    private _activity = [call GAIT_fnc_getMovementInput, _horizontalSpeed,
        animationState _unit, _canSprint, isTouchingGround _unit] call GAIT_fnc_sprintReserveActivity;
    if (_activity isNotEqualTo "sprint") exitWith {
        [_before, _after, _debit, _activity, 1] call GAIT_fnc_aceSprintReserveDelta
    };

    // Use the same total inventory load that ACE just rated, including
    // delegated load providers such as ACE Movement when available.
    private _loadAbs = _unit getVariable ["ace_movement_totalLoad", loadAbs _unit];
    private _gearLbs = _loadAbs / ((missionNamespace getVariable ["GAIT_ss_loadAbsPerLb", 10]) max 0.01);
    // Values above 1 still increase native work, without stacking the ACE
    // slider a second time onto GAIT's own mass and ascent multipliers.
    private _loadInfluence = (missionNamespace getVariable ["ace_advanced_fatigue_loadFactor", 1]) max 0 min 1;
    private _terrainInfluence = (missionNamespace getVariable ["ace_advanced_fatigue_terrainGradientFactor", 1]) max 0 min 1;
    private _gradeMultiplier = 1;
    if (_degrees > 0 && {missionNamespace getVariable ["GAIT_ss_slopeHandlingEnabled", true]}) then {
        // ACE already reduces the native downhill gradient. Add the GAIT
        // climb cost using the live grade from this same ACE work sample.
        _gradeMultiplier = [_degrees,
            missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainEnabled", true],
            missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainStartDegrees", 10],
            missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainMaxDegrees", 35],
            missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainMaxMultiplier", 1.75]]
            call GAIT_fnc_sprintReserveGradeMultiplier;
    };
    private _massMultiplier = [_gearLbs, 1] call GAIT_fnc_sprintReserveDrainRate;
    private _drainRate = (1 + ((_massMultiplier - 1) * _loadInfluence)) *
        (1 + ((_gradeMultiplier - 1) * _terrainInfluence));
    private _adjustedDebit = [_debit, _workInputs] call GAIT_fnc_aceSprintReserveAdjustedDebit;
    [_before, _after, _debit, _activity, _drainRate, _adjustedDebit] call GAIT_fnc_aceSprintReserveDelta
};
