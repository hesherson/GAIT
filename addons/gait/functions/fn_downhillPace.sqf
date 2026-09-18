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
    private _loadFactor = 1 / (1 + ((_gearLbs max 0) / (_loadReferenceLbs max 1)));

    // A steep descent calls for control. Reduce only the extra downhill bonus;
    // the underlying sprint pace, walk floor and trip handling remain intact.
    _steepStartDegrees = _steepStartDegrees max _peakDegrees;
    _steepFullDegrees = _steepFullDegrees max (_steepStartDegrees + 0.1);
    private _steep = ((_decline - _steepStartDegrees) / (_steepFullDegrees - _steepStartDegrees)) max 0 min 1;
    _steep = _steep * _steep * (3 - (2 * _steep));
    1 + (_maximumBoost * _angle * _momentumEase * _loadFactor * (1 - (0.75 * _steep)))
};
