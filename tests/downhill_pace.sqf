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
[([-18, 0, 0] call GAIT_fnc_downhillPaceMultiplier) isEqualTo 1, "no downhill acceleration before momentum exists"] call _assert;
[([-18, 0, 1, 4, 18, 0] call GAIT_fnc_downhillPaceMultiplier) isEqualTo 1, "configured zero bonus stays zero"] call _assert;

private _moderateLight = [-18, 0, 1] call GAIT_fnc_downhillPaceMultiplier;
private _steepLight = [-40, 0, 1] call GAIT_fnc_downhillPaceMultiplier;
[_moderateLight > 1 && {_steepLight > _moderateLight}, "steeper descent adds acceleration instead of tapering it"] call _assert;
[_steepLight <= 1.650001, "downhill acceleration remains bounded"] call _assert;

private _lastSteep = 1;
for "_i" from 0 to 220 do {
    private _grade = -18 - (_i / 10);
    private _mult = [_grade, 100, 1] call GAIT_fnc_downhillPaceMultiplier;
    [_mult >= (_lastSteep - 0.000001), "heavy downhill bonus never falls as grade becomes steeper"] call _assert;
    _lastSteep = _mult;
};

{
    private _grade = _x;
    private _lastMultiplier = 999;
    for "_kit" from 0 to 200 step 5 do {
        private _mult = [_grade, _kit, 1] call GAIT_fnc_downhillPaceMultiplier;
        [_mult <= (_lastMultiplier + 0.000001), "heavier kit cannot create a larger downhill bonus"] call _assert;
        _lastMultiplier = _mult;
    };
} forEach [-18,-28,-35,-40,-60];

private _heavy100 = [-40,100,1] call GAIT_fnc_downhillPaceMultiplier;
private _heavy150 = [-40,150,1] call GAIT_fnc_downhillPaceMultiplier;
[_heavy100 > 1.30, "100 lb kit gains more than 30 percent pace on a full steep descent"] call _assert;
[_heavy150 > 1.25, "150 lb kit retains substantial gravity acceleration"] call _assert;

private _targetLight = [-35,0,1] call GAIT_fnc_downhillGravityTargetKmh;
private _targetHeavy = [-35,150,1] call GAIT_fnc_downhillGravityTargetKmh;
[abs (_targetLight - 34) < 0.001, "steep calibrated light target reaches 34 km/h"] call _assert;
[abs (_targetHeavy - 32) < 0.001, "steep calibrated very-heavy target remains above 30 km/h"] call _assert;
[([-35,150,0] call GAIT_fnc_downhillGravityTargetKmh) isEqualTo 0, "physical downhill target requires built momentum"] call _assert;
private _halfTarget = [-35,100,0.5] call GAIT_fnc_downhillGravityTargetKmh;
[_halfTarget > 24 && {_halfTarget < 34}, "physical downhill target rises with momentum"] call _assert;
private _gradeTargetA = [-15,100,1] call GAIT_fnc_downhillGravityTargetKmh;
private _gradeTargetB = [-25,100,1] call GAIT_fnc_downhillGravityTargetKmh;
[_gradeTargetB > _gradeTargetA, "physical downhill target rises with steepness"] call _assert;

// Uphill slowdown is now temporal: shallow hills bleed speed gradually while
// steep hills converge faster to the same steady grade curve.
private _uphillShallow = 0;
private _uphillSteep = 0;
for "_i" from 1 to 20 do {
    _uphillShallow = [_uphillShallow, 10, true, 0.05, 5, 35]
        call GAIT_fnc_stepUphillPaceExposure;
    _uphillSteep = [_uphillSteep, 35, true, 0.05, 5, 35]
        call GAIT_fnc_stepUphillPaceExposure;
};
[_uphillShallow > 0 && {_uphillShallow < 1}, "shallow uphill slowdown builds gradually"] call _assert;
[_uphillSteep > _uphillShallow && {_uphillSteep < 1}, "steeper uphill builds slowdown faster"] call _assert;
private _fullShallow = [10,5,35,0.40] call GAIT_fnc_uphillPaceMultiplier;
private _partialShallow = [_fullShallow,_uphillShallow] call GAIT_fnc_applyUphillPaceExposure;
[_partialShallow < 1 && {_partialShallow > _fullShallow}, "temporal uphill multiplier starts between flat and full penalty"] call _assert;
private _recover = _uphillSteep;
for "_i" from 1 to 20 do {
    _recover = [_recover, 0, false, 0.05, 5, 35] call GAIT_fnc_stepUphillPaceExposure;
};
[_recover < _uphillSteep && {_recover > 0}, "flattening recovers uphill slowdown smoothly"] call _assert;
private _uphillFrames = [];
{
    private _dt = _x;
    private _exposure = 0;
    for "_i" from 1 to round (1 / _dt) do {
        _exposure = [_exposure, 22, true, _dt, 5, 35] call GAIT_fnc_stepUphillPaceExposure;
    };
    _uphillFrames pushBack _exposure;
} forEach [0.01,0.02,0.05,0.1,0.2];
{[abs (_x - (_uphillFrames select 0)) < 0.00001, "uphill exposure is update-rate independent"] call _assert;} forEach _uphillFrames;

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
diag_log format ["GAIT TEST PASS: exponential uphill slowdown, gravity-driven downhill acceleration, heavy 30+ km/h target and time-based momentum (%1 checks)", _checks];
