private _assert = {params ["_ok", "_label"]; if (!_ok) then {throw ("FAIL " + _label);};};
private _state = [];
private _accepted = -1;
for "_i" from 0 to 50 do {
    private _r = [_state, ["jog", "surface"], _i * 0.05, 4, 0.86, true] call GAIT_fnc_paceObservationStep;
    _state = _r select 0;
    if ((_r select 1) > 0) then {_accepted = _r select 1;};
};
[_accepted isEqualTo 4, "stable movement yields observed coefficient-one reference"] call _assert;
{
    private _r = [_state, _x select 0, 2.55, _x select 1, _x select 2, _x select 3] call GAIT_fnc_paceObservationStep;
    [(_r select 1) < 0, "changed clip, speed, coefficient and unsafe context cannot publish measurement"] call _assert;
} forEach [[["other"],4,0.86,true],[["jog","surface"],2,0.86,true],[["jog","surface"],4,0.5,true],[["jog","surface"],4,0.86,false]];
private _cache = [[["clip","file",1,"character","pistol","ground"],4,0,10]];
private _key = ["clip","file",1,"character","pistol","ground"];
[([_cache,_key,0,11] call GAIT_fnc_lookupPaceReference) isEqualTo 4,"exact measured context can be reused"] call _assert;
[([_cache,_key,3,11] call GAIT_fnc_lookupPaceReference) < 0,"different grade requires fresh measurement"] call _assert;
[([_cache,_key,0,611] call GAIT_fnc_lookupPaceReference) < 0,"stale sample is rejected"] call _assert;
[([_cache,_key,0,9] call GAIT_fnc_lookupPaceReference) < 0,"future sample is rejected"] call _assert;

private _profileResolved = [0.8, 0.4, 2.4, 3.0, true];
private _profileReference = [_profileResolved, 9] call GAIT_fnc_resolveMovingPaceReference;
[abs (_profileReference - 7.5) < 0.00001, "complete profile reference takes precedence over passive cache"] call _assert;
private _fallbackResolved = [0.8, 1.1, -1, -1, false];
[abs (([_fallbackResolved, 4.2] call GAIT_fnc_resolveMovingPaceReference) - 4.2) < 0.00001,
    "passive exact-clip reference activates physical target without full profile"] call _assert;
[([_fallbackResolved, -1] call GAIT_fnc_resolveMovingPaceReference) < 0,
    "missing profile and passive evidence retain coefficient-only fallback"] call _assert;
for "_i" from 0 to 5 do {
    private _changed = +_key;
    _changed set [_i,"changed"];
    [([_cache,_changed,0,11] call GAIT_fnc_lookupPaceReference) < 0,"clip/config/character/weapon/surface changes cannot reuse reference"] call _assert;
};
diag_log "GAIT TEST PASS: passive pace reference stability, validity, scope and moving pace resolution.";
