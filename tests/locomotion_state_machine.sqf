/*
    Load the real fn_traversalHelpers.sqf and fn_slopeLocomotion.sqf first.
    Exercises the shared pure policy, input resolver and blend-name parser.
    No Arma unit, animation command or engine movement is mocked here.

    Counts below are policy entry/release decisions, not proof that Arma has
    accepted a switchMove or that queued cleanup passes its runtime guards.
    Config-backed blend family checks and Draw3D effect execution require
    their own integration checks and in-game acceptance.
*/
private _failures = [];
private _policyCases = [
    ["No Turbo: no entry", ["native", false, true, false, false, false, true], "clear"],
    ["Turbo without direction does not enter", ["native", true, true, false, false, false, false], "hold"],
    ["First held forward input enters once", ["native", true, true, false, false, false, true], "enter"],
    ["Unsafe context prevents entry", ["native", true, false, false, false, false, true], "clear"],
    ["Waiting entry is not reasserted", ["entering", true, true, false, false, false, true], "hold"],
    ["Exact slow entry blend survives deadline", ["entering", true, true, false, true, true, true], "hold"],
    ["Observed custom entry becomes active", ["entering", true, true, true, false, false, true], "active"],
    ["Unobserved expired entry latches failure", ["entering", true, true, false, false, true, true], "escape"],
    ["Turbo released during entry requests cleanup", ["entering", false, true, false, false, false, true], "release"],
    ["Medical context interrupts pending entry", ["entering", true, false, false, true, false, true], "release"],
    ["Custom movement stays active", ["active", true, true, true, false, false, true], "active"],
    ["Custom idle stays owned while Turbo held", ["active", true, true, true, false, false, false], "active"],
    ["Unexpected graph escape does not re-enter", ["active", true, true, false, false, false, true], "escape"],
    ["Turbo release requests one exit", ["active", false, true, true, false, false, true], "release"],
    ["Medical handoff requests safe cleanup", ["active", true, false, true, false, false, true], "release"],
    ["Blocked held request cannot reassert", ["blocked", true, true, false, false, true, true], "hold"],
    ["Late entry does not unlatch failure", ["blocked", true, true, true, false, true, true], "hold"],
    ["Late custom entry still exits on release", ["blocked", false, true, true, false, true, true], "release"],
    ["Blocked native state clears on release", ["blocked", false, true, false, false, true, true], "clear"],
    ["Unowned custom state cannot be abandoned", ["native", false, true, true, false, false, true], "release"],
    ["Pending exit is not requested twice", ["exiting", false, true, true, false, false, true], "hold"],
    ["Pending exit holds through contact loss", ["exiting", false, false, true, false, false, true], "hold"],
    ["Pending exit blend keeps cleanup metadata", ["exiting", false, false, false, true, true, true], "hold"],
    ["New press cannot overtake pending exit", ["exiting", true, true, true, false, false, true], "hold"],
    ["Timed-out exit never becomes entry retry", ["exiting", true, true, true, false, true, true], "hold"],
    ["Native takeover completes release", ["exiting", false, true, false, false, false, true], "clear"],
    ["Medical takeover clears without entering", ["exiting", true, false, false, false, false, true], "clear"]
];
{
    _x params ["_label", "_arguments", "_expected"];
    private _actual = _arguments call GAIT_fnc_locomotionDecision;
    if (_actual isNotEqualTo _expected) then {
        _failures pushBack format ["%1: expected %2, got %3", _label, _expected, _actual];
    };
} forEach _policyCases;

// Live W/A/D and idle changes retain one owned family. Policy `_requested`
// here means graph ownership; sprint pace intentionally has its own forward gate.
private _phase = "native";
private _entryDecisions = 0;
private _releaseDecisions = 0;
private _directionSequence = [];
{
    _x params ["_raw", "_inside", "_expectedDirection", "_expectedAction"];
    private _input = _raw call GAIT_fnc_resolveMovementInput;
    private _moving = abs (_input select 0) > 0.05 || {abs (_input select 1) > 0.05};
    private _direction = [_input select 0, _input select 1] call GAIT_fnc_slopeDirection;
    private _action = [_phase, _input select 2, true, _inside, false, false, _moving] call GAIT_fnc_locomotionDecision;
    _directionSequence pushBack _direction;
    if (_direction isNotEqualTo _expectedDirection || {_action isNotEqualTo _expectedAction}) then {
        _failures pushBack format ["Direction sequence %1: direction=%2 action=%3 expected=%4/%5", _forEachIndex, _direction, _action, _expectedDirection, _expectedAction];
    };
    switch (_action) do {
        case "enter": {_phase = "entering"; _entryDecisions = _entryDecisions + 1;};
        case "active": {_phase = "active";};
        case "release": {_phase = "exiting"; _releaseDecisions = _releaseDecisions + 1;};
        case "clear": {_phase = "native";};
        case "escape": {_phase = "blocked";};
    };
} forEach [
    [[1,0,0,0,1], false, "Df", "enter"],
    [[1,0,0,0,1], true, "Df", "active"],
    [[1,0,1,0,1], true, "Dfl", "active"],
    [[0,0,1,0,1], true, "Dl", "active"],
    [[0,0,0,1,1], true, "Dr", "active"],
    [[0,0,1,1,1], true, "Dnon", "active"],
    [[0,0,0,0,1], true, "Dnon", "active"],
    [[1,0,0,1,1], true, "Dfr", "active"],
    [[1,0,0,0,0], true, "Df", "release"],
    [[1,0,0,0,0], true, "Df", "hold"],
    [[1,0,0,0,0], false, "Df", "clear"]
];
if (_entryDecisions isNotEqualTo 1 || {_releaseDecisions isNotEqualTo 1} || {_phase isNotEqualTo "native"}) then {
    _failures pushBack format ["Held-input sequence restarted ownership: entries=%1 releases=%2 phase=%3", _entryDecisions, _releaseDecisions, _phase];
};

private _forwardTarget = "AmovPercMevaSrasWrflDf_GAIT";
if !([_forwardTarget, "Dfl"] call GAIT_fnc_locomotionDirectionRedirectNeeded) then {
    _failures pushBack "Forward target did not admit W+A redirect";
};
if !([_forwardTarget, "Dl"] call GAIT_fnc_locomotionDirectionRedirectNeeded) then {
    _failures pushBack "Forward target did not admit pure-left redirect";
};
if ([_forwardTarget, "Df"] call GAIT_fnc_locomotionDirectionRedirectNeeded) then {
    _failures pushBack "Unchanged forward target requested redundant redirect";
};
if ((["SrasWrfl", "Dfl"] call GAIT_fnc_slopeStateName) isNotEqualTo "AmovPercMevaSrasWrflDfl_GAIT") then {
    _failures pushBack "Diagonal redirect lost sprint family";
};
if ((["SrasWrfl", "Dl"] call GAIT_fnc_slopeStateName) isNotEqualTo "AmovPercMrunSrasWrflDl_GAIT") then {
    _failures pushBack "Lateral redirect lost run family";
};

private _nativeEntrySource = "AmovPercMrunSrasWrflDf";
if !([_nativeEntrySource, _nativeEntrySource, true, false, false, false]
    call GAIT_fnc_locomotionEntryRedirectKnown) then {
    _failures pushBack "Exact native entry source could not redirect before blend appeared";
};
if ([_nativeEntrySource, _nativeEntrySource, false, false, false, false]
    call GAIT_fnc_locomotionEntryRedirectKnown) then {
    _failures pushBack "Expired native entry source retained redirect authority";
};
if (["AmovPercMrunSrasWrflDr", _nativeEntrySource, true, false, false, false]
    call GAIT_fnc_locomotionEntryRedirectKnown) then {
    _failures pushBack "Unrelated native observation gained entry redirect authority";
};

// Failed entry followed by a late custom observation stays blocked until the
// user's release. Cleanup remains pending through unsafe contact, and a
// medical/native takeover clears it without any new entry decision.
_phase = "native";
private _failureSequence = [];
{
    _x params ["_requested", "_eligible", "_inside", "_blend", "_expired", "_moving", "_expectedAction"];
    private _action = [_phase, _requested, _eligible, _inside, _blend, _expired, _moving] call GAIT_fnc_locomotionDecision;
    _failureSequence pushBack _action;
    if (_action isNotEqualTo _expectedAction) then {
        _failures pushBack format ["Escape/cleanup sequence %1: expected %2, got %3", _forEachIndex, _expectedAction, _action];
    };
    switch (_action) do {
        case "enter": {_phase = "entering";};
        case "active": {_phase = "active";};
        case "escape": {_phase = "blocked";};
        case "release": {_phase = "exiting";};
        case "clear": {_phase = "native";};
    };
} forEach [
    [true,true,false,false,false,true,"enter"],
    [true,true,false,false,true,true,"escape"],
    [true,true,false,false,true,true,"hold"],
    [true,true,true,false,true,true,"hold"],
    [false,true,true,false,true,true,"release"],
    [false,false,true,false,true,true,"hold"],
    [false,false,false,false,true,true,"clear"],
    [false,true,false,false,true,true,"clear"]
];
if (({_x isEqualTo "enter"} count _failureSequence) isNotEqualTo 1) then {
    _failures pushBack "Escape/medical cleanup produced a delayed entry";
};

// Parser contract: syntax only. Real custom-family membership is checked by
// GAIT_fnc_slopeAnimationFamily against loaded config, not inferred from names.
private _left = "amovpercmevasraswrfldf_gait";
private _right = "amovpercmrunsraswrfldl_gait";
private _blendCases = [
    ["AmovPercMevaSrasWrflDf_GAIT_AmovPercMrunSrasWrflDl_GAIT", [_left, _right]],
    ["amovpercmstpsraswrfldnon_gait_amovpercmevasraswrfldfr_gait", ["amovpercmstpsraswrfldnon_gait", "amovpercmevasraswrfldfr_gait"]],
    ["AmovPercMevaSrasWrflDf_GAIT", []],
    ["AmovPercMevaSrasWrflDf_AmovPercMrunSrasWrflDl_GAIT", []],
    ["AmovPercMevaSrasWrflDf_GAIT_AmovPercMrunSrasWrflDl", []],
    ["AmovPercMevaSrasWrflDf_GAIT_AmovPknlMstpSrasWrflDnon", []],
    ["AmovPercMevaSrasWrflDf_GAIT_AinvPknlMstpSnonWnonDnon_medic", []],
    ["AmovPercMevaSrasWrflDf_GAIT_AmovPercMrunSrasWrflDl_GAIT_reload", []],
    ["AmovPercMevaSrasWrflDf_GAIT_AmovPercMrunSrasWrflDl_GAIT_AmovPercMevaSrasWrflDf_GAIT", []],
    ["", []]
];
{
    _x params ["_name", "_expected"];
    private _actual = [_name] call GAIT_fnc_splitSlopeBlend;
    if (_actual isNotEqualTo _expected) then {
        _failures pushBack format ["Blend-name parser %1: expected %2, got %3", _name, _expected, _actual];
    };
} forEach _blendCases;

if (_failures isEqualTo []) then {
    diag_log format ["GAIT locomotion state machine tests PASS: %1 policy cases; held W/A/D/idle, immediate native-source startup redirect and release direction redirects; blocked/late-entry/medical sequence; %2 blend-name cases.", count _policyCases, count _blendCases];
} else {
    {diag_log ("GAIT locomotion state machine tests FAIL: " + _x);} forEach _failures;
    throw "GAIT locomotion state machine regression failed";
};
