// Run after fn_downhillPace.sqf and fn_slopePaceModel.sqf in SQF-VM or Arma.
private _checks = 0;
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {throw format ["FAIL: %1", _label];};
    _checks = _checks + 1;
};

{
    private _mult = [_x, 0, 1] call GAIT_fnc_downhillPaceMultiplier;
    [_mult isEqualTo 1, "flat, uphill and below-start grade give no bonus"] call _assert;
} forEach [90, 35, 1, 0, -3.999, -4];
[([-18, 0, 0] call GAIT_fnc_downhillPaceMultiplier) isEqualTo 1, "no launch bonus before momentum exists"] call _assert;
[([-18, 0, 1, 4, 18, 0] call GAIT_fnc_downhillPaceMultiplier) isEqualTo 1, "configured zero bonus stays zero"] call _assert;
private _peak = [-18, 0, 1] call GAIT_fnc_downhillPaceMultiplier;
[abs (_peak - 1.18) < 0.00001, "configured cap reached with sustained unloaded run"] call _assert;
private _last = 1;
for "_i" from 0 to 140 do {
    private _mult = [-4 - (_i / 10), 35, 1] call GAIT_fnc_downhillPaceMultiplier;
    [_mult >= (_last - 0.000001), "bonus rises continuously up to peak angle"] call _assert;
    _last = _mult;
};
private _atStart = [-4.01, 35, 1] call GAIT_fnc_downhillPaceMultiplier;
[_atStart - 1 < 0.00001, "smooth angle onset avoids a threshold jump"] call _assert;
private _nearPeak = [-17.99, 0, 1] call GAIT_fnc_downhillPaceMultiplier;
[abs (_peak - _nearPeak) < 0.00001, "angle curve joins its plateau smoothly"] call _assert;
private _nearSteep = [-35.01, 0, 1] call GAIT_fnc_downhillPaceMultiplier;
[abs (_peak - _nearSteep) < 0.00001, "extreme-slope control enters smoothly"] call _assert;

{
    private _grade = _x;
    private _lastMultiplier = 999;
    private _lastPace = 999;
    for "_kit" from 0 to 200 step 5 do {
        private _mult = [_grade, _kit, 1] call GAIT_fnc_downhillPaceMultiplier;
        private _load = [_kit] call GAIT_fnc_continuousLoadMultiplier;
        private _paces = [0.8, 1.1, 1, _mult, _load, 1.2] call GAIT_fnc_slopePaceModel;
        [_mult <= (_lastMultiplier + 0.000001), "heavier kit cannot increase downhill bonus"] call _assert;
        [(_paces select 1) <= (_lastPace + 0.000001), "combined slope/load sprint target decreases with kit"] call _assert;
        [(_paces select 1) >= ((_paces select 0) * 1.2 - 0.000001), "sprint/walk floor survives downhill integration"] call _assert;
        _lastMultiplier = _mult;
        _lastPace = _paces select 1;
    };
} forEach [-5, -18, -32, -50, -85];

{
    private _mult = [_x, 0, 1, 4, 18, 99] call GAIT_fnc_downhillPaceMultiplier;
    [_mult >= 1 && {_mult <= 1.350001}, "extreme angles/configuration cannot create runaway boost"] call _assert;
} forEach [-10000, -90, -75, -45, -32, -18, -4, 0, 10000];
private _extreme = [-75, 0, 1] call GAIT_fnc_downhillPaceMultiplier;
[abs (_extreme - 1.045) < 0.00001, "extreme slopes retain only a quarter of the bonus"] call _assert;
private _malformed = [-85, -50, 99, 90, -10, -1, -1, -10, -20] call GAIT_fnc_downhillPaceMultiplier;
[_malformed isEqualTo 1, "malformed numeric configuration remains bounded"] call _assert;
private _oldMax = [-18, 0, 1, 4, 18, 0.06] call GAIT_fnc_downhillPaceMultiplier;
[abs (_oldMax - 1.06) < 0.00001, "existing explicit 6 percent setting is honored"] call _assert;

// Light/medium pace is exact; the requested heavy change is deliberately
// limited to the downhill bonus before the original total-load penalty.
{
    private _oldPace = 1 + (0.18 / (1 + (_x / 75)));
    private _newPace = [-18, _x, 1] call GAIT_fnc_downhillPaceMultiplier;
    [abs (_newPace - _oldPace) < 0.000001, "light and medium downhill target remains exact"] call _assert;
} forEach [0, 10, 20, 35, 45, 55];
{
    private _oldPace = 1 + (0.18 / (1 + (_x / 75)));
    private _newPace = [-18, _x, 1] call GAIT_fnc_downhillPaceMultiplier;
    private _gain = (_newPace / _oldPace) - 1;
    [_gain > 0.019 && {_gain < 0.034}, "100 to 150 lb heavy downhill target gains about 2 to 3.3 percent"] call _assert;
    [([-18, _x, 0] call GAIT_fnc_downhillPaceMultiplier) isEqualTo 1, "heavy gain requires built momentum"] call _assert;
    [([-18, _x, 1, 4, 18, 0] call GAIT_fnc_downhillPaceMultiplier) isEqualTo 1, "heavy gain respects disabled bonus"] call _assert;
} forEach [100, 125, 150];
private _atMediumEnd = [-18, 55, 1] call GAIT_fnc_downhillPaceMultiplier;
private _justHeavy = [-18, 55.001, 1] call GAIT_fnc_downhillPaceMultiplier;
[_justHeavy < _atMediumEnd && {abs (_atMediumEnd - _justHeavy) < 0.00001}, "heavy bonus joins without a pace jump"] call _assert;
private _peakHeavy = [-18, 100, 1] call GAIT_fnc_downhillPaceMultiplier;
private _steepHeavy = [-75, 100, 1] call GAIT_fnc_downhillPaceMultiplier;
[abs ((_peakHeavy - 1) * 0.25 - (_steepHeavy - 1)) < 0.000001, "existing steep-descent control scales the heavy gain"] call _assert;

private _riseResults = [];
private _fallResults = [];
{
    private _dt = _x;
    private _rise = 0;
    private _fall = 1;
    for "_i" from 1 to round (2 / _dt) do {
        _rise = [_rise, 1, _dt] call GAIT_fnc_stepDownhillMomentum;
        _fall = [_fall, 0, _dt] call GAIT_fnc_stepDownhillMomentum;
    };
    _riseResults pushBack _rise;
    _fallResults pushBack _fall;
} forEach [0.01, 0.02, 0.05, 0.1, 0.2];
{[abs (_x - (_riseResults select 0)) < 0.00001, "momentum rise is independent of regular update interval"] call _assert;} forEach _riseResults;
{[abs (_x - (_fallResults select 0)) < 0.00001, "momentum decay is independent of regular update interval"] call _assert;} forEach _fallResults;
private _firstStep = [0, 1, 0.05] call GAIT_fnc_stepDownhillMomentum;
[_firstStep > 0 && {_firstStep < 0.10}, "start builds bonus gradually"] call _assert;
private _releaseStep = [1, 0, 0.05] call GAIT_fnc_stepDownhillMomentum;
[_releaseStep > 0.90 && {_releaseStep < 1}, "brief release does not erase downhill momentum"] call _assert;
private _resumeStep = [_releaseStep, 1, 0.05] call GAIT_fnc_stepDownhillMomentum;
[_resumeStep > _releaseStep && {_resumeStep <= 1}, "resuming sprint continues preserved momentum"] call _assert;
private _stall = [0, 1, 10] call GAIT_fnc_stepDownhillMomentum;
private _capped = [0, 1, 0.20] call GAIT_fnc_stepDownhillMomentum;
[abs (_stall - _capped) < 0.00001, "scheduler stall does not skip acceleration"] call _assert;
[([0.4, 1, 0] call GAIT_fnc_stepDownhillMomentum) isEqualTo 0.4, "zero delta cannot change momentum"] call _assert;
[([0.4, 1, -1] call GAIT_fnc_stepDownhillMomentum) isEqualTo 0.4, "negative delta cannot change momentum"] call _assert;
[([0.4, 1, 0.05, 0] call GAIT_fnc_stepDownhillMomentum) isEqualTo 1, "zero rise duration explicitly disables rise easing"] call _assert;
diag_log format ["GAIT TEST PASS: downhill pace, load order, slope bounds and time-based momentum (%1 checks)", _checks];
