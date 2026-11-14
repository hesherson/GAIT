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
// The last fifth of reserve tapers toward 65–75% of the kit's unboosted run.
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
        "light kit holds normal pace from half reserve through the start of exhaustion"] call _near;
    [[_fullSprint, _fullSprint, _reserve, 100, 0, 0.70, true] call GAIT_fnc_sprintReservePace, _fullSprint,
        "heavy kit holds the same normal pace until the final fifth"] call _near;
} forEach [0.20, 0.25, 0.45, 0.50, 0.75, 1];

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
[[5.69, true, true, 0.90, 0.05] call GAIT_fnc_stepDeadSprint, -1,
    "held burst expires after its limited window"] call _near;
[[-1, true, true, 1, 0.05] call GAIT_fnc_stepDeadSprint, -1,
    "reaching full reserve while still held does not arm a burst"] call _near;
{
    private _elapsed = _burstStart;
    private _dt = _x;
    for "_step" from 1 to round (4.2 / _dt) do {
        _elapsed = [_elapsed, true, true, 0.80, _dt] call GAIT_fnc_stepDeadSprint;
    };
    [[_elapsed, 0.80] call GAIT_fnc_deadSprintStrength, 0.50, "burst time response is independent of the feature interval"] call _near;
} forEach [0.02, 0.05, 0.10, 0.20];
{
    [[_x, 0.80] call GAIT_fnc_deadSprintStrength, 1, "peak allowance remains available while building initial acceleration"] call _near;
} forEach [0, 1, 2, 2.7];
[[2, 0.625] call GAIT_fnc_deadSprintStrength, 0.50, "rapid reserve use can taper the dead sprint before the timer"] call _near;
[[2, 0.50] call GAIT_fnc_deadSprintStrength, 0, "dead-sprint strength is zero at half reserve"] call _near;
[[5.70, 1] call GAIT_fnc_deadSprintStrength, 0, "the full-reserve burst still ends on time"] call _near;

private _lastPeak = 2;
{
    private _mass = _x;
    private _peak = [_fullSprint, _fullSprint, 1, _mass, 0, 0.70, true, 1.10, 1] call GAIT_fnc_sprintReservePace;
    [_peak > _fullSprint && {_peak < _lastPeak}, "additional carried mass continuously reduces the dead-sprint peak"] call _assert;
    _lastPeak = _peak;
    private _previous = _peak;
    for "_step" from 28 to 57 do {
        private _strength = [_step / 10, 0.80] call GAIT_fnc_deadSprintStrength;
        private _target = [_fullSprint, _fullSprint, 0.80, _mass, 0, 0.70, true, 1.10, _strength]
            call GAIT_fnc_sprintReservePace;
        [_target < _previous, "dead sprint tapers continuously to normal pace as time runs out"] call _assert;
        _previous = _target;
    };
    [_previous, _fullSprint, "ending a dead sprint returns every load to normal pace"] call _near;
} forEach [0, 50, 110, 150];
[[_fullSprint, _fullSprint, 1, 0, 0, 0.70, true, 1.10, 1] call GAIT_fnc_sprintReservePace, _fullSprint * 1.10,
    "an unloaded dead sprint tops out at the configured 110 percent"] call _near;
[[_fullSprint, _fullSprint, 1, 110, 0, 0.70, true, 1.10, 1] call GAIT_fnc_sprintReservePace, _fullSprint * 1.06,
    "110 lb of carried mass leaves a six percent peak bonus"] call _near;
[[_fullSprint, _fullSprint, 0.50, 50, 0, 0.70, true, 1.10, 1] call GAIT_fnc_sprintReservePace, _fullSprint,
    "flat sprint never receives a burst bonus at half reserve"] call _near;
[[_fullSprint, _fullSprint, 0.75, 0, 0, 0.70, true, 1.20, 0.50] call GAIT_fnc_sprintReservePace, _fullSprint * 1.10,
    "custom peak changes the active bonus without changing normal sprint pace"] call _near;
[[_fullSprint, _fullSprint, 1, 50, 0, 0.70, true, 1, 1] call GAIT_fnc_sprintReservePace, _fullSprint,
    "a flat peak of one disables the bonus"] call _near;
{
    [[_x, _fullSprint, 1, 50, 0, 0.70, false, 1.10, 1] call GAIT_fnc_sprintReservePace, _x,
        "uphill and downhill pace do not receive a flat sprint bonus"] call _near;
} forEach [0.9, 1.6];
private _previous = _heavyFloor;
for "_percent" from 1 to 20 do {
    private _target = [_fullSprint, _fullSprint, _percent / 100, 100, 0, 0.70, true] call GAIT_fnc_sprintReservePace;
    [_target > _previous, "sprint target changes continuously through low reserve"] call _assert;
    _previous = _target;
};
private _nearEmpty = [_fullSprint, _fullSprint, 0.01, 100, 0, 0.70, true] call GAIT_fnc_sprintReservePace;
[_nearEmpty < (_heavyFloor * 1.01), "last reserve ticks approach the run floor smoothly"] call _assert;
private _justBelowTaper = [_fullSprint, _fullSprint, 0.19, 100, 0, 0.70, true] call GAIT_fnc_sprintReservePace;
[_justBelowTaper > (_fullSprint * 0.99), "pace begins tapering gradually below one fifth reserve"] call _assert;
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
diag_log format ["GAIT TEST PASS: physical pace adapter; %1 exact legacy fallback cases, %2 conversion roundtrips, physical floor, partial profiles and invalid calibration rejection", _fallbackChecks, _roundTrips];
