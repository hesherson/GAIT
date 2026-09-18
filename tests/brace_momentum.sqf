// Execute after the actual fn_braceMomentum.sqf definitions.
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {throw format ["FAIL: %1", _label];};
};
private _empty = [false, -999, 0, 0];
private _first = [_empty, false, true, 1.3, 0.86, 0.86, 10, 0.05, 3, 2, 0.04] call GAIT_fnc_stepBraceMomentum;
[!(_first select 1), "first walk-to-sprint press has no fabricated momentum"] call _assert;
[[true, _first select 1, false, false, false, true, false] call GAIT_fnc_shouldBrace, "ordinary walking start braces"] call _assert;
private _running = [_empty, true, true, 3.5, 0.70, 0.86, 10, 0.05, 3, 2, 0.04] call GAIT_fnc_stepBraceMomentum;
[_running select 1, "actual uphill sprint establishes momentum below flat walk coefficient"] call _assert;
private _retap = [_running select 0, false, true, 3.0, 0.65, 0.86, 11, 0.05, 3, 2, 0.04] call GAIT_fnc_stepBraceMomentum;
[_retap select 1, "moving uphill re-tap keeps momentum"] call _assert;
{
    private _causes = [false, false, false, false, false];
    _causes set [_x, true];
    private _args = [true, true] + _causes;
    [!(_args call GAIT_fnc_shouldBrace), format ["momentum veto covers trigger %1", _x]] call _assert;
} forEach [0,1,2,3,4];
private _brief = [_running select 0, false, true, 0, 0.7, 0.86, 10.05, 0.05, 3, 2, 0.04] call GAIT_fnc_stepBraceMomentum;
[_brief select 1, "single zero-velocity frame does not erase motion history"] call _assert;
private _stopState = _running select 0;
for "_i" from 1 to 4 do {
    private _stop = [_stopState, false, true, 0, 0.7, 0.86, 10 + _i * 0.05, 0.05, 3, 2, 0.04] call GAIT_fnc_stepBraceMomentum;
    _stopState = _stop select 0;
};
[!(_stopState select 0), "actual stop clears momentum within the old grace window"] call _assert;
[[true, false, false, false, false, true, true] call GAIT_fnc_shouldBrace, "stopped hill restart can brace again"] call _assert;
private _settledState = _running select 0;
for "_i" from 1 to 110 do {
    private _walk = [_settledState, false, true, 1.5, 0.86, 0.86, 10 + _i * 0.05, 0.05, 3, 2, 0.04] call GAIT_fnc_stepBraceMomentum;
    _settledState = _walk select 0;
    if (_i < 60) then {[_walk select 1, "grace protects a moving recovery"] call _assert;};
};
[!(_settledState select 0), "sustained settled walking rearms brace"] call _assert;
private _fastRecovery = [_running select 0, false, true, 5.5, 1.20, 0.86, 30, 0.05, 3, 2, 0.04] call GAIT_fnc_stepBraceMomentum;
[_fastRecovery select 1, "unsettled running remains protected beyond grace"] call _assert;
private _fastLowCoefState = _running select 0;
for "_i" from 1 to 120 do {
    private _coast = [_fastLowCoefState, false, true, 5.5, 0.70, 0.86, 10 + _i * 0.05, 0.05, 3, 2, 0.04] call GAIT_fnc_stepBraceMomentum;
    _fastLowCoefState = _coast select 0;
    [_coast select 1, "high actual speed protects low-coefficient downhill coast"] call _assert;
};
private _unsafe = [_running select 0, true, false, 5.5, 1.20, 0.86, 11, 0.05, 3, 2, 0.04] call GAIT_fnc_stepBraceMomentum;
[!(_unsafe select 1), "medical/vehicle/disabled context cannot retain motion ownership"] call _assert;
private _wall = [_empty, true, true, 0, 1.28, 0.86, 11, 0.05, 3, 2, 0.04] call GAIT_fnc_stepBraceMomentum;
[!(_wall select 1), "held sprint against wall does not earn momentum"] call _assert;
[!([false, false, true, true, true, true, true] call GAIT_fnc_shouldBrace), "disabled brace stays disabled"] call _assert;
diag_log "GAIT TEST PASS: walking brace, uphill/downhill recovery veto, crouch veto, stop/rearm, grace and unsafe contexts";
