/* Load fn_nativeController.sqf first. Exercise its real ownership lifecycle.
   Only engine stamina/locality access and the body-context sampler are mocked;
   SQF-VM cannot simulate Arma stamina or prove backpack sprinting in-game. */
private _failures = [];
private _first = player;
private _second = "B_Soldier_F" createVehicle [0,0,0];
GAIT_testStaminaMode = true;
GAIT_testStaminaContext = true;
GAIT_testStaminaWrites = [];
GAIT_testStaminaFrameChecks = 0;
GAIT_fnc_modeAllowsMovement = {GAIT_testStaminaMode};
if ([objNull] call GAIT_fnc_fatigueMovementContextEligible) then {
    _failures pushBack "Null body passed the production ownership context";
};
GAIT_fnc_fatigueMovementContextEligible = {
    params ["_unit"];
    !isNull _unit && GAIT_testStaminaContext
};
GAIT_fnc_nativeMovementEligible = {GAIT_testStaminaFrameChecks = GAIT_testStaminaFrameChecks + 1; false};
GAIT_fnc_nativeStaminaSnapshot = {
    params ["_unit"];
    if (isNull _unit || {!(_unit getVariable ["GAIT_testLocal", true])}) exitWith {[]};
    [_unit getVariable ["GAIT_testStaminaEnabled", true]]
};
GAIT_fnc_writeNativeStaminaEnabled = {
    params ["_unit", "_enabled"];
    GAIT_testStaminaWrites pushBack [_unit, _enabled];
    _unit setVariable ["GAIT_testStaminaEnabled", _enabled];
};
missionNamespace setVariable ["GAIT_nativeStaminaOwnership", []];

// A healthy, heavily loaded player owns stamina before sprint eligibility is
// sampled. Injury masks stay intact; no clear-all movement command is involved.
_first setVariable ["ace_common_effect_blockSprint", 6];
_first setVariable ["ace_common_effect_forceWalk", 4];
[_first] call GAIT_fnc_updateNativeStaminaOwnership;
[_first] call GAIT_fnc_updateNativeStaminaOwnership;
if (GAIT_testStaminaWrites isNotEqualTo [[_first,false]]) then {
    _failures pushBack "Acquisition was missing or repeatedly wrote stamina";
};
if ((missionNamespace getVariable ["GAIT_nativeStaminaOwnership", []]) isNotEqualTo [_first,true]) then {
    _failures pushBack "Repeated update lost the original stamina flag";
};
if ((_first getVariable ["ace_common_effect_blockSprint",0]) != 6 || {(_first getVariable ["ace_common_effect_forceWalk",0]) != 4}) then {
    _failures pushBack "Stamina ownership removed a medical or external ACE source";
};
// An animation-only release cannot turn vanilla stamina back on mid-blend.
missionNamespace setVariable ["GAIT_nativeOwner", objNull];
missionNamespace setVariable ["GAIT_nativeLastWritten", -1];
GAIT_fnc_releaseSlopeLocomotion = {};
[] call GAIT_fnc_releaseNativeMovement;
if (!(missionNamespace getVariable ["GAIT_nativeStaminaOwned",false]) || {_first getVariable ["GAIT_testStaminaEnabled",true]}) then {
    _failures pushBack "Temporary animation release surrendered stamina policy";
};

// Mode disable and unsafe contexts restore exactly once, with no reset of ACE
// reserves or permission flags. Re-entry takes a fresh snapshot.
{
    missionNamespace setVariable [_x, false];
    [_first] call GAIT_fnc_updateNativeStaminaOwnership;
    private _after = count GAIT_testStaminaWrites;
    [_first] call GAIT_fnc_updateNativeStaminaOwnership;
    if (!(_first getVariable ["GAIT_testStaminaEnabled",false]) || {(missionNamespace getVariable ["GAIT_nativeStaminaOwned",true])} || {(count GAIT_testStaminaWrites) != _after}) then {
        _failures pushBack format ["Gate %1 failed idempotent restore",_x];
    };
    missionNamespace setVariable [_x, true];
    [_first] call GAIT_fnc_updateNativeStaminaOwnership;
} forEach ["GAIT_testStaminaMode","GAIT_testStaminaContext"];

// Changing player restores the old object and snapshots the new object.
_second setVariable ["GAIT_testStaminaEnabled", false];
[_second] call GAIT_fnc_updateNativeStaminaOwnership;
if (!(_first getVariable ["GAIT_testStaminaEnabled",false]) || {(missionNamespace getVariable ["GAIT_nativeStaminaOwnership",[]]) isNotEqualTo [_second,false]}) then {
    _failures pushBack "Player change failed to restore old owner or snapshot the new one";
};
private _before = count GAIT_testStaminaWrites;
[] call GAIT_fnc_releaseNativeStaminaOwnership;
if ((count GAIT_testStaminaWrites) != _before || {_second getVariable ["GAIT_testStaminaEnabled",true]}) then {
    _failures pushBack "Release enabled stamina that was already disabled by another system";
};

// A current external enable is left untouched on explicit cleanup. A lost
// locality prevents commands to that object, and does not contaminate the next.
[_first] call GAIT_fnc_updateNativeStaminaOwnership;
_first setVariable ["GAIT_testStaminaEnabled",true];
_before = count GAIT_testStaminaWrites;
[] call GAIT_fnc_releaseNativeStaminaOwnership;
if ((count GAIT_testStaminaWrites) != _before) then {_failures pushBack "Cleanup overwrote a newer external enabled state";};
[_first] call GAIT_fnc_updateNativeStaminaOwnership;
_first setVariable ["GAIT_testLocal",false];
_before = count GAIT_testStaminaWrites;
[_first] call GAIT_fnc_updateNativeStaminaOwnership;
[] call GAIT_fnc_releaseNativeStaminaOwnership;
if ((count GAIT_testStaminaWrites) != _before || {(missionNamespace getVariable ["GAIT_nativeStaminaOwnership",[]]) isNotEqualTo []}) then {
    _failures pushBack "Locality loss wrote remotely or retained a stale owner";
};
[_second] call GAIT_fnc_updateNativeStaminaOwnership;
[_second] call GAIT_fnc_updateNativeStaminaOwnership;
[_second] call {[] call GAIT_fnc_releaseNativeStaminaOwnership;};
[_first] call {[] call GAIT_fnc_releaseNativeStaminaOwnership;};
_before = count GAIT_testStaminaWrites;
[objNull] call GAIT_fnc_updateNativeStaminaOwnership;
if ((count GAIT_testStaminaWrites) != _before || {GAIT_testStaminaFrameChecks != 0}) then {
    _failures pushBack "Null/temporary animation context wrote stamina or consulted sprint-frame eligibility";
};
if (_failures isEqualTo []) then {
    diag_log "GAIT native stamina ownership PASS: acquisition; unchanged injury masks; animation-independent policy; idempotent restore; mode/context release; player switch; pre-disabled state; external enable; locality loss; null owner.";
} else {
    {diag_log ("GAIT native stamina ownership FAIL: " + _x);} forEach _failures;
    throw "GAIT native stamina ownership regression failed";
};
