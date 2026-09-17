// Run after fn_traversalHelpers.sqf in SQF-VM, or execVM in an Arma test mission.
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {throw format ["FAIL: %1", _label];};
};
private _left = [0,0,1,0,1] call GAIT_fnc_resolveMovementInput;
[_left isEqualTo [0,-1,true], "A only has no forward movement"] call _assert;
private _right = [0,0,0,1,1] call GAIT_fnc_resolveMovementInput;
[_right isEqualTo [0,1,true], "A to D reverses on the next sample"] call _assert;
private _overlap = [1,0,1,1,1] call GAIT_fnc_resolveMovementInput;
[_overlap isEqualTo [1,0,true], "opposing strafes cancel while W remains held"] call _assert;
private _opposite = [1,1,0,0,1] call GAIT_fnc_resolveMovementInput;
[_opposite isEqualTo [0,0,true], "W and S cancel"] call _assert;
private _diagonal = [1,0,1,0,1] call GAIT_fnc_resolveMovementInput;
[abs (((_diagonal select 0)^2 + (_diagonal select 1)^2) - 1) < 0.00001, "diagonal magnitude is one"] call _assert;
private _analog = [0.4,0,0,0.3,0] call GAIT_fnc_resolveMovementInput;
[_analog isEqualTo [0.4,0.3,false], "analog magnitude below one is preserved"] call _assert;
private _deadzone = [0.03,0,0.02,0,0] call GAIT_fnc_resolveMovementInput;
[_deadzone isEqualTo [0,0,false], "input deadzone"] call _assert;
private _results = [];
{
    private _dt = _x;
    private _value = 0.6;
    for "_i" from 1 to round (1 / _dt) do {
        _value = [_value,1.2,0.05,_dt] call GAIT_fnc_stepSpeedCoefficient;
    };
    _results pushBack _value;
} forEach [0.01,0.02,0.05,0.1,0.2];
{[abs (_x - (_results select 0)) < 0.00001, "one-second ramp independent of update interval"] call _assert;} forEach _results;
private _decel = [1.2,0.6,0.05,0.05] call GAIT_fnc_stepSpeedCoefficient;
[_decel < 1.2 && {_decel > 0.6}, "deceleration is monotonic without overshoot"] call _assert;
private _stalled = [0.6,1.2,0.05,4] call GAIT_fnc_stepSpeedCoefficient;
private _bounded = [0.6,1.2,0.05,0.2] call GAIT_fnc_stepSpeedCoefficient;
[abs (_stalled - _bounded) < 0.00001, "scheduler stall cannot skip the full ramp"] call _assert;
diag_log "GAIT TEST PASS: input cancellation, reversal, diagonals, analog input and time-based ramp";
