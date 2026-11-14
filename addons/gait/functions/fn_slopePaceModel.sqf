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
        ["_paceAnchors", [1.08, 1.02, 0.97, 0.92], [[]]],
        ["_extraHeavyPer50Lb", 0.18, [0]]
    ];
    _gearLbs = _gearLbs max 0;
    private _light = (_thresholds param [0, 35, [0]]) max 1;
    private _medium = (_thresholds param [1, 55, [0]]) max (_light + 1);
    private _heavy = (_thresholds param [2, 75, [0]]) max (_medium + 1);
    private _m0 = (_paceAnchors param [0, 1.08, [0]]) max 0.01;
    private _m1 = ((_paceAnchors param [1, 1.02, [0]]) max 0.01) min _m0;
    private _m2 = ((_paceAnchors param [2, 0.97, [0]]) max 0.01) min _m1;
    private _m3 = ((_paceAnchors param [3, 0.92, [0]]) max 0.01) min _m2;

    // The settings define points on the curve. Every change in carried weight
    // between them contributes to pace, including above the last point.
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

GAIT_fnc_uphillSprintPaceMultiplier = {
    params ["_gradeDegrees", "_startDegrees", "_referenceDegrees", "_referencePenalty", "_gearLbs"];
    private _mass = _gearLbs max 0;
    private _loadScale = 0.70 + (0.60 * (_mass / (_mass + 75)));
    [_gradeDegrees, _startDegrees, _referenceDegrees, _referencePenalty * _loadScale]
        call GAIT_fnc_uphillPaceMultiplier
};

// Scale the regular coefficient response without altering bracing or release
// timing. In particular, a rising hill should slow a moving sprint promptly.
GAIT_fnc_slopeSprintRamp = {
    params ["_baseRamp", "_gradeDegrees", "_speedRising", "_uphillStart", "_uphillEnabled"];
    private _rateScale = 1;
    if (_uphillEnabled && {_gradeDegrees > _uphillStart}) then {
        private _hill = sqrt (((_gradeDegrees - _uphillStart) / 25) min 1);
        _rateScale = 1 + (_hill * ([2.4, 0.65] select _speedRising));
    };
    1 - ((1 - (_baseRamp max 0.001 min 1)) ^ _rateScale)
};

// The final grade curve above remains the steady-state target. This helper
// controls how much of that penalty has been earned through continued uphill
// sprinting. The initial change is prompt, and steeper grades converge faster.
// Duration values mean approximately 95% of the remaining change.
GAIT_fnc_stepUphillPaceExposure = {
    params [
        ["_current", 0, [0]],
        ["_gradeDegrees", 0, [0]],
        ["_sprinting", false, [false]],
        ["_dt", 0.05, [0]],
        ["_startDegrees", 5, [0]],
        ["_referenceDegrees", 35, [0]],
        ["_shallowBuildSeconds", 1.25, [0]],
        ["_steepBuildSeconds", 0.40, [0]],
        ["_recoverySeconds", 0.85, [0]]
    ];
    _current = (_current max 0) min 1;
    _dt = (_dt max 0) min 0.20;
    if (_dt <= 0) exitWith {_current};
    _startDegrees = _startDegrees max 0;
    _referenceDegrees = _referenceDegrees max (_startDegrees + 0.1);
    private _severity = ((_gradeDegrees - _startDegrees) /
        (_referenceDegrees - _startDegrees)) max 0 min 1;
    private _uphill = _sprinting && {_gradeDegrees > _startDegrees};
    private _target = [0, 1] select _uphill;
    private _duration = _recoverySeconds max 0;
    if (_uphill) then {
        private _ease = _severity * _severity * (3 - (2 * _severity));
        _duration = (_shallowBuildSeconds max 0) +
            (((_steepBuildSeconds max 0) - (_shallowBuildSeconds max 0)) * _ease);
    };
    if (_duration <= 0) exitWith {_target};
    private _alpha = 1 - exp (-3 * _dt / (_duration max 0.01));
    (_current + ((_target - _current) * _alpha)) max 0 min 1
};

GAIT_fnc_applyUphillPaceExposure = {
    params [
        ["_fullMultiplier", 1, [0]],
        ["_exposure", 0, [0]]
    ];
    _fullMultiplier = (_fullMultiplier max 0.001) min 1;
    _exposure = (_exposure max 0) min 1;
    1 + ((_fullMultiplier - 1) * _exposure)
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
