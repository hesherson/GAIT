// Run after fn_downhillPace.sqf and fn_slopePaceModel.sqf in SQF-VM or Arma.
private _checks = 0;
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {throw format ["FAIL: %1", _label];};
    _checks = _checks + 1;
};

private _downhillPace = {
    params ["_grade", "_kit", "_momentum"];
    [_grade, _kit / 150, _momentum] call GAIT_fnc_downhillPaceMultiplier
};

{
    _x params ["_args","_expected"];
    [(_args call GAIT_fnc_shufflePose) == _expected,"shuffle follows grade and keeps its lead across small fluctuations"] call _assert;
} forEach [
    [[23,-0.25,""],"gait_shuffleleft"],
    [[29,0.25,""],"gait_shufflerightmedium"],
    [[26,-0.02,"gait_shufflerightmedium"],"gait_shufflerightmedium"],
    [[36,0.22,"gait_shuffleleftmedium"],"gait_shufflerightsteep"],
    [[33,-0.05,"gait_shufflerightsteep"],"gait_shufflerightsteep"],
    [[24,-0.3,"gait_shufflerightsteep"],"gait_shuffleleft"]
];

private _cross = [0.12,0,0,0.05] call GAIT_fnc_turnDownhillBonus;
private _climb = [0.12,0,8,0.05] call GAIT_fnc_turnDownhillBonus;
[_climb > 0 && {_climb < _cross} && {_cross < 0.12}, "cross-slope fades, uphill sheds speed faster"] call _assert;
private _alternating = 0;
for "_i" from 1 to 100 do {
    _alternating = [_alternating, [0,0.06] select (_i mod 2), 0, 0.05] call GAIT_fnc_turnDownhillBonus;
    [_alternating <= 0.06, "turns cannot stack downhill speed"] call _assert;
};

private _lightAngles = [0.5, 18];
private _heavyAngles = _lightAngles call GAIT_fnc_downhillRunAngles;
[abs ((_heavyAngles select 0) - 0.15) < 0.000001 && {([-0.3, 0, 0] call _downhillPace) isEqualTo 1} &&
    {([-0.3, 115, 0] call _downhillPace) > 1},
    "heavy kits start gaining pace sooner while light kits use the selected onset"] call _assert;
private _lightMomentum = ([-0.3] + _lightAngles) call GAIT_fnc_downhillMomentumTarget;
private _heavyMomentum = ([-0.3] + _heavyAngles) call GAIT_fnc_downhillMomentumTarget;
[_lightMomentum isEqualTo 0 && {_heavyMomentum > 0}, "the live momentum curve can build on a shallower descent with heavy gear"] call _assert;
[ (([-5] + _heavyAngles) call GAIT_fnc_downhillMomentumTarget) >
    (([-5] + _lightAngles) call GAIT_fnc_downhillMomentumTarget),
    "heavy kits build a larger share of momentum on a gentle descent"] call _assert;

private _walkFlat = [0, 0.5, 18] call GAIT_fnc_downhillWalkMultiplier;
private _walkGentle = [-5, 0.5, 18] call GAIT_fnc_downhillWalkMultiplier;
private _walkModerate = [-10, 0.5, 18] call GAIT_fnc_downhillWalkMultiplier;
private _walkSteep = [-30, 0.5, 18] call GAIT_fnc_downhillWalkMultiplier;
[_walkFlat isEqualTo 1 && {([12, 0.5, 18] call GAIT_fnc_downhillWalkMultiplier) isEqualTo 1},
    "walking bonus applies only to the downhill direction"] call _assert;
[_walkGentle > 1 && {_walkGentle < _walkModerate} && {_walkModerate < _walkSteep} &&
    {abs (_walkSteep - 1.10) < 0.000001}, "walk pace rises gradually to a ten percent cap"] call _assert;

{
    private _clip = _x;
    private _flat = [0, _clip] call GAIT_fnc_casualtyTerrainMultiplier;
    private _shallow = [-5, _clip] call GAIT_fnc_casualtyTerrainMultiplier;
    private _downhill = [-18, _clip] call GAIT_fnc_casualtyTerrainMultiplier;
    private _climb = [25, _clip] call GAIT_fnc_casualtyTerrainMultiplier;
    [_flat isEqualTo 1 && {_shallow > _flat} && {_downhill > _shallow} && {_downhill <= 1.10} &&
        {_climb < _flat}, "casualty movement follows directional grade with a bounded downhill boost"] call _assert;
} forEach ["carryWalk", "carryRun", "drag"];
[([-18, "drag"] call GAIT_fnc_casualtyTerrainMultiplier) < ([-18, "carryWalk"] call GAIT_fnc_casualtyTerrainMultiplier) &&
    {([-18, "carryWalk"] call GAIT_fnc_casualtyTerrainMultiplier) < ([-18, "carryRun"] call GAIT_fnc_casualtyTerrainMultiplier)},
    "dragging has less downhill assistance than walking or running with a patient"] call _assert;

{
    private _mult = [_x, 0, 1] call GAIT_fnc_downhillPaceMultiplier;
    [_mult isEqualTo 1, "flat, uphill and below-start grade give no bonus"] call _assert;
} forEach [90, 35, 1, 0, -0.499, -0.5];
private _mildEntry = [-2, 0, 0] call GAIT_fnc_downhillPaceMultiplier;
[_mildEntry > 1 && {_mildEntry < 1.01}, "mild descent gives a small immediate pace gain"] call _assert;
[([-18, 1, 1, 0.5, 18, 0, 0] call GAIT_fnc_downhillPaceMultiplier) isEqualTo 1,
    "configured zero bonuses stay zero at all loads"] call _assert;
private _entryOnly = [-6, 1, 0, 0.5, 18, 0.03, 0] call GAIT_fnc_downhillPaceMultiplier;
[abs (([-6, 1, 1, 0.5, 18, 0.03, 0] call GAIT_fnc_downhillPaceMultiplier) - _entryOnly) < 0.000001,
    "disabling sustained boost prevents it for every kit"] call _assert;

private _moderateLight = [-18, 0, 1] call _downhillPace;
private _steepLight = [-40, 0, 1] call _downhillPace;
[_moderateLight > 1.08 && {_steepLight > _moderateLight}, "steeper descent adds more pace"] call _assert;
private _maximumLight = [-40, 0, 1, 0.5, 18, 0.35, 0.25] call GAIT_fnc_downhillPaceMultiplier;
private _maximumLoaded = [-40, 1, 1, 0.5, 18, 0.35, 0.25] call GAIT_fnc_downhillPaceMultiplier;
[abs (_maximumLight - 1.18) < 0.000001 && {abs (_maximumLoaded - 1.18) < 0.000001},
    "downhill gravity stays within eighteen percent of each kit's flat target"] call _assert;
private _customCap = [-60, 0, 1, 0.5, 18, 0.35, 0.25, 1.08]
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
        private _gain = ([_grade, _kit, 1] call _downhillPace) / ([0, _kit, 0] call _downhillPace);
        [_gain >= (_lastGain - 0.000001), "heavier kit gains a larger share of its flat pace on sustained descents"] call _assert;
        _lastGain = _gain;
    };
} forEach [-2,-4,-6,-18,-28,-35,-40,-60];

private _mildHeavyEntry = [-2, 150, 0] call _downhillPace;
private _mildHeavyMid = [-2, 150, 0.5] call _downhillPace;
private _mildHeavySustained = [-2, 150, 1] call _downhillPace;
[_mildHeavyEntry > ([0, 150, 0] call _downhillPace), "heavy kit gets immediate pull on mild downhill"] call _assert;
[_mildHeavyMid > _mildHeavyEntry && {_mildHeavySustained > _mildHeavyMid}, "mild downhill gradually gains pace"] call _assert;
{
    private _movementSeconds = _x;
    {
        private _grade = _x;
        private _lightBonus = [_movementSeconds, _grade] call GAIT_fnc_lightLoadPaceBonus;
        private _lastPace = 10;
        private _lastCappedPace = 10;
        for "_kit" from 0 to 150 step 5 do {
            private _scale = 1 + ((1 - (_kit / 150)) * _lightBonus);
            private _gravity = [_grade, _kit, _movementSeconds / 8] call _downhillPace;
            private _pace = _scale * _gravity;
            [_pace < _lastPace, "a lighter sprint target stays ahead at equal reserve and travel time"] call _assert;
            private _cappedPace = [_pace, 10, 30, 1 - (0.025 * _kit / 150)] call GAIT_fnc_capDownhillPace;
            [_cappedPace < _lastCappedPace && {_cappedPace <= (30 / 36)},
                "a calibrated ceiling preserves the lighter kit's small advantage"] call _assert;
            _lastPace = _pace;
            _lastCappedPace = _cappedPace;
        };
    } forEach [20, 0, -0.2, -0.5, -2, -5, -12, -18, -28, -45];
} forEach [0, 4, 8];

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
    [([_x] call GAIT_fnc_downhillMomentumTarget) isEqualTo 0, "flat, uphill and sub-threshold grades earn no downhill momentum"] call _assert;
} forEach [35, 1, 0, -0.49, -0.5];
private _shallowTarget = [-2] call GAIT_fnc_downhillMomentumTarget;
private _moderateTarget = [-6] call GAIT_fnc_downhillMomentumTarget;
[_shallowTarget > 0.4 && {_shallowTarget < _moderateTarget} && {_moderateTarget < 0.9},
    "mild descents keep immediate pull and earn less sustained momentum"] call _assert;
[([-10.2] call GAIT_fnc_downhillMomentumTarget) isEqualTo 1 && {([-30] call GAIT_fnc_downhillMomentumTarget) isEqualTo 1},
    "a decent descent can earn full momentum without requiring a steep slope"] call _assert;
[([-4, 7, 3] call GAIT_fnc_downhillMomentumTarget) isEqualTo 0 && {([-8, 7, 3] call GAIT_fnc_downhillMomentumTarget) isEqualTo 1},
    "custom onset with an invalid reference grade keeps a usable range"] call _assert;
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
private _oneSecondPace = 0;
private _fourSecondPace = 0;
private _lightAfterSixSeconds = 0;
private _momentum = 0;
private _flatMedium = [0, 90, 0] call _downhillPace;
for "_i" from 1 to 160 do {
    private _grade = [-11, -10, -12, -10.5] select (_i mod 4);
    private _target = [_grade] call GAIT_fnc_downhillMomentumTarget;
    _momentum = [_momentum, _target, 0.05] call GAIT_fnc_stepDownhillMomentum;
    // Sample the actual sprint bound with an unchanged grade to isolate inertia.
    private _mediumPace = (([-18, 90, _momentum] call _downhillPace) / _flatMedium) min 1.18;
    if (_i isEqualTo 20) then {_oneSecondPace = _mediumPace;};
    if (_i isEqualTo 80) then {_fourSecondPace = _mediumPace;};
    if (_i isEqualTo 120) then {_lightAfterSixSeconds = [-18, 0, _momentum] call _downhillPace;};
};
private _eightSecondPace = (([-18, 90, _momentum] call _downhillPace) / _flatMedium) min 1.18;
private _lightAfterEightSeconds = [-18, 0, _momentum] call _downhillPace;
[_oneSecondPace > 1.03 && {_oneSecondPace < 1.06}, "a 90 lb pack still gets a restrained opening second"] call _assert;
[_fourSecondPace > (_oneSecondPace + 0.065) && {_eightSecondPace > 1.16} && {_eightSecondPace <= 1.18},
    "heavy sprint builds more speed on the same descent then settles inside the cap"] call _assert;
[_lightAfterEightSeconds > (_lightAfterSixSeconds + 0.01), "an unloaded sprint can still earn pace after six seconds"] call _assert;
[_momentum > 0.97, "nearby grade changes do not restart the descent timer"] call _assert;
private _previousMomentum = _momentum;
for "_i" from 1 to 30 do {
    _momentum = [_momentum, _shallowTarget, 0.05] call GAIT_fnc_stepDownhillMomentum;
    [_momentum < _previousMomentum, "shallow grade gradually sheds excess earned momentum"] call _assert;
    _previousMomentum = _momentum;
};
[_momentum > _shallowTarget && {_momentum < (_shallowTarget + 0.035)}, "shallow grade returns close to its own momentum ceiling"] call _assert;
for "_i" from 1 to 30 do {
    _momentum = [_momentum, ([4] call GAIT_fnc_downhillMomentumTarget), 0.05] call GAIT_fnc_stepDownhillMomentum;
};
[_momentum < 0.03, "an uphill interruption sheds the previous descent's momentum"] call _assert;
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
diag_log format ["GAIT TEST PASS: responsive uphill pace, initial downhill pull, sustained heavy-kit descent and time-based momentum (%1 checks)", _checks];
