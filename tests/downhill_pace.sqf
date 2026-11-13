// Run after fn_downhillPace.sqf and fn_slopePaceModel.sqf in SQF-VM or Arma.
private _checks = 0;
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {throw format ["FAIL: %1", _label];};
    _checks = _checks + 1;
};

private _downhillPace = {
    params ["_grade", "_kit", "_momentum"];
    private _load = [_kit] call GAIT_fnc_continuousLoadMultiplier;
    private _unloaded = [0] call GAIT_fnc_continuousLoadMultiplier;
    _load * ([_grade, _kit, _momentum, 0.5, 18, 0.10, 0.18, _load, _unloaded]
        call GAIT_fnc_downhillPaceMultiplier)
};

{
    private _mult = [_x, 0, 1] call GAIT_fnc_downhillPaceMultiplier;
    [_mult isEqualTo 1, "flat, uphill and below-start grade give no bonus"] call _assert;
} forEach [90, 35, 1, 0, -0.499, -0.5];
[([-2, 0, 0] call GAIT_fnc_downhillPaceMultiplier) > 1.01, "mild decline gives an immediate pace gain"] call _assert;
[([-18, 150, 1, 0.5, 18, 0, 0, 0.72, 1.08] call GAIT_fnc_downhillPaceMultiplier) isEqualTo 1,
    "configured zero bonuses stay zero at all loads"] call _assert;
private _entryOnly = [-6, 150, 0, 0.5, 18, 0.10, 0, 0.72, 1.08] call GAIT_fnc_downhillPaceMultiplier;
[abs (([-6, 150, 1, 0.5, 18, 0.10, 0, 0.72, 1.08] call GAIT_fnc_downhillPaceMultiplier) - _entryOnly) < 0.000001,
    "disabling sustained boost also removes the sustained load recovery"] call _assert;

private _moderateLight = [-18, 0, 1] call _downhillPace;
private _steepLight = [-40, 0, 1] call _downhillPace;
[_moderateLight > 1.08 && {_steepLight > _moderateLight}, "steeper descent adds more pace"] call _assert;
private _maximumLoaded = [-40, 150, 1, 0.5, 18, 0.35, 0.25, 0.72, 1.08] call GAIT_fnc_downhillPaceMultiplier;
[_maximumLoaded * 0.72 <= (1.08 * 1.65) + 0.000001, "loaded acceleration remains bounded relative to unloaded flat pace"] call _assert;

private _lastSteep = 0;
for "_i" from 0 to 400 do {
    private _grade = -(_i / 10);
    private _pace = [_grade, 100, 1] call _downhillPace;
    [_pace >= (_lastSteep - 0.000001), "heavy downhill pace never falls as grade becomes steeper"] call _assert;
    _lastSteep = _pace;
};

{
    private _grade = _x;
    private _lastGain = 0;
    for "_kit" from 0 to 200 step 5 do {
        private _gain = ([_grade, _kit, 1] call _downhillPace) - ([0, _kit, 0] call _downhillPace);
        [_gain >= (_lastGain - 0.000001), "heavier kit carries more speed into sustained descents"] call _assert;
        _lastGain = _gain;
    };
} forEach [-2,-4,-6,-18,-28,-35,-40,-60];

private _mildHeavyEntry = [-2, 150, 0] call _downhillPace;
private _mildHeavyMid = [-2, 150, 0.5] call _downhillPace;
private _mildHeavySustained = [-2, 150, 1] call _downhillPace;
[_mildHeavyEntry > ([0, 150, 0] call _downhillPace), "heavy kit gets immediate pull on mild downhill"] call _assert;
[_mildHeavyMid > _mildHeavyEntry && {_mildHeavySustained > _mildHeavyMid}, "mild downhill gradually gains pace"] call _assert;
[([-6, 150, 1] call _downhillPace) > ([-6, 35, 1] call _downhillPace), "heavy kit can overtake light kit on a sustained downhill"] call _assert;
[([-40, 150, 1] call _downhillPace) > _steepLight, "heavy kit has greater top pace on a steep descent"] call _assert;

private _targetLight = [-35,0,1] call GAIT_fnc_downhillGravityTargetKmh;
private _targetHeavy = [-35,150,1] call GAIT_fnc_downhillGravityTargetKmh;
[abs (_targetLight - 34) < 0.001, "steep calibrated light target reaches 34 km/h"] call _assert;
[abs (_targetHeavy - 37.626667) < 0.001, "steep calibrated heavy target exceeds light target"] call _assert;
[([-35,150,0] call GAIT_fnc_downhillGravityTargetKmh) isEqualTo 0, "physical downhill target requires built momentum"] call _assert;
[([-35,150,1,8,35,0] call GAIT_fnc_downhillGravityTargetKmh) isEqualTo 0, "physical downhill target honors zero sustained boost"] call _assert;
private _halfTarget = [-35,100,0.5] call GAIT_fnc_downhillGravityTargetKmh;
[_halfTarget > 0 && {_halfTarget < ([-35,100,1] call GAIT_fnc_downhillGravityTargetKmh)}, "physical downhill target rises with momentum"] call _assert;
[([-8.01,150,1] call GAIT_fnc_downhillGravityTargetKmh) < 1, "calibrated target rises continuously from its onset"] call _assert;
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
private _quickUphillEntry = [0, 18, true, 0.20, 2, 35] call GAIT_fnc_stepUphillPaceExposure;
[_quickUphillEntry > 0.45 && {_quickUphillEntry < 1}, "uphill sprint takes on a substantial penalty in its first 200 ms"] call _assert;
private _lightClimb = [25, 2, 35, 0.40, 35] call GAIT_fnc_uphillSprintPaceMultiplier;
private _heavyClimb = [25, 2, 35, 0.40, 150] call GAIT_fnc_uphillSprintPaceMultiplier;
[_heavyClimb < _lightClimb && {_lightClimb < 1}, "actual carried mass amplifies uphill slowdown"] call _assert;
private _flatRamp = [0.05, 0, true, 2, 0.5, true, true] call GAIT_fnc_slopeSprintRamp;
private _descentRamp = [0.05, -2, true, 2, 0.5, true, true] call GAIT_fnc_slopeSprintRamp;
private _climbRamp = [0.05, 18, false, 2, 0.5, true, true] call GAIT_fnc_slopeSprintRamp;
[_descentRamp > _flatRamp && {_climbRamp > (2 * _flatRamp)}, "mild descents accelerate earlier and incline entries decelerate sooner"] call _assert;
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
diag_log format ["GAIT TEST PASS: responsive mass-dependent uphill pace, initial downhill pull, sustained heavy-kit descent and time-based momentum (%1 checks)", _checks];
