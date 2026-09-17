/*
    Pure pace helpers. Supply both final-model base speeds in the same units,
    preferably metres per second along the travel surface. Common-reference
    pace units also work; coefficients of different animation families do not.
    The caller owns reserve/fatigue interpolation, brace timing, acceleration
    and movement I/O. The floor applies to the steady target, not launch speed.
*/

GAIT_fnc_continuousLoadMultiplier = {
    params [
        ["_gearLbs", 0, [0]],
        ["_thresholds", [35, 55, 75], [[]]],
        ["_tierMultipliers", [1.08, 1.05, 1.025, 1], [[]]],
        ["_extraHeavyPer50Lb", 0.18, [0]]
    ];
    _gearLbs = _gearLbs max 0;
    private _light = (_thresholds param [0, 35, [0]]) max 1;
    private _medium = (_thresholds param [1, 55, [0]]) max (_light + 1);
    private _heavy = (_thresholds param [2, 75, [0]]) max (_medium + 1);
    private _m0 = (_tierMultipliers param [0, 1.08, [0]]) max 0.01;
    private _m1 = ((_tierMultipliers param [1, 1.05, [0]]) max 0.01) min _m0;
    private _m2 = ((_tierMultipliers param [2, 1.025, [0]]) max 0.01) min _m1;
    private _m3 = ((_tierMultipliers param [3, 1, [0]]) max 0.01) min _m2;

    // Interpolate all four existing gear multipliers instead of stepping on
    // tier boundaries. The heavy baseline is reached at the heavy threshold;
    // it is not a cap on the weight penalty. Extra kit keeps reducing speed.
    if (_gearLbs <= _light) exitWith {
        _m0 + ((_m1 - _m0) * (_gearLbs / _light))
    };
    if (_gearLbs <= _medium) exitWith {
        _m1 + ((_m2 - _m1) * ((_gearLbs - _light) / (_medium - _light)))
    };
    if (_gearLbs <= _heavy) exitWith {
        _m2 + ((_m3 - _m2) * ((_gearLbs - _medium) / (_heavy - _medium)))
    };
    _m3 / (1 + ((_extraHeavyPer50Lb max 0) * ((_gearLbs - _heavy) / 50)))
};

GAIT_fnc_uphillPaceMultiplier = {
    params [
        ["_gradeDegrees", 0, [0]],
        ["_startDegrees", 5, [0]],
        ["_referenceDegrees", 35, [0]],
        ["_referencePenalty", 0.40, [0]]
    ];
    _startDegrees = _startDegrees max 0;
    _referenceDegrees = _referenceDegrees max (_startDegrees + 0.1);
    private _severity = ((_gradeDegrees - _startDegrees) / (_referenceDegrees - _startDegrees)) max 0;
    // The chosen penalty is reached at the reference angle. Continue the
    // curve above that angle so a steeper traversable hill remains slower.
    (1 - (_referencePenalty max 0 min 0.99)) ^ _severity
};

GAIT_fnc_slopePaceModel = {
    params [
        ["_flatWalkMS", 1.6, [0]],
        ["_flatSprintMS", 6.2, [0]],
        ["_walkSlopeMultiplier", 1, [0]],
        ["_sprintSlopeMultiplier", 1, [0]],
        ["_loadMultiplier", 1, [0]],
        ["_minimumSprintRatio", 1.20, [0]]
    ];
    private _load = _loadMultiplier max 0.001;
    private _walk = (_flatWalkMS max 0.01) * (_walkSlopeMultiplier max 0.001) * _load;
    private _sprintCandidate = (_flatSprintMS max 0) * (_sprintSlopeMultiplier max 0.001) * _load;
    private _sprintFloor = _walk * (_minimumSprintRatio max 1.01);
    [_walk, _sprintCandidate max _sprintFloor]
};
