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
    _load * ([_grade, _kit, _momentum, 0.5, 18, 0.03, 0.10, _load, _unloaded]
        call GAIT_fnc_downhillPaceMultiplier)
};

{
    private _mult = [_x, 0, 1] call GAIT_fnc_downhillPaceMultiplier;
    [_mult isEqualTo 1, "flat, uphill and below-start grade give no bonus"] call _assert;
} forEach [90, 35, 1, 0, -0.499, -0.5];
private _mildEntry = [-2, 0, 0] call GAIT_fnc_downhillPaceMultiplier;
[_mildEntry > 1 && {_mildEntry < 1.01}, "mild descent gives a small immediate pace gain"] call _assert;
[([-18, 150, 1, 0.5, 18, 0, 0, 0.72, 1.08] call GAIT_fnc_downhillPaceMultiplier) isEqualTo 1,
    "configured zero bonuses stay zero at all loads"] call _assert;
private _entryOnly = [-6, 150, 0, 0.5, 18, 0.03, 0, 0.72, 1.08] call GAIT_fnc_downhillPaceMultiplier;
[abs (([-6, 150, 1, 0.5, 18, 0.03, 0, 0.72, 1.08] call GAIT_fnc_downhillPaceMultiplier) - _entryOnly) < 0.000001,
    "disabling sustained boost also removes the sustained load recovery"] call _assert;

private _moderateLight = [-18, 0, 1] call _downhillPace;
private _steepLight = [-40, 0, 1] call _downhillPace;
[_moderateLight > 1.08 && {_steepLight > _moderateLight}, "steeper descent adds more pace"] call _assert;
private _maximumLight = [-40, 0, 1, 0.5, 18, 0.35, 0.25, 1.08, 1.08] call GAIT_fnc_downhillPaceMultiplier;
private _maximumLoaded = [-40, 150, 1, 0.5, 18, 0.35, 0.25, 0.72, 1.08] call GAIT_fnc_downhillPaceMultiplier;
[abs (_maximumLight - 1.15) < 0.000001, "descent remains bounded relative to unloaded flat pace"] call _assert;
[abs (_maximumLoaded - 1.42) < 0.000001, "very heavy loads have a bounded increase relative to their own flat pace"] call _assert;
private _customCap = [-60, 0, 1, 0.5, 18, 0.35, 0.25, 1.08, 1.08, 18, 40, 1.08]
    call GAIT_fnc_downhillPaceMultiplier;
[abs (_customCap - 1.08) < 0.000001, "lower configured relative ceiling limits steep descent"] call _assert;

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
    for "_kit" from 0 to 90 step 5 do {
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
[([-18, 90, 1] call _downhillPace) > ([-18, 35, 1] call _downhillPace), "heavier kit can overtake light kit on a sustained descent"] call _assert;
[([-60, 150, 1] call _downhillPace) < _steepLight, "very heavy kit cannot gain unbounded speed to reach the unloaded cap"] call _assert;

private _sprintClipMS = 7.5;
private _runClipMS = 4.5;
private _sprintCeiling = [2, _sprintClipMS, 30] call GAIT_fnc_capDownhillPace;
private _runCeiling = [2, _runClipMS, 18] call GAIT_fnc_capDownhillPace;
[abs ((_sprintCeiling * _sprintClipMS * 3.6) - 30) < 0.00001, "matched sprint clip uses the physical ceiling"] call _assert;
[abs ((_runCeiling * _runClipMS * 3.6) - 18) < 0.00001, "matched jog clip uses its own physical ceiling"] call _assert;
[
    ([0.45, _sprintClipMS, 30] call GAIT_fnc_capDownhillPace) isEqualTo 0.45,
    "physical ceiling does not raise fatigue-limited pace"
] call _assert;
{
    [([1.35, _x, 30] call GAIT_fnc_capDownhillPace) isEqualTo 1.35,
        "missing or implausible clip reference keeps the bounded coefficient target"] call _assert;
} forEach [-1, 0, 0.05, 25, 100];

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
private _flatRamp = [0.05, 0, true, 2, true] call GAIT_fnc_slopeSprintRamp;
private _descentRamp = [0.05, -2, true, 2, true] call GAIT_fnc_slopeSprintRamp;
private _climbRamp = [0.05, 18, false, 2, true] call GAIT_fnc_slopeSprintRamp;
[_descentRamp isEqualTo _flatRamp && {_climbRamp > (2 * _flatRamp)}, "descents use the flat sprint ramp and incline entries decelerate sooner"] call _assert;
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
[_firstStep > 0 && {_firstStep < 0.04}, "start builds bonus gradually"] call _assert;
private _midFirstSecond = [0, 1, 0.05] call GAIT_fnc_stepDownhillMomentum;
for "_i" from 2 to 10 do {
    _midFirstSecond = [_midFirstSecond, 1, 0.05] call GAIT_fnc_stepDownhillMomentum;
};
private _flatHeavy = [0, 150, 0] call _downhillPace;
private _initialHeavy = [-18, 150, 0] call _downhillPace;
private _firstHalfSecondHeavy = [-18, 150, _midFirstSecond] call _downhillPace;
[_initialHeavy / _flatHeavy < 1.07 && {_firstHalfSecondHeavy / _flatHeavy < 1.09},
    "heavy load does not cause a sharp acceleration on entry"] call _assert;
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
