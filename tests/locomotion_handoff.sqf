/* Load fn_traversalHelpers.sqf and fn_slopeLocomotion.sqf first.
   Tests actual graph handoff parsing, numerical brace cancellation and live
   input history. Arma animation interpolation remains a runtime check. */
private _failures = [];
// Every launch enters a sprint clip immediately, independently of the brace
// token and load. The numeric speed dip is tested by the brace suites.
{
    private _family = _x;
    {
        private _actual = [_family,_x] call GAIT_fnc_slopeStateName;
        private _expected = "AmovPercMeva" + _family + _x + "_GAIT";
        if (_actual isNotEqualTo _expected) then {_failures pushBack format ["Launch delayed by non-sprint clip %1",_actual];};
    } forEach ["Df","Dfl","Dfr"];
} forEach ["SrasWrfl","SlowWrfl","SrasWpst","SnonWnon"];
// Release from a completed entry or the middle of a known blend keeps its
// exact cleanup lease; medical, stance, wrong-pose and chained names do not.
private _sprint = "AmovPercMevaSrasWrflDf_GAIT";
private _walk = "AmovPercMrunSrasWrflDf";
private _idle = "AmovPercMstpSrasWrflDnon";
{
    _x params ["_animation", "_source", "_target", "_expected"];
    private _actual = [_animation,_source,_target] call GAIT_fnc_isLocomotionHandoffBlend;
    if (_actual isNotEqualTo _expected) then {_failures pushBack format ["Handoff lease %1: got %2",_animation,_actual];};
} forEach [
    [_sprint+"_"+_walk,_sprint,_walk,true],
    [_sprint+"_"+_idle,_walk+"_"+_sprint,_idle,true],
    [_walk+"_"+_idle,_walk+"_"+_sprint,_idle,true],
    [_sprint+"_"+_walk,_sprint,_idle,false],
    [_sprint+"_AmovPknlMstpSrasWrflDnon",_sprint,_idle,false],
    [_sprint+"_AinvPknlMstpSnonWnonDnon_medic",_sprint,_idle,false],
    ["AmovPercMevaSrasWpstDf_GAIT_"+_idle,_sprint,_idle,false],
    [_sprint+"_"+_idle,_walk+"_"+_sprint+"_"+_walk,_idle,false],
    [_sprint+"_"+_idle+"_"+_walk,_sprint,_idle,false]
];
// The old exit blend may be observed briefly after an edge-based re-entry.
// That exact source has bounded grace; an ignored request must still fail.
private _oldExit = _sprint + "_" + _walk;
{
    _x params ["_animation", "_source", "_fresh", "_expected"];
    private _actual = [_animation,_source,_fresh] call GAIT_fnc_isLocomotionHandoffSource;
    if (_actual isNotEqualTo _expected) then {_failures pushBack "Interrupted handoff source grace escaped its identity/deadline";};
} forEach [
    [_oldExit,_oldExit,true,true],
    [_oldExit,_oldExit,false,false],
    [_sprint,_sprint,true,false],
    [_sprint+"_"+_idle,_oldExit,true,false],
    [_sprint+"_AinvPknlMstpSnonWnonDnon_medic",_sprint+"_AinvPknlMstpSnonWnonDnon_medic",true,false]
];
// Exercise the actual render observer across changes entirely between two
// scheduled feature updates. Its unit variables must survive ordinary
// animation cleanup, or a stale brace/coast can restart after a quick W tap.
private _testUnit = player;
private _savedGlobals = [];
{
    _x params ["_name", "_default"];
    _savedGlobals pushBack [_name, missionNamespace getVariable [_name, _default]];
} forEach [["GAIT_braceActive",false], ["GAIT_braceEndTime",-1], ["GAIT_uphillBrakeActive",false], ["GAIT_uphillBrakeEndTime",-1], ["GAIT_uphillBrakeUnit",objNull]];
_testUnit setVariable ["GAIT_forwardReleaseSerial", 0];
_testUnit setVariable ["GAIT_forwardInputHeld", true];
_testUnit setVariable ["GAIT_slopeCanceledBraceEndTime", -2];
missionNamespace setVariable ["GAIT_braceActive", true];
missionNamespace setVariable ["GAIT_braceEndTime", time + 10];
missionNamespace setVariable ["GAIT_uphillBrakeActive", false];
{
    _x params ["_input", "_expected", "_serial", "_label"];
    private _actual = [_testUnit, _input] call GAIT_fnc_observeLocomotionInput;
    if (_actual isNotEqualTo _expected || {(_testUnit getVariable ["GAIT_forwardReleaseSerial", -1]) isNotEqualTo _serial}) then {
        _failures pushBack format ["%1: brace=%2 serial=%3", _label, _actual, _testUnit getVariable ["GAIT_forwardReleaseSerial", -1]];
    };
} forEach [
    [[1,0,true],true,0,"fresh launch begins brace"],
    [[0.707,0.707,true],true,0,"forward diagonal does not cancel forward intent"],
    [[0,1,true],false,1,"W release cancels launch and increments serial once"],
    [[0,0,true],false,1,"held stop does not repeatedly increment serial"],
    [[1,0,true],false,1,"quick W re-press cannot revive stale launch token"]
];
[_testUnit] call GAIT_fnc_clearSlopeLocomotionState;
if ([_testUnit,[1,0,true]] call GAIT_fnc_observeLocomotionInput) then {_failures pushBack "Cleanup revived consumed brace token";};
if ((_testUnit getVariable ["GAIT_forwardReleaseSerial", -1]) isNotEqualTo 1) then {_failures pushBack "Cleanup lost W-release serial";};
missionNamespace setVariable ["GAIT_braceEndTime", time + 11];
if !([_testUnit,[1,0,true]] call GAIT_fnc_observeLocomotionInput) then {_failures pushBack "Fresh launch token did not rearm";};
if ([_testUnit,[1,0,false]] call GAIT_fnc_observeLocomotionInput) then {_failures pushBack "Released Turbo retained launch coefficient dip";};
if ([_testUnit,[1,0,true]] call GAIT_fnc_observeLocomotionInput) then {_failures pushBack "Raw Turbo re-tap revived stale launch";};

private _brakeEnd = time + 12;
missionNamespace setVariable ["GAIT_braceEndTime", _brakeEnd];
missionNamespace setVariable ["GAIT_uphillBrakeEndTime", _brakeEnd];
missionNamespace setVariable ["GAIT_uphillBrakeActive", true];
missionNamespace setVariable ["GAIT_uphillBrakeUnit", _testUnit];
if !([_testUnit,[1,0,false]] call GAIT_fnc_observeLocomotionInput) then {_failures pushBack "Forward uphill brake lost its numerical braking step";};
if ([_testUnit,[1,0,true]] call GAIT_fnc_observeLocomotionInput) then {_failures pushBack "Turbo re-tap retained stale uphill braking step";};
if ([_testUnit,[1,0,false]] call GAIT_fnc_observeLocomotionInput) then {_failures pushBack "Released Turbo revived consumed uphill step";};

{missionNamespace setVariable [_x select 0, _x select 1];} forEach _savedGlobals;

if (_failures isEqualTo []) then {
    diag_log "GAIT locomotion handoff tests PASS: immediate sprint launch, exact entry/exit blend leases, raw W/Turbo brace cancellation and persistent release serial.";
} else {
    {diag_log ("GAIT locomotion handoff tests FAIL: "+_x);} forEach _failures;
    throw "GAIT locomotion handoff regression failed";
};
