/*
    GAIT 1.8.0-alpha7: replace only ACE Advanced Fatigue's blackout while
    GAIT's intermittent fatigue vignette owns the local player's view.

    ACE creates/enables ppeBlackout once in advanced_fatigue/XEH_postInit.sqf.
    handleEffects only adjusts/commits that handle; handlePlayerChanged resets
    its timer without creating or enabling another effect. Disabling this
    single handle leaves ACE physiology, breathing, pain and medical effects
    running. Never destroy it or replace an ACE function.

    A stale numeric handle is never queried or restored after ACE's published
    handle changes. Arma exposes no generation token for a handle destroyed
    and recreated with the same ID between frames; stock ACE never does this.
*/
GAIT_fnc_aceFatigueVisualHandle = {
    if (isNil {missionNamespace getVariable "ace_advanced_fatigue_ppeBlackout"}) exitWith {-1};
    private _handle = missionNamespace getVariable ["ace_advanced_fatigue_ppeBlackout", -1];
    if !(_handle isEqualType 0) exitWith {-1};
    if (_handle < 0 || {_handle != floor _handle}) exitWith {-1};
    _handle
};

// Engine access stays behind these adapters so lifecycle regressions exercise
// the real ownership code without pretending SQF-VM renders post processing.
GAIT_fnc_aceFatigueVisualHandleSnapshot = {
    params ["_handle"];
    if (_handle < 0 || {_handle != call GAIT_fnc_aceFatigueVisualHandle}) exitWith {[]};
    [ppEffectEnabled _handle]
};

GAIT_fnc_writeACEFatigueVisualEnabled = {
    params ["_handle", "_enabled"];
    if (_handle >= 0 && {_handle == call GAIT_fnc_aceFatigueVisualHandle}) then {
        _handle ppEffectEnable _enabled;
    };
};

GAIT_fnc_ownsACEFatigueVisualPolicy = {
    params [["_unit", player, [objNull]]];
    if !(missionNamespace getVariable ["ace_advanced_fatigue_enabled", false]) exitWith {false};
    if (isNil "GAIT_fnc_fatigueVisualContextEligible") exitWith {false};
    [_unit] call GAIT_fnc_fatigueVisualContextEligible
};

GAIT_fnc_releaseACEFatigueVisualOwnership = {
    private _saved = missionNamespace getVariable ["GAIT_aceFatigueVisualOwnership", []];
    missionNamespace setVariable ["GAIT_aceFatigueVisualOwnership", []];
    missionNamespace setVariable ["GAIT_aceFatigueVisualOwned", false];
    if ((count _saved) != 3) exitWith {};
    _saved params ["_unit", "_handle", "_wasEnabled"];
    // Post effects are local view state, not unit-local state. A player swap,
    // death or locality loss must still restore our current local ACE handle.
    // A replaced/cleared ACE handle may already be destroyed or reused by a
    // different system, so do not query or command its old numeric ID.
    if (!_wasEnabled || {_handle != call GAIT_fnc_aceFatigueVisualHandle}) exitWith {};
    private _current = [_handle] call GAIT_fnc_aceFatigueVisualHandleSnapshot;
    if ((count _current) == 1 && {!(_current select 0)}) then {
        [_handle, true] call GAIT_fnc_writeACEFatigueVisualEnabled;
    };
};

GAIT_fnc_updateACEFatigueVisualOwnership = {
    params [["_unit", player, [objNull]]];
    if !([_unit] call GAIT_fnc_ownsACEFatigueVisualPolicy) exitWith {
        [] call GAIT_fnc_releaseACEFatigueVisualOwnership;
    };
    private _handle = call GAIT_fnc_aceFatigueVisualHandle;
    private _saved = missionNamespace getVariable ["GAIT_aceFatigueVisualOwnership", []];
    if ((count _saved) == 3 && {
        (_saved select 0) isNotEqualTo _unit || {(_saved select 1) != _handle}
    }) then {
        [] call GAIT_fnc_releaseACEFatigueVisualOwnership;
        _saved = [];
    };
    if (_handle < 0) exitWith {[] call GAIT_fnc_releaseACEFatigueVisualOwnership;};
    private _current = [_handle] call GAIT_fnc_aceFatigueVisualHandleSnapshot;
    if ((count _current) != 1) exitWith {[] call GAIT_fnc_releaseACEFatigueVisualOwnership;};
    if (_saved isEqualTo []) then {
        missionNamespace setVariable ["GAIT_aceFatigueVisualOwnership", [_unit, _handle, _current select 0]];
    };
    if (_current select 0) then {[_handle, false] call GAIT_fnc_writeACEFatigueVisualEnabled;};
    missionNamespace setVariable ["GAIT_aceFatigueVisualOwned", true];
};
