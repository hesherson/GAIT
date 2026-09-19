/*
    Pure downhill pace helpers. No animation, velocity, fatigue or settings I/O.

    The caller supplies smoothed travel grade and observed running momentum.
    The returned bonus multiplies the existing slope target BEFORE the common
    load multiplier and sprint/walk floor. It never replaces those policies.
    Numbers describe target ratios, not measured physical top speeds.
*/

GAIT_fnc_stepDownhillMomentum = {
    params [
        ["_current", 0, [0]],
        ["_target", 0, [0]],
        ["_dt", 0.05, [0]],
        ["_riseSeconds", 2.5, [0]],
        ["_fallSeconds", 1.5, [0]]
    ];
    _current = (_current max 0) min 1;
    _target = (_target max 0) min 1;
    // Limit recovery after a scheduler stall, matching the main pace ramp.
    _dt = (_dt max 0) min 0.20;
    if (_dt <= 0) exitWith {_current};
    private _duration = [_fallSeconds, _riseSeconds] select (_target > _current);
    if (_duration <= 0) exitWith {_target};
    // Duration means approximately 95% of a target change. Exponential decay
    // composes across normal update intervals without overshoot.
    private _alpha = 1 - exp (-3 * _dt / (_duration max 0.01));
    (_current + ((_target - _current) * _alpha)) max 0 min 1
};

GAIT_fnc_downhillPaceMultiplier = {
    params [
        ["_gradeDegrees", 0, [0]],
        ["_gearLbs", 0, [0]],
        ["_momentum", 0, [0]],
        ["_startDegrees", 4, [0]],
        ["_peakDegrees", 18, [0]],
        ["_maximumBoost", 0.18, [0]],
        ["_loadReferenceLbs", 75, [0]],
        ["_steepStartDegrees", 35, [0]],
        ["_steepFullDegrees", 75, [0]]
    ];
    private _decline = (-_gradeDegrees) max 0;
    _startDegrees = (_startDegrees max 0) min 80;
    _peakDegrees = (_peakDegrees max (_startDegrees + 0.1)) min 89.9;
    _maximumBoost = (_maximumBoost max 0) min 0.35;
    _momentum = (_momentum max 0) min 1;
    if (_decline <= _startDegrees || {_maximumBoost <= 0} || {_momentum <= 0}) exitWith {1};

    private _angle = ((_decline - _startDegrees) / (_peakDegrees - _startDegrees)) max 0 min 1;
    _angle = _angle * _angle * (3 - (2 * _angle));
    private _momentumEase = _momentum * _momentum * (3 - (2 * _momentum));
    // Preserve light/medium downhill pace. Above 55 lb, soften only the
    // bonus's load attenuation. This joins with matching value/derivative
    // and stays strictly decreasing as kit gets heavier. The common load
    // curve still applies its full penalty to the complete sprint target.
    private _bonusLoad = _gearLbs max 0;
    if (_bonusLoad > 55) then {
        private _extraLoad = _bonusLoad - 55;
        _bonusLoad = 55 + (0.10 * _extraLoad) + (2.70 * (1 - exp (-_extraLoad / 3)));
    };
    private _loadFactor = 1 / (1 + (_bonusLoad / (_loadReferenceLbs max 1)));

    // A steep descent calls for control. Reduce only the extra downhill bonus;
    // the underlying sprint pace, walk floor and trip handling remain intact.
    _steepStartDegrees = _steepStartDegrees max _peakDegrees;
    _steepFullDegrees = _steepFullDegrees max (_steepStartDegrees + 0.1);
    private _steep = ((_decline - _steepStartDegrees) / (_steepFullDegrees - _steepStartDegrees)) max 0 min 1;
    _steep = _steep * _steep * (3 - (2 * _steep));
    1 + (_maximumBoost * _angle * _momentumEase * _loadFactor * (1 - (0.75 * _steep)))
};

GAIT_fnc_downhillTripSpeedFactors = {
    params [
        ["_actualSpeedKmh", 0, [0]],
        ["_minimumSpeedKmh", 20, [0]],
        ["_referenceSpeedKmh", 34, [0]],
        ["_influence", 1, [0]]
    ];
    _minimumSpeedKmh = _minimumSpeedKmh max 0;
    _referenceSpeedKmh = _referenceSpeedKmh max (_minimumSpeedKmh + 0.1);
    _influence = (_influence max 0) min 2;
    // Actual horizontal velocity drives risk. The reference is calibration,
    // not a cap: going faster keeps increasing risk. At default influence,
    // excess speed and risk are directly proportional, starting from zero.
    private _severity = (((_actualSpeedKmh max 0) - _minimumSpeedKmh) / (_referenceSpeedKmh - _minimumSpeedKmh)) max 0;
    // Retain the explicit setting that opts out of speed scaling. Positive
    // influence adjusts the curve exponent while preserving the previous
    // calibrated multiplier at the reference speed (1.55 at default 1).
    if (_influence <= 0) exitWith {[_severity, 1]};
    [_severity, (_severity ^ _influence) * (1 + (0.55 * _influence))]
};

GAIT_fnc_downhillTripRollChance = {
    params [["_chancePerSecond", 0, [0]], ["_dt", 0, [0]]];
    if (_dt <= 0) exitWith {0};
    _chancePerSecond = (_chancePerSecond max 0) min 1;
    // Compose a per-second probability over the actual update interval.
    // Shorter update intervals must not change the total risk over a second.
    1 - ((1 - _chancePerSecond) ^ _dt)
};

GAIT_fnc_stepDownhillTripQualification = {
    params [
        ["_starts", [-1, -1], [[]]],
        ["_now", 0, [0]],
        ["_movementEligible", false, [true]],
        ["_isSprinting", false, [true]],
        ["_actualSpeedKmh", 0, [0]],
        ["_highSpeedThresholdKmh", 20, [0]],
        ["_minimumTripSpeedKmh", 20, [0]],
        ["_requiredSprintSeconds", 5, [0]]
    ];
    if (!_movementEligible) exitWith {[-1, -1, 0, 0]};
    private _sprintStart = _starts param [0, -1, [0]];
    private _highSpeedStart = _starts param [1, -1, [0]];
    private _sprintSeconds = 0;
    private _highSpeedSeconds = 0;
    if (_isSprinting) then {
        if (_sprintStart < 0) then {_sprintStart = _now;};
        _sprintSeconds = (_now - _sprintStart) max 0;
    } else {
        // Preserve an earned sprint qualification through real deceleration,
        // even if a heavy load only recently crossed the high-speed gate.
        // Otherwise releasing Shift could briefly grant trip immunity.
        private _qualifiedCoast = _sprintStart >= 0 &&
            {(_now - _sprintStart) >= (_requiredSprintSeconds max 0)} &&
            {_actualSpeedKmh >= (_minimumTripSpeedKmh max 0)};
        if (_qualifiedCoast) then {
            _sprintSeconds = (_now - _sprintStart) max 0;
        } else {
            _sprintStart = -1;
        };
    };
    // Shift release cannot erase a sustained high-speed history while the
    // body is still travelling that fast. Stops/context changes reset it.
    if (_actualSpeedKmh >= (_highSpeedThresholdKmh max 0)) then {
        if (_highSpeedStart < 0) then {_highSpeedStart = _now;};
        _highSpeedSeconds = (_now - _highSpeedStart) max 0;
    } else {
        _highSpeedStart = -1;
    };
    [_sprintStart, _highSpeedStart, _sprintSeconds, _highSpeedSeconds]
};
