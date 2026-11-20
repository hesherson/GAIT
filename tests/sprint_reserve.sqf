private _checks = 0;
private _assert = {
    params ["_condition", "_description"];
    _checks = _checks + 1;
    if (!_condition) then {diag_log format ["FAIL: %1", _description];};
};
private _close = {
    params ["_actual", "_expected", "_description", ["_tolerance", 0.001]];
    [abs (_actual - _expected) < _tolerance, _description] call _assert;
};

{
    _x params ["_input", "_speed", "_allowed", "_grounded", "_expected", "_description"];
    private _activity = [_input, _speed, _allowed, _grounded] call GAIT_fnc_sprintReserveActivity;
    [_activity isEqualTo _expected, _description] call _assert;
} forEach [
    [[1,0,true], 4, true, true, "sprint", "grounded forward sprint spends reserve"],
    [[1,0,false], 4, true, true, "hold", "Shift release stops drain through the sprint blend"],
    [[1,0,true], 2, true, true, "sprint", "a steep climb spends reserve at jog ground speed"],
    [[1,0,true], 0, true, true, "sprint", "grounded allowed sprint effort at zero ground speed"],
    [[1,0,false], 3, true, true, "hold", "ordinary jog holds reserve"],
    [[0,1,false], 2, true, true, "hold", "sideways movement holds reserve"],
    [[0,0,false], 2, true, true, "hold", "coasting does not regenerate"],
    [[0,0,false], 0, true, true, "rest", "standing still regenerates reserve"],
    [[0,0,false], 0, true, false, "hold", "airborne motion never counts as resting"],
    [[1,0,true], 4, false, true, "hold", "movement locks prevent sprint drain"]
];

{
    _x params ["_grade", "_enabled", "_expected"];
    [[_grade, _enabled, 4, 35, 2.10] call GAIT_fnc_sprintReserveGradeMultiplier, _expected,
        format ["grade %1 degrees with uphill drain enabled %2", _grade, _enabled]] call _close;
} forEach [[0,true,1], [4,true,1], [5,true,1.006373], [10,true,1.093665], [20,true,1.407878],
    [25,true,1.613309], [35,true,2.10], [70,true,2.10], [35,false,1], [-5,true,0.934001],
    [-13,true,0.80], [-18,true,0.80], [-25,true,0.833359], [-40,true,0.981964], [-45,true,1]];

private _uphill = [25, true, 4, 35, 2.10] call GAIT_fnc_sprintReserveGradeMultiplier;
{
    _x params ["_mass", "_flat"];
    [[_mass, 1] call GAIT_fnc_sprintReserveDrainRate, _flat, format ["flat reserve load at %1 lb", _mass]] call _close;
    [[_mass, _uphill] call GAIT_fnc_sprintReserveDrainRate, _flat * _uphill,
        format ["uphill and gear costs multiply at %1 lb", _mass]] call _close;
} forEach [[0,1], [70,1.03861], [110,1.14528], [120,1.19], [150,1.5]];
private _lastRate = 1;
for "_load" from 0 to 200 do {
    private _rate = [_load, 1] call GAIT_fnc_sprintReserveDrainRate;
    [_rate >= _lastRate && {_rate - _lastRate < 0.015}, "load changes drain continuously"] call _assert;
    _lastRate = _rate;
};
[[150, _uphill, 0, 0] call GAIT_fnc_sprintReserveDrainRate, 1, "ACE can disable the load and terrain terms"] call _close;
private _normalCost = [150, _uphill, 1, 1] call GAIT_fnc_sprintReserveDrainRate;
[([150, _uphill, 2, 1] call GAIT_fnc_sprintReserveDrainRate) > _normalCost, "ACE load factor above one increases drain"] call _assert;
[([150, _uphill, 1, 2] call GAIT_fnc_sprintReserveDrainRate) > _normalCost, "ACE gradient factor above one increases climb drain"] call _assert;
[[0, 0.80, 1, 0] call GAIT_fnc_sprintReserveDrainRate, 1, "ACE terrain factor zero disables downhill relief"] call _close;
[[0, 0.80, 1, 5] call GAIT_fnc_sprintReserveDrainRate, 0.80, "high ACE gradient factor cannot flatten descent drain"] call _close;

private _heavyRate = [110, 1] call GAIT_fnc_sprintReserveDrainRate;
private _remaining = [60, "sprint", 15, 60, 10, _heavyRate] call GAIT_fnc_stepFallbackSprintReserve;
[_remaining, 45.885943, "110 lb has a gradual onset to depletion"] call _close;
private _jogged = [_remaining, "hold", 90, 60, 10, _heavyRate] call GAIT_fnc_stepFallbackSprintReserve;
[_jogged isEqualTo _remaining, "jogging neither spends nor restores fallback reserve"] call _assert;
[([_jogged, "rest", 10, 60, 10, _heavyRate] call GAIT_fnc_stepFallbackSprintReserve) isEqualTo 60,
    "stationary recovery refills fallback reserve to its cap"] call _assert;
private _lightWalkShare = [20] call GAIT_fnc_walkRecoveryShare;
private _heavyWalkShare = [120] call GAIT_fnc_walkRecoveryShare;
private _patientWalkShare = [120, true] call GAIT_fnc_walkRecoveryShare;
[_lightWalkShare <= 0.19 && {_lightWalkShare > _heavyWalkShare} &&
    {_heavyWalkShare > _patientWalkShare} && {_patientWalkShare > 0},
    "walking restores a small weight-scaled share, reduced with a patient"] call _assert;
[[30, "walk", 1, 60, 10, 0, _lightWalkShare] call GAIT_fnc_stepFallbackSprintReserve, 30 + 6 * _lightWalkShare,
    "walking uses a share of the existing fallback recovery rate"] call _close;
[([[1,0,false],1.3,false,true,"",true] call GAIT_fnc_sprintReserveActivity) isEqualTo "walk" &&
    {([[1,0,false],1.3,false,true,"",false] call GAIT_fnc_sprintReserveActivity) isEqualTo "hold"} &&
    {([[0,0,false],1.3,false,true,"",true] call GAIT_fnc_sprintReserveActivity) isEqualTo "hold"} &&
    {([[1,0,true],1.3,true,true,"",true] call GAIT_fnc_sprintReserveActivity) isEqualTo "sprint"},
    "only commanded walking earns walking recovery, and sprint still takes priority"] call _assert;

{
    _x params ["_mass", "_slope", "_expectedDuration"];
    private _grade = [_slope, true, 4, 35, 2.10] call GAIT_fnc_sprintReserveGradeMultiplier;
    private _rate = [_mass, _grade] call GAIT_fnc_sprintReserveDrainRate;
    private _emptyAt = 60 / _rate;
    [_emptyAt, _expectedDuration, format ["%1 lb on a %2 degree slope reaches empty after %3 s", _mass, _slope, _expectedDuration], 0.05] call _close;
    private _almostEmpty = [60, "sprint", _emptyAt - 0.25, 60, 10, _rate] call GAIT_fnc_stepFallbackSprintReserve;
    [_almostEmpty > 0 && {_almostEmpty < 1}, "sustained effort still drains just before empty"] call _assert;
    private _empty = [_almostEmpty, "sprint", 0.25, 60, 10, _rate] call GAIT_fnc_stepFallbackSprintReserve;
    [_empty isEqualTo 0, "continuous fallback effort exhausts its full budget"] call _assert;
} forEach [[0, 0, 60], [110, 0, 52.39], [110, 5, 52.06], [110, 10, 47.90], [110, 25, 32.47],
    [110, 35, 24.95], [110, -15, 65.49], [110, -35, 55.85], [110, -45, 52.39]];

private _aceCapacity = [55] call GAIT_fnc_aceSprintCapacitySeconds;
[_aceCapacity, 60, "ACE default performance factor gives a 60 second base budget"] call _close;
[[35] call GAIT_fnc_aceSprintCapacitySeconds, 60 * 35 / 55, "ACE lowest Performance Factor still has finite capacity"] call _close;
[[235] call GAIT_fnc_aceSprintCapacitySeconds, 60 * 235 / 55, "ACE highest Performance Factor still has finite capacity"] call _close;
private _early = [2300, 2300, 1, 0, 1, _aceCapacity] call GAIT_fnc_aceSprintReserveDelta;
private _half = [2300, 2300, 30, 0, 30, _aceCapacity] call GAIT_fnc_aceSprintReserveDelta;
private _later = [_half, _half, 1, 0, 1, _aceCapacity] call GAIT_fnc_aceSprintReserveDelta;
[_half, 1293.75, "cumulative sprint cost is curved with time"] call _close;
[_half - _later > 2300 - _early, "the same effort consumes more after sustained exertion"] call _assert;
[([_half, 0, 1, 0, 1, _aceCapacity] call GAIT_fnc_aceSprintReserveDelta) isEqualTo _later,
    "reserve drain ignores changes in ACE speed-derived debit and aerobic surplus"] call _assert;
[[1100, 1095, 0, 1, 1, _aceCapacity] call GAIT_fnc_aceSprintReserveDelta, 1100, "rest cannot drain reserve"] call _close;
[[1100, 1125, 0, 1, 1, _aceCapacity] call GAIT_fnc_aceSprintReserveDelta, 1125, "rest uses ACE's actual recovery"] call _close;
[[1100, 1125, 0, 0, 1, _aceCapacity] call GAIT_fnc_aceSprintReserveDelta, 1100, "a jogging interval ignores native recovery"] call _close;
[[1100, 930, 0, 0, 1, _aceCapacity] call GAIT_fnc_aceSprintReserveDelta, 1100, "a jogging interval ignores native debit"] call _close;
[[1100, 1125, 0, 0.2, 0.5, _aceCapacity] call GAIT_fnc_aceSprintReserveDelta, 1110,
    "recovery is proportional to observed rest time"] call _close;
[[1100, 1125, 0.2, 0, 1, _aceCapacity] call GAIT_fnc_aceSprintReserveDelta,
    [1100, 2300, 0.2 / _aceCapacity] call GAIT_fnc_spendSprintReserve,
    "a short sprint still spends reserve if Shift is released before the ACE tick"] call _close;

{
    _x params ["_step", "_number"];
    private _reserve = 2300;
    for "_i" from 1 to _number do {
        _reserve = [_reserve, _reserve, _step, 0, _step, _aceCapacity] call GAIT_fnc_aceSprintReserveDelta;
    };
    [_reserve, _half, "equal time uses the same reserve across update intervals", 0.05] call _close;
    for "_i" from 1 to _number do {
        _reserve = [_reserve, _reserve, _step, 0, _step, _aceCapacity] call GAIT_fnc_aceSprintReserveDelta;
    };
    [_reserve, 0, "sustained effort empties the bar at the same time across update intervals", 0.05] call _close;
} forEach [[0.05,600], [0.25,120], [1,30], [2,15]];

private _weighted = [2300, 2300, 10 * _heavyRate + 8 * _heavyRate * _uphill, 0, 18, _aceCapacity] call GAIT_fnc_aceSprintReserveDelta;
private _split = [2300, 2300, 10 * _heavyRate, 0, 10, _aceCapacity] call GAIT_fnc_aceSprintReserveDelta;
_split = [_split, _split, 8 * _heavyRate * _uphill, 0, 8, _aceCapacity] call GAIT_fnc_aceSprintReserveDelta;
[_weighted, _split, "grade changes yield the same model whether split across ACE ticks or within one"] call _close;

GAIT_fnc_modeAllowsMovement = {true};
GAIT_fnc_aceAdvancedFatigueActive = {true};
GAIT_fnc_fatigueMovementContextEligible = {
    params ["_unit"];
    _unit isEqualTo player
};
private _otherUnit = "B_Soldier_F" createVehicle [0,0,0];
player setVariable ["ace_movement_totalLoad", 1100];
[player, "sprint", 0.20, 0] call GAIT_fnc_accumulateAceSprintEffort;
[player, "sprint", 0.25, 25] call GAIT_fnc_accumulateAceSprintEffort;
[player, "hold", 0.55, 0] call GAIT_fnc_accumulateAceSprintEffort;
[[2300, 2300, _otherUnit] call GAIT_fnc_filterAceSprintReserve, 2300,
    "a noncontrolled unit keeps its stock result"] call _close;
private _expectedEffort = _heavyRate * (0.20 + (0.25 * _uphill));
private _expectedReserve = [2300, 2300, _expectedEffort, 0, 1, _aceCapacity] call GAIT_fnc_aceSprintReserveDelta;
[[2300, 2300, player] call GAIT_fnc_filterAceSprintReserve, _expectedReserve,
    "queued time at different grades charges the controlled player after release"] call _close;
[[_expectedReserve, _expectedReserve, player] call GAIT_fnc_filterAceSprintReserve, _expectedReserve,
    "a second ACE tick cannot charge the same exertion twice"] call _close;
[player, "sprint", 0.25, 25] call GAIT_fnc_accumulateAceSprintEffort;
[] call GAIT_fnc_clearAceSprintEffort;
[[2300, 2300, player] call GAIT_fnc_filterAceSprintReserve, 2300,
    "reset discards pending exertion"] call _close;
[player, "rest", 0.20, 0] call GAIT_fnc_accumulateAceSprintEffort;
[player, "hold", 0.30, 0] call GAIT_fnc_accumulateAceSprintEffort;
[[1100, 1125, player] call GAIT_fnc_filterAceSprintReserve, 1110,
    "the ACE hook restores only the fraction spent resting"] call _close;
[player, "walk", 0.50, 0, 0, _lightWalkShare] call GAIT_fnc_accumulateAceSprintEffort;
[player, "hold", 0.50, 0] call GAIT_fnc_accumulateAceSprintEffort;
[[1100, 1140, player] call GAIT_fnc_filterAceSprintReserve, 1100 + 20 * _lightWalkShare,
    "walking recovery is a share of ACE's recovery, weighted by time walking"] call _close;
[player,"walk",0.5,0,0,_heavyWalkShare] call GAIT_fnc_accumulateAceSprintEffort;
[player,"hold",0.5,0] call GAIT_fnc_accumulateAceSprintEffort;
[[1100,1095,player] call GAIT_fnc_filterAceSprintReserve,1100 + 4 * _heavyWalkShare,
    "zero-surplus walking earns its weighted floor only for time walking"] call _close;
[[1100,1100,0,0.2,1,_aceCapacity,0.2,0] call GAIT_fnc_aceSprintReserveDelta,1100,
    "a disabled recovery factor disables the walking floor"] call _close;

private _lightRise = ["stance", 20, 1] call GAIT_fnc_stanceReserveDrainRate;
private _heavyRise = ["stance", 120, 1] call GAIT_fnc_stanceReserveDrainRate;
private _heavyCrouch = ["crouch", 120, 0] call GAIT_fnc_stanceReserveDrainRate;
[_heavyRise > _lightRise && {_heavyRise > _heavyCrouch}, "heavy prone rise costs more reserve than a light rise or crouch travel"] call _assert;
[([[0,0,false],0,false,true,"crouch"] call GAIT_fnc_sprintReserveActivity) isEqualTo "rest",
    "stationary crouch can recover reserve"] call _assert;
private _lower = [60,"stance",0.5,60,10,_heavyRise] call GAIT_fnc_stepFallbackSprintReserve;
[_lower < 60, "confirmed stance changes spend fallback reserve"] call _assert;
[player, "stance", 0.5, 0, _heavyRise] call GAIT_fnc_accumulateAceSprintEffort;
private _expectedStanceReserve = [2300, 2300, 0.5 * _heavyRise, 0, 0.5, _aceCapacity]
    call GAIT_fnc_aceSprintReserveDelta;
[[2300, 2300, player] call GAIT_fnc_filterAceSprintReserve, _expectedStanceReserve,
    "stance effort spends the same reserve through ACE"] call _close;

diag_log format ["GAIT TEST PASS: time-based exertion, multiplicative gear and terrain, and native ACE recovery (%1 checks)", _checks];
