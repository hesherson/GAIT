/* Load traversal, slope locomotion and native controller definitions first.
   Execute in SQF-VM; null owners avoid needing an Arma animation runtime. */
private _failures = [];
missionNamespace setVariable ["GAIT_nativeOwner", objNull];
missionNamespace setVariable ["GAIT_nativeLastWritten", -1];
missionNamespace setVariable ["GAIT_slopeOwner", objNull];

private _actualRelease = GAIT_fnc_releaseSlopeLocomotion;
GAIT_testReleaseArguments = [];
GAIT_fnc_releaseSlopeLocomotion = {
    GAIT_testReleaseArguments pushBack _this;
    _this call _actualRelease;
};
// Exercise full cleanup from ambient movement, callback and scalar arguments.
// This intentionally uses unary call at the outer test boundary, reproducing
// the caller environment. Internal cleanup must pass [] to its typed helper.
{
    _x call {call GAIT_fnc_releaseNativeMovement;};
} forEach [[objNull, 1.20, false], [objNull, 0.42, true], 0.05, "callback", []];
if !(GAIT_testReleaseArguments isEqualTo [[], [], [], [], []]) then {
    _failures pushBack format ["Cleanup arguments leaked: %1", GAIT_testReleaseArguments];
};
private _before = count GAIT_testReleaseArguments;
[objNull, 1.2, false] call {[] call GAIT_fnc_releaseSpeedCoefficient;};
if ((count GAIT_testReleaseArguments) != _before) then {
    _failures pushBack "Coefficient-only cleanup released the animation family";
};
GAIT_fnc_releaseSlopeLocomotion = _actualRelease;

private _source = "AmovPercMrunSrasWrflDf";
private _target = "AmovPercMevaSrasWrflDf_GAIT";
{
    _x params ["_animation", "_expected"];
    private _actual = [_animation, _source, _target] call GAIT_fnc_isStandingLocomotionBlend;
    if !(_actual isEqualTo _expected) then {_failures pushBack format ["Blend classification: %1", _animation];};
} forEach [
    ["AmovPercMrunSrasWrflDf_AmovPercMevaSrasWrflDf", true],
    ["AmovPercMrunSrasWrflDf_AmovPercMevaSrasWrflDf_GAIT", true],
    ["AmovPercMrunSrasWrflDf_GAIT_AmovPercMevaSrasWrflDf_GAIT", true],
    ["AmovPercMevaSrasWrflDf_GAIT_AmovPercMrunSrasWrflDl_GAITSprint", false],
    ["AmovPercMrunSrasWrflDf_AmovPknlMstpSrasWrflDnon", false],
    ["AmovPercMrunSrasWrflDf_AmovPpneMstpSrasWrflDnon", false],
    ["AmovPercMrunSrasWrflDf_AinvPknlMstpSnonWrflDnon_medic", false],
    ["AmovPercMrunSrasWrflDf_AmovPercMevaSrasWrflDf_reload", false],
    ["AmovPercMrunSrasWrflDf_AmovPercMevaSrasWrflDfr_GAIT", false],
    ["AmovPercMrunSrasWpstDf_AmovPercMevaSrasWrflDf_GAIT", false],
    ["AmovPercMevaSrasWrflDf_GAIT", false],
    ["AmovPercMrunSrasWrflDf_AmovPercMrunSrasWrflDl", false],
    ["AmovPercMrunSrasWrflDf_AmovPercMevaSrasWrflDf_GAIT_AmovPercMevaSrasWrflDf", false]
];

// Lowered-rifle walk/tactical _ver2 states already have graph edges. Their
// exact native suffix must survive validation into the brief brace state;
// unknown suffixes and near-matching source/target states remain rejected.
private _variantSource = "AmovPercMwlkSlowWrflDf_ver2";
private _braceTarget = "AmovPercMwlkSlowWrflDf_GAIT";
{
    _x params ["_animation", "_expected"];
    private _actual = [_animation, _variantSource, _braceTarget] call GAIT_fnc_isStandingLocomotionBlend;
    if (_actual isNotEqualTo _expected) then {_failures pushBack format ["Native variant brace blend classification: %1", _animation];};
} forEach [
    ["AmovPercMwlkSlowWrflDf_ver2_AmovPercMwlkSlowWrflDf_GAIT", true],
    ["AmovPercMwlkSlowWrflDf_ver2_AmovPercMwlkSlowWrflDf", true],
    ["AmovPercMwlkSlowWrflDf_AmovPercMwlkSlowWrflDf_GAIT", false],
    ["AmovPercMwlkSlowWrflDf_ver3_AmovPercMwlkSlowWrflDf_GAIT", false],
    ["AmovPercMwlkSlowWrflDf_ver2_AmovPercMwlkSlowWrflDfr_GAIT", false],
    ["AmovPercMwlkSlowWrflDf_ver2_AmovPknlMwlkSlowWrflDf_GAIT", false],
    ["AmovPercMwlkSlowWrflDf_ver2_AinvPknlMstpSnonWrflDnon_medic", false],
    ["AmovPercMwlkSlowWrflDf_ver2_AmovPercMwlkSlowWrflDf_GAIT_reload", false],
    ["AmovPercMwlkSlowWrflDf_ver2_AmovPercMwlkSlowWrflDf_GAIT_AmovPercMevaSlowWrflDf_GAIT", false]
];
{
    _x params ["_sourceState", "_expected"];
    private _actual = [_sourceState + "_" + _braceTarget, _sourceState, _braceTarget] call GAIT_fnc_isStandingLocomotionBlend;
    if (_actual isNotEqualTo _expected) then {_failures pushBack format ["Native variant whitelist: %1", _sourceState];};
} forEach [
    ["AmovPercMtacSlowWrflDfr_ver2",true],
    ["AmovPercMwlkSrasWrflDf_ver2",false],
    ["AmovPercMevaSlowWrflDf_ver2",false],
    ["AmovPercMwlkSlowWrflDnon_ver2",false],
    ["AmovPercMwlkSlowWrflDf_ver2_GAIT",false]
];

// Lowered pistol is now its own GAIT family. A native SlowWpst source must
// enter a SlowWpst custom state directly instead of converting through SrasWpst.
private _pistolLowSprint = "AmovPercMevaSlowWpstDf_GAIT";
private _loweredRun = "AmovPercMrunSlowWpstDf";
private _loweredIdle = "AmovPercMstpSlowWpstDnon";
{
    _x params ["_animation", "_sourceState", "_targetState", "_expected"];
    private _actual = [_animation, _sourceState, _targetState] call GAIT_fnc_isLocomotionHandoffBlend;
    if (_actual isNotEqualTo _expected) then {_failures pushBack format ["Lowered pistol same-pose handoff: %1", _animation];};
} forEach [
    [_loweredRun + "_" + _pistolLowSprint, _loweredRun, _pistolLowSprint, true],
    [_loweredIdle + "_" + _pistolLowSprint, _loweredIdle, _pistolLowSprint, true],
    [_pistolLowSprint + "_" + _loweredRun, _pistolLowSprint, _loweredRun, true],
    [_loweredRun + "_AmovPercMevaSrasWpstDf_GAIT", _loweredRun, "AmovPercMevaSrasWpstDf_GAIT", true]
];
private _lowLaunchBlend = _loweredRun + "_" + _pistolLowSprint;
private _lowExpectedLaunch = [_lowLaunchBlend, _loweredRun, _pistolLowSprint] call GAIT_fnc_isLocomotionHandoffBlend;
private _lowDecision = ["entering", true, _lowExpectedLaunch, false, _lowExpectedLaunch, true, true] call GAIT_fnc_locomotionDecision;
if (_lowDecision isNotEqualTo "hold") then {_failures pushBack "Lowered pistol same-pose launch released ownership before its sprint blend completed";};

if (_failures isEqualTo []) then {
    diag_log "GAIT cleanup and blend tests PASS: inherited arguments, coefficient-only cleanup, expected/unsafe transitions and strict native _ver2 brace handoffs.";
} else {
    {diag_log ("GAIT cleanup and blend tests FAIL: " + _x);} forEach _failures;
    throw "GAIT cleanup/blend regression failed";
};
