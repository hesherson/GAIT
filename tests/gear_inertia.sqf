/* Verify continuous gear acceleration and launch brace relief. */
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {throw format ["FAIL: %1", _label];};
};
private _epsilon = 0.00001;
private _carryLight = [20,false] call GAIT_fnc_patientBurden;
private _carryHeavy = [110,false] call GAIT_fnc_patientBurden;
private _dragHeavy = [110,true] call GAIT_fnc_patientBurden;
[_carryLight < _carryHeavy && {_dragHeavy < _carryHeavy} && {_dragHeavy > ([20,true] call GAIT_fnc_patientBurden)},
    "patient kit increases load for both carry and drag with reduced drag effort"] call _assert;
{
    _x params ["_weight", "_relief"];
    private _response = [_weight] call GAIT_fnc_gearInertia;
    [abs ((_response select 1) - _relief) < _epsilon, format ["interpolated brace relief at %1 lb", _weight]] call _assert;
} forEach [[0,0.55],[17.5,0.45],[35,0.35],[45,0.265],[55,0.18],[65,0.09],[75,0],[125,0],[2000,0]];
{
    _x params ["_weight", "_relief"];
    private _custom = [_weight,[0.6,0.4,0.2,0.1],[20,40,90]] call GAIT_fnc_gearInertia;
    [abs ((_custom select 1) - _relief) < _epsilon,"custom brace anchors interpolate"] call _assert;
} forEach [[20,0.4],[30,0.3],[40,0.2],[65,0.15],[90,0.1],[91,0.1]];
private _invalid = [80,[8,-1],[75,35,0]] call GAIT_fnc_gearInertia;
[count _invalid isEqualTo 2 && {(_invalid select 1) >= 0} && {(_invalid select 1) <= 1},"invalid settings remain bounded"] call _assert;
private _lastAcceleration = 2;
private _maximum = [125] call GAIT_fnc_gearInertia;
for "_weight" from 0 to 200 do {
    private _response = [_weight] call GAIT_fnc_gearInertia;
    private _acceleration = _response select 0;
    [_acceleration >= 0.71999 && {_acceleration <= 1.12001},"load acceleration stays bounded"] call _assert;
    [_acceleration <= (_lastAcceleration + _epsilon),"heavier gear does not accelerate faster"] call _assert;
    _lastAcceleration = _acceleration;
};
[[2000] call GAIT_fnc_gearInertia isEqualTo _maximum,"extreme gear cannot add unbounded delay"] call _assert;
[[0] call GAIT_fnc_gearInertia isEqualTo ([-200] call GAIT_fnc_gearInertia),"negative load uses unloaded response"] call _assert;
private _light = [15] call GAIT_fnc_gearInertia;
private _medium = [55] call GAIT_fnc_gearInertia;
private _heavy = [100] call GAIT_fnc_gearInertia;
[abs ((_heavy select 0) - 0.77) < _epsilon && {abs ((_maximum select 0) - 0.72) < _epsilon},"heavy and extreme loads accelerate more slowly"] call _assert;
private _accelerated = [];
{
    private _ramp = [0.05,_x select 0] call GAIT_fnc_scaleInertiaRamp;
    private _speed = 0.65;
    for "_i" from 1 to 20 do {_speed = [_speed,1.3,_ramp,0.05] call GAIT_fnc_stepSpeedCoefficient;};
    [_speed > 0.65 && {_speed < 1.3},"all loads continue building toward sprint"] call _assert;
    _accelerated pushBack _speed;
} forEach [_light,_medium,_heavy];
[(_accelerated select 0) > (_accelerated select 1) && {(_accelerated select 1) >= (_accelerated select 2)},"load preserves meaningful buildup differences"] call _assert;
private _frames = [];
private _heavyRamp = [0.05,_heavy select 0] call GAIT_fnc_scaleInertiaRamp;
{
    private _dt = _x;
    private _speed = 0.65;
    for "_i" from 1 to round (1 / _dt) do {_speed = [_speed,1.3,_heavyRamp,_dt] call GAIT_fnc_stepSpeedCoefficient;};
    _frames pushBack _speed;
} forEach [0.01,0.02,0.05,0.1,0.2];
{[abs (_x - (_frames select 0)) < _epsilon,"buildup is independent of scheduler rate"] call _assert;} forEach _frames;

// Upward sprint acceleration is deliberately slower than generic movement.
private _genericRamp = [0.05, 1] call GAIT_fnc_scaleInertiaRamp;
private _sprintRamp = [0.05, 1] call GAIT_fnc_sprintAccelerationRamp;
[_sprintRamp < _genericRamp && {_sprintRamp > 0}, "sprint acceleration rate is slower but positive"] call _assert;
private _genericValue = 0;
private _sprintValue = 0;
private _genericSteps = 0;
private _sprintSteps = 0;
while {_genericValue < 0.95 && {_genericSteps < 500}} do {
    _genericValue = _genericValue + ((1 - _genericValue) * _genericRamp);
    _genericSteps = _genericSteps + 1;
};
while {_sprintValue < 0.95 && {_sprintSteps < 500}} do {
    _sprintValue = _sprintValue + ((1 - _sprintValue) * _sprintRamp);
    _sprintSteps = _sprintSteps + 1;
};
private _generic95 = _genericSteps * 0.05;
private _sprint95 = _sprintSteps * 0.05;
[_generic95 > 2.8 && {_generic95 < 3.1}, "default generic ramp remains about three seconds to 95 percent"] call _assert;
[_sprint95 > 4.0 && {_sprint95 < 4.4}, "default sprint acceleration stretches to about 4.1 seconds to 95 percent"] call _assert;
[_sprint95 > (_generic95 * 1.35), "sprint acceleration is materially slower than generic movement"] call _assert;

private _stanceRested = [120, 1, 1] call GAIT_fnc_stancePaceCoefficient;
private _stanceDrained = [120, 0, 1] call GAIT_fnc_stancePaceCoefficient;
[_stanceRested > 0.85 && {_stanceRested < 0.88}, "120 lb has noticeable stance inertia at full reserve"] call _assert;
[_stanceDrained < _stanceRested && {_stanceDrained > 0.70}, "fatigue adds a bounded penalty to heavy stance moves"] call _assert;
[( [200, 0, 1] call GAIT_fnc_stancePaceCoefficient) isEqualTo 0.65, "the heaviest exhausted prone move keeps its 0.65 floor"] call _assert;
[( [150, 0, 0.85] call GAIT_fnc_stancePaceCoefficient) > 0.65, "crouching carries a smaller penalty than rising from prone"] call _assert;
diag_log "GAIT TEST PASS: continuous sprint brace relief, load-scaled acceleration and bounded stance pace.";
