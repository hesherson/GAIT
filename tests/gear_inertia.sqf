/* Load actual gearInertia, traversalHelpers and uphillBrake helpers first.
   Verify restored brace settings and finite response across loads, targets
   and scheduler rates. This does not simulate engine root motion. */
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {throw format ["FAIL: %1", _label];};
};
private _epsilon = 0.00001;
[!([0.4,0.8] call GAIT_fnc_hasReleaseExcess),"sub-walk brace release has no deceleration coast"] call _assert;
[!([0.8,0.8] call GAIT_fnc_hasReleaseExcess),"already settled movement does not start a coast"] call _assert;
[[1.2,0.8] call GAIT_fnc_hasReleaseExcess,"built sprint keeps finite deceleration"] call _assert;
private _earlyReleaseRamp = [0.4,0.8,0.05,0.05] call GAIT_fnc_stepSpeedCoefficient;
[_earlyReleaseRamp > 0.4 && {_earlyReleaseRamp < 0.8},"early brace release resumes ordinary movement smoothly with no hold or snap"] call _assert;
// Every release starts from the latest rendered sample, including partially
// accelerated, exhausted and downhill sprint. Vegetation was already applied
// when the sample was read: undo it once before the normal writer reapplies it.
{
    _x params ["_applied", "_drag", "_planned", "_actualMS", "_expected"];
    private _sample = [[10, _applied, _actualMS, _drag], 10.05, _planned, 99] call GAIT_fnc_releasePaceSnapshot;
    [abs ((_sample select 1) - _expected) < _epsilon, "release preserves consistent coefficient space"] call _assert;
    [(_sample select 0) isEqualTo 10 && {(_sample select 2) isEqualTo _actualMS}, "release keeps input-edge time and actual velocity"] call _assert;
    private _start = [_sample select 1, 0.8, 0, 0.3, 1.45] call GAIT_fnc_forwardCoastPace;
    [abs ((_start select 0) - _expected) < _epsilon, "release begins at current pace without promoting to full sprint"] call _assert;
} forEach [[0.4,0,0.4,1.2,0.4], [0.85,0,0.85,3,0.85], [1.6,0.2,2,7,2], [1.1,0,0.9,4,0.9]];
{
    private _sample = [_x, 10, 0.75, 3] call GAIT_fnc_releasePaceSnapshot;
    [_sample isEqualTo [10,0.75,3], "missing/stale/future sample falls back to current pace"] call _assert;
} forEach [[],[9,2,8,0],[11,2,8,0],[10,0,8,0],[10,2,-1,0]];
// A second release during a retap ramps from the pace actually retained at
// that second release. It cannot revive the first release's faster origin.
private _firstRelease = [1.8,0.8,0.12,0.3,1.45] call GAIT_fnc_forwardCoastPace;
private _resumed = [_firstRelease select 0,2,0.05,0.05] call GAIT_fnc_stepSpeedCoefficient;
private _secondRelease = [[11,_resumed,5,0],11,_resumed,5] call GAIT_fnc_releasePaceSnapshot;
private _secondStart = [_secondRelease select 1,0.8,0,0.3,1.45] call GAIT_fnc_forwardCoastPace;
[abs ((_secondStart select 0)-_resumed) < _epsilon && {_resumed < 1.8},"retap hysteresis never resurrects earlier sprint pace"] call _assert;
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
    [_acceleration >= 1 && {_acceleration <= 1.06001},"heavy gains a small 2% acceleration boost with bounded lighter rates"] call _assert;
    [_acceleration <= (_lastAcceleration + _epsilon),"heavier gear does not accelerate faster"] call _assert;
    _lastAcceleration = _acceleration;
    private _window = [1,0.85,_response select 2] call GAIT_fnc_gearCoastWindow;
    [(_window select 0) isEqualTo 0,"saved sustain does not delay slowdown"] call _assert;
    [(_window select 1) >= (0.765 - _epsilon) && {(_window select 1) <= (0.978 + _epsilon)},"default release uses the slower tier-scaled window for all loads"] call _assert;
    [(_window select 1) >= (_lastDuration - _epsilon),"heavier release is slightly longer"] call _assert;
    _lastDuration = _window select 1;
};
[[2000] call GAIT_fnc_gearInertia isEqualTo _maximum,"extreme gear cannot add unbounded delay"] call _assert;
[[0] call GAIT_fnc_gearInertia isEqualTo ([-200] call GAIT_fnc_gearInertia),"negative load uses unloaded response"] call _assert;
{
    private _window = _x call GAIT_fnc_gearCoastWindow;
    [(_window select 0) isEqualTo 0,"all hold settings are ignored"] call _assert;
    [(_window select 1) >= 0.35 && {(_window select 1) <= 1.20},"custom response stays bounded and noninstant"] call _assert;
} forEach [[0,0.05,0.9],[3,4,1.15],[1000,1000,1000],[-100,-100,-100],[1,0.85,1]];

private _light = [15] call GAIT_fnc_gearInertia;
private _medium = [55] call GAIT_fnc_gearInertia;
private _heavy = [100] call GAIT_fnc_gearInertia;
[(_heavy select 0) isEqualTo 1.02 && {(_maximum select 0) isEqualTo 1.02},"heavy and extreme loads use only a 2% faster acceleration rate"] call _assert;
private _accelerated = [];
{
    private _ramp = [0.05,_x select 0] call GAIT_fnc_scaleInertiaRamp;
    private _speed = 0.65;
    for "_i" from 1 to 20 do {_speed = [_speed,1.3,_ramp,0.05] call GAIT_fnc_stepSpeedCoefficient;};
    [_speed > 0.65 && {_speed < 1.3},"all loads continue building toward sprint"] call _assert;
    _accelerated pushBack _speed;
} forEach [_light,_medium,_heavy];
[(_accelerated select 0) > (_accelerated select 1) && {(_accelerated select 1) >= (_accelerated select 2)},"load preserves modest buildup differences"] call _assert;
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

// Upward sprint acceleration is deliberately slower than generic movement.
private _genericRamp = [0.05, 1] call GAIT_fnc_scaleInertiaRamp;
private _sprintRamp = [0.05, 1] call GAIT_fnc_sprintAccelerationRamp;
[_sprintRamp < _genericRamp && {_sprintRamp > 0}, "sprint acceleration rate is slower but positive"] call _assert;
private _generic95 = ln 0.05 / ln (1 - _genericRamp) * 0.05;
private _sprint95 = ln 0.05 / ln (1 - _sprintRamp) * 0.05;
[_generic95 > 2.8 && {_generic95 < 3.1}, "default generic ramp remains about three seconds to 95 percent"] call _assert;
[_sprint95 > 4.0 && {_sprint95 < 4.4}, "default sprint acceleration stretches to about 4.1 seconds to 95 percent"] call _assert;
[_sprint95 > (_generic95 * 1.35), "sprint acceleration is materially slower than generic movement"] call _assert;

diag_log "GAIT TEST PASS: original sprint brace relief; modest acceleration; slower finite forward and diagonal release; no hold or tail; late tick completion; stop/retap cancellation; uphill priority";
