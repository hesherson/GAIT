/*
    Pure uphill sprint-release braking. This is separate from launch bracing:
    releasing a moving uphill sprint briefly digs in, while flat/downhill
    release retains the existing momentum policy. No animation, velocity,
    fatigue, namespace or input writes occur in these helpers.
*/

GAIT_fnc_uphillBrakeParameters = {
    params [
        ["_gradeDegrees", 0, [0]],
        ["_currentCoefficient", 1, [0]],
        ["_walkCoefficient", 1, [0]],
        ["_startDegrees", 15, [0]],
        ["_maximumDegrees", 35, [0]],
        ["_baseDuration", 0.15, [0]],
        ["_extraDuration", 0.18, [0]],
        ["_extraDip", 0.28, [0]],
        ["_normalRamp", 0.05, [0]],
        ["_braceRamp", 0.575, [0]]
    ];
    _currentCoefficient = _currentCoefficient max 0;
    _walkCoefficient = _walkCoefficient max 0;
    _startDegrees = _startDegrees max 0 min 60;
    _maximumDegrees = _maximumDegrees max (_startDegrees + 0.1) min 80;
    _normalRamp = _normalRamp max 0.001 min 1;
    _braceRamp = _braceRamp max _normalRamp min 1;
    private _factor = ((_gradeDegrees - _startDegrees) / (_maximumDegrees - _startDegrees)) max 0 min 1;
    _factor = _factor * _factor * (3 - (2 * _factor));
    if (_factor <= 0) exitWith {[0, 0, _currentCoefficient, _normalRamp]};

    // Both the duration and force vanish at the onset angle. A nearly level
    // release cannot suddenly lose its coast through a fixed-duration brace.
    private _duration = ((_baseDuration max 0 min 2) + (_extraDuration max 0 min 2)) * _factor;
    private _dip = _extraDip max 0 min 0.90;
    // Never accelerate a slow uphill body toward its nominal walking pace.
    private _fullTarget = (_currentCoefficient min _walkCoefficient) * (1 - _dip);
    private _target = _currentCoefficient + ((_fullTarget - _currentCoefficient) * _factor);
    private _ramp = _normalRamp + ((_braceRamp - _normalRamp) * _factor);
    [_factor, _duration, _target, _ramp]
};

// Shorten the old release coast continuously as the uphill brake strengthens.
// A zero-strength event keeps the exact old window; full strength removes it.
GAIT_fnc_uphillBrakeCoastWindow = {
    params ["_severity", "_holdDuration", "_taperDuration"];
    private _total = (_holdDuration max 0 min 3) + (_taperDuration max 0.05 min 4);
    private _spent = _total * (_severity max 0 min 1);
    [_spent, _total - _spent]
};

/*
    State: [previousRawSprintIntent, previousActualSprint, previousTravelGrade,
            endTime, severity, targetCoefficient, ramp, originalDuration].
    Raw intent means forward + sprint keys, without eligibility/medical gates.
    Context must mean safe standing movement, excluding carry/reload/actions.
    The caller supplies its existing slope-stop tuning as the final array.

    Return: [state, active, started, severity, targetCoefficient, ramp,
             remainingSeconds, originalDuration, resumedDuringBrake].
*/
GAIT_fnc_stepUphillBrake = {
    params [
        ["_state", [false, false, 0, -1, 0, 0, 0.05, 0], [[]]],
        ["_rawSprintIntent", false, [false]],
        ["_actualSprinting", false, [false]],
        ["_forwardHeld", false, [false]],
        ["_contextOk", false, [false]],
        ["_actualSpeedMS", 0, [0]],
        ["_gradeDegrees", 0, [0]],
        ["_currentCoefficient", 1, [0]],
        ["_walkCoefficient", 1, [0]],
        ["_now", 0, [0]],
        ["_enabled", true, [false]],
        ["_parameters", [15, 35, 0.15, 0.18, 0.28, 0.05, 0.575], [[]]]
    ];
    if ((count _state) < 8) then {_state = [false, false, 0, -1, 0, 0, 0.05, 0];};
    if ((count _parameters) < 7) then {_parameters = [15, 35, 0.15, 0.18, 0.28, 0.05, 0.575];};
    private _previousIntent = _state param [0, false, [false]];
    private _previousSprint = _state param [1, false, [false]];
    private _previousGrade = _state param [2, 0, [0]];
    private _until = _state param [3, -1, [0]];
    private _severity = _state param [4, 0, [0]];
    private _target = _state param [5, _currentCoefficient, [0]];
    private _ramp = _state param [6, 0.05, [0]];
    private _duration = _state param [7, 0, [0]];
    private _normalRamp = (_parameters param [5, 0.05, [0]]) max 0.001 min 1;
    private _resumed = _rawSprintIntent && {!_previousIntent} && {_contextOk} && {_enabled} &&
        {_actualSpeedMS > 0.25} && {_until > _now} && {_severity > 0};

    // Remember grade only from an actual forward sprint. Releasing W makes
    // the input-based slope sample zero, so that edge needs the previous one.
    private _rememberedGrade = [_previousGrade, _gradeDegrees] select (_actualSprinting && {_forwardHeld});
    private _nextIntent = _rawSprintIntent;
    private _nextSprint = _actualSprinting && {_rawSprintIntent} && {_contextOk} && {_enabled};
    private _started = false;

    // A sprint re-tap cancels the release brake immediately. It must never
    // become another launch brace while there is still traveling momentum.
    if (!_enabled || {!_contextOk} || {_rawSprintIntent} || {_actualSpeedMS <= 0.25} || {_now >= _until}) then {
        _until = -1;
        _severity = 0;
        _target = _currentCoefficient max 0;
        _ramp = _normalRamp;
        _duration = 0;
    };

    private _releaseEdge = _previousIntent && {_previousSprint} && {!_rawSprintIntent};
    if (_enabled && {_contextOk} && {_actualSpeedMS > 0.25} && {_releaseEdge}) then {
        private _releaseGrade = [_previousGrade, _gradeDegrees] select _forwardHeld;
        private _curve = [
            _releaseGrade, _currentCoefficient, _walkCoefficient,
            _parameters param [0, 15, [0]],
            _parameters param [1, 35, [0]],
            _parameters param [2, 0.15, [0]],
            _parameters param [3, 0.18, [0]],
            _parameters param [4, 0.28, [0]],
            _normalRamp,
            _parameters param [6, 0.575, [0]]
        ] call GAIT_fnc_uphillBrakeParameters;
        if ((_curve select 0) > 0 && {(_curve select 1) > 0}) then {
            _severity = _curve select 0;
            _duration = _curve select 1;
            _target = _curve select 2;
            _ramp = _curve select 3;
            _until = _now + _duration;
            _started = true;
        };
    };

    private _active = _until > _now && {_severity > 0};
    // If another legitimate restriction already slowed the unit further,
    // do not let the stored brake target accelerate it again.
    _target = _target min (_currentCoefficient max 0);
    private _nextState = [_nextIntent, _nextSprint, _rememberedGrade, _until, _severity, _target, _ramp, _duration];
    [_nextState, _active, _started, _severity, _target, _ramp, (_until - _now) max 0, _duration, _resumed]
};
