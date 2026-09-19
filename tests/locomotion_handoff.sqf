/* Load fn_slopeLocomotion.sqf first. These tests exercise the live controller's
   pure command arguments and one-shot brace lifecycle, not engine blending. */
private _failures = [];
private _target = "AmovPercMevaSrasWrflDf_GAIT";
{
    _x params ["_same", "_progress", "_expected"];
    private _actual = [_target, _same, _progress] call GAIT_fnc_locomotionSwitchArguments;
    if (_actual isNotEqualTo [_target, _expected, 0, false]) then {
        _failures pushBack format ["Handoff changed aim/blend/phase: %1", _actual];
    };
} forEach [[true,0.63,0.63],[true,-0.1,0],[true,1.3,0],[false,0.63,0],[false,0.99,0]];
private _policyCases = [
    ["Walking brace stays until its tuned deadline", ["brace",true,true,"brace",false,false], "hold"],
    ["Walking brace promotes when expired", ["brace",true,false,"brace",false,false], "promote"],
    ["Canceled brace does not prolong slow movement", ["brace",false,true,"brace",false,false], "promote"],
    ["No repeated promotion while previous request pending", ["promoting",false,false,"brace",false,false], "hold"],
    ["Slow internal blend is not force-restarted", ["promoting",false,false,"",true,true], "hold"],
    ["Observed sprint completes promotion", ["promoting",false,false,"move",false,false], "complete"],
    ["Stop during promotion can complete into idle", ["promoting",false,false,"idle",false,false], "complete"],
    ["Failed promotion reports instead of reasserting", ["promoting",false,false,"brace",false,true], "failed"],
    ["Old brace token cannot restart active sprint", ["complete",true,true,"move",false,false,false], "hold"],
    ["Fresh genuine brace after real stop starts once", ["complete",true,true,"idle",false,false,true], "brace"],
    ["Expired new token cannot start late brace", ["complete",true,false,"move",false,false,true], "hold"],
    ["Momentum protected retap cannot enter brace", ["complete",false,true,"move",false,false,true], "hold"]
];
{
    _x params ["_label", "_args", "_expected"];
    private _actual = _args call GAIT_fnc_braceLocomotionDecision;
    if (_actual isNotEqualTo _expected) then {_failures pushBack format ["%1: got %2 expected %3", _label, _actual, _expected];};
} forEach _policyCases;
// Enter brace once, promote once, observe sprint, ignore the consumed token.
private _stage = "complete";
private _commands = [];
{
    _x params ["_active", "_before", "_role", "_blend", "_expired", "_new"];
    private _action = [_stage,_active,_before,_role,_blend,_expired,_new] call GAIT_fnc_braceLocomotionDecision;
    switch (_action) do {
        case "brace": {_stage="brace"; _commands pushBack "brace";};
        case "promote": {_stage="promoting"; _commands pushBack "promote";};
        case "complete": {_stage="complete";};
        case "failed": {_failures pushBack "Valid sequence failed promotion";};
    };
} forEach [
    [true,true,"idle",false,false,true],
    [true,true,"brace",false,false,false],
    [false,false,"brace",false,false,false],
    [false,false,"",true,false,false],
    [false,false,"move",false,false,false],
    [false,false,"move",false,false,false]
];
if (_commands isNotEqualTo ["brace","promote"] || {_stage isNotEqualTo "complete"}) then {
    _failures pushBack format ["Brace sequence repeated command or stayed slow: %1/%2", _commands,_stage];
};
// Every brace direction uses a walking RTM; no change to existing sprint names.
{
    private _family = _x;
    {
        private _actual = [_family,_x,true] call GAIT_fnc_slopeStateName;
        private _expected = "AmovPercMwlk" + _family + _x + "_GAIT";
        if (_actual isNotEqualTo _expected) then {_failures pushBack format ["Wrong brace clip %1",_actual];};
    } forEach ["Df","Dfl","Dl","Dbl","Db","Dbr","Dr","Dfr"];
    if (([_family,"Dnon",true] call GAIT_fnc_slopeStateName) isNotEqualTo ("AmovPercMstp"+_family+"DnonBrace_GAIT")) then {
        _failures pushBack "Brace idle escaped its own action map";
    };
} forEach ["SrasWrfl","SlowWrfl","SrasWpst","SnonWnon"];

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
if ([_testUnit,[1,0,false]] call GAIT_fnc_observeLocomotionInput) then {_failures pushBack "Released Turbo retained launch walking clip";};
if ([_testUnit,[1,0,true]] call GAIT_fnc_observeLocomotionInput) then {_failures pushBack "Raw Turbo re-tap revived stale launch";};

private _brakeEnd = time + 12;
missionNamespace setVariable ["GAIT_braceEndTime", _brakeEnd];
missionNamespace setVariable ["GAIT_uphillBrakeEndTime", _brakeEnd];
missionNamespace setVariable ["GAIT_uphillBrakeActive", true];
missionNamespace setVariable ["GAIT_uphillBrakeUnit", _testUnit];
if !([_testUnit,[1,0,false]] call GAIT_fnc_observeLocomotionInput) then {_failures pushBack "Forward uphill brake lost its walking step";};
if ([_testUnit,[1,0,true]] call GAIT_fnc_observeLocomotionInput) then {_failures pushBack "Turbo re-tap retained stale uphill walking step";};
if ([_testUnit,[1,0,false]] call GAIT_fnc_observeLocomotionInput) then {_failures pushBack "Released Turbo revived consumed uphill step";};

// A failed promotion uses the existing safe native-exit boundary exactly
// once. Mock only that boundary; the failure latch and input observer are
// production code. Engine blend acceptance still needs an Arma test.
private _actualRelease = GAIT_fnc_releaseSlopeLocomotion;
private _actualExit = GAIT_fnc_serviceLocomotionExit;
private _releaseCalls = [];
private _serviceCalls = 0;
GAIT_fnc_releaseSlopeLocomotion = {_releaseCalls pushBack _this; (_this select 0) setVariable ["GAIT_locomotionPhase", "exiting"];};
GAIT_fnc_serviceLocomotionExit = {_serviceCalls = _serviceCalls + 1; false};
[_testUnit,[1,0,true]] call GAIT_fnc_failBraceLocomotion;
if ((count _releaseCalls) isNotEqualTo 1 || {_serviceCalls isNotEqualTo 1} || {(_testUnit getVariable ["GAIT_locomotionPhase", ""]) isNotEqualTo "exiting"}) then {
    _failures pushBack "Failed brace did not request one native cleanup";
};
if (((_releaseCalls select 0) select 1) isNotEqualTo [1,0,true]) then {_failures pushBack "Failed brace cleanup lost current input";};
GAIT_fnc_releaseSlopeLocomotion = _actualRelease;
GAIT_fnc_serviceLocomotionExit = _actualExit;
[_testUnit] call GAIT_fnc_clearSlopeLocomotionState;
[_testUnit,[1,0,true]] call GAIT_fnc_observeLocomotionInput;
if !(_testUnit getVariable ["GAIT_slopeBraceFailedUntilRelease", false]) then {_failures pushBack "Held Turbo lost failure latch after cleanup";};
[_testUnit,[1,0,false]] call GAIT_fnc_observeLocomotionInput;
if (_testUnit getVariable ["GAIT_slopeBraceFailedUntilRelease", true]) then {_failures pushBack "Turbo release failed to rearm after cleanup";};
{missionNamespace setVariable [_x select 0, _x select 1];} forEach _savedGlobals;

if (_failures isEqualTo []) then {
    diag_log "GAIT locomotion handoff tests PASS: aim-preserving arguments, brace lifecycle/states, raw W/Turbo cancellation, persistent release serial, failed-brace native cleanup.";
} else {
    {diag_log ("GAIT locomotion handoff tests FAIL: "+_x);} forEach _failures;
    throw "GAIT locomotion handoff regression failed";
};
