/* Execute the production handoff lifecycle; replace the engine observation only. */
private _assert = {params ["_ok", "_label"]; if (!_ok) then {throw ("FAIL " + _label);};};
private _unit = player;
private _match = ["sprint", "jog", 6, 4, 3.44, "rifle", "Df", "ground", 0];
private _context = [true, false, "sprint", [0,0,0,1]];
GAIT_fnc_paceHandoffContext = {_context};
private _start = {
    _unit setVariable ["GAIT_paceHandoff", [_match,diag_tickTime+0.5,[],0,diag_tickTime]];
    _unit setVariable ["GAIT_releaseResume", []];
};
call _start;
private _out = [_unit, 1.2] call GAIT_fnc_samplePaceHandoff;
[abs (_out - 3.44/6) < 0.00001, "source endpoint starts at converted sprint coefficient"] call _assert;
_context = [true,false,"sprint",[0,0,0,0.5]];
_out = [_unit,0.86] call GAIT_fnc_samplePaceHandoff;
[abs (_out - 3.44/5) < 0.00001, "outgoing primary clip uses complementary weight"] call _assert;
_context = [true,false,"jog",[0,0,0,0.5]];
_out = [_unit,0.86] call GAIT_fnc_samplePaceHandoff;
[abs (_out - 3.44/5) < 0.00001, "live engine blend factor controls conversion"] call _assert;
_context = [true,false,"jog",[0,0,0,1]];
_out = [_unit,0.5] call GAIT_fnc_samplePaceHandoff;
[abs (_out - 0.86) < 0.00001, "native endpoint reaches ordinary coefficient without a second tail"] call _assert;
[(_unit getVariable ["GAIT_paceHandoff",[]]) isEqualTo [],"completed bridge retires"] call _assert;
// Explicit transition clips use phase, and unsupported actions are not converted.
call _start;
_context = [true,false,"sprint_jog",[0.25,0,0,1]];
_out = [_unit,0.86] call GAIT_fnc_samplePaceHandoff;
[abs (_out - 3.44/5.5) < 0.00001,"explicit transition uses its normalized phase"] call _assert;
_context = [true,false,"medical",[0,0,0,1]];
_out = [_unit,0.75] call GAIT_fnc_samplePaceHandoff;
[_out isEqualTo 0.75 && {(_unit getVariable ["GAIT_paceHandoff",[]]) isEqualTo []},"unknown action cancels without stealing its pace"] call _assert;
// Mid-blend sprint re-press retires the fade and returns ownership immediately.
call _start;
_context = [true,true,"jog",[0,0,0,1]];
_out = [_unit,1.2] call GAIT_fnc_samplePaceHandoff;
[_out isEqualTo 1.2 && {(_unit getVariable ["GAIT_paceHandoff",[]]) isEqualTo []},"retap returns to the normal live coefficient writer"] call _assert;
[abs (((_unit getVariable ["GAIT_releaseResume",[]]) select 0)-3.44/6)<0.00001,"retap supplies converted sprint seed"] call _assert;

// Issue a jog immediately. It can finish blending while the same finite
// physical deceleration is still running on the ordinary gait.
private _plan = [10,7.2,1.2,3.44/6,1.15,1.45] call GAIT_fnc_releaseMomentumPlan;
_unit setVariable ["GAIT_releaseMomentumState",[_plan,["rifle","SrasWrfl","Df","sprint"]]];
_unit setVariable ["GAIT_paceHandoffCandidate",[_match,diag_tickTime+0.15]];
[_unit,"sprint","jog"] call GAIT_fnc_beginPaceHandoff;
(_unit getVariable ["GAIT_paceHandoff", []]) set [4, 10];
_context = [true,false,"sprint",[0,0,0,1]];
_out = [_unit,1.2,10] call GAIT_fnc_samplePaceHandoff;
[abs (_out-1.2)<0.00001,"armed handoff starts from the captured sprint speed"] call _assert;
_context = [true,false,"jog",[0,0,0,1]];
private _sampleAt = 10 + ((_plan select 1) * 0.5);
private _intended = ([_plan,_sampleAt] call GAIT_fnc_releaseMomentumSample) select 1;
_out = [_unit,0.86,_sampleAt] call GAIT_fnc_samplePaceHandoff;
[abs (_out * 4 - _intended)<0.00001,"the native jog follows the remaining pace instead of holding the sprint clip"] call _assert;
[(_unit getVariable ["GAIT_paceHandoff",[]]) isNotEqualTo [],"completed animation blend does not end numerical deceleration early"] call _assert;
_out = [_unit,0.86,12] call GAIT_fnc_samplePaceHandoff;
[abs (_out-0.86)<0.00001 && {(_unit getVariable ["GAIT_releaseMomentumState",[]]) isEqualTo []},
    "native jog reaches ordinary speed and retires the same plan"] call _assert;

call _start;
(_unit getVariable ["GAIT_paceHandoff", []]) set [4, 10];
_context = [true,false,"sprint",[0,0,0,1]];
_out = [_unit,0.86,10.16] call GAIT_fnc_samplePaceHandoff;
[_out isEqualTo 0.86 && {(_unit getVariable ["GAIT_paceHandoff",[]]) isEqualTo []},
    "unobserved native exit cannot keep a sprint-speed fade in the old clip"] call _assert;

call _start;
_context = [false,false,"jog",[0,0,0,0.5]];
_out = [_unit,0.86] call GAIT_fnc_samplePaceHandoff;
[_out isEqualTo 0.86 && {(_unit getVariable ["GAIT_paceHandoff",[]]) isEqualTo []},"expired, changed input or lost ownership cancels immediately"] call _assert;
_unit setVariable ["GAIT_paceHandoffCandidate",[_match,diag_tickTime+0.15]];
[_unit,"sprint","stop"] call GAIT_fnc_beginPaceHandoff;
[(_unit getVariable ["GAIT_paceHandoff",[]]) isEqualTo [],"stop cannot start a stale jog bridge"] call _assert;
diag_log "GAIT TEST PASS: immediate native jog and continuing finite pace, blend endpoints, retap conversion, unsafe context and stale target cancellation.";
