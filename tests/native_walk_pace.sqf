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
GAIT_testAnimation = "AmovPercMrunSrasWrflDf";
GAIT_fnc_readLocomotionWalkToggle = {GAIT_testWalkToggle};
GAIT_fnc_readTemporaryWalkRun = {GAIT_testTemporaryWalkRun};
GAIT_fnc_readLocomotionForcedWalk = {GAIT_testForcedWalk};
GAIT_fnc_readLocomotionAnimation = {GAIT_testAnimation};
GAIT_fnc_nativeCoefficientLocal = {true};
GAIT_fnc_readNativeCoefficient = {params ["_unit"]; _unit getVariable ["GAIT_testWalkCoefficient", 1]};
GAIT_fnc_writeNativeCoefficient = {
    params ["_unit", "_coefficient"];
    _unit setVariable ["GAIT_testWalkCoefficient", _coefficient];
    GAIT_testWalkWrites pushBack _coefficient;
};
GAIT_fnc_nativeMovementEligible = {true};
missionNamespace setVariable ["GAIT_ss_vegetationDragMax", 0];

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
_unit setVariable ["GAIT_nativeStopPaceLease", ["stop"]];
_unit setVariable ["GAIT_stanceCarryCoefficient", ["stance"]];
_unit setVariable ["GAIT_locomotionPhase", "active"];
private _pace = [_unit, 0.65, false, true] call GAIT_fnc_applyNativeMovement;
[_pace isEqualTo 1 && {GAIT_testWalkWrites isEqualTo [0.72, 1]}, "selecting walk restores the prior native rate immediately"] call _assert;
[_unit getVariable ["GAIT_locomotionPhase", ""] isEqualTo "active", "pace relinquishment leaves body exit to live input"] call _assert;
{
    [(_unit getVariable [_x, [-1]]) isEqualTo [], "walk clears speed lease " + _x] call _assert;
} forEach ["GAIT_nativeStopPaceLease", "GAIT_stanceCarryCoefficient"];
private _writes = count GAIT_testWalkWrites;
[_unit, 0.99, false, true] call GAIT_fnc_applyNativeMovement;
[(count GAIT_testWalkWrites) isEqualTo _writes, "held walk never reacquires coefficient ownership"] call _assert;

_unit setVariable ["GAIT_testWalkCoefficient", 0.9];
[_unit, 1.03, false] call GAIT_fnc_applyNativeMovement;
_unit setVariable ["GAIT_testWalkCoefficient", 0.83];
_writes = count GAIT_testWalkWrites;
_pace = [_unit, 0.74, false, true] call GAIT_fnc_applyNativeMovement;
[_pace isEqualTo 0.83 && {(count GAIT_testWalkWrites) isEqualTo _writes}, "walk preserves a newer external coefficient"] call _assert;

missionNamespace setVariable ["GAIT_ss_vegetationDragMax", 0.20];
missionNamespace setVariable ["GAIT_vegNextCheck", time + 10];
{
    _x params ["_animation", "_paceBeforeDrag", "_expected"];
    GAIT_testAnimation = _animation;
    missionNamespace setVariable ["GAIT_vegDragFactor", 0.20];
    [_unit, _paceBeforeDrag, false] call GAIT_fnc_applyNativeMovement;
    private _actual = [_unit] call GAIT_fnc_readNativeCoefficient;
    [abs (_actual - _expected) < 0.000001, "final playback coefficient for " + _animation] call _assert;
} forEach [
    ["AmovPercMwlkSlowWrflDf_ver2", 0.60, 0.89],
    ["AmovPknlMwlkSlowWpstDfl_GAIT", 0.92, 0.89],
    ["AmovPercMrunSlowWrflDf_GAIT_AmovPercMwlkSlowWrflDf_GAIT", 0.70, 0.89],
    ["AmovPercMtacSlowWrflDfr_ver2", 0.65, 0.89],
    ["AmovPknlMtacSrasWrflDf", 0.72, 0.89],
    ["AmovPercMtacSrasWrflDf", 1.20, 0.96],
    ["AmovPercMwlkSrasWrflDf", 0.75, 0.60],
    ["AmovPercMrunSlowWrflDf", 0.75, 0.60]
];

GAIT_testAnimation = "AmovPercMtacSrasWrflDf";
[_unit, 0.89, false, false, false, 1.05] call GAIT_fnc_applyNativeMovement;
[abs (([_unit] call GAIT_fnc_readNativeCoefficient) - (0.89 * 1.05)) < 0.000001,
    "light kit keeps a small combat-pace advantage at the vegetation floor"] call _assert;

GAIT_testAnimation = "AmovPercMrunSlowWrflDf";
missionNamespace setVariable ["GAIT_vegDragFactor", 0.75];
missionNamespace setVariable ["GAIT_ss_vegetationDragMax", 0.75];
[_unit, 1, false] call GAIT_fnc_applyNativeMovement;
[abs (([_unit] call GAIT_fnc_readNativeCoefficient) - 0.75) < 0.000001,
    "old high brush settings cannot exceed the new cap"] call _assert;
missionNamespace setVariable ["GAIT_ss_vegetationDragMax", 0];
[_unit, 1, false] call GAIT_fnc_applyNativeMovement;
[([_unit] call GAIT_fnc_readNativeCoefficient) isEqualTo 1, "zero disables brush slowdown immediately"] call _assert;

if (_failures isNotEqualTo []) then {
    {diag_log ("GAIT native walk FAIL: " + _x);} forEach _failures;
    throw "GAIT native walk regression failed";
};
diag_log "GAIT native walk PASS: toggle, temporary action, Turbo, forced walk, coefficient restore, clean ownership and external writer.";
