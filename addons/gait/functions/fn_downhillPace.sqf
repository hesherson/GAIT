/*
    Pure downhill pace helpers. No animation, velocity, fatigue or settings I/O.

    Gravity acts along the slope. All kits share that acceleration, with a
    small additional response to gentle descents as the carried load rises.
*/

GAIT_fnc_downhillRunAngles = {
    params ["_startDegrees", "_peakDegrees"];
    private _span = (_peakDegrees - _startDegrees) max 0.1;
    private _start = _startDegrees - ((0.70 * _startDegrees) min 2);
    [_start, _start + (0.75 * _span)]
};

GAIT_fnc_downhillWalkMultiplier = {
    params ["_gradeDegrees", "_startDegrees", "_peakDegrees"];
    private _span = (_peakDegrees - _startDegrees) max 0.1;
    private _gradeShare = ((-_gradeDegrees - _startDegrees) / _span) max 0 min 1;
    1 + (0.10 * ((0.65 * sqrt _gradeShare) + (0.35 * _gradeShare)))
};

GAIT_fnc_casualtyTerrainMultiplier = {
    params ["_grade", "_clip"];
    if (_grade < 0) exitWith {
        private _pull = ([_grade, 0.5, 18] call GAIT_fnc_downhillWalkMultiplier) - 1;
        private _share = switch (_clip) do {
            case "drag": {0.45};
            case "carryWalk": {0.75};
            default {1};
        };
        1 + (_pull * _share)
    };
    private _penalty = [0.24, 0.28] select (_clip isEqualTo "drag");
    ([_grade, 2, 35, _penalty] call GAIT_fnc_uphillPaceMultiplier) max 0.65
};

GAIT_fnc_downhillMomentumTarget = {
    params [
        ["_gradeDegrees", 0, [0]],
        ["_startDegrees", 0.5, [0]],
        ["_peakDegrees", 18, [0]]
    ];
    _startDegrees = (_startDegrees max 0) min 80;
    _peakDegrees = (_peakDegrees max (_startDegrees + 0.1)) min 89.9;
    // Moderate descents sustain the full meter. Shallow grades earn a smaller
    // share so a long gentle descent cannot bank the full steep descent boost.
    private _range = (_peakDegrees - _startDegrees) * 0.55;
    private _gradeShare = (((-_gradeDegrees) - _startDegrees) / _range) max 0 min 1;
    _gradeShare ^ 0.35
};

GAIT_fnc_stepDownhillMomentum = {
    params [
        ["_current", 0, [0]],
        ["_target", 0, [0]],
        ["_dt", 0.05, [0]],
        ["_riseSeconds", 6.5, [0]],
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

// Only the scalar speed bonus carries across a turn. Live input keeps steering.
GAIT_fnc_turnDownhillBonus = {
    params ["_previous", "_earned", "_grade", "_dt"];
    private _seconds = if (_earned >= _previous) then {0.25} else {[0.50,0.18] select (_grade > 2)};
    [_previous, _earned, _dt, _seconds, _seconds] call GAIT_fnc_stepDownhillMomentum
};

GAIT_fnc_shufflePose = {
    params ["_decline","_crossfall","_previous"];
    private _right = _crossfall > 0;
    if (_previous != "" && {abs _crossfall < 0.16}) then {_right = _previous find "right" >= 0};
    private _medium = _previous find "medium" >= 0;
    private _steep = _previous find "steep" >= 0;
    private _band = "";
    if (_decline >= ([28,25] select (_medium || _steep))) then {_band = "medium"};
    if (_decline >= ([35,32] select _steep)) then {_band = "steep"};
    (["gait_shuffleleft","gait_shuffleright"] select _right) + _band
};

GAIT_fnc_downhillGradeFactor = {
    params ["_decline", "_startDegrees", "_peakDegrees"];
    _startDegrees = (_startDegrees max 0) min 80;
    _peakDegrees = (_peakDegrees max (_startDegrees + 0.1)) min 89.9;
    private _relativePull = sin ((_decline - _startDegrees) max 0 min (_peakDegrees - _startDegrees)) /
        sin (_peakDegrees - _startDegrees);
    (0.65 * _relativePull) + (0.35 * sqrt _relativePull)
};

GAIT_fnc_downhillPaceMultiplier = {
    params ["_gradeDegrees", "_loadShare", "_momentum", ["_startDegrees", 0.5], ["_peakDegrees", 18],
        ["_entryBoost", 0.03], ["_sustainedBoost", 0.14], ["_maximumPace", 1.18]];
    private _decline = -_gradeDegrees;
    if (_decline <= 0) exitWith {1};
    private _activeBoost = (_entryBoost max 0 min 0.35) +
        ((_sustainedBoost max 0 min 0.25) * (_momentum max 0 min 1) ^ 4);
    private _steepStart = _peakDegrees max 18;
    private _steep = ((_decline - _steepStart) / ((40 - _steepStart) max 0.1)) max 0 min 1;
    private _gravity = _activeBoost * (1 + (0.20 * _steep ^ 2 * (3 - (2 * _steep))));
    private _basePull = [_decline, _startDegrees, _peakDegrees] call GAIT_fnc_downhillGradeFactor;
    private _earlyPull = ([_decline] + ([_startDegrees, _peakDegrees] call GAIT_fnc_downhillRunAngles))
        call GAIT_fnc_downhillGradeFactor;
    // The extra downhill pull uses less than the minimum 2.5% light-kit
    // advantage, so stronger relative acceleration preserves pace ordering.
    private _extra = (_gravity * (1.08 * _earlyPull - _basePull)) max 0 min 0.012;
    (1 + (_gravity * _basePull) + (_loadShare * _extra)) min _maximumPace
};

// An exact clip reference converts a physical ceiling to a coefficient.
// Without a reference the caller retains its bounded coefficient model.
GAIT_fnc_capDownhillPace = {
    params [
        ["_candidate", 0, [0]],
        ["_referenceMS", -1, [0]],
        ["_maximumKmh", 0, [0]],
        ["_loadPaceRatio", 1, [0]]
    ];
    if (!(_referenceMS > 0.1 && {_referenceMS < 25}) || {_maximumKmh <= 0}) exitWith {_candidate};
    _candidate min (_maximumKmh * _loadPaceRatio / (3.6 * _referenceMS))
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

GAIT_fnc_stepDepletedRunTime = {
    params ["_time", "_reserve", "_running", "_eligible", "_dt"];
    if (!_eligible || {_reserve > 0.05}) exitWith {0};
    private _step = _dt max 0 min 0.25;
    if (_running && {_reserve <= 0.02}) exitWith {(_time + _step) min 12};
    (_time - 2 * _step) max 0
};

GAIT_fnc_downhillTripFatigueFactors = {
    params ["_reserve", "_depletedRunTime"];
    private _fatigue = (1 - (_reserve max 0 min 1)) ^ 2.2;
    private _exposure = (_depletedRunTime / 12) max 0 min 1;
    [1 + 0.65 * _fatigue, 1 + 0.35 * _exposure, 1 - 0.25 * _fatigue]
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
