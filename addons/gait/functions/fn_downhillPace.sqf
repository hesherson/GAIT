/*
    Pure downhill pace helpers. No animation, velocity, fatigue or settings I/O.

    The caller supplies directional grade, earned downhill momentum and the
    loaded and unloaded flat pace multipliers. Gravity acts along the slope.
    The additional load response represents how much momentum a runner with
    heavy kit carries into each step when braking the descent.
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
        ["_startDegrees", 0.5, [0]],
        ["_peakDegrees", 18, [0]],
        ["_entryBoost", 0.10, [0]],
        ["_sustainedBoost", 0.18, [0]],
        ["_loadMultiplier", 1, [0]],
        ["_unloadedMultiplier", 1, [0]],
        ["_steepStartDegrees", 18, [0]],
        ["_steepFullDegrees", 40, [0]]
    ];
    private _decline = (-_gradeDegrees) max 0;
    _startDegrees = (_startDegrees max 0) min 80;
    _peakDegrees = (_peakDegrees max (_startDegrees + 0.1)) min 89.9;
    _entryBoost = (_entryBoost max 0) min 0.35;
    _sustainedBoost = (_sustainedBoost max 0) min 0.25;
    _momentum = (_momentum max 0) min 1;
    private _activeBoost = _entryBoost + (_sustainedBoost * _momentum);
    if (_decline <= _startDegrees || {_activeBoost <= 0}) exitWith {1};

    private _relativePull = sin ((_decline - _startDegrees) min (_peakDegrees - _startDegrees)) /
        sin (_peakDegrees - _startDegrees);
    // Preserve some pull on a shallow slope, where a smoothstep around zero
    // would make the change barely perceptible.
    private _gradeFactor = (0.65 * _relativePull) + (0.35 * sqrt _relativePull);

    _steepStartDegrees = _steepStartDegrees max _peakDegrees;
    _steepFullDegrees = _steepFullDegrees max (_steepStartDegrees + 0.1);
    private _steep = ((_decline - _steepStartDegrees) / (_steepFullDegrees - _steepStartDegrees)) max 0 min 1;
    _steep = _steep * _steep * (3 - (2 * _steep));

    private _mass = _gearLbs max 0;
    private _loadShare = _mass / (_mass + 75);
    private _load = _loadMultiplier max 0.001;
    private _unloaded = _unloadedMultiplier max _load;
    // Carried weight limits self-powered flat pace. With time on the decline,
    // the slope offsets that penalty as the runner builds speed.
    private _retentionScale = (0.25 * ((_entryBoost / 0.10) min 1)) +
        (0.75 * _momentum * ((_sustainedBoost / 0.18) min 1));
    private _retention = (1 - ((1 - _gradeFactor) ^ 7)) * _retentionScale;
    private _retainedPace = (_unloaded - _load) * _retention;
    private _gravityScale = 1 + (0.65 * _steep);
    private _bonus = _unloaded * _activeBoost * _gradeFactor * _gravityScale * (1 + (0.50 * _loadShare));
    private _maximumPace = _unloaded * (1.50 + (0.15 * _loadShare));
    ((_load + _retainedPace + _bonus) min _maximumPace) / _load
};

// A calibrated lower bound supplements the coefficient target on steep
// descents. It grows from zero as the hill steepens and momentum builds.
GAIT_fnc_downhillGravityTargetKmh = {
    params [
        ["_gradeDegrees", 0, [0]],
        ["_gearLbs", 0, [0]],
        ["_momentum", 0, [0]],
        ["_startDegrees", 8, [0]],
        ["_fullDegrees", 35, [0]],
        ["_sustainedBoost", 0.18, [0]]
    ];
    private _decline = (-_gradeDegrees) max 0;
    if (_decline <= _startDegrees || {_momentum <= 0} || {_sustainedBoost <= 0}) exitWith {0};
    _fullDegrees = _fullDegrees max (_startDegrees + 0.1);
    private _severity = ((_decline - _startDegrees) /
        (_fullDegrees - _startDegrees)) max 0 min 1;
    private _mass = _gearLbs max 0;
    private _loadShare = _mass / (_mass + 75);
    private _strength = (_sustainedBoost / 0.18) min 1;
    34 * (_severity ^ 0.55) * (_momentum max 0 min 1) * (1 + (0.16 * _loadShare)) * _strength
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
