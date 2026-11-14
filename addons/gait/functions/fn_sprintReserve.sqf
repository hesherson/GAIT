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
    (1 + (0.35 * (_mass / (_mass + 75)))) * _gradeMultiplier
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
    params ["_before", "_after", "_debit", "_activity", "_drainRate"];
    switch (_activity) do {
        case "sprint": {
            // ACE samples once a second. Recover its original ATP debit near
            // zero before easing and capping it, so the last bar can empty.
            private _tickRecovery = (_after - ((_before - _debit) max 0)) max 0;
            private _netDebit = (_debit - _tickRecovery) max 0;
            private _limit = 2300 * _drainRate / 40;
            private _spent = (0.75 * _netDebit) max (0.20 * _limit) min _limit;
            (_before - _spent) max 0
        };
        case "rest": {_before max _after};
        default {_before};
    }
};

GAIT_fnc_filterAceSprintReserve = {
    params ["_before", "_after", "_unit", "_debit"];
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
    private _gearLbs = (loadAbs _unit) / ((missionNamespace getVariable ["GAIT_ss_loadAbsPerLb", 10]) max 0.01);
    private _gradeMultiplier = missionNamespace getVariable ["GAIT_uphillFatigueDrainMultiplier", 1];
    private _drainRate = [_gearLbs, _gradeMultiplier] call GAIT_fnc_sprintReserveDrainRate;
    [_before, _after, _debit, _activity, _drainRate] call GAIT_fnc_aceSprintReserveDelta
};
