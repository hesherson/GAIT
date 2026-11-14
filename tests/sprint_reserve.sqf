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

private _lightRate = [0, 1] call GAIT_fnc_sprintReserveDrainRate;
private _heavyRate = [110, 1] call GAIT_fnc_sprintReserveDrainRate;
private _uphillRate = [110, 1.75] call GAIT_fnc_sprintReserveDrainRate;
[_heavyRate > _lightRate && {_heavyRate < 1.22}, "110 lb adds a bounded flat endurance cost"] call _assert;
[_uphillRate > _heavyRate, "heavy uphill sprint has a higher drain cap"] call _assert;

private _remaining = [40, "sprint", 15, 40, 10, _heavyRate] call GAIT_fnc_stepFallbackSprintReserve;
[_remaining > 21 && {_remaining < 22}, "fallback reserve remains above half after 15 full sprint seconds with 110 lb"] call _assert;
private _jogged = [_remaining, "hold", 90, 40, 10, _heavyRate] call GAIT_fnc_stepFallbackSprintReserve;
[_jogged isEqualTo _remaining, "jogging neither spends nor restores fallback reserve"] call _assert;
[([_jogged, "rest", 10, 40, 10, _heavyRate] call GAIT_fnc_stepFallbackSprintReserve) isEqualTo 40,
    "stationary recovery refills fallback reserve to its cap"] call _assert;

private _heavy = [2300, 2150, 150, "sprint", _heavyRate] call GAIT_fnc_aceSprintReserveDelta;
private _light = [2300, 2150, 150, "sprint", _lightRate] call GAIT_fnc_aceSprintReserveDelta;
[_heavy < _light && {_heavy > 2230}, "heavy sprint consumes more reserve with a 110 lb cap of about 3% per tick"] call _assert;
[([1000, 980, 25, "sprint", _heavyRate] call GAIT_fnc_aceSprintReserveDelta) isEqualTo 985,
    "ACE debit is eased after accounting for recovery"] call _assert;
[([12, 1, 35, "sprint", _heavyRate] call GAIT_fnc_aceSprintReserveDelta) isEqualTo 0,
    "unfloored ACE debit can reach zero in one tick"] call _assert;
[([0, 5, 2, "sprint", _heavyRate] call GAIT_fnc_aceSprintReserveDelta) isEqualTo 0,
    "ACE sprint cannot recover reserve"] call _assert;
private _lowWorkSprint = [1000, 1005, 2, "sprint", _heavyRate] call GAIT_fnc_aceSprintReserveDelta;
[_lowWorkSprint < 1000 && {_lowWorkSprint > 985}, "moving sprint still spends a small amount when ACE reports a surplus"] call _assert;
{
    [([1100, _x, 170, "hold", _heavyRate] call GAIT_fnc_aceSprintReserveDelta) isEqualTo 1100,
        "jogging neutralizes both ACE drain and recovery"] call _assert;
} forEach [930, 1125];
[([1100, 1125, 0, "rest", _heavyRate] call GAIT_fnc_aceSprintReserveDelta) isEqualTo 1125,
    "stationary recovery retains native ACE gain"] call _assert;
[([1100, 1095, 5, "rest", _heavyRate] call GAIT_fnc_aceSprintReserveDelta) isEqualTo 1100,
    "ACE rest cannot drain reserve"] call _assert;

diag_log format ["GAIT TEST PASS: sprint-only drain, rest-only recovery and heavy-load endurance (%1 checks)", _checks];
