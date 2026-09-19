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
