// Concatenate after fn_slopePaceModel.sqf and fn_locomotionPace.sqf in SQF-VM.
// The numbers below are SYNTHETIC test fixtures, never shipped calibration.
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {throw format ["FAIL: %1", _label];};
};
private _near = {
    params ["_actual", "_expected", "_label"];
    [abs (_actual - _expected) < 0.00001, _label] call _assert;
};
private _profiles = [["SrasWrfl", "Df", 1.5, 3, 6]];
private _roundTrips = 0;
{
    private _reference = _x;
    {
        private _ms = [_x, _reference] call GAIT_fnc_paceCoefficientToMS;
        private _back = [_ms, _reference] call GAIT_fnc_paceMSToCoefficient;
        [_back, _x, "coefficient/physical conversion preserves tuning"] call _near;
        _roundTrips = _roundTrips + 1;
    } forEach [0, 0.01, 0.15, 0.3, 0.59, 0.86, 1, 1.28, 2, 3.5];
} forEach [0.05, 0.25, 1.5, 3, 6, 25];

private _fallbackChecks = 0;
{
    private _modelArgs = _x;
    private _legacy = _modelArgs call GAIT_fnc_slopePaceModel;
    {
        private _result = (_modelArgs + [_x, "SrasWrfl", "Df", "sprint"])
            call GAIT_fnc_locomotionPaceTargets;
        [(_result select [0, 2]) isEqualTo _legacy, "missing/invalid calibration preserves exact old targets"] call _assert;
        [(_result select [2, 3]) isEqualTo [-1, -1, false], "unknown calibration never reports metres per second"] call _assert;
        _fallbackChecks = _fallbackChecks + 1;
    } forEach [
        [], [false], [["SrasWrfl"]], [["SrasWrfl", "Df"]],
        [["SrasWrfl", "Df", 1.5, 3, 0]],
        [["SrasWrfl", "Df", 1.5, 3, -1]],
        [["SrasWrfl", "Df", 0, 3, 6]],
        [["SrasWrfl", "Df", 1.5, "bad", 6]],
        [["SrasWrfl", "Df", 1.5, 3, 25.01]],
        [["SrasWrfl", "Df", 1.5, 3, 6, 7]],
        [["SlowWrfl", "Df", 1.5, 3, 6]],
        [["SrasWrfl", "Dfl", 1.5, 3, 6]],
        [["SrasWrfl", "Df", 1.5, 3, 6], ["sraswrfl", "df", 1.6, 3, 6]]
    ];
} forEach [[0.86, 1.28, 1, 1, 1, 1.4], [0.86, 0.89, 0.35, 0.1, 0.7, 1.2], [0.3, 0.01, 0.001, 0.001, 0.001, 1.01]];

// Different clips: a legacy coefficient floor is not also applied on top of
// the physical floor. Here sprint's faster reference meets the ratio itself.
private _free = [0.8, 0.5, 1, 1, 0.75, 1.2, _profiles, "SrasWrfl", "Df", "sprint"] call GAIT_fnc_locomotionPaceTargets;
[_free select 0, 0.6, "walk coefficient retains original slope/load tuning"] call _near;
[_free select 1, 0.375, "no extra coefficient floor after physical conversion"] call _near;
[_free select 2, 0.9, "physical walking target"] call _near;
[_free select 3, 2.25, "physical sprint target"] call _near;
[_free select 4, "valid profile is calibrated"] call _assert;

// The floor compares the walk and sprint speeds under identical grade/load.
private _floor = [0.8, 0.01, 0.5, 0.2, 0.75, 1.4, _profiles, "sraswrfl", "df", "SPRINT"] call GAIT_fnc_locomotionPaceTargets;
[_floor select 2, 0.45, "walk speed includes walking grade and load"] call _near;
[_floor select 3, 0.63, "physical floor uses common units"] call _near;
[_floor select 1, 0.105, "floor converts through selected sprint reference"] call _near;

private _slow = [0.001, 0.01, 0.001, 0.001, 0.001, 1.2,
    [["SrasWrfl", "Df", 0.05, 0.1, 0.2]], "SrasWrfl", "Df", "sprint"]
    call GAIT_fnc_locomotionPaceTargets;
[abs ((_slow select 0) - 0.00000001) < 0.000000000001, "input clamp remains in coefficient units at tiny targets"] call _assert;
[abs ((_slow select 2) - 0.0000000005) < 0.000000000001, "tiny measured references do not acquire physical input floor"] call _assert;
private _extreme = [1, 1, 1, 1, 1, 1.2,
    [["SrasWrfl", "Df", 25, 3, 0.05]], "SrasWrfl", "Df", "sprint"]
    call GAIT_fnc_locomotionPaceTargets;
[(_extreme select [2, 3]) isEqualTo [-1, -1, false], "implausible calibrated output cannot reach the controller"] call _assert;
[(_extreme select [0, 2]) isEqualTo ([1, 1, 1, 1, 1, 1.2] call GAIT_fnc_slopePaceModel), "out-of-range conversion retains exact legacy fallback"] call _assert;

// Ordinary slope jog uses a physical floor only 6% above the corresponding
// walk target when walk/jog references are available.
private _slopeJogFloor = [0.8, 0.01, 0.5, 0.5, 0.75, 1.06,
    _profiles, "SrasWrfl", "Df", "jog"] call GAIT_fnc_locomotionPaceTargets;
[(_slopeJogFloor select 4), "slope jog fixture resolves calibrated walk/jog references"] call _assert;
[(_slopeJogFloor select 3) / (_slopeJogFloor select 2), 1.06,
    "ordinary slope jog stays only six percent above forced-walk physical pace"] call _near;

private _partial = [["SrasWrfl", "Dr", 1, 2, -1]];
[[ _partial, "SrasWrfl", "Dr", "jog"] call GAIT_fnc_locomotionPaceReferences isEqualTo [1, 2], "directional jog needs walk/jog measurements only"] call _assert;
[[ _partial, "SrasWrfl", "Dr", "sprint"] call GAIT_fnc_locomotionPaceReferences isEqualTo [], "missing sprint reference cannot substitute jog"] call _assert;
private _lowPistolProfile = [["SlowWpst", "Df", 1.4, 2.8, 5.6]];
[[ _lowPistolProfile, "SlowWpst", "Df", "sprint"] call GAIT_fnc_locomotionPaceReferences isEqualTo [1.4, 5.6],
    "lowered pistol is a first-class measured locomotion family"] call _assert;
[[ _profiles, "SrasWrfl", "Dnon", "sprint"] call GAIT_fnc_locomotionPaceReferences isEqualTo [], "idle is not a measured movement direction"] call _assert;
[[ _profiles, "SrasWrfl", "Df", "unknown"] call GAIT_fnc_locomotionPaceReferences isEqualTo [], "unknown gait cannot select another reference"] call _assert;

{
    [[_x] call GAIT_fnc_paceReferenceValid isEqualTo false, "invalid reference rejected"] call _assert;
    [[1, _x] call GAIT_fnc_paceCoefficientToMS isEqualTo -1, "invalid reference cannot produce speed"] call _assert;
    [[1, _x] call GAIT_fnc_paceMSToCoefficient isEqualTo -1, "invalid reference cannot produce coefficient"] call _assert;
} forEach [-1, 0, 0.049, 25.01, "1", true, []];
[[0, 6] call GAIT_fnc_paceCoefficientToMS isEqualTo 0, "zero coefficient remains zero; no launch floor"] call _assert;
[[-0.1, 6] call GAIT_fnc_paceCoefficientToMS isEqualTo -1, "negative coefficient is unknown"] call _assert;
[["1", 6] call GAIT_fnc_paceMSToCoefficient isEqualTo -1, "nonnumeric speed is unknown"] call _assert;
// The second half of reserve tapers toward 65–75% of the kit's unboosted run.
private _fullSprint = 1.28;
private _lightFloor = [_fullSprint, _fullSprint, 0, 0, 0, 0.70, true] call GAIT_fnc_sprintReservePace;
private _heavyFloor = [_fullSprint, _fullSprint, 0, 100, 0, 0.70, true] call GAIT_fnc_sprintReservePace;
[_lightFloor, _fullSprint * 0.75, "empty unloaded sprint retains 75% of normal sprint"] call _near;
[_heavyFloor, _fullSprint * 0.65, "empty heavy sprint retains 65% of normal sprint"] call _near;
private _mediumFloor = [_fullSprint, _fullSprint, 0, 50] call GAIT_fnc_sprintReservePace;
[_mediumFloor, _fullSprint * 0.70, "empty midweight sprint retains 70% of normal sprint"] call _near;
[_lightFloor > _mediumFloor && {_mediumFloor > _heavyFloor}, "depleted pace decreases with load"] call _assert;
[[_fullSprint, _fullSprint, 0, 150] call GAIT_fnc_sprintReservePace, _heavyFloor,
    "extreme carried mass stays within the exhaustion ratio range"] call _near;
[[2, _fullSprint, 0, 100] call GAIT_fnc_sprintReservePace, _heavyFloor,
    "downhill momentum does not raise the empty-reserve target"] call _near;
{
    private _reserve = _x;
    [[_fullSprint, _fullSprint, _reserve, 0, 0, 0.70, true] call GAIT_fnc_sprintReservePace, _fullSprint,
        "light kit holds normal pace above half reserve"] call _near;
    [[_fullSprint, _fullSprint, _reserve, 100, 0, 0.70, true] call GAIT_fnc_sprintReservePace, _fullSprint,
        "heavy kit holds the same normal pace above half reserve"] call _near;
} forEach [0.50, 0.51, 0.75, 1];

private _burstStart = [-1, true, false, 1, 0.05] call GAIT_fnc_stepDeadSprint;
[_burstStart, 0, "starting fully rested arms the dead sprint"] call _near;
[[-1, true, false, 0.99, 0.05] call GAIT_fnc_stepDeadSprint, -1,
    "starting with partial reserve does not arm the burst"] call _near;
[[2, false, true, 0.95, 0.05] call GAIT_fnc_stepDeadSprint, -1,
    "releasing sprint cancels the active burst"] call _near;
[[-1, true, false, 0.95, 0.05] call GAIT_fnc_stepDeadSprint, -1,
    "a partially recovered re-press cannot replay the burst"] call _near;
[[2, true, true, 0.50, 0.05] call GAIT_fnc_stepDeadSprint, -1,
    "the burst is spent by half reserve even if its timer has time left"] call _near;
[[4.09, true, true, 0.90, 0.05] call GAIT_fnc_stepDeadSprint, -1,
    "held burst expires after its limited window"] call _near;
[[-1, true, true, 1, 0.05] call GAIT_fnc_stepDeadSprint, -1,
    "reaching full reserve while still held does not arm a burst"] call _near;
{
    private _elapsed = _burstStart;
    private _dt = _x;
    for "_step" from 1 to round (3.0 / _dt) do {
        _elapsed = [_elapsed, true, true, 0.80, _dt] call GAIT_fnc_stepDeadSprint;
    };
    [[_elapsed, 0.80] call GAIT_fnc_deadSprintStrength, 0.50, "burst time response is independent of the feature interval"] call _near;
} forEach [0.02, 0.05, 0.10, 0.20];
{
    [[_x, 0.80] call GAIT_fnc_deadSprintStrength, 1, "peak allowance remains available while building initial acceleration"] call _near;
} forEach [0, 1, 1.5, 1.9];
[[2, 0.625] call GAIT_fnc_deadSprintStrength, 0.50, "rapid reserve use can taper the dead sprint before the timer"] call _near;
[[2, 0.50] call GAIT_fnc_deadSprintStrength, 0, "dead-sprint strength is zero at half reserve"] call _near;
[[4.10, 1] call GAIT_fnc_deadSprintStrength, 0, "the full-reserve burst still ends on time"] call _near;

private _lastPeak = 2;
{
    private _mass = _x;
    private _peak = [_fullSprint, _fullSprint, 1, _mass, 0, 0.70, true, 1.14, 1] call GAIT_fnc_sprintReservePace;
    [_peak > _fullSprint && {_peak < _lastPeak}, "additional carried mass continuously reduces the dead-sprint peak"] call _assert;
    _lastPeak = _peak;
    private _previous = _peak;
    for "_step" from 20 to 41 do {
        private _strength = [_step / 10, 0.80] call GAIT_fnc_deadSprintStrength;
        private _target = [_fullSprint, _fullSprint, 0.80, _mass, 0, 0.70, true, 1.14, _strength]
            call GAIT_fnc_sprintReservePace;
        [_target < _previous, "dead sprint tapers continuously to normal pace as time runs out"] call _assert;
        _previous = _target;
    };
    [_previous, _fullSprint, "ending a dead sprint returns every load to normal pace"] call _near;
} forEach [0, 50, 110, 150];
[[_fullSprint, _fullSprint, 1, 0, 0, 0.70, true, 1.14, 1] call GAIT_fnc_sprintReservePace, _fullSprint * 1.14,
    "an unloaded dead sprint tops out at the configured 114 percent"] call _near;
[[_fullSprint, _fullSprint, 1, 110, 0, 0.70, true, 1.14, 1] call GAIT_fnc_sprintReservePace, _fullSprint * 1.084,
    "110 lb of carried mass leaves an 8.4 percent peak bonus"] call _near;
[[_fullSprint, _fullSprint, 0.50, 50, 0, 0.70, true, 1.14, 1] call GAIT_fnc_sprintReservePace, _fullSprint,
    "flat sprint never receives a burst bonus at half reserve"] call _near;
[[_fullSprint, _fullSprint, 0.75, 0, 0, 0.70, true, 1.20, 0.50] call GAIT_fnc_sprintReservePace, _fullSprint * 1.10,
    "custom peak changes the active bonus without changing normal sprint pace"] call _near;
[[_fullSprint, _fullSprint, 1, 50, 0, 0.70, true, 1, 1] call GAIT_fnc_sprintReservePace, _fullSprint,
    "a flat peak of one disables the bonus"] call _near;
{
    [[_x, _fullSprint, 1, 50, 0, 0.70, false, 1.14, 1] call GAIT_fnc_sprintReservePace, _x,
        "uphill and downhill pace do not receive a flat sprint bonus"] call _near;
} forEach [0.9, 1.6];
private _midTaperPace = [_fullSprint, _fullSprint, 0.25, 100] call GAIT_fnc_sprintReservePace;
[_midTaperPace, (_fullSprint + _heavyFloor) / 2, "halfway through the exhaustion taper is halfway to the floor"] call _near;
private _justUnderHalf = [_fullSprint, _fullSprint, 0.49, 100] call GAIT_fnc_sprintReservePace;
[_justUnderHalf < _fullSprint && {_justUnderHalf > 0.999 * _fullSprint}, "taper begins just below half reserve without a step"] call _assert;
private _previous = _heavyFloor;
for "_percent" from 1 to 50 do {
    private _target = [_fullSprint, _fullSprint, _percent / 100, 100, 0, 0.70, true] call GAIT_fnc_sprintReservePace;
    [_target > _previous, "sprint target changes continuously through low reserve"] call _assert;
    _previous = _target;
};
private _nearEmpty = [_fullSprint, _fullSprint, 0.01, 100, 0, 0.70, true] call GAIT_fnc_sprintReservePace;
[_nearEmpty < (_heavyFloor * 1.01), "last reserve ticks approach the run floor smoothly"] call _assert;
[[ _fullSprint, _fullSprint, 0, 100, 0, 0.80] call GAIT_fnc_sprintReservePace, _fullSprint * 0.75,
    "custom exhaustion setting shifts the weight-scaled floor"] call _near;

// Steep grades can push a heavy sprint's candidate below its matching jog.
private _uphillWalk = 0.48;
private _uphillJog = 0.51;
private _walkRef = 1.5;
private _jogRef = 3.6;
private _sprintRef = 5.8;
private _uphillFloor = [_uphillWalk, _uphillJog, _walkRef, _jogRef, _sprintRef] call GAIT_fnc_uphillSprintFloor;
[_uphillFloor * _sprintRef, _uphillJog * _jogRef * 1.08,
    "calibrated uphill sprint exceeds the same-load jog"] call _near;
private _fallbackFloor = [_uphillWalk, _uphillJog, -1, -1, -1] call GAIT_fnc_uphillSprintFloor;
[_fallbackFloor, _uphillJog * 0.75 * 1.08, "fallback uphill floor uses jog root-motion estimate"] call _near;
{
    private _sprint = [0.14, 0.14, _x, 100, _uphillFloor] call GAIT_fnc_sprintReservePace;
    [_sprint, _uphillFloor, "fresh and fatigued uphill sprint honor the pace floor"] call _near;
} forEach [0, 0.10, 0.20, 1];
private _walkDominates = [0.9, 0.2, _walkRef, _jogRef, _sprintRef] call GAIT_fnc_uphillSprintFloor;
[_walkDominates * _sprintRef, 0.9 * _walkRef * 1.06 * 1.08, "uphill sprint also exceeds a jog held at its walk-relative floor"] call _near;
[[1, 1.5, 2.8, 4] call GAIT_fnc_ordinaryJogFloor, 2.8 * 1.04 / 4,
    "ordinary jog floor is slightly faster than measured combat pace"] call _near;
[[1.2, 2.5, 2.4, 4] call GAIT_fnc_ordinaryJogFloor, 3 * 1.04 / 4,
    "ordinary jog floor also respects measured walk pace"] call _near;
[[1, -1, -1, -1] call GAIT_fnc_ordinaryJogFloor, 0.78,
    "uncalibrated jog uses an estimate without changing native walk"] call _near;

{
    _x params ["_mass", "_margin"];
    private _combatPace = 0.91;
    private _combatReference = 3.6;
    private _sprintReference = 4.2;
    private _minimum = [_combatPace, _combatReference, _sprintReference, 1, _mass] call GAIT_fnc_combatRelativeSprintFloor;
    [_minimum * _sprintReference, _combatPace * _combatReference * _margin, "measured combat pace sets a load-aware sprint floor"] call _near;
    {
        private _target = [_fullSprint, _fullSprint, _x, _mass, _minimum, 0.50] call GAIT_fnc_sprintReservePace;
        [_target * _sprintReference > _combatPace * _combatReference, "sprint stays faster than combat at every low reserve"] call _assert;
    } forEach [0, 0.01, 0.25, 0.50];
    private _unarmedFallback = [1, -1, -1, 0.725, _mass] call GAIT_fnc_combatRelativeSprintFloor;
    [_unarmedFallback, 0.74 * 0.725 * _margin, "uncalibrated floor uses the sprint clip scale independently of configured sprint speed"] call _near;
} forEach [[0, 1.08], [50, 1.07], [100, 1.06], [150, 1.05], [200, 1.05]];
private _startSpeed = 5.2;
private _walkLoadFactors = [0, 35, 55, 75, 100, 150, 200] apply {
    [_x, [35,55,75], [1.08,1.02,0.97,0.92], 0.18] call GAIT_fnc_walkingLoadMultiplier
};
[_walkLoadFactors select 0, 1, "unloaded walking retains its native pace"] call _near;
for "_i" from 1 to 5 do {
    [(_walkLoadFactors select _i) < (_walkLoadFactors select (_i - 1)),
        "walking slows progressively with carried weight"] call _assert;
};
[_walkLoadFactors select 6, _walkLoadFactors select 5, "walking penalty stops growing at 150 lb"] call _near;
private _walkSpeed = 1.38;
private _lastReleasePace = _startSpeed;
for "_i" from 1 to 30 do {
    private _speed = [_startSpeed, _walkSpeed, _i / 30] call GAIT_fnc_sprintWalkPace;
    [_speed < _lastReleasePace && {_speed >= (_walkSpeed - 0.00001)},
        "held movement decelerates throughout the taper"] call _assert;
    _lastReleasePace = _speed;
};
[_lastReleasePace, _walkSpeed, "release finishes at the selected walk's physical speed"] call _near;
[[5.2, 1.1, 0.5] call GAIT_fnc_sprintWalkPace, 3.15, "crouched taper uses its own walk speed"] call _near;
private _movingStanceRelease = [10, 4.2, 1, 0.4];
[[_movingStanceRelease, 2.1, 0.4] call GAIT_fnc_sprintReleaseSpeed, 4.2,
    "the stance handoff starts at measured travel speed"] call _near;
private _afterStance = [_movingStanceRelease, 2.1, 0.6] call GAIT_fnc_sprintReleaseSpeed;
[_afterStance < 4.2 && {_afterStance > 2.1}, "the remaining taper keeps decelerating"] call _assert;
[[_movingStanceRelease, 2.1, 1] call GAIT_fnc_sprintReleaseSpeed, 2.1,
    "the crouched endpoint keeps the original deadline"] call _near;
[[[10, 1.7, 1, 0.8], 2.1, 0.8] call GAIT_fnc_sprintReleaseSpeed, 1.7,
    "a near-end handoff also begins below the target without a forward kick"] call _near;
private _shortCrouchRelease = [[10, 5.2, 1], 11.2, 4.2, true] call GAIT_fnc_rebaseSprintRelease;
[_shortCrouchRelease select 3, 1.2 / 2.7, "shortening the crouch taper preserves the current curve position"] call _near;
[[_shortCrouchRelease, 2.1, _shortCrouchRelease select 3] call GAIT_fnc_sprintReleaseSpeed, 4.2,
    "the shorter crouch taper still starts at measured speed"] call _near;
[[_shortCrouchRelease select 0, 12.55, _shortCrouchRelease select 2] call GAIT_fnc_sprintWalkProgress, 1,
    "entering crouch uses 75 percent of the original remaining time"] call _near;
private _standAgain = [_shortCrouchRelease, 11.4, 3.9, false] call GAIT_fnc_rebaseSprintRelease;
private _crouchAgain = [_standAgain, 11.6, 3.5, true] call GAIT_fnc_rebaseSprintRelease;
[_crouchAgain select 2, 0.75, "tapping crouch again cannot repeatedly shorten or reset the taper"] call _near;
private _stanceSpeedLimit = [10.65, "rifle", 4.2];
[[10.2, "rifle", 5.6, _stanceSpeedLimit] call GAIT_fnc_limitStanceTravelSpeed, 4.2,
    "rapid crouch inputs cannot bank a faster post-transition stride"] call _near;
[[10.2, "rifle", 3.9, _stanceSpeedLimit] call GAIT_fnc_limitStanceTravelSpeed, 3.9,
    "rapid stance inputs still reflect genuine deceleration"] call _near;
[[10.66, "rifle", 5.6, _stanceSpeedLimit] call GAIT_fnc_limitStanceTravelSpeed, 5.6,
    "an isolated stance input uses the speed reached by ordinary sprinting"] call _near;
[[10.2, "pistol", 5.6, _stanceSpeedLimit] call GAIT_fnc_limitStanceTravelSpeed, 5.6,
    "switching weapons discards the old stance speed ceiling"] call _near;

private _releaseSample = [];
{
    private _reference = _x;
    {
        private _terrain = _x;
        {
            private _scale = _x;
            private _bounded = [2.5, _reference, _scale, _terrain, 1.02] call GAIT_fnc_capSprintPace;
            [_bounded * _reference <= (((6 * (_terrain max 1) * 1.02) min (30 / 3.6)) + 0.00001),
                "fast weapon and empty-kit clips obey the physical sprint ceiling"] call _assert;
            [_bounded <= 1.10 * _scale * (_terrain max 1) * 1.02 + 0.00001,
                "a leftover wind-down playback rate cannot become sprint speed"] call _assert;
        } forEach [0.725, 1];
    } forEach [0.3, 1, 1.18, 1.6];
} forEach [3.9, 5.1, 7.2, 10];
[[0.7,5.1,1,1,1.02] call GAIT_fnc_capSprintPace, 0.7, "the ceiling preserves a tired sprint below the limit"] call _near;
[[4, -1, 0.725, 1, 1.02] call GAIT_fnc_capSprintPace, 1.10 * 0.725 * 1.02,
    "unmeasured unarmed sprint has a bounded coefficient fallback"] call _near;
[[6, 1.4, "AmovPercMwlkSlowWrflDf_GAIT"] call GAIT_fnc_releasePlaybackRate, 1.15,
    "a release cannot play the walking feet several times faster"] call _near;
[[6, 3.9, "AmovPercMrunSrasWrflDf_GAIT"] call GAIT_fnc_releasePlaybackRate, 1.20,
    "the interim jogging cadence is capped during high-speed release"] call _near;
[[1.4,1.4,"AmovPercMwlkSrasWrflDf_GAIT"] call GAIT_fnc_releasePlaybackRate, 1,
    "release finishes at the normal walking cadence"] call _near;
{
    private _weaponReference = _x;
    private _scale = [5.1, _weaponReference] call GAIT_fnc_weaponStrideScale;
    [_scale * _weaponReference, 5.1, "weapon strides produce the same physical sprint target"] call _near;
} forEach [3.9,4.8,5.1,6.3,7.2];
[[5.1,-1,0.725] call GAIT_fnc_weaponStrideScale, 0.725,
    "an unmeasured unarmed clip retains its conservative fallback"] call _near;
private _lastReference = 5.1;
for "_blend" from 1 to 20 do {
    private _reference = [5.1,1.4,_blend / 20] call GAIT_fnc_blendedStrideReference;
    [_reference < _lastReference && {_reference >= 1.4 - 0.00001},
        "the mixed sprint-to-walk stride changes continuously"] call _assert;
    _lastReference = _reference;
};
[[5.1,1.4,0] call GAIT_fnc_blendedStrideReference,5.1,"source stride starts at its own reference"] call _near;
[[5.1,1.4,1] call GAIT_fnc_blendedStrideReference,1.4,"target stride ends at its own reference"] call _near;
[[1.5,3.9,"AmovPercMrunSlowWrflDf_GAIT"] call GAIT_fnc_releasePlaybackRate,1.5 / 3.9,
    "the jog's minimum rate cannot force an overspeed at the final walking handoff"] call _near;
[[6,1.4,"AmovPercMrunSlowWrflDf_GAIT_AmovPercMwlkSlowWrflDf_GAIT"] call GAIT_fnc_releasePlaybackRate,1.15,
    "a mixed walk state obeys the walking cadence ceiling"] call _near;
private _plan = [10,9,"rifle","AmovPercMwlkSlowWrflDf_GAIT",2,1.4,3.9,0.51,0.37];
{
    _x params ["_now","_start","_weapon","_clip","_expected"];
    [([_plan,_now,_start,_weapon,_clip] call GAIT_fnc_releasePlanValid) isEqualTo _expected,
        "only the current release, weapon, direction and recent plan can choose the gait"] call _assert;
} forEach [
    [10.1,9,"rifle","AmovPercMwlkSlowWrflDf_GAIT",true],
    [10.3,9,"rifle","AmovPercMwlkSlowWrflDf_GAIT",false],
    [9.9,9,"rifle","AmovPercMwlkSlowWrflDf_GAIT",false],
    [10.1,8,"rifle","AmovPercMwlkSlowWrflDf_GAIT",false],
    [10.1,9,"pistol","AmovPercMwlkSlowWrflDf_GAIT",false],
    [10.1,9,"rifle","AmovPercMwlkSlowWrflDr_GAIT",false],
    [10.1,9,"rifle","AmovPknlMwlkSlowWrflDf_GAIT",false]
];
private _lateWalkSpeed = [[0,6,1],1.4,1] call GAIT_fnc_sprintReleaseSpeed;
[([1,"AmovPercMrunSlowWrflDf_GAIT","AmovPercMrunSlowWrflDf_GAIT",0.55,"mwlk",_lateWalkSpeed,1.4]
    call GAIT_fnc_sprintReleaseUsesSlowerPace),
    "the jog cadence floor cannot prevent the final walking handoff"] call _assert;
for "_i" from 0 to 6 do {
    _releaseSample = [_releaseSample, 7, 10 + (_i * 0.05), 6, 1.5, 1]
        call GAIT_fnc_stepSprintReleaseSample;
};
[[_releaseSample, 7, 10.35] call GAIT_fnc_sprintReleaseStartSpeed, 4,
    "a held sprint earns momentum at its bounded physical pace"] call _near;
[[_releaseSample, 8, 10.35] call GAIT_fnc_sprintReleaseStartSpeed, 0,
    "a retap cannot inherit the previous sprint sample"] call _near;
_releaseSample = [_releaseSample, 8, 10.36, 7, 1.8, 1] call GAIT_fnc_stepSprintReleaseSample;
_releaseSample = [_releaseSample, 8, 10.41, 7, 1.8, 1] call GAIT_fnc_stepSprintReleaseSample;
[[_releaseSample, 8, 10.42] call GAIT_fnc_sprintReleaseStartSpeed, 0,
    "a brief sprint tap cannot cash in a clip transition speed spike"] call _near;
_releaseSample = [_releaseSample, 8, 10.67, 4, 0.9, 1] call GAIT_fnc_stepSprintReleaseSample;
[[_releaseSample, 8, 10.68] call GAIT_fnc_sprintReleaseStartSpeed, 0,
    "a break in settled sprint samples starts a new observation window"] call _near;
diag_log format ["GAIT TEST PASS: physical pace adapter; %1 exact legacy fallback cases, %2 conversion roundtrips, physical floor, partial profiles and invalid calibration rejection", _fallbackChecks, _roundTrips];
