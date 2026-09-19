/* Execute production edge ownership, plan sampling and the one native writer.
   Only engine context/clock/coefficient I/O are substituted. The main/render
   order and state mutations are the actual production functions. */
private _failures = [];
private _unit = player;
GAIT_testReleaseNow = 10;
GAIT_testReleaseWrites = [];
GAIT_testReleaseEligible = true;
GAIT_testReleaseBrake = false;
GAIT_testReleaseSpeed = 6;
GAIT_testReleaseWeapon = "pistol";
GAIT_testReleaseFamily = "SrasWpst";
GAIT_testReleaseAnimation = "AmovPercMevaSrasWpstDf_GAIT";
GAIT_testReleaseOrdinary = 0.5;
GAIT_testReleaseWindow = 0.35;
GAIT_fnc_nativeMovementEligible = {GAIT_testReleaseEligible};
GAIT_fnc_nativeCoefficientLocal = {true};
GAIT_fnc_readNativeCoefficient = {params ["_unit"]; _unit getVariable ["GAIT_testCoefficient", 1]};
GAIT_fnc_writeNativeCoefficient = {
    params ["_unit", "_coefficient"];
    _unit setVariable ["GAIT_testCoefficient", _coefficient];
    GAIT_testReleaseWrites pushBack _coefficient;
};
GAIT_fnc_releaseSlopeLocomotion = {};
GAIT_fnc_releaseMomentumContext = {
    params ["_unit", "_input", "_now"];
    private _owns = _unit isEqualTo (missionNamespace getVariable ["GAIT_nativeOwner", objNull]) &&
        {abs (([_unit] call GAIT_fnc_readNativeCoefficient) - (missionNamespace getVariable ["GAIT_nativeLastWritten", -1])) < 0.001};
    private _requestLive = [missionNamespace getVariable ["GAIT_releaseMomentumRequest", []], _unit, _now]
        call GAIT_fnc_releaseMomentumRequestValid;
    [GAIT_testReleaseEligible && {_requestLive}, _owns, GAIT_testReleaseWeapon, GAIT_testReleaseFamily,
        GAIT_testReleaseAnimation, missionNamespace getVariable ["GAIT_nativeLastPreVegetation", 1],
        GAIT_testReleaseSpeed, GAIT_testReleaseBrake, GAIT_testReleaseOrdinary, GAIT_testReleaseWindow, 1.45, true]
};
private _actualSample = GAIT_fnc_sampleReleaseCoefficient;
GAIT_fnc_sampleReleaseCoefficient = {
    params ["_unit", "_coefficient"];
    [_unit, _coefficient, GAIT_testReleaseNow] call _actualSample
};
missionNamespace setVariable ["GAIT_ss_vegetationDragEnabled", false];
missionNamespace setVariable ["GAIT_ss_registerAceAnimExclusion", false];
missionNamespace setVariable ["GAIT_ss_shiftReleaseRunTaperEnabled", true];
private _fixture = {
    [_unit] call GAIT_fnc_clearReleaseMomentum;
    GAIT_testReleaseNow = 10;
    missionNamespace setVariable ["GAIT_releaseMomentumRequest", [_unit, 0.5, 0.35, 1.45, true, 10.5]];
    GAIT_testReleaseWrites = [];
    GAIT_testReleaseEligible = true;
    GAIT_testReleaseBrake = false;
    GAIT_testReleaseSpeed = 6;
    GAIT_testReleaseWeapon = "pistol";
    GAIT_testReleaseFamily = "SrasWpst";
    GAIT_testReleaseAnimation = "AmovPercMevaSrasWpstDf_GAIT";
    GAIT_testReleaseOrdinary = 0.5;
    missionNamespace setVariable ["GAIT_ss_shiftReleaseRunTaperEnabled", true];
    missionNamespace setVariable ["GAIT_nativeOwner", _unit];
    missionNamespace setVariable ["GAIT_nativePreviousCoef", 0.87];
    missionNamespace setVariable ["GAIT_nativeLastWritten", 1.2];
    missionNamespace setVariable ["GAIT_nativeLastPreVegetation", 1.2];
    _unit setVariable ["GAIT_testCoefficient", 1.2];
    [_unit, [1,0,true], 9.95] call GAIT_fnc_observeReleaseMomentum;
};
// Both scheduler orders capture actual pre-write speed exactly once.
{
    call _fixture;
    private _firstLabel = _x;
    [_unit, [1,0,false], GAIT_testReleaseNow] call GAIT_fnc_observeReleaseMomentum;
    // Main submits its newly computed ordinary ramp; rendering submits the
    // last applied sample. Run both orderings against the same sole writer.
    private _firstCandidate = [0.51, 1.2] select (_firstLabel isEqualTo "render");
    private _secondCandidate = [1.2, 0.51] select (_firstLabel isEqualTo "render");
    [_unit, _firstCandidate, false] call GAIT_fnc_applyNativeMovement;
    private _firstPlan = +((_unit getVariable ["GAIT_releaseMomentumState", []]) select 0);
    [_unit, [1,0,false], GAIT_testReleaseNow] call GAIT_fnc_observeReleaseMomentum;
    [_unit, _secondCandidate, false] call GAIT_fnc_applyNativeMovement;
    if (GAIT_testReleaseWrites isNotEqualTo [1.2,1.2] ||
        {((_unit getVariable ["GAIT_releaseMomentumState", []]) select 0) isNotEqualTo _firstPlan} ||
        {(missionNamespace getVariable ["GAIT_nativePreviousCoef", -1]) != 0.87}) then {
        _failures pushBack format ["%1-first release pulsed, restarted, or replaced prior ownership", _firstLabel];
    };
    private _duration = _firstPlan select 1;
    GAIT_testReleaseNow = 10 + (_duration / 2);
    [_unit, [1,0,false], GAIT_testReleaseNow] call GAIT_fnc_observeReleaseMomentum;
    private _applied = [_unit, 0.51, false] call GAIT_fnc_applyNativeMovement;
    private _expected = ([_firstPlan, GAIT_testReleaseNow] call GAIT_fnc_releaseMomentumSample) select 0;
    if (abs (_applied - _expected) > 0.00001 || {_applied >= 1.2} || {_applied <= 0.5}) then {
        _failures pushBack "Actual writer did not return the remaining finite prevegetation pace";
    };
    GAIT_testReleaseNow = 11;
    missionNamespace setVariable ["GAIT_releaseMomentumRequest", [_unit, 0.5, 0.35, 1.45, true, 11.2]];
    [_unit, [1,0,false], GAIT_testReleaseNow] call GAIT_fnc_observeReleaseMomentum;
    _applied = [_unit, 0.95, false] call GAIT_fnc_applyNativeMovement;
    if (abs (_applied - 0.5) > 0.00001 ||
        {(_unit getVariable ["GAIT_releaseMomentumState", []]) isNotEqualTo []} ||
        {missionNamespace getVariable ["GAIT_releaseMomentumActive", true]}) then {
        _failures pushBack "Late endpoint failed to write ordinary pace and release the held clip exactly once";
    };
    [_unit, [1,0,false], GAIT_testReleaseNow] call GAIT_fnc_observeReleaseMomentum;
    _applied = [_unit, 0.5, false] call GAIT_fnc_applyNativeMovement;
    if (_applied != 0.5 || {(missionNamespace getVariable ["GAIT_nativePreviousCoef", -1]) != 0.87}) then {
        _failures pushBack "Native handoff reset coefficient or reacquired its own output";
    };
} forEach ["main", "render"];

// Re-tap reverses the same plan at its remaining sample, with a main seed token.
call _fixture;
[_unit, [1,0,false], 10] call GAIT_fnc_observeReleaseMomentum;
private _plan = (_unit getVariable ["GAIT_releaseMomentumState", []]) select 0;
GAIT_testReleaseNow = 10 + ((_plan select 1) * 0.4);
private _expected = ([_plan, GAIT_testReleaseNow] call GAIT_fnc_releaseMomentumSample) select 0;
[_unit, [1,0,true], GAIT_testReleaseNow] call GAIT_fnc_observeReleaseMomentum;
[_unit, [1,0,true], GAIT_testReleaseNow] call GAIT_fnc_observeReleaseMomentum;
private _resume = _unit getVariable ["GAIT_releaseResume", []];
private _applied = [_unit, 1.3, false] call GAIT_fnc_applyNativeMovement;
if (abs (_applied - _expected) > 0.00001 || {abs ((_resume select 0) - _expected) > 0.00001} ||
    {(_unit getVariable ["GAIT_releaseMomentumState", []]) isNotEqualTo []}) then {
    _failures pushBack "Rapid retap restored stale sprint pace or lost the main-loop resume seed";
};
// A later release observes the actual decayed speed, including early ramp-up.
GAIT_testReleaseSpeed = 3.5;
GAIT_testReleaseNow = GAIT_testReleaseNow + 0.02;
[_unit, [1,0,false], GAIT_testReleaseNow] call GAIT_fnc_observeReleaseMomentum;
_plan = (_unit getVariable ["GAIT_releaseMomentumState", []]) select 0;
if (abs ((_plan select 4) - _expected) > 0.00001 || {(_plan select 2) != 3.5}) then {
    _failures pushBack "Second release did not capture the currently remaining physical pace";
};

// Actual speed differences change the finite duration at identical coefficient.
private _durations = [];
{
    call _fixture;
    GAIT_testReleaseSpeed = _x;
    [_unit, [1,0,false], 10] call GAIT_fnc_observeReleaseMomentum;
    _durations pushBack (((_unit getVariable ["GAIT_releaseMomentumState", []]) select 0) select 1);
} forEach [1,6];
if ((_durations select 0) >= (_durations select 1)) then {_failures pushBack "Release duration ignored actual velocity";};

// Live input cancellation cannot keep boosted forward scalar into a new heading.
{
    call _fixture;
    [_unit, [1,0,false], 10] call GAIT_fnc_observeReleaseMomentum;
    GAIT_testReleaseNow = 10.02;
    [_unit, _x, GAIT_testReleaseNow] call GAIT_fnc_observeReleaseMomentum;
    if ((_unit getVariable ["GAIT_releaseMomentumState", []]) isNotEqualTo []) then {
        _failures pushBack format ["Direction/stop %1 retained the release clip", _x];
    };
    if ((_x select 0) != 0 || {(_x select 1) != 0}) then {
        _applied = [_unit, 1.1, false] call GAIT_fnc_applyNativeMovement;
        if (_applied > 0.5) then {_failures pushBack format ["Direction %1 received stale sprint boost", _x];};
    } else {
        if ((_unit getVariable ["GAIT_testCoefficient", -1]) != 0.87 ||
            {(missionNamespace getVariable ["GAIT_nativeOwner", _unit]) isNotEqualTo objNull}) then {
            _failures pushBack "W-up stop retained owned pace instead of promptly returning the native stop blend";
        };
    };
} forEach [[0,0,false], [0,1,false], [-1,0,false], [1,1,false]];

// Brake priority retains the same body while the separate finite brake runs.
call _fixture;
GAIT_testReleaseBrake = true;
[_unit, [1,0,false], 10] call GAIT_fnc_observeReleaseMomentum;
if ((_unit getVariable ["GAIT_releaseMomentumState", []]) isNotEqualTo [] ||
    {(_unit getVariable ["GAIT_releaseBrakeHold", []]) isEqualTo []}) then {
    _failures pushBack "Prearmed uphill brake failed to take priority over the velocity plan";
};
[_unit, [0,0,false], 10.01] call GAIT_fnc_observeReleaseMomentum;
if ((_unit getVariable ["GAIT_releaseBrakeHold", []]) isNotEqualTo []) then {_failures pushBack "W-up waited for uphill brake deadline";};

// Weapon, family, clip, setting, unsafe context and external writes all cancel.
{
    call _fixture;
    [_unit, [1,0,false], 10] call GAIT_fnc_observeReleaseMomentum;
    call _x;
    [_unit, [1,0,false], 10.01] call GAIT_fnc_observeReleaseMomentum;
    if ((_unit getVariable ["GAIT_releaseMomentumState", []]) isNotEqualTo [] ||
        {missionNamespace getVariable ["GAIT_shiftReleaseRunTaperActive", true]}) then {
        _failures pushBack "Context/identity/ownership cancellation left finite release active";
    };
} forEach [
    {GAIT_testReleaseWeapon = "rifle";},
    {GAIT_testReleaseFamily = "SrasWrfl";},
    {GAIT_testReleaseAnimation = "other";},
    {missionNamespace setVariable ["GAIT_ss_shiftReleaseRunTaperEnabled", false];},
    {GAIT_testReleaseEligible = false;},
    {missionNamespace setVariable ["GAIT_releaseMomentumRequest", [_unit, 0.5, 0.35, 1.45, true, 9.9]];},
    {missionNamespace setVariable ["GAIT_releaseMomentumRequest", [objNull, 0.5, 0.35, 1.45, true, 10.5]];},
    {_unit setVariable ["GAIT_testCoefficient", 0.7];}
];
[] call GAIT_fnc_releaseNativeMovement;
if ((_unit getVariable ["GAIT_testCoefficient", -1]) != 0.7) then {_failures pushBack "Cleanup overwrote another coefficient writer";};

if (_failures isEqualTo []) then {
    diag_log "GAIT release runtime PASS: shared edge, ordered main/render sampling, finite endpoint, actual velocity duration, retap seed, no boost direction cancellation, uphill priority and owner-checked cleanup.";
} else {
    {diag_log ("GAIT release runtime FAIL: " + _x);} forEach _failures;
    throw "GAIT release runtime regression failed";
};
