// Numerical uphill braking must not delay the native jog animation handoff.
// Run after actual fn_slopeLocomotion.sqf definitions.
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {throw format ["FAIL: %1", _label];};
};
private _release = [true, false, true] call GAIT_fnc_locomotionIntent;
[!_release, "released Turbo immediately ends animation ownership during numerical uphill brake"] call _assert;
private _action = ["active", _release, true, true, false, false, true] call GAIT_fnc_locomotionDecision;
[_action isEqualTo "release", "uphill numerical brake begins graph release promptly"] call _assert;
private _unsafe = ["active", true, false, true, false, false, true] call GAIT_fnc_locomotionDecision;
[_unsafe isEqualTo "release", "brake cannot override medical or stance restrictions"] call _assert;
private _reenter = ["exiting", true, true, true, true, true] call GAIT_fnc_locomotionResumeDecision;
[_reenter, "safe re-press may replace brake-release graph request once"] call _assert;
private _deferred = ["exiting", true, false, true, true, true] call GAIT_fnc_locomotionResumeDecision;
[!_deferred, "re-press cannot overtake an unissued unsafe cleanup"] call _assert;
diag_log "GAIT TEST PASS: numerical uphill brake releases animation immediately; safe edge re-press and medical handoff";
