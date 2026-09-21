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
diag_log format ["GAIT TEST PASS: physical pace adapter; %1 exact legacy fallback cases, %2 conversion roundtrips, physical floor, partial profiles and invalid calibration rejection", _fallbackChecks, _roundTrips];
