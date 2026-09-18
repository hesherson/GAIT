// Run after actual fn_slopeLocomotion.sqf definitions.
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {throw format ["FAIL: %1", _label];};
};
{
    _x params ["_args", "_expected", "_label"];
    [(_args call GAIT_fnc_uphillBrakeKeepsFamily) isEqualTo _expected, _label] call _assert;
} forEach [
    [["active", true, false, false, true], true, "prearm bridges render-before-scheduled release"],
    [["entering", true, false, false, true], true, "prearm covers observed entry blend"],
    [["active", true, false, false, false], false, "expired prearm releases normally"],
    [["native", true, false, false, true], false, "prearm cannot acquire a new body"],
    [["exiting", true, false, false, true], false, "prearm cannot reverse pending cleanup"],
    [["blocked", true, false, false, true], false, "prearm cannot restart failed entry"],
    [["active", false, true, true, true], false, "old-player metadata cannot own replacement body"],
    [["active", true, true, true, false], true, "published brake survives prearm expiry"],
    [["active", true, true, false, false], false, "expired brake cannot retain sprint family"]
];
// Existing state policy remains above the brake request: a medical or stance
// handoff still releases even if the brake's brief ownership window is live.
private _held = ["active", true, true, true, false] call GAIT_fnc_uphillBrakeKeepsFamily;
private _unsafe = ["active", _held, false, true, false, false, true] call GAIT_fnc_locomotionDecision;
[_unsafe isEqualTo "release", "brake does not override ineligible body context"] call _assert;
private _expired = ["active", false, true, true, false, false, true] call GAIT_fnc_locomotionDecision;
[_expired isEqualTo "release", "end of released-sprint brake exits before any sprint promotion"] call _assert;
diag_log "GAIT TEST PASS: bounded uphill release lease, same-unit ownership, expiry and medical handoff";
