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

if (_failures isEqualTo []) then {
    diag_log "GAIT cleanup and blend tests PASS: five inherited argument contexts; coefficient-only cleanup; 12 expected/unsafe transition cases.";
} else {
    {diag_log ("GAIT cleanup and blend tests FAIL: " + _x);} forEach _failures;
    throw "GAIT cleanup/blend regression failed";
};
