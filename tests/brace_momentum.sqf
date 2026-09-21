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

// Ordinary movement from a true stop gets a separate shallow, finite step.
// Tier boundaries are inclusive and heavier kits are both deeper and longer.
private _walkProfiles = [];
{
    private _profile = [_x, [35,55,75]] call GAIT_fnc_walkStartBraceProfile;
    _walkProfiles pushBack _profile;
} forEach [20,45,65,90];
for "_i" from 0 to 2 do {
    private _lighter = _walkProfiles select _i;
    private _heavier = _walkProfiles select (_i + 1);
    [(_heavier select 0) > (_lighter select 0), "heavier walk brace lasts slightly longer"] call _assert;
    [(_heavier select 1) < (_lighter select 1), "heavier walk brace has a deeper first step"] call _assert;
};
[((_walkProfiles select 0) select 1) < 0.90, "lightest walk brace remains noticeable"] call _assert;
[((_walkProfiles select 3) select 1) >= 0.70, "heaviest walk brace stays bounded and non-annoying"] call _assert;
[(([35,[35,55,75]] call GAIT_fnc_walkStartBraceProfile) select 3) isEqualTo 0, "light boundary is inclusive"] call _assert;
[(([35.001,[35,55,75]] call GAIT_fnc_walkStartBraceProfile) select 3) isEqualTo 1, "medium begins above light boundary"] call _assert;
[(([55.001,[35,55,75]] call GAIT_fnc_walkStartBraceProfile) select 3) isEqualTo 2, "moderate begins above medium boundary"] call _assert;
[(([75.001,[35,55,75]] call GAIT_fnc_walkStartBraceProfile) select 3) isEqualTo 3, "heavy begins above moderate boundary"] call _assert;

{
    private _plan = [10, _x, [35,55,75]] call GAIT_fnc_walkStartBracePlan;
    private _profile = [_x, [35,55,75]] call GAIT_fnc_walkStartBraceProfile;
    private _duration = _profile select 0;
    private _low = _profile select 1;
    private _hold = _profile select 2;
    private _first = [_plan, 10] call GAIT_fnc_walkStartBraceSample;
    [abs ((_first select 0) - _low) < 0.00001 && {_first select 1}, "walk brace begins at its tier first-step factor"] call _assert;
    private _held = [_plan, 10 + (_duration * (_hold * 0.5))] call GAIT_fnc_walkStartBraceSample;
    [abs ((_held select 0) - _low) < 0.00001, "walk brace keeps a brief planted first step"] call _assert;
    private _mid = [_plan, 10 + (_duration * ((_hold + 1) * 0.5))] call GAIT_fnc_walkStartBraceSample;
    [(_mid select 0) > _low && {(_mid select 0) < 1} && {_mid select 1}, "walk brace recovers smoothly"] call _assert;
    private _end = [_plan, 10 + _duration] call GAIT_fnc_walkStartBraceSample;
    [_end select 0 isEqualTo 1 && {!(_end select 1)}, "walk brace reaches exact finite endpoint"] call _assert;
    private _timestamp = 10 + (_duration * 0.73);
    private _direct = [_plan, _timestamp] call GAIT_fnc_walkStartBraceSample;
    {
        private _hz = _x;
        for "_frame" from 0 to floor (_duration * _hz * 0.73) do {
            [_plan, 10 + (_frame / _hz)] call GAIT_fnc_walkStartBraceSample;
        };
        [([_plan, _timestamp] call GAIT_fnc_walkStartBraceSample) isEqualTo _direct,
            format ["walk brace is render-rate independent at %1 Hz", _hz]] call _assert;
    } forEach [20,30,60,144];
} forEach [20,45,65,90];

diag_log "GAIT TEST PASS: sprint brace momentum plus weight-scaled ordinary walk-start brace, finite recovery, tier bounds and render-rate independence";
