// Run after fn_gearInertia.sqf, fn_traversalHelpers.sqf and fn_uphillBrake.sqf.
// Tests response behavior across loads, custom thresholds, scheduler rates,
// long coasts and uphill precedence. Helpers cannot write animation or input.
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {throw format ["FAIL: %1", _label];};
};
private _epsilon = 0.00001;
private _light = [15] call GAIT_fnc_gearInertia;
private _medium = [55] call GAIT_fnc_gearInertia;
private _heavy = [100] call GAIT_fnc_gearInertia;
private _maximum = [125] call GAIT_fnc_gearInertia;
private _previous = [0] call GAIT_fnc_gearInertia;
for "_lbs" from 1 to 200 do {
    private _response = [_lbs] call GAIT_fnc_gearInertia;
    [(_response select 0) <= ((_previous select 0) + _epsilon), "more gear never accelerates faster"] call _assert;
    [(_response select 1) <= ((_previous select 1) + _epsilon), "more gear never decelerates faster"] call _assert;
    [(_response select 2) >= ((_previous select 2) - _epsilon), "more gear never gets a shorter coast"] call _assert;
    [(_response select 3) >= ((_previous select 3) - _epsilon), "more gear never gets a shorter launch brace"] call _assert;
    [(_response select 4) <= ((_previous select 4) + _epsilon), "more gear never gets extra brace relief"] call _assert;
    [(_response select 0) >= 0.619 && {(_response select 1) >= 0.599}, "extreme load retains a useful response"] call _assert;
    [(_response select 2) <= 1.451 && {(_response select 3) <= 1.281}, "extreme load cannot extend delay indefinitely"] call _assert;
    _previous = _response;
};
{
    private _below = [_x - 0.0001] call GAIT_fnc_gearInertia;
    private _above = [_x + 0.0001] call GAIT_fnc_gearInertia;
    for "_index" from 0 to 4 do {
        [abs ((_below select _index) - (_above select _index)) < 0.00002, "crossing a gear tier has no response jump"] call _assert;
    };
} forEach [35,55,75,100,125];
[[2000] call GAIT_fnc_gearInertia isEqualTo _maximum, "oversized load clamps at the heavy endpoint"] call _assert;
[[0] call GAIT_fnc_gearInertia isEqualTo ([-200] call GAIT_fnc_gearInertia), "negative load uses the unloaded endpoint"] call _assert;
private _custom = [90, [0.6,0.4,0.2,0.1], [20,40,90]] call GAIT_fnc_gearInertia;
[abs ((_custom select 4) - 0.1) < _epsilon, "custom heavy threshold preserves configured heavy brace relief"] call _assert;
private _customMedium = [40, [0.6,0.4,0.2,0.1], [20,40,90]] call GAIT_fnc_gearInertia;
[abs ((_customMedium select 4) - 0.2) < _epsilon, "custom middle threshold shifts relief with gear tiers"] call _assert;
private _invalid = [80, [8,-1], [75,35,0]] call GAIT_fnc_gearInertia;
[count _invalid isEqualTo 5 && {(_invalid select 4) >= 0} && {(_invalid select 4) <= 1}, "malformed thresholds and relief remain bounded"] call _assert;
[( [0,0.7] call GAIT_fnc_scaleInertiaRamp) isEqualTo 0, "zero response is preserved"] call _assert;
[( [1,0.7] call GAIT_fnc_scaleInertiaRamp) isEqualTo 1, "instant response is preserved"] call _assert;

private _accelerated = [];
private _decelerated = [];
{
    private _accelRamp = [0.05, _x select 0] call GAIT_fnc_scaleInertiaRamp;
    private _decelRamp = [0.05, _x select 1] call GAIT_fnc_scaleInertiaRamp;
    private _accelValue = 0.65;
    private _decelValue = 1.3;
    for "_i" from 1 to 20 do {
        _accelValue = [_accelValue,1.3,_accelRamp,0.05] call GAIT_fnc_stepSpeedCoefficient;
        _decelValue = [_decelValue,0.65,_decelRamp,0.05] call GAIT_fnc_stepSpeedCoefficient;
    };
    _accelerated pushBack _accelValue;
    _decelerated pushBack _decelValue;
    [_accelValue > 0.65 && {_accelValue < 1.3}, "one-second acceleration approaches without overshoot"] call _assert;
    [_decelValue > 0.65 && {_decelValue < 1.3}, "one-second deceleration approaches without overshoot"] call _assert;
} forEach [_light,_medium,_heavy];
[(_accelerated select 0) > (_accelerated select 1) && {(_accelerated select 1) > (_accelerated select 2)}, "same start/target produces light then medium then heavy acceleration"] call _assert;
[(_decelerated select 0) < (_decelerated select 1) && {(_decelerated select 1) < (_decelerated select 2)}, "same sprint release sheds light momentum first and heavy momentum last"] call _assert;

private _frameResults = [];
private _heavyRamp = [0.05, _heavy select 0] call GAIT_fnc_scaleInertiaRamp;
{
    private _dt = _x;
    private _speed = 0.65;
    for "_i" from 1 to round (1 / _dt) do {_speed = [_speed,1.3,_heavyRamp,_dt] call GAIT_fnc_stepSpeedCoefficient;};
    _frameResults pushBack _speed;
} forEach [0.01,0.02,0.05,0.1,0.2];
{[abs (_x - (_frameResults select 0)) < _epsilon, "load response is independent of normal tick interval"] call _assert;} forEach _frameResults;

private _lightWindow = [1,0.85,_light select 2] call GAIT_fnc_gearCoastWindow;
private _heavyWindow = [1,0.85,_heavy select 2] call GAIT_fnc_gearCoastWindow;
[(_lightWindow select 0) < (_heavyWindow select 0) && {(_lightWindow select 1) < (_heavyWindow select 1)}, "heavy release coast lasts longer than light"] call _assert;
[( [0,0.85,_heavy select 2] call GAIT_fnc_gearCoastWindow select 0) isEqualTo 0, "disabled hold is not reintroduced by gear"] call _assert;
private _extremeWindow = [1000,1000,1000] call GAIT_fnc_gearCoastWindow;
[_extremeWindow isEqualTo [3,4], "coast remains bounded under oversized settings"] call _assert;

// Use the actual exponential response after the actual finite taper target.
// A 125 lb kit must eventually reach walking pace without fabricated thrust.
private _window = [1,0.85,_maximum select 2] call GAIT_fnc_gearCoastWindow;
private _walk = 0.8;
private _releaseSpeed = 1.3;
private _speed = _releaseSpeed;
private _ramp = [0.05,_maximum select 1] call GAIT_fnc_scaleInertiaRamp;
for "_i" from 1 to 300 do {
    private _now = _i * 0.05;
    private _elapsedTaper = ((_now - (_window select 0)) / (_window select 1)) max 0 min 1;
    private _target = _walk + ((_releaseSpeed - _walk) * ((1 - _elapsedTaper) ^ 1.45));
    private _next = [_speed,_target,_ramp,0.05] call GAIT_fnc_stepSpeedCoefficient;
    [_next <= (_speed + _epsilon) && {_next >= (_walk - _epsilon)}, "long heavy coast monotonically settles without acceleration or overshoot"] call _assert;
    _speed = _next;
};
[abs (_speed - _walk) < 0.001, "even the heaviest coast returns to walking pace"] call _assert;
private _shallow = [0, _window select 0, _window select 1] call GAIT_fnc_uphillBrakeCoastWindow;
private _steep = [1, _window select 0, _window select 1] call GAIT_fnc_uphillBrakeCoastWindow;
[abs ((_shallow select 1) - ((_window select 0) + (_window select 1))) < _epsilon, "zero uphill brake preserves the gear coast"] call _assert;
[(_steep select 1) isEqualTo 0, "full uphill brake removes even the heaviest coast"] call _assert;

// A heavy release still has scalar momentum when its target taper finishes.
// It must keep the current family through that decay, including the next
// possible re-tap frame, but raw direction/stop changes remain authoritative.
private _tail = [true,false,true,false,true,true,1.12,0.8,13,12.68,false];
[_tail call GAIT_fnc_gearCoastActive, "heavy residual after the taper retains its existing sprint family"] call _assert;
{
    private _cancelled = +_tail;
    _cancelled set [_x select 0, _x select 1];
    [!(_cancelled call GAIT_fnc_gearCoastActive), _x select 2] call _assert;
} forEach [
    [0,false,"disabled coast cannot retain a family"],
    [1,true,"sprint re-tap resumes sprint ownership immediately"],
    [2,false,"forward release cannot use residual coast"],
    [3,true,"strafe intent cannot use residual coast"],
    [4,false,"walking without established sprint history cannot coast"],
    [5,false,"actual stop cannot retain a family"],
    [6,0.83,"settled walking coefficient ends family retention"],
    [8,18.69,"bounded residual tail expires even with remaining scalar momentum"],
    [9,-999,"cancelled taper cannot restart from an old coefficient"]
];
private _staleTaper = +_tail;
_staleTaper set [9,-999];
_staleTaper set [10,true];
[!(_staleTaper call GAIT_fnc_gearCoastActive), "stale active flag cannot revive a cancelled taper"] call _assert;
private _finished = +_tail;
_finished set [6,_speed];
_finished set [8,16];
[!(_finished call GAIT_fnc_gearCoastActive), "actual simulated coast releases after settling"] call _assert;
diag_log "GAIT TEST PASS: continuous gear response, tunable thresholds, heavy acceleration/bracing, finite coast, residual re-tap continuity, live stop/strafe priority and uphill priority";
