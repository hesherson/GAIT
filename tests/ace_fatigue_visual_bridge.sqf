/* Load fn_aceFatigueVisualBridge.sqf first. Real policy/ownership lifecycle;
   only the shared camera/body context and PP engine access are adapted. */
private _failures = [];
private _first = player;
private _second = "B_Soldier_F" createVehicle [0,0,0];
missionNamespace setVariable ["ace_advanced_fatigue_enabled", true];
if ([objNull] call GAIT_fnc_ownsACEFatigueVisualPolicy) then {
    _failures pushBack "Uninstalled view context unexpectedly acquired ACE fatigue effects";
};
GAIT_testVisualContext = true;
GAIT_fnc_fatigueVisualContextEligible = {
    params ["_unit"];
    !isNull _unit && GAIT_testVisualContext && {_unit getVariable ["GAIT_testViewLocal", true]}
};
GAIT_testPPStates = [[101,true], [102,true], [103,false], [201,true], [202,false]];
GAIT_testPPWrites = [];
GAIT_testPPReads = [];
GAIT_fnc_aceFatigueVisualHandleSnapshot = {
    params ["_handle"];
    GAIT_testPPReads pushBack _handle;
    private _index = GAIT_testPPStates findIf {(_x select 0) == _handle};
    if (_index < 0 || {_handle != call GAIT_fnc_aceFatigueVisualHandle}) exitWith {[]};
    [(GAIT_testPPStates select _index) select 1]
};
GAIT_fnc_writeACEFatigueVisualEnabled = {
    params ["_handle", "_enabled"];
    GAIT_testPPWrites pushBack [_handle,_enabled];
    private _index = GAIT_testPPStates findIf {(_x select 0) == _handle};
    if (_index >= 0) then {(GAIT_testPPStates select _index) set [1,_enabled];};
};
missionNamespace setVariable ["GAIT_aceFatigueVisualOwnership", []];
missionNamespace setVariable ["ace_advanced_fatigue_ppeBlackout", 101];
[_first] call GAIT_fnc_updateACEFatigueVisualOwnership;
[_first] call GAIT_fnc_updateACEFatigueVisualOwnership;
if (GAIT_testPPWrites isNotEqualTo [[101,false]] || {
    (missionNamespace getVariable ["GAIT_aceFatigueVisualOwnership",[]]) isNotEqualTo [_first,101,true]
}) then {_failures pushBack "Acquisition repeated its write or lost the original enabled flag";};

// Context, mode/setting, manual reset and a stale main lease all release via
// the same watchdog API. Cleanup must be idempotent and preserve medical PP.
GAIT_testVisualContext = false;
[_first] call GAIT_fnc_updateACEFatigueVisualOwnership;
private _before = count GAIT_testPPWrites;
[_first] call GAIT_fnc_updateACEFatigueVisualOwnership;
[] call GAIT_fnc_releaseACEFatigueVisualOwnership;
if ((count GAIT_testPPWrites) != _before || {GAIT_testPPWrites isNotEqualTo [[101,false],[101,true]]}) then {
    _failures pushBack "Context cleanup did not restore the original enable exactly once";
};
GAIT_testVisualContext = true;
[_first] call GAIT_fnc_updateACEFatigueVisualOwnership;
missionNamespace setVariable ["ace_advanced_fatigue_enabled", false];
[_first] call GAIT_fnc_updateACEFatigueVisualOwnership;
if (!((GAIT_testPPStates select 0) select 1) || {missionNamespace getVariable ["GAIT_aceFatigueVisualOwned",true]}) then {
    _failures pushBack "ACE disable retained suppression";
};
missionNamespace setVariable ["ace_advanced_fatigue_enabled", true];
[_first] call GAIT_fnc_updateACEFatigueVisualOwnership;

// On player change this remains a local screen effect: restore the old view's
// saved enable, then take a fresh snapshot for the new controlled player.
_before = count GAIT_testPPWrites;
[_second] call GAIT_fnc_updateACEFatigueVisualOwnership;
if ((GAIT_testPPWrites select [_before,(count GAIT_testPPWrites) - _before]) isNotEqualTo [[101,true],[101,false]] || {
    (missionNamespace getVariable ["GAIT_aceFatigueVisualOwnership",[]]) isNotEqualTo [_second,101,true]
}) then {_failures pushBack "Player change did not restore and resnapshot local view state";};
_second setVariable ["GAIT_testViewLocal",false];
[_second] call GAIT_fnc_updateACEFatigueVisualOwnership;
if (!((GAIT_testPPStates select 0) select 1)) then {_failures pushBack "Lost unit locality stranded the local screen effect disabled";};
[_first] call GAIT_fnc_updateACEFatigueVisualOwnership;

// A recreated handle invalidates the saved numeric ID. Simulate the old ID
// already belonging to another effect: no stale read, enable or disable.
missionNamespace setVariable ["ace_advanced_fatigue_ppeBlackout", 102];
GAIT_testPPReads = [];
_before = count GAIT_testPPWrites;
[_first] call GAIT_fnc_updateACEFatigueVisualOwnership;
if ((101 in GAIT_testPPReads) || {(GAIT_testPPWrites select [_before,(count GAIT_testPPWrites) - _before]) isNotEqualTo [[102,false]]}) then {
    _failures pushBack "Handle replacement touched a stale or potentially reused old handle";
};
if ((missionNamespace getVariable ["GAIT_aceFatigueVisualOwnership",[]]) isNotEqualTo [_first,102,true]) then {
    _failures pushBack "New ACE handle failed fresh acquisition";
};
missionNamespace setVariable ["ace_advanced_fatigue_ppeBlackout", nil];
GAIT_testPPReads = [];
_before = count GAIT_testPPWrites;
[_first] call GAIT_fnc_updateACEFatigueVisualOwnership;
[] call GAIT_fnc_releaseACEFatigueVisualOwnership;
if ((count GAIT_testPPWrites) != _before || {GAIT_testPPReads isNotEqualTo []} || {
    (missionNamespace getVariable ["GAIT_aceFatigueVisualOwnership",[]]) isNotEqualTo []
}) then {_failures pushBack "Missing/deleted handle was queried or retained ownership";};

// Respect a disabled effect inherited from another owner and a newer external
// enable during cleanup. Neither case should write an unsolicited restore.
missionNamespace setVariable ["ace_advanced_fatigue_ppeBlackout", 103];
_before = count GAIT_testPPWrites;
[_first] call GAIT_fnc_updateACEFatigueVisualOwnership;
[] call GAIT_fnc_releaseACEFatigueVisualOwnership;
if ((count GAIT_testPPWrites) != _before || {((GAIT_testPPStates select 2) select 1)}) then {
    _failures pushBack "An originally disabled ACE effect was enabled by GAIT cleanup";
};
missionNamespace setVariable ["ace_advanced_fatigue_ppeBlackout", 101];
(GAIT_testPPStates select 0) set [1,true];
[_first] call GAIT_fnc_updateACEFatigueVisualOwnership;
(GAIT_testPPStates select 0) set [1,true];
_before = count GAIT_testPPWrites;
[] call GAIT_fnc_releaseACEFatigueVisualOwnership;
if ((count GAIT_testPPWrites) != _before) then {_failures pushBack "Cleanup overwrote a newer external enable";};
{
    missionNamespace setVariable ["ace_advanced_fatigue_ppeBlackout", _x];
    if ((call GAIT_fnc_aceFatigueVisualHandle) != -1) then {_failures pushBack "Malformed handle accepted";};
    [_first] call GAIT_fnc_updateACEFatigueVisualOwnership;
} forEach [-1,0.5,"101",[]];
if ((count GAIT_testPPWrites) != _before || {(GAIT_testPPStates select 3) isNotEqualTo [201,true]} || {
    (GAIT_testPPStates select 4) isNotEqualTo [202,false]
}) then {_failures pushBack "Invalid handles or unrelated medical effects were modified";};
if (_failures isEqualTo []) then {
    diag_log "GAIT ACE fatigue visual bridge PASS: single-handle disable; original-state restoration; idempotent cleanup; ACE/context gates; player and locality change; handle recreation and disappearance; pre-disabled/external enable; malformed handles; unrelated medical effects preserved.";
} else {
    {diag_log ("GAIT ACE fatigue visual bridge FAIL: " + _x);} forEach _failures;
    throw "GAIT ACE fatigue visual bridge regression failed";
};
