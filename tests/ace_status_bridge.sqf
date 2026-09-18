/*
    Load fn_nativeController.sqf before this file, then run in SQF-VM.
    Models ACE 3.21's ordered CBA dispatch and statusEffect_set owner masks.
    Tests the real GAIT installer and clear helper, not Arma animation physics.
*/
private _failures = [];
GAIT_testBridgeEventNames = ["ace_common_blockSprint", "ace_common_forceWalk"];
GAIT_testBridgeEffectNames = ["blockSprint", "forceWalk"];
GAIT_testBridgeEvents = [[], []];
GAIT_testBridgeMasks = [0, 0];
GAIT_testBridgeEngine = [false, false];
GAIT_testBridgeDispatches = 0;
GAIT_testBridgeMode = true;
GAIT_testBridgeMaster = true;
GAIT_testBridgeClearSetting = true;
GAIT_testBridgeActive = true;
GAIT_testBridgePolicyContext = true;
GAIT_testBridgeFrameChecks = 0;
GAIT_testBridgeEffectsCalls = 0;
GAIT_testBridgeReasons = ["ace_advanced_fatigue", "ace_medical_fracture", "ace_dragging"];

// Model the existing mode helper's master/mode/clear-setting contract; exercise
// the real ownership predicate, cleanup helper and event installer below.
GAIT_fnc_modeAllowsAceLockClearing = {GAIT_testBridgeMaster && GAIT_testBridgeMode && GAIT_testBridgeClearSetting};
GAIT_fnc_aceAdvancedFatigueActive = {GAIT_testBridgeActive};
if ([objNull] call GAIT_fnc_fatigueMovementContextEligible) then {
    _failures pushBack "Null unit was eligible to own fatigue movement policy";
};
// SQF-VM has no live player/animation runtime. Replace only the body-context
// sampler, keeping GAIT's real policy gates. An unsafe animation frame must
// not be consulted by the fatigue bridge or hand AF ownership back.
GAIT_fnc_fatigueMovementContextEligible = {GAIT_testBridgePolicyContext};
GAIT_fnc_nativeMovementEligible = {GAIT_testBridgeFrameChecks = GAIT_testBridgeFrameChecks + 1; false};
// SQF-VM does not implement compileFinal. Compare the original code value to
// detect any replacement; final-code engine enforcement is covered by Arma.
ace_advanced_fatigue_fnc_handleEffects = {GAIT_testBridgeEffectsCalls = GAIT_testBridgeEffectsCalls + 1;};
private _originalEffects = ace_advanced_fatigue_fnc_handleEffects;

CBA_fnc_addEventHandler = {
    params ["_event", "_callback"];
    private _eventIndex = GAIT_testBridgeEventNames find _event;
    private _list = GAIT_testBridgeEvents select _eventIndex;
    private _id = _list pushBack _callback;
    GAIT_testBridgeEvents set [_eventIndex, _list];
    _id
};
GAIT_testBridgeDispatch = {
    params ["_event", "_args"];
    GAIT_testBridgeDispatches = GAIT_testBridgeDispatches + 1;
    if (GAIT_testBridgeDispatches > 100) then {throw "Status bridge recursed without stopping";};
    {_args call _x;} forEach (GAIT_testBridgeEvents select (GAIT_testBridgeEventNames find _event));
};
ace_common_fnc_statusEffect_set = {
    params ["_unit", "_effect", "_reason", "_set"];
    private _effectIndex = GAIT_testBridgeEffectNames find _effect;
    private _mask = GAIT_testBridgeMasks select _effectIndex;
    private _index = GAIT_testBridgeReasons find _reason;
    if (_index < 0) then {throw ("Unexpected owner: " + _reason);};
    private _bit = 2 ^ _index;
    private _wasSet = (floor (_mask / _bit) mod 2) == 1;
    if (_wasSet isEqualTo _set) exitWith {};
    private _next = _mask + ([-_bit, _bit] select _set);
    GAIT_testBridgeMasks set [_effectIndex, _next];
    // ACE only sends its event when entering/leaving the zero aggregate mask.
    if (_mask == 0 || {_next == 0}) then {
        ["ace_common_" + _effect, [_unit, _next]] call GAIT_testBridgeDispatch;
    };
};

missionNamespace setVariable ["GAIT_nativeAceBridgeInstalled", false];
missionNamespace setVariable ["GAIT_nativeAceBridgeHandlers", []];
missionNamespace setVariable ["ace_common_commonPostInited", false];
[] call GAIT_fnc_installNativeAceBridge;
if (GAIT_testBridgeEvents isNotEqualTo [[], []]) then {
    _failures pushBack "Bridge registered before ACE Common finished postInit";
};
if (missionNamespace getVariable ["GAIT_nativeAceBridgeInstalled", false]) then {
    _failures pushBack "Bridge reported ready while ACE was still initializing";
};

// The engine setters are ACE's first handlers. GAIT must be appended after them.
["ace_common_blockSprint", {
    GAIT_testBridgeEngine set [0, (_this select 1) > 0];
}] call CBA_fnc_addEventHandler;
["ace_common_forceWalk", {
    GAIT_testBridgeEngine set [1, (_this select 1) > 0];
}] call CBA_fnc_addEventHandler;
missionNamespace setVariable ["ace_common_commonPostInited", true];
[] call GAIT_fnc_installNativeAceBridge;
[] call GAIT_fnc_installNativeAceBridge;
missionNamespace setVariable ["GAIT_nativeAceBridgeInstalled", false];
[] call GAIT_fnc_installNativeAceBridge;
{
    if ((count (GAIT_testBridgeEvents select _forEachIndex)) != 2) then {
        _failures pushBack ("Duplicate bridge handlers after reset: " + _x);
    };
} forEach ["ace_common_blockSprint", "ace_common_forceWalk"];
if !(ace_advanced_fatigue_fnc_handleEffects isEqualTo _originalEffects) then {
    _failures pushBack "Bridge changed ACE's effects function";
};
[] call ace_advanced_fatigue_fnc_handleEffects;
if (GAIT_testBridgeEffectsCalls != 1) then {
    _failures pushBack "ACE effects function did not execute unchanged";
};

{
    private _effect = _x;
    private _effectIndex = _forEachIndex;
    GAIT_testBridgeMasks set [_effectIndex, 0];
    GAIT_testBridgeEngine set [_effectIndex, false];
    private _before = GAIT_testBridgeDispatches;
    [objNull, _effect, "ace_advanced_fatigue", true] call ace_common_fnc_statusEffect_set;
    if ((GAIT_testBridgeMasks select _effectIndex) != 0 || {GAIT_testBridgeEngine select _effectIndex}) then {
        _failures pushBack ("AF lock survived synchronous event dispatch: " + _effect);
    };
    if ((GAIT_testBridgeDispatches - _before) != 2) then {
        _failures pushBack ("Unexpected recursive event count: " + _effect);
    };

    // Existing fracture and dragging owners must survive AF cleanup.
    [objNull, _effect, "ace_medical_fracture", true] call ace_common_fnc_statusEffect_set;
    [objNull, _effect, "ace_dragging", true] call ace_common_fnc_statusEffect_set;
    [objNull, _effect, "ace_advanced_fatigue", true] call ace_common_fnc_statusEffect_set;
    // Adding a reason to a nonzero ACE mask sends no event. Exercise the
    // existing main-loop fallback for that case, where another owner blocks it.
    [objNull] call GAIT_fnc_clearACEAdvancedFatigueMovementLocks;
    if ((GAIT_testBridgeMasks select _effectIndex) != 6 || {!(GAIT_testBridgeEngine select _effectIndex)}) then {
        _failures pushBack ("AF cleanup changed another owner's restriction: " + _effect);
    };
    [objNull, _effect, "ace_medical_fracture", false] call ace_common_fnc_statusEffect_set;
    if ((GAIT_testBridgeMasks select _effectIndex) != 4 || {!(GAIT_testBridgeEngine select _effectIndex)}) then {
        _failures pushBack ("Removing fracture also removed dragging: " + _effect);
    };
    [objNull, _effect, "ace_dragging", false] call ace_common_fnc_statusEffect_set;

    // Disabled master/mode/setting, inactive AF and unsafe body context keep
    // ACE in charge. A transient animation gate has remained false throughout.
    {
        private _gate = _x;
        missionNamespace setVariable [_gate, false];
        [objNull, _effect, "ace_advanced_fatigue", true] call ace_common_fnc_statusEffect_set;
        if ((GAIT_testBridgeMasks select _effectIndex) != 1 || {!(GAIT_testBridgeEngine select _effectIndex)}) then {
            _failures pushBack format ["Bridge ignored eligibility gate %1 for %2", _gate, _effect];
        };
        [objNull, _effect, "ace_advanced_fatigue", false] call ace_common_fnc_statusEffect_set;
        missionNamespace setVariable [_gate, true];
    } forEach ["GAIT_testBridgeMaster", "GAIT_testBridgeMode", "GAIT_testBridgeClearSetting", "GAIT_testBridgeActive", "GAIT_testBridgePolicyContext"];
} forEach ["blockSprint", "forceWalk"];

if (GAIT_testBridgeFrameChecks != 0) then {
    _failures pushBack "Fatigue ownership consulted transient animation/frame eligibility";
};

if (_failures isEqualTo []) then {
    diag_log "GAIT ACE status bridge PASS: initialization order; reset idempotence; effects function preserved; synchronous nested dispatch; medical owner masks; master/mode/AF/context gates; ownership independent of transient animation eligibility.";
} else {
    {diag_log ("GAIT ACE status bridge FAIL: " + _x);} forEach _failures;
    throw "GAIT ACE status bridge regression failed";
};
