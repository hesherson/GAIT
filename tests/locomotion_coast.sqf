/* Load actual fn_traversalHelpers.sqf and fn_slopeLocomotion.sqf first.
   Exercise release/retap ordering and live movement priority using the same
   pure policies called by Draw3D. This does not simulate engine root motion. */
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {throw format ["FAIL: %1", _label];};
};
{
    _x params ["_args", "_expected", "_label"];
    [(_args call GAIT_fnc_coastKeepsFamily) isEqualTo _expected, _label] call _assert;
} forEach [
    [["active",true,false,true,1],true,"raw release before scheduled taper keeps current clip"],
    [["active",true,true,false,1],true,"published forward taper keeps current clip"],
    [["entering",true,true,false,1],true,"existing entry can finish while forward coasting"],
    [["native",true,true,true,1],false,"old coast cannot acquire a new animation"],
    [["exiting",true,true,true,1],false,"old coast cannot reverse issued cleanup"],
    [["blocked",true,true,true,1],false,"coast never retries failed entry"],
    [["active",false,true,true,1],false,"replacement player ignores old coast"],
    [["active",true,false,false,1],false,"expired coast releases normally"],
    [["active",true,true,true,0],false,"stop and pure strafe override cached inertia"],
    [["active",true,true,true,0.707],true,"held W diagonal retains scalar coast while changing direction"],
    [["active",true,true,true,-1],false,"backward input overrides forward inertia"]
];

// Keep exactly one entry across sprint -> released sprint -> re-tap. Stop,
// strafe or no-W input must request release even with stale brake/coast data.
private _phase = "native";
private _entries = 0;
private _releases = 0;
{
    _x params ["_turbo","_forward","_right","_activeCoast","_prearm","_inside","_expected"];
    private _moving = abs _forward > 0.05 || {abs _right > 0.05};
    private _coast = [_phase,true,_activeCoast,_prearm,_forward] call GAIT_fnc_coastKeepsFamily;
    private _intent = [true,_turbo,_moving,_forward,false,_coast] call GAIT_fnc_locomotionIntent;
    private _action = [_phase,_intent,true,_inside,false,false,_moving] call GAIT_fnc_locomotionDecision;
    [_action isEqualTo _expected,format ["coast sequence %1: %2",_forEachIndex,_action]] call _assert;
    switch (_action) do {
        case "enter": {_phase="entering"; _entries=_entries+1;};
        case "active": {_phase="active";};
        case "release": {_phase="exiting"; _releases=_releases+1;};
        case "clear": {_phase="native";};
    };
} forEach [
    [true,1,0,false,false,false,"enter"],
    [true,1,0,false,true,true,"active"],
    [false,1,0,false,true,true,"active"],
    [false,1,0,true,false,true,"active"],
    [true,1,0,true,false,true,"active"],
    [false,0,-1,true,true,true,"release"],
    [false,0,-1,false,false,false,"clear"]
];
[_entries isEqualTo 1 && {_releases isEqualTo 1},"forward re-tap never exits/re-enters animation"] call _assert;
{
    _x params ["_args","_expected","_label"];
    [(_args call GAIT_fnc_locomotionIntent) isEqualTo _expected,_label] call _assert;
} forEach [
    [[true,true,false,0,true,true],false,"stop wins even with Turbo and stale brake/taper"],
    [[true,false,true,0,true,true],false,"released sprint and lateral input exits immediately"],
    [[true,false,true,-1,true,true],false,"backpedal cannot retain forward brake/taper"],
    [[true,false,true,0.707,false,true],true,"forward diagonal keeps short taper without inventing input"],
    [[true,true,true,0,false,false],true,"held sprint still supports custom pure strafing"],
    [[true,false,true,1,true,false],true,"uphill forward release retains its tuned brake"],
    [[false,true,true,1,true,true],false,"feature gate still controls entry"]
];
{
    _x params ["_args","_expected","_label"];
    [(_args call GAIT_fnc_locomotionExitOwnsObservation) isEqualTo _expected,_label] call _assert;
} forEach [
    [[true,false,false,false,false],true,"observed custom state always needs native exit"],
    [[false,true,true,false,false],true,"known slow entry blend keeps cleanup ownership"],
    [[false,false,true,true,true],true,"release before entry appears cancels pending command"],
    [[false,false,true,true,false],false,"expired unseen entry cannot retain native body"],
    [[false,false,true,false,true],false,"medical/native takeover clears pending entry"],
    [[false,false,false,true,true],false,"issued exit observed at source completes cleanup"]
];
// Exercise the real render dispatcher with exit service deliberately deferred.
// This replaces only the body-effect boundary; no engine movement is mocked.
// A new fresh sprint submission cannot reach entry handling while cleanup
// owns an unobserved entry. Read-only input observation must still record W
// and Turbo edges during that safe deferral.
private _actualExitService = GAIT_fnc_serviceLocomotionExit;
private _actualInput = GAIT_fnc_getMovementInput;
private _actualDecision = GAIT_fnc_locomotionDecision;
private _exitCalls = 0;
GAIT_fnc_serviceLocomotionExit = {_exitCalls = _exitCalls + 1; false};
GAIT_fnc_getMovementInput = {[0,0,false]};
GAIT_fnc_locomotionDecision = {throw "Deferred exit was overtaken by movement/entry handling";};
missionNamespace setVariable ["GAIT_slopeOwner",player];
missionNamespace setVariable ["GAIT_locomotionRequest",[player,true,false,diag_tickTime]];
player setVariable ["GAIT_locomotionPhase","exiting"];
player setVariable ["GAIT_forwardInputHeld",true];
private _releaseSerial = player getVariable ["GAIT_forwardReleaseSerial",0];
[] call GAIT_fnc_tickLocomotion;
[] call GAIT_fnc_tickLocomotion;
[_exitCalls isEqualTo 2,"render dispatcher services each deferred exit frame"] call _assert;
[(player getVariable ["GAIT_locomotionPhase",""]) isEqualTo "exiting","native source cannot discard deferred entry cancellation"] call _assert;
[(player getVariable ["GAIT_forwardReleaseSerial",0]) isEqualTo (_releaseSerial+1),"deferred cleanup still observes W release exactly once"] call _assert;
GAIT_fnc_serviceLocomotionExit = _actualExitService;
GAIT_fnc_getMovementInput = _actualInput;
GAIT_fnc_locomotionDecision = _actualDecision;
[player] call GAIT_fnc_clearSlopeLocomotionState;
missionNamespace setVariable ["GAIT_locomotionRequest",[]];
diag_log "GAIT TEST PASS: forward coast/re-tap continuity; immediate stop/strafe priority; bounded pending-entry cancellation";
