// Run after fn_traversalHelpers.sqf in SQF-VM, or execVM in an Arma test mission.
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {throw format ["FAIL: %1", _label];};
};
private _left = [0,0,1,0,1] call GAIT_fnc_resolveMovementInput;
{
    _x params ["_normal", "_direction", "_degrees"];
    [abs (([_normal, _direction] call GAIT_fnc_surfaceTravelGrade) - _degrees) < 0.01,
        "walkable face grade follows travel on ramp, contour and level bridge"] call _assert;
} forEach [[[0,0,1],[1,0,0],0], [[-0.5,0,0.8660254],[1,0,0],30],
    [[-0.5,0,0.8660254],[-1,0,0],-30], [[-0.5,0,0.8660254],[0,1,0],0], [[1,0,0],[1,0,0],0]];
[_left isEqualTo [0,-1,true], "A only has no forward movement"] call _assert;
private _right = [0,0,0,1,1] call GAIT_fnc_resolveMovementInput;
[_right isEqualTo [0,1,true], "A to D reverses on the next sample"] call _assert;
private _overlap = [1,0,1,1,1] call GAIT_fnc_resolveMovementInput;
[_overlap isEqualTo [1,0,true], "opposing strafes cancel while W remains held"] call _assert;
private _opposite = [1,1,0,0,1] call GAIT_fnc_resolveMovementInput;
[_opposite isEqualTo [0,0,true], "W and S cancel"] call _assert;
private _diagonal = [1,0,1,0,1] call GAIT_fnc_resolveMovementInput;
[abs (((_diagonal select 0)^2 + (_diagonal select 1)^2) - 1) < 0.00001, "diagonal magnitude is one"] call _assert;
private _analog = [0.4,0,0,0.3,0] call GAIT_fnc_resolveMovementInput;
[_analog isEqualTo [0.4,0.3,false], "analog magnitude below one is preserved"] call _assert;
private _deadzone = [0.03,0,0.02,0,0] call GAIT_fnc_resolveMovementInput;
[_deadzone isEqualTo [0,0,false], "input deadzone"] call _assert;
[([0,0,0,0,0,[1,0,0,0]] call GAIT_fnc_resolveMovementInput) isEqualTo [1,0,false],
    "Ctrl+W remains forward when only the adjustment action is reported"] call _assert;
[([0,0,0,0,0,[0,0,1,0]] call GAIT_fnc_resolveMovementInput) isEqualTo [0,-1,false] &&
    {([0,0,0,0,0,[0,0,0,1]] call GAIT_fnc_resolveMovementInput) isEqualTo [0,1,false]},
    "Ctrl+A and Ctrl+D follow live input without a carried direction"] call _assert;
[([0,0,0,0,0,[0,0,0,0]] call GAIT_fnc_resolveMovementInput) isEqualTo [0,0,false],
    "Ctrl alone produces no movement"] call _assert;
{
    _x params ["_animation", "_handoff", "_expected"];
    [([_animation, false, _handoff] call GAIT_fnc_canReadTravelAdjustments) isEqualTo _expected,
        format ["Adjust inputs in %1 during handoff=%2", _animation, _handoff]] call _assert;
} forEach [
    ["AmovPercMrunSlowWrflDf_GAIT", true, true],
    ["AmovPercMstpSlowWrflDnon_GAIT", true, true],
    ["AmovPercMstpSlowWrflDnon", true, true],
    ["AmovPknlMrunSrasWrflDfr", true, true],
    ["AmovPercMstpSlowWrflDnon", false, false],
    ["AadjPercMstpSrasWrflDup", true, false]
];
private _results = [];
{
    private _dt = _x;
    private _value = 0.6;
    for "_i" from 1 to round (1 / _dt) do {
        _value = [_value,1.2,0.05,_dt] call GAIT_fnc_stepSpeedCoefficient;
    };
    _results pushBack _value;
} forEach [0.01,0.02,0.05,0.1,0.2];
{[abs (_x - (_results select 0)) < 0.00001, "one-second ramp independent of update interval"] call _assert;} forEach _results;
private _decel = [1.2,0.6,0.05,0.05] call GAIT_fnc_stepSpeedCoefficient;
[_decel < 1.2 && {_decel > 0.6}, "deceleration is monotonic without overshoot"] call _assert;
private _jogRamp = [1.50, true] call GAIT_fnc_jogDecelerationRamp;
private _pace = 1.10;
{
    _x params ["_actions", "_direction", "_jogTarget"];
    private _input = _actions call GAIT_fnc_resolveMovementInput;
    [[_input select 0, _input select 1] isEqualTo _direction, "live direction reaches the engine on the current sample"] call _assert;
    private _next = [_pace, _jogTarget, _jogRamp, 0.05] call GAIT_fnc_stepSpeedCoefficient;
    [_next < _pace && {_next > _jogTarget}, "changed direction uses current scalar without restarting or snapping"] call _assert;
    _pace = _next;
} forEach [
    [[1,0,0,0,0], [1,0], 0.86],
    [[1,0,1,0,0], [sqrt 0.5,-sqrt 0.5], 0.86],
    [[0,0,1,0,0], [0,-1], 0.82],
    [[0,0,0,1,0], [0,1], 0.82],
    [[0,1,0,0,0], [-1,0], 0.82]
];
private _settled = 1.10;
for "_i" from 1 to 30 do {_settled = [_settled, 0.86, _jogRamp, 0.05] call GAIT_fnc_stepSpeedCoefficient;};
[abs (_settled - (0.86 + (0.05 * (1.10 - 0.86)))) < 0.00001, "jog deceleration duration represents 95% convergence"] call _assert;
private _direct = [1.50, false] call GAIT_fnc_jogDecelerationRamp;
if (abs (([10,11.35] call GAIT_fnc_sprintWalkProgress) - 0.5) > 0.00001 ||
    {abs (([10,12.7] call GAIT_fnc_sprintWalkProgress) - 1) > 0.00001}) then {
    throw "FAIL: sprint-to-walk progress reaches the endpoint at 2.7 seconds";
};
private _jog = "AmovPercMrunSrasWrflDf_GAIT";
private _downhillScale = [-24] call GAIT_fnc_sprintReleaseSlopeScale;
private _uphillScale = [32] call GAIT_fnc_sprintReleaseSlopeScale;
private _downhillProgress = [10, 11.5, _downhillScale] call GAIT_fnc_sprintWalkProgress;
private _uphillProgress = [10, 11.5, _uphillScale] call GAIT_fnc_sprintWalkProgress;
{
    _x params ["_animation", "_carrying", "_expected"];
    if (([_animation, _carrying] call GAIT_fnc_casualtyClip) isNotEqualTo _expected) then {
        throw ("Unexpected casualty movement classification for " + _animation);
    };
} forEach [
    ["AcinPercMwlkSnonWnonDfl", true, "carryWalk"],
    ["AcinPercMrunSnonWnonDf", true, "carryRun"],
    ["AcinPknlMwlkSrasWrflDb", false, "drag"],
    ["ace_dragging_rifle_limpB", false, "drag"],
    ["ace_dragging_limpB", false, "drag"],
    ["AcinPercMstpSnonWnonDnon", true, ""],
    ["AcinPknlMstpSnonWnonDnon_AcinPercMrunSnonWnonDnon", true, ""],
    ["AmovPercMstpSlowWrflDnon_AcinPknlMwlkSlowWrflDb_2", false, ""],
    ["ace_dragging_static", false, ""],
    ["ace_dragging_drop", false, ""],
    ["AinjPpneMrunSnonWnonDb_still", false, ""]
];
missionNamespace setVariable ["GAIT_ss_sprintWalkTaperDuration", 0.05];
private _shortLegacyTaper = [10, 11.5] call GAIT_fnc_sprintWalkProgress;
missionNamespace setVariable ["GAIT_ss_sprintWalkTaperDuration", 4];
private _longLegacyTaper = [10, 11.5] call GAIT_fnc_sprintWalkProgress;
missionNamespace setVariable ["GAIT_ss_sprintWalkTaperDuration", nil];
if (abs (_shortLegacyTaper - (1.5 / 2.3)) > 0.00001 || {abs (_longLegacyTaper - (1.5 / 2.9)) > 0.00001}) then {
    throw "Saved sprint-release settings must stay within the new taper range.";
};
if (!(_downhillProgress < 0.40) || {_uphillProgress isNotEqualTo 1} ||
    {([0] call GAIT_fnc_sprintReleaseSlopeScale) isNotEqualTo 1}) then {
    throw "FAIL: directional grade lengthens downhill release and shortens uphill release";
};
{
    _x params ["_animation", "_blending", "_expected"];
    if (([_animation, _blending] call GAIT_fnc_stanceAnimationDepth) isNotEqualTo _expected) then {
        throw format ["FAIL: stance depth for %1", _animation];
    };
} forEach [
    ["AmovPercMrunSrasWrflDf_GAIT_AmovPknlMrunSrasWrflDf", false, 0.85],
    ["AmovPpneMstpSrasWrflDnon_AmovPercMstpSrasWrflDnon", false, 1],
    ["AadjPknlMstpSrasWrflDup", true, 0.85],
    ["AadjPpneMstpSrasWrflDleft_AmovPpneMstpSrasWrflDnon", false, 1],
    ["AadjPknlMstpSrasWrflDup", false, 0],
    ["AmovPercMrunSrasWrflDf_GAIT_AmovPercMrunSrasWrflDfl_GAIT", true, 0]
];
private _walk = "AmovPercMwlkSrasWrflDf_GAIT";
private _sprint = "AmovPercMevaSrasWrflDf_GAIT";
if ([0.2,_jog,_jog,0.9,"mwlk"] call GAIT_fnc_sprintReleaseUsesSlowerPace ||
    {[0.2,_jog,_sprint,0.58,"mwlk"] call GAIT_fnc_sprintReleaseUsesSlowerPace} ||
    {!([0.2,_jog,_jog,0.58,"mwlk"] call GAIT_fnc_sprintReleaseUsesSlowerPace)} ||
    {!([0.85,_jog,_jog,0.8,"mwlk"] call GAIT_fnc_sprintReleaseUsesSlowerPace)} ||
    {!([0.3,_walk,_jog,0.8,"mwlk"] call GAIT_fnc_sprintReleaseUsesSlowerPace)}) then {
    throw "FAIL: the walk handoff is early at low jog cadence, bounded in time and stays latched";
};
[[ "combat", 5, _downhillScale ] call GAIT_fnc_sprintReleaseInterimJog,
    "steep downhill combat release retains a jog for the high-speed portion"] call _assert;
[[ "combat", 5, _uphillScale ] call GAIT_fnc_sprintReleaseInterimJog &&
    {!([ "walk", 0, _downhillScale ] call GAIT_fnc_sprintReleaseInterimJog)},
    "fast combat release retains a jog on any grade, while a release without speed uses its selected pace"] call _assert;
[[0.3,"AmovPercMtacSrasWrflDf_GAIT",_jog,0.8,"mtac"] call GAIT_fnc_sprintReleaseUsesSlowerPace,
    "the downhill combat handoff stays latched once requested"] call _assert;
[!([0.8,_jog,_jog,0.9,"mwlk",3,1.4] call GAIT_fnc_sprintReleaseUsesSlowerPace),
    "late wind-down stays in a jog while walking would need double playback"] call _assert;
[[0.8,_jog,_jog,0.55,"mwlk",1.5,1.4] call GAIT_fnc_sprintReleaseUsesSlowerPace,
    "walking starts once its cadence can carry the remaining speed"] call _assert;
[([1.1,0.86,_direct,0.05] call GAIT_fnc_stepSpeedCoefficient) isEqualTo 0.86, "disabled smoothing uses the current jog target"] call _assert;
private _stalled = [0.6,1.2,0.05,4] call GAIT_fnc_stepSpeedCoefficient;
{
    private _releaseProgress = _x;
    {
        _x params ["_actions","_expected"];
        private _input = _actions call GAIT_fnc_resolveMovementInput;
        [_input isEqualTo _expected, format ["live interruption input at release progress %1",_releaseProgress]] call _assert;
    } forEach [
        [[0,0,0,0,0,[1,0,0,0]],[1,0,false]],
        [[0,0,0,0,0,[0,0,1,0]],[0,-1,false]],
        [[0,0,0,0,0,[0,0,0,1]],[0,1,false]],
        [[0,0,0,0,1,[1,0,0,0]],[1,0,true]],
        [[0,0,0,0,0,[0,0,0,0]],[0,0,false]]
    ];
} forEach [0,0.25,0.5,0.9,1];
private _bounded = [0.6,1.2,0.05,0.2] call GAIT_fnc_stepSpeedCoefficient;
[abs (_stalled - _bounded) < 0.00001, "scheduler stall cannot skip the full ramp"] call _assert;
diag_log "GAIT TEST PASS: input cancellation, reversal, diagonals, analog input and time-based ramp";
