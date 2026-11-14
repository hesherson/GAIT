private _unit = player;
private _failures = [];
private _assert = {
    params ["_condition", "_description"];
    if (!_condition) then {_failures pushBack _description;};
};

GAIT_testWalkToggle = true;
GAIT_testTemporaryWalkRun = false;
GAIT_testForcedWalk = false;
GAIT_testWalkWrites = [];
GAIT_fnc_readLocomotionWalkToggle = {GAIT_testWalkToggle};
GAIT_fnc_readTemporaryWalkRun = {GAIT_testTemporaryWalkRun};
GAIT_fnc_readLocomotionForcedWalk = {GAIT_testForcedWalk};
GAIT_fnc_nativeCoefficientLocal = {true};
GAIT_fnc_readNativeCoefficient = {params ["_unit"]; _unit getVariable ["GAIT_testWalkCoefficient", 1]};
GAIT_fnc_writeNativeCoefficient = {
    params ["_unit", "_coefficient"];
    _unit setVariable ["GAIT_testWalkCoefficient", _coefficient];
    GAIT_testWalkWrites pushBack _coefficient;
};
GAIT_fnc_clearReleaseMomentum = {params ["_unit"]; _unit setVariable ["GAIT_releaseMomentumState", []];};
GAIT_fnc_clearPaceHandoff = {
    params ["_unit"];
    if (!isNull _unit) then {_unit setVariable ["GAIT_paceHandoff", []];};
};
GAIT_fnc_nativeMovementEligible = {true};
GAIT_fnc_sampleReleaseCoefficient = {params ["_unit", "_coefficient"]; _coefficient};
missionNamespace setVariable ["GAIT_ss_vegetationDragEnabled", false];

[[_unit, false] call GAIT_fnc_nativeWalkRequested, "walk toggle selects native walk"] call _assert;
[!([_unit, true] call GAIT_fnc_nativeWalkRequested), "Turbo can sprint over the walk toggle"] call _assert;
GAIT_testTemporaryWalkRun = true;
[!([_unit, false] call GAIT_fnc_nativeWalkRequested), "temporary action can run over walk toggle"] call _assert;
GAIT_testWalkToggle = false;
[[_unit, false] call GAIT_fnc_nativeWalkRequested, "temporary action can select walk"] call _assert;
GAIT_testForcedWalk = true;
[[_unit, true] call GAIT_fnc_nativeWalkRequested, "engine forced walk wins even with Turbo"] call _assert;
GAIT_testForcedWalk = false;
_unit setVariable ["ace_common_effect_forceWalk", 4];
[[_unit, true] call GAIT_fnc_nativeWalkRequested, "ACE forced walk wins even with Turbo"] call _assert;

[_unit, 0.72, false] call GAIT_fnc_applyNativeMovement;
_unit setVariable ["GAIT_releaseMomentumState", ["release"]];
_unit setVariable ["GAIT_paceHandoff", ["handoff"]];
_unit setVariable ["GAIT_nativeStopPaceLease", ["stop"]];
_unit setVariable ["GAIT_stanceCarryCoefficient", ["stance"]];
_unit setVariable ["GAIT_locomotionPhase", "active"];
private _pace = [_unit, 0.65, false, true] call GAIT_fnc_applyNativeMovement;
[_pace isEqualTo 1 && {GAIT_testWalkWrites isEqualTo [0.72, 1]}, "selecting walk restores the prior native rate immediately"] call _assert;
[_unit getVariable ["GAIT_locomotionPhase", ""] isEqualTo "active", "pace relinquishment leaves body exit to live input"] call _assert;
{
    [(_unit getVariable [_x, [-1]]) isEqualTo [], "walk clears speed lease " + _x] call _assert;
} forEach ["GAIT_releaseMomentumState", "GAIT_paceHandoff", "GAIT_nativeStopPaceLease", "GAIT_stanceCarryCoefficient"];
private _writes = count GAIT_testWalkWrites;
[_unit, 0.99, false, true] call GAIT_fnc_applyNativeMovement;
[(count GAIT_testWalkWrites) isEqualTo _writes, "held walk never reacquires coefficient ownership"] call _assert;

_unit setVariable ["GAIT_testWalkCoefficient", 0.9];
[_unit, 1.03, false] call GAIT_fnc_applyNativeMovement;
_unit setVariable ["GAIT_testWalkCoefficient", 0.83];
_writes = count GAIT_testWalkWrites;
_pace = [_unit, 0.74, false, true] call GAIT_fnc_applyNativeMovement;
[_pace isEqualTo 0.83 && {(count GAIT_testWalkWrites) isEqualTo _writes}, "walk preserves a newer external coefficient"] call _assert;

if (_failures isNotEqualTo []) then {
    {diag_log ("GAIT native walk FAIL: " + _x);} forEach _failures;
    throw "GAIT native walk regression failed";
};
diag_log "GAIT native walk PASS: toggle, temporary action, Turbo, forced walk, coefficient restore, clean ownership and external writer.";
