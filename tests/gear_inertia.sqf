/* Load actual gearInertia, traversalHelpers and uphillBrake helpers first.
   Verify restored brace settings and finite response across loads, targets
   and scheduler rates. This does not simulate engine root motion. */
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {throw format ["FAIL: %1", _label];};
};
private _epsilon = 0.00001;
{
    _x params ["_weight", "_relief"];
    private _response = [_weight] call GAIT_fnc_gearInertia;
    [abs ((_response select 4) - _relief) < _epsilon, format ["original brace relief at %1 lb", _weight]] call _assert;
    [(_response select 3) isEqualTo 1, "original launch duration unchanged"] call _assert;
    [(_response select 1) isEqualTo 1, "no added load deceleration filter"] call _assert;
} forEach [[0,0.55],[35,0.55],[35.001,0.35],[55,0.35],[55.001,0.18],[75,0.18],[75.001,0],[125,0],[2000,0]];
{
    _x params ["_weight", "_relief"];
    private _custom = [_weight,[0.6,0.4,0.2,0.1],[20,40,90]] call GAIT_fnc_gearInertia;
    [abs ((_custom select 4) - _relief) < _epsilon,"custom tiers preserve inclusive original boundaries"] call _assert;
} forEach [[20,0.6],[20.001,0.4],[40,0.4],[40.001,0.2],[90,0.2],[90.001,0.1]];
private _invalid = [80,[8,-1],[75,35,0]] call GAIT_fnc_gearInertia;
[count _invalid isEqualTo 5 && {(_invalid select 4) >= 0} && {(_invalid select 4) <= 1},"invalid settings remain bounded"] call _assert;
private _lastAcceleration = 2;
private _lastDuration = 0;
private _maximum = [125] call GAIT_fnc_gearInertia;
for "_weight" from 0 to 200 do {
    private _response = [_weight] call GAIT_fnc_gearInertia;
    private _acceleration = _response select 0;
    [_acceleration >= 1 && {_acceleration <= 1.06001},"heavy keeps base acceleration with only small lighter boosts"] call _assert;
    [_acceleration <= (_lastAcceleration + _epsilon),"heavier gear does not accelerate faster"] call _assert;
    _lastAcceleration = _acceleration;
    private _window = [1,0.85,_response select 2] call GAIT_fnc_gearCoastWindow;
    [(_window select 0) isEqualTo 0,"saved sustain does not delay slowdown"] call _assert;
    [(_window select 1) > 0.26 && {(_window select 1) < 0.35},"default release settles in about a third of a second for all loads"] call _assert;
    [(_window select 1) >= (_lastDuration - _epsilon),"heavier release is slightly longer"] call _assert;
    _lastDuration = _window select 1;
};
[[2000] call GAIT_fnc_gearInertia isEqualTo _maximum,"extreme gear cannot add unbounded delay"] call _assert;
[[0] call GAIT_fnc_gearInertia isEqualTo ([-200] call GAIT_fnc_gearInertia),"negative load uses unloaded response"] call _assert;
{
    private _window = _x call GAIT_fnc_gearCoastWindow;
    [(_window select 0) isEqualTo 0,"all hold settings are ignored"] call _assert;
    [(_window select 1) >= 0.15 && {(_window select 1) <= 0.45},"custom response stays bounded and noninstant"] call _assert;
} forEach [[0,0.05,0.9],[3,4,1.15],[1000,1000,1000],[-100,-100,-100],[1,0.85,1]];

private _light = [15] call GAIT_fnc_gearInertia;
private _medium = [55] call GAIT_fnc_gearInertia;
private _heavy = [100] call GAIT_fnc_gearInertia;
[(_heavy select 0) isEqualTo 1 && {(_maximum select 0) isEqualTo 1},"heavy and extreme loads retain original acceleration rate"] call _assert;
private _accelerated = [];
{
    private _ramp = [0.05,_x select 0] call GAIT_fnc_scaleInertiaRamp;
    private _speed = 0.65;
    for "_i" from 1 to 20 do {_speed = [_speed,1.3,_ramp,0.05] call GAIT_fnc_stepSpeedCoefficient;};
    [_speed > 0.65 && {_speed < 1.3},"all loads continue building toward sprint"] call _assert;
    _accelerated pushBack _speed;
} forEach [_light,_medium,_heavy];
[(_accelerated select 0) > (_accelerated select 1) && {(_accelerated select 1) > (_accelerated select 2)},"load preserves modest buildup differences"] call _assert;
private _frames = [];
private _heavyRamp = [0.05,_heavy select 0] call GAIT_fnc_scaleInertiaRamp;
{
    private _dt = _x;
    private _speed = 0.65;
    for "_i" from 1 to round (1 / _dt) do {_speed = [_speed,1.3,_heavyRamp,_dt] call GAIT_fnc_stepSpeedCoefficient;};
    _frames pushBack _speed;
} forEach [0.01,0.02,0.05,0.1,0.2];
{[abs (_x - (_frames select 0)) < _epsilon,"buildup is independent of scheduler rate"] call _assert;} forEach _frames;

// Test the actual direct curve, including release during a sub-walk brace.
{
    private _response = [_x] call GAIT_fnc_gearInertia;
    private _duration = ([1,0.85,_response select 2] call GAIT_fnc_gearCoastWindow) select 1;
    {
        _x params ["_start","_walk"];
        private _goal = _start min _walk;
        private _previous = _start;
        private _first = [_start,_walk,_duration / 20,_duration,1.45] call GAIT_fnc_forwardCoastPace;
        if (_start > (_goal + 0.01)) then {
            [(_first select 0) < _start && {(_first select 0) > _goal},"first sample eases down without snapping"] call _assert;
        };
        for "_i" from 0 to 25 do {
            private _curve = [_start,_walk,(_i / 20) * _duration,_duration,1.45] call GAIT_fnc_forwardCoastPace;
            private _next = _curve select 0;
            [_next <= (_previous + _epsilon) && {_next >= (_goal - _epsilon)},"curve never accelerates or undershoots"] call _assert;
            if (_i >= 20) then {
                [abs (_next - _goal) < _epsilon && {!(_curve select 2)},"exact endpoint has no residual tail"] call _assert;
            };
            _previous = _next;
        };
        {
            private _dt = _x;
            private _late = (ceil (_duration / _dt)) * _dt;
            private _curve = [_start,_walk,_late + 0.001,_duration,1.45] call GAIT_fnc_forwardCoastPace;
            [abs ((_curve select 0) - _goal) < _epsilon && {!(_curve select 2)},"late tick consumes endpoint"] call _assert;
        } forEach [0.01,0.02,0.05,0.1,0.2];
    } forEach [[1.35,0.85],[0.4,0.75],[0.2,0.1],[0,0],[2,1.4]];
} forEach [0,15,35,35.001,55,55.001,75,100,125,2000];

// Old brace history and speed cannot keep a family after its finite curve.
private _active = [true,false,true,false,true,true,1.12,0.8,10.2,10.49,true];
[_active call GAIT_fnc_gearCoastActive,"forward curve retains current family"] call _assert;
private _diagonal = +_active;
_diagonal set [3,true];
[_diagonal call GAIT_fnc_gearCoastActive,"W with A or D keeps response and direction"] call _assert;
{
    private _cancelled = +_active;
    _cancelled set [_x select 0,_x select 1];
    [!(_cancelled call GAIT_fnc_gearCoastActive),_x select 2] call _assert;
} forEach [
    [0,false,"disabled taper cannot retain family"],
    [1,true,"sprint re-tap resumes sprint immediately"],
    [2,false,"released W cannot retain coast"],
    [5,false,"actual stop cannot retain coast"],
    [8,10.49,"exact deadline ends retention"],
    [8,10.50,"residual speed cannot extend deadline"],
    [9,-999,"cancelled curve cannot revive from history"],
    [10,false,"history without live curve cannot coast"]
];
private _window = [1,0.85,_maximum select 2] call GAIT_fnc_gearCoastWindow;
private _flat = [0,_window select 0,_window select 1] call GAIT_fnc_uphillBrakeCoastWindow;
private _steep = [1,_window select 0,_window select 1] call GAIT_fnc_uphillBrakeCoastWindow;
[abs ((_flat select 1) - (_window select 1)) < _epsilon,"flat release keeps short curve"] call _assert;
[(_steep select 1) isEqualTo 0,"full uphill brake removes coast"] call _assert;
diag_log "GAIT TEST PASS: original tier brace relief and duration; modest acceleration; finite forward and diagonal release; no hold or tail; late tick completion; stop/retap cancellation; uphill priority";
