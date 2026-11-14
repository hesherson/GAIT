private _checks = 0;
private _assert = {
    params ["_condition", "_description"];
    _checks = _checks + 1;
    if (!_condition) then {diag_log format ["FAIL: %1", _description];};
};

{
    _x params ["_input", "_speed", "_clip", "_allowed", "_grounded", "_expected", "_description"];
    private _activity = [_input, _speed, _clip, _allowed, _grounded] call GAIT_fnc_sprintReserveActivity;
    [_activity isEqualTo _expected, _description] call _assert;
} forEach [
    [[1,0,true], 4, "AmovPercMevaSrasWrflDf_GAITSprint", true, true, "sprint", "grounded forward sprint spends reserve"],
    [[1,0,false], 4, "AmovPercMevaSrasWrflDf_GAITSprint", true, true, "hold", "Shift release stops drain through the sprint blend"],
    [[1,0,true], 2, "AmovPercMrunSlowWrflDf", true, true, "hold", "sprint request while still jogging holds reserve"],
    [[1,0,false], 3, "AmovPercMrunSrasWrflDf", true, true, "hold", "ordinary jog holds reserve"],
    [[0,1,false], 2, "AmovPercMwlkSrasWrflDr", true, true, "hold", "sideways movement holds reserve"],
    [[0,0,false], 2, "AmovPercMrunSlowWrflDf", true, true, "hold", "coasting does not regenerate"],
    [[1,0,true], 0, "AmovPercMevaSrasWrflDf_GAITSprint", true, true, "hold", "running against an obstacle holds reserve"],
    [[0,0,false], 0, "AmovPercMstpSrasWrflDnon", true, true, "rest", "standing still regenerates reserve"],
    [[0,0,false], 0, "AmovPercMstpSrasWrflDnon", true, false, "hold", "airborne motion never counts as resting"],
    [[1,0,true], 4, "AmovPercMevaSrasWrflDf_GAITSprint", false, true, "hold", "movement locks prevent sprint drain"]
];

private _close = {
    params ["_actual", "_expected", "_description"];
    [abs (_actual - _expected) < 0.001, _description] call _assert;
};
private _uphill = [25, true, 10, 35, 1.75] call GAIT_fnc_sprintReserveGradeMultiplier;
[_uphill, 1.45, "25-degree climb has a partial uphill drain multiplier"] call _close;
{
    _x params ["_grade", "_enabled", "_expected"];
    [[_grade, _enabled, 10, 35, 1.75] call GAIT_fnc_sprintReserveGradeMultiplier, _expected,
        format ["grade %1 degrees with uphill drain enabled %2", _grade, _enabled]] call _close;
} forEach [[0,true,1], [35,true,1.75], [70,true,1.75], [35,false,1], [-10,true,0.925], [-20,true,0.85], [-45,true,1]];

{
    _x params ["_mass", "_flat"];
    [[_mass, 1] call GAIT_fnc_sprintReserveDrainRate, _flat, format ["flat reserve load at %1 lb", _mass]] call _close;
    [[_mass, _uphill] call GAIT_fnc_sprintReserveDrainRate, _flat * 1.45,
        format ["uphill reserve load at %1 lb", _mass]] call _close;
} forEach [[0,1], [70,1.03861], [110,1.14528], [120,1.19], [150,1.5]];
private _lastRate = 1;
for "_load" from 0 to 200 do {
    private _rate = [_load, 1] call GAIT_fnc_sprintReserveDrainRate;
    [_rate >= _lastRate && {_rate - _lastRate < 0.015}, "load changes drain continuously"] call _assert;
    _lastRate = _rate;
};

private _heavyRate = [110, 1] call GAIT_fnc_sprintReserveDrainRate;
private _remaining = [40, "sprint", 15, 40, 10, _heavyRate] call GAIT_fnc_stepFallbackSprintReserve;
[_remaining, 22.82083, "110 lb still leaves more than half after 15 level seconds"] call _close;
private _jogged = [_remaining, "hold", 90, 40, 10, _heavyRate] call GAIT_fnc_stepFallbackSprintReserve;
[_jogged isEqualTo _remaining, "jogging neither spends nor restores fallback reserve"] call _assert;
[([_jogged, "rest", 10, 40, 10, _heavyRate] call GAIT_fnc_stepFallbackSprintReserve) isEqualTo 40,
    "stationary recovery refills fallback reserve to its cap"] call _assert;

private _heavy = [2300, 2150, 150, "sprint", _heavyRate] call GAIT_fnc_aceSprintReserveDelta;
[_heavy, 2300 - (0.65 * _heavyRate * 150), "a high native debit keeps its proportional effect"] call _close;
[[1000, 980, 25, "sprint", _heavyRate] call GAIT_fnc_aceSprintReserveDelta,
    1000 - (0.65 * _heavyRate * 20), "a low native debit has no fixed floor"] call _close;
[[12, 1, 35, "sprint", _heavyRate] call GAIT_fnc_aceSprintReserveDelta, 0,
    "unfloored native debit can reach zero in one tick"] call _close;
[[0, 5, 2, "sprint", _heavyRate] call GAIT_fnc_aceSprintReserveDelta, 0,
    "ACE sprint cannot recover reserve"] call _close;
[[1000, 1005, 2, "sprint", _heavyRate] call GAIT_fnc_aceSprintReserveDelta, 1000,
    "ACE sprint at aerobic surplus holds reserve without a manufactured debit"] call _close;
{
    [[1100, _x, 170, "hold", _heavyRate] call GAIT_fnc_aceSprintReserveDelta, 1100,
        "jogging neutralizes both ACE drain and recovery"] call _close;
} forEach [930, 1125];
[[1100, 1125, 0, "rest", _heavyRate] call GAIT_fnc_aceSprintReserveDelta, 1125,
    "stationary recovery retains native ACE gain"] call _close;
[[1100, 1095, 5, "rest", _heavyRate] call GAIT_fnc_aceSprintReserveDelta, 1100,
    "ACE rest cannot drain reserve"] call _close;

// Sample the stock 3.21.2 workload at 6 m/s with configurable native
// aerobic power, duty, effective load and terrain. All are already present
// in the tick before GAIT attributes a smaller share of cargo to the bar.
private _spentAt = {
    params ["_load", "_aceLoadFactor", "_slope", "_terrainFactor", "_duty", "_aerobic"];
    private _speed = 6;
    private _wattsPerATP = 9;
    private _gearKg = (_load / 2.2046 - 3.5) max 0;
    _gearKg = _gearKg * _aceLoadFactor;
    private _gradient = _slope * _terrainFactor * 0.1;
    private _work = (147 + ((70 + _gearKg) *
        (4 * (_gearKg / 70) ^ 2 + (0.9 * _speed ^ 2) + (0.66 * _speed * _gradient)))) * 0.23 * _duty;
    private _debit = ((_work - _aerobic) / _wattsPerATP) max 0;
    private _adjusted = [_debit, [_work, _gearKg, _gradient, 1, _speed, _wattsPerATP]]
        call GAIT_fnc_aceSprintReserveAdjustedDebit;
    private _mass = [_load, 1] call GAIT_fnc_sprintReserveDrainRate;
    private _grade = [_slope, true, 10, 35, 1.75] call GAIT_fnc_sprintReserveGradeMultiplier;
    private _rate = (1 + ((_mass - 1) * (_aceLoadFactor min 1))) *
        (1 + ((_grade - 1) * (_terrainFactor min 1)));
    2300 - ([2300, 2300 - _debit, _debit, "sprint", _rate, _adjusted] call GAIT_fnc_aceSprintReserveDelta)
};
private _unloaded = [0, 1, 0, 1, 1, 255] call _spentAt;
private _loaded = [70, 1, 0, 1, 1, 255] call _spentAt;
private _heavy = [120, 1, 0, 1, 1, 255] call _spentAt;
private _veryHeavy = [150, 1, 0, 1, 1, 255] call _spentAt;
[_loaded > _unloaded && {_loaded / _unloaded < 1.2}, "native response makes 70 lb only a moderate reserve cost"] call _assert;
[_veryHeavy / _heavy > 1.25, "overload has a stronger reserve cost past 120 lb"] call _assert;
{
    _x params ["_load", "_duty", "_aerobic"];
    private _previous = -1;
    {
        private _spent = [_load, _x, 25, 1, _duty, _aerobic] call _spentAt;
        [_spent >= _previous, "increasing ACE load factor does not reduce drain"] call _assert;
        _previous = _spent;
    } forEach [0,0.25,1,2,5];
} forEach [[70,1,255], [70,2.5,120], [120,1,255], [150,2.5,120], [150,1,500]];
[[150, 0, 0, 1, 1, 255] call _spentAt, _unloaded,
    "ACE load factor zero disables load contributions"] call _close;
private _gentle = [110, 1, 25, 0.25, 1, 255] call _spentAt;
private _climb = [110, 1, 25, 1, 1, 255] call _spentAt;
private _hardClimb = [110, 1, 25, 2, 1, 255] call _spentAt;
[_gentle < _climb && {_climb < _hardClimb}, "terrain factor remains effective above and below default"] call _assert;
[([110, 1, 25, 1, 1, 350] call _spentAt) < _climb, "higher native aerobic performance preserves more reserve"] call _assert;
[([110, 1, 25, 1, 2.5, 255] call _spentAt) > _climb, "medical duty remains effective during heavy uphill sprint"] call _assert;

diag_log format ["GAIT TEST PASS: continuous load and grade, ACE-native physiology ordering, sprint-only drain and rest-only recovery (%1 checks)", _checks];
