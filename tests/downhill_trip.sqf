// Run after fn_downhillPace.sqf in SQF-VM or Arma.
private _checks = 0;
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {throw format ["FAIL: %1", _label];};
    _checks = _checks + 1;
};

{
    private _factors = [_x] call GAIT_fnc_downhillTripSpeedFactors;
    [(_factors select 0) isEqualTo 0 && {(_factors select 1) isEqualTo 0}, "no default speed risk at or below minimum"] call _assert;
} forEach [-50, 0, 5, 19.9, 20];
private _onset = [20.001] call GAIT_fnc_downhillTripSpeedFactors;
[(_onset select 1) > 0 && {(_onset select 1) < 0.0002}, "risk rises continuously from minimum velocity"] call _assert;
private _reference = [34] call GAIT_fnc_downhillTripSpeedFactors;
[abs ((_reference select 1) - 1.55) < 0.000001, "old reference-speed risk calibration survives"] call _assert;
{
    private _influence = _x;
    private _lastRisk = -1;
    for "_speed" from 20.1 to 100 step 0.1 do {
        private _factors = [_speed, 20, 34, _influence] call GAIT_fnc_downhillTripSpeedFactors;
        private _risk = _factors select 1;
        [_risk > _lastRisk, "positive influence is strictly monotonic above speed threshold, including above reference"] call _assert;
        _lastRisk = _risk;
    };
} forEach [0.25, 0.5, 1, 1.5, 2];
private _halfExcess = [27] call GAIT_fnc_downhillTripSpeedFactors;
private _doubleExcess = [48] call GAIT_fnc_downhillTripSpeedFactors;
[abs (((_halfExcess select 1) * 2) - (_reference select 1)) < 0.000001, "default risk scales directly with current excess velocity"] call _assert;
[abs ((_doubleExcess select 1) - (2 * (_reference select 1))) < 0.000001, "risk does not plateau beyond former maximum speed"] call _assert;
{
    private _factors = [_x, 20, 34, 0] call GAIT_fnc_downhillTripSpeedFactors;
    [(_factors select 1) isEqualTo 1, "explicit zero-influence setting still opts out of speed scaling"] call _assert;
} forEach [0, 20, 27, 34, 60];
private _malformed = [-10, -20, -30, -1] call GAIT_fnc_downhillTripSpeedFactors;
[(_malformed select 0) isEqualTo 0 && {(_malformed select 1) isEqualTo 1}, "negative inputs are sanitized"] call _assert;

{
    private _chancePerSecond = _x;
    {
        private _dt = _x;
        private _perTick = [_chancePerSecond, _dt] call GAIT_fnc_downhillTripRollChance;
        private _survival = 1;
        for "_i" from 1 to round (1 / _dt) do {_survival = _survival * (1 - _perTick);};
        [abs ((1 - _survival) - _chancePerSecond) < 0.0001, "one-second probability is independent of regular update interval"] call _assert;
        [_perTick >= 0 && {_perTick <= 1}, "every roll probability is bounded"] call _assert;
    } forEach [0.01, 0.02, 0.05, 0.1, 0.2];
    private _whole = [_chancePerSecond, 0.37] call GAIT_fnc_downhillTripRollChance;
    private _first = [_chancePerSecond, 0.12] call GAIT_fnc_downhillTripRollChance;
    private _second = [_chancePerSecond, 0.25] call GAIT_fnc_downhillTripRollChance;
    [abs (_whole - (1 - ((1 - _first) * (1 - _second)))) < 0.000001, "probability composes across irregular intervals"] call _assert;
} forEach [0, 0.005, 0.1, 0.4, 0.9, 1];
[([0.9, 0] call GAIT_fnc_downhillTripRollChance) isEqualTo 0, "zero elapsed time cannot roll"] call _assert;
[([2, 0.1] call GAIT_fnc_downhillTripRollChance) isEqualTo 1, "malformed excessive probability stays bounded"] call _assert;
[([-2, 0.1] call GAIT_fnc_downhillTripRollChance) isEqualTo 0, "negative probability stays zero"] call _assert;

private _start = [[-1, -1], 10, true, true, 30, 20] call GAIT_fnc_stepDownhillTripQualification;
[_start isEqualTo [10, 10, 0, 0], "valid sprint begins both sustained timers"] call _assert;
private _qualified = [_start, 15, true, true, 30, 20] call GAIT_fnc_stepDownhillTripQualification;
[_qualified isEqualTo [10, 10, 5, 5], "unchanged sustained sprint and high-speed durations"] call _assert;
private _release = [_qualified, 15.05, true, false, 28, 20] call GAIT_fnc_stepDownhillTripQualification;
[(_release select 0) isEqualTo 10 && {(_release select 1) isEqualTo 10} && {(_release select 3) > 5}, "Shift release keeps earned sprint and high-speed qualifications"] call _assert;
private _retap = [_release, 15.1, true, true, 29, 20] call GAIT_fnc_stepDownhillTripQualification;
[(_retap select 1) isEqualTo 10 && {(_retap select 3) > 5}, "sprint retap does not restart high-speed qualification"] call _assert;
private _slowed = [_release, 16, true, false, 19, 20] call GAIT_fnc_stepDownhillTripQualification;
[_slowed isEqualTo [-1, -1, 0, 0], "dropping below speed gate clears high-speed qualification"] call _assert;
private _unsafe = [_qualified, 16, false, true, 50, 20] call GAIT_fnc_stepDownhillTripQualification;
[_unsafe isEqualTo [-1, -1, 0, 0], "ineligible context clears both timers despite high speed or held sprint"] call _assert;
private _restored = [_unsafe, 18, true, false, 30, 20] call GAIT_fnc_stepDownhillTripQualification;
[_restored isEqualTo [-1, 18, 0, 0], "returning to valid context starts fresh qualification"] call _assert;
private _stationary = [[-1, -1], 1, true, false, 0, 20] call GAIT_fnc_stepDownhillTripQualification;
[_stationary isEqualTo [-1, -1, 0, 0], "stationary grounded player gains no qualification"] call _assert;
private _heavyRelease = [[10, 14.5], 15.1, true, false, 21, 20] call GAIT_fnc_stepDownhillTripQualification;
[(_heavyRelease select 2) >= 5 && {(_heavyRelease select 3) < 4}, "qualified slow heavy sprint remains qualified when Shift released soon after crossing speed minimum"] call _assert;
private _earlyRelease = [[10, 12], 13, true, false, 25, 20] call GAIT_fnc_stepDownhillTripQualification;
[(_earlyRelease select 0) isEqualTo -1 && {(_earlyRelease select 1) isEqualTo 12}, "unqualified sprint history cannot continue accumulating after release"] call _assert;
private _customGate = [[10, -1], 18, true, false, 26, 40, 25, 7] call GAIT_fnc_stepDownhillTripQualification;
[(_customGate select 2) >= 7, "earned sprint qualification honors independently configured minimum speed and duration"] call _assert;
private _belowCustomGate = [_customGate, 18.1, true, false, 24.9, 40, 25, 7] call GAIT_fnc_stepDownhillTripQualification;
[_belowCustomGate isEqualTo [-1, -1, 0, 0], "earned coast qualification ends below actual configured minimum"] call _assert;

diag_log format ["GAIT TEST PASS: downhill velocity risk, smooth threshold, no speed plateau, timestep probability and release qualification (%1 checks)", _checks];
