/* Load actual fn_traversalHelpers.sqf and fn_slopeLocomotion.sqf first.
   Exercise release/retap ordering and live movement priority using the same
   pure policies called by Draw3D. This does not simulate engine root motion. */
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {throw format ["FAIL: %1", _label];};
};
// Stop, re-press and strafing do not wait for the prior graph exit to finish.
// The target is updated by the actual service before returning, so holding
// the same direction cannot issue a second request on subsequent frames.
private _stopTarget = "AmovPercMstpSrasWrflDnon_GAITStop";
[[true,true,true,true,true] call GAIT_fnc_nativeStopDecision,"fresh owned native jogging stop gets short blend"] call _assert;
for "_gate" from 0 to 4 do {
    private _gates = [true,true,true,true,true];
    _gates set [_gate,false];
    [!(_gates call GAIT_fnc_nativeStopDecision),"held stop, foreign pace, prior handoff, idle and unsafe contexts do not issue stop"] call _assert;
};
{
    _x params ["_lease","_now","_weapon","_coefficient","_expected"];
    [([_lease,_now,_weapon,_coefficient] call GAIT_fnc_nativeStopLeaseValid) isEqualTo _expected,"scheduled-to-render stop lease stays scoped to time, weapon and restored coefficient"] call _assert;
} forEach [
    [[10.15,"rifle",1],10.05,"rifle",1,true],
    [[10.15,"rifle",1],10.16,"rifle",1,false],
    [[10.15,"rifle",1],10.05,"pistol",1,false],
    [[10.15,"rifle",1],10.05,"rifle",0.8,false],
    [[],10.05,"rifle",1,false]
];
{
    _x params ["_target","_direction","_expected"];
    [([_target,_direction] call GAIT_fnc_locomotionStopRedirect) isEqualTo _expected,"exit redirect only on changed movement intent"] call _assert;
} forEach [
    [_stopTarget,"Dnon",false],[_stopTarget,"Df",true],[_stopTarget,"Dl",true],[_stopTarget,"Dr",true],
    ["AmovPercMrunSrasWrflDf","Df",false],["AmovPercMrunSrasWrflDf","Dnon",true],
    ["AmovPercMrunSrasWrflDl","Dr",true],["AmovPercMrunSrasWrflDr","Dr",false],["","Df",false]
];
// The numerical coast never prolongs the sprint animation. Live input wins
// on first release frame, even before the feature loop refreshes its envelope.
{
    _x params ["_args", "_expected", "_label"];
    [(_args call GAIT_fnc_locomotionIntent) isEqualTo _expected, _label] call _assert;
} forEach [
    [[true,false,true],false,"release starts jog interpolation while W remains held"],
    [[true,true,false],false,"no movement key means no sprint animation"],
    [[true,true,true],true,"raw Turbo accepts forward and lateral movement"],
    [[false,true,true],false,"context gate still prevents entry"]
];
{
    _x params ["_args", "_expected", "_label"];
    [(_args call GAIT_fnc_locomotionResumeDecision) isEqualTo _expected, _label] call _assert;
} forEach [
    [["exiting",true,true,true,true,true],true,"fresh Turbo edge reverses known safe exit"],
    [["entering",true,true,true,true,true],false,"pending entry is never replayed"],
    [["active",true,true,true,true,true],false,"active clip is never restarted"],
    [["exiting",false,true,true,true,true],false,"held Turbo is not a reassertion loop"],
    [["exiting",true,false,true,true,true],false,"unissued safety deferral cannot be overtaken"],
    [["exiting",true,true,false,true,true],false,"missing live direction or context prevents resume"],
    [["exiting",true,true,true,false,true],false,"medical and stance handoffs retain priority"],
    [["exiting",true,true,true,true,false],false,"unrelated native animation is never overwritten"]
];
// One release edge, one reverse edge, then held input cannot send a second
// request because the live helper latches phase=entering before its command.
private _phase = "exiting";
private _resumes = 0;
{
    private _resume = [_phase,_x,true,true,true,true] call GAIT_fnc_locomotionResumeDecision;
    if (_resume) then {_resumes = _resumes + 1; _phase = "entering";};
} forEach [true,false,false,true];
[_resumes isEqualTo 1,"one interrupted-exit request cannot turn into animation restarting"] call _assert;
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
diag_log "GAIT TEST PASS: prompt graph release/re-tap reversal; immediate stop/strafe priority; bounded pending-entry cancellation";
