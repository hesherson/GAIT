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

// A finite Shift-release taper has already ended while W-only native jogging
// still travels faster than 2 m/s. That ordinary pace must eventually rearm a
// launch brace for every load rather than retaining sprint history forever.
{
    private _walkCoefficient = _x;
    private _jogState = ([_empty, true, true, 6, _walkCoefficient + 0.4,
        _walkCoefficient, 10, 0.05, 3, 2, 0.04] call GAIT_fnc_stepBraceMomentum) select 0;
    private _shortRetap = [_jogState, false, true, 5.6,
        _walkCoefficient + 0.2, _walkCoefficient, 10.10, 0.05, 3, 2, 0.04]
        call GAIT_fnc_stepBraceMomentum;
    [_shortRetap select 1, "moving re-tap during release retains momentum for every load"] call _assert;
    [!([true, _shortRetap select 1, false, false, false, true, false]
        call GAIT_fnc_shouldBrace), "short re-tap cannot add another launch brace"] call _assert;
    for "_i" from 1 to 110 do {
        private _elapsed = _i * 0.05;
        private _coefficient = _walkCoefficient;
        private _speedMS = 4;
        if (_elapsed < 0.5) then {
            _coefficient = _walkCoefficient + (0.4 * (1 - (_elapsed / 0.5)));
            _speedMS = 6 - (2 * (_elapsed / 0.5));
        };
        private _jog = [_jogState, false, true, _speedMS, _coefficient,
            _walkCoefficient, 10 + _elapsed, 0.05, 3, 2, 0.04]
            call GAIT_fnc_stepBraceMomentum;
        _jogState = _jog select 0;
        if (_elapsed < 4.9) then {
            [_jog select 1, "original grace and settle time protect a brief jog recovery"] call _assert;
        };
    };
    [!(_jogState select 0), "settled W-only jog at 4 m/s rearms a launch brace"] call _assert;
    [[true, _jogState select 0, false, false, false, true, false]
        call GAIT_fnc_shouldBrace, "next sprint from settled jog braces again"] call _assert;
} forEach [0.93, 0.89, 0.78];

// Ongoing uphill sprint can have both a low coefficient and low physical
// speed; neither is evidence that the player released sprint and settled.
private _uphillState = _running select 0;
for "_i" from 1 to 120 do {
    private _uphill = [_uphillState, true, true, 1.2, 0.35, 0.70,
        10 + _i * 0.05, 0.05, 3, 2, 0.04] call GAIT_fnc_stepBraceMomentum;
    _uphillState = _uphill select 0;
    [_uphill select 1, "continuing steep sprint cannot rearm from its low coefficient"] call _assert;
};
private _unsafe = [_running select 0, true, false, 5.5, 1.20, 0.86, 11, 0.05, 3, 2, 0.04] call GAIT_fnc_stepBraceMomentum;
[!(_unsafe select 1), "medical/vehicle/disabled context cannot retain motion ownership"] call _assert;
private _wall = [_empty, true, true, 0, 1.28, 0.86, 11, 0.05, 3, 2, 0.04] call GAIT_fnc_stepBraceMomentum;
[!(_wall select 1), "held sprint against wall does not earn momentum"] call _assert;
[!([false, false, true, true, true, true, true] call GAIT_fnc_shouldBrace), "disabled brace stays disabled"] call _assert;
diag_log "GAIT TEST PASS: walking and settled native-jog brace, moving re-tap veto, continuing uphill protection, crouch veto, stop/rearm, grace and unsafe contexts";
