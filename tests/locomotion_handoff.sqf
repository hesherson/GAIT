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
if (_failures isEqualTo []) then {
    diag_log "GAIT locomotion handoff tests PASS: aim-preserving arguments, exact-clip phase, 12 lifecycle cases, one brace/promotion sequence, 36 brace states.";
} else {
    {diag_log ("GAIT locomotion handoff tests FAIL: "+_x);} forEach _failures;
    throw "GAIT locomotion handoff regression failed";
};
