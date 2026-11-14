/*
    ACE retains its installed fatigue loop, effects and stamina bar.
    Capture the anaerobic reserve before ACE debits it, then let GAIT filter
    exertion and rest immediately before ACE publishes percentages and feedback.
    Prevent ACE's own fatigue locks from interrupting GAIT land movement.
*/
private _originalPath = "\z\ace\addons\advanced_fatigue\functions\fnc_mainLoop.sqf";
private _loop = uiNamespace getVariable "GAIT_aceSprintReserveLoop";
if (isNil "_loop") then {
    private _source = preprocessFileLineNumbers _originalPath;
    private _before = '\bace_advanced_fatigue_anReserve\s*=\s*0\s+max\s*\(\s*ace_advanced_fatigue_anReserve\s*-\s*_anPower\s*/\s*ace_advanced_fatigue_anWattsPerATP\s*\)\s*;/g';
    private _after = '\bace_advanced_fatigue_anReservePercentage\s*=\s*ace_advanced_fatigue_anReserve\s*/\s*2300\s*;/g';
    private _beforeMatches = _source regexFind [_before];
    private _afterMatches = _source regexFind [_after];
    private _supported = (count _beforeMatches) isEqualTo 1 && {(count _afterMatches) isEqualTo 1} &&
        {((_beforeMatches select 0 select 0) select 1) < ((_afterMatches select 0 select 0) select 1)};
    if (_supported) then {
        private _beforeOffset = (_beforeMatches select 0 select 0) select 1;
        private _afterOffset = (_afterMatches select 0 select 0) select 1;
        private _capture = 'private _gaitReserveBefore = ace_advanced_fatigue_anReserve; ';
        private _filter = 'ace_advanced_fatigue_anReserve = [_gaitReserveBefore, ace_advanced_fatigue_anReserve, ACE_player] call (missionNamespace getVariable ["GAIT_fnc_filterAceSprintReserve", {_this select 1}]); ';
        _source = (_source select [0, _beforeOffset]) + _capture +
            (_source select [_beforeOffset, _afterOffset - _beforeOffset]) + _filter + (_source select [_afterOffset]);
    } else {
        diag_log "[GAIT] ACE sprint reserve rules unavailable: installed Advanced Fatigue loop does not match the supported layout.";
    };
    private _effectsCall = '\bcall\s+ace_advanced_fatigue_fnc_handleEffects\s*;/gi';
    private _effectsSupported = count (_source regexFind [_effectsCall]) isEqualTo 1;
    if (_effectsSupported) then {
        _source = _source regexReplace [_effectsCall, 'call _gaitRunFatigueEffects;'];
    } else {
        diag_log "[GAIT] ACE fatigue movement guard unavailable: installed Advanced Fatigue loop does not match the supported effects call.";
    };
    if (_supported || {_effectsSupported}) then {
        _loop = compileFinal _source;
    } else {
        _loop = compileScript [_originalPath, true];
    };
    uiNamespace setVariable ["GAIT_aceSprintReserveLoop", _loop];
    uiNamespace setVariable ["GAIT_aceSprintReserveHookInstalled", _supported];
};

// Resolve the live function: ACM and ACME replace it via CfgFunctions. Keep
// the original callback intact for swimming and any movement GAIT does not own.
private _gaitRunFatigueEffects = {
    private _original = ace_advanced_fatigue_fnc_handleEffects;
    private _unit = _this param [0, objNull, [objNull]];
    if !([_unit] call (missionNamespace getVariable ["GAIT_fnc_ownsFatigueMovementPolicy", {false}])) exitWith {
        _this call _original
    };
    private _cache = missionNamespace getVariable ["GAIT_aceFatigueEffectsCache", []];
    if (_cache isEqualTo [] || {_original isNotEqualRef (_cache select 0)}) then {
        private _source = toString _original;
        // Match each literal ACE fatigue write in the installed callback.
        // A variant with fewer/more writes still gets its known locks guarded.
        private _fatigueLock = '\[\s*_unit\s*,\s*"(blockSprint|forceWalk)"\s*,\s*"ace_advanced_fatigue"\s*,\s*true\s*\]\s*call\s+ace_common_fnc_statusEffect_set\b/gi';
        private _matches = _source regexFind [_fatigueLock];
        private _guarded = _original;
        if (_matches isNotEqualTo []) then {
            _guarded = compileFinal (_source regexReplace [_fatigueLock, "false"]);
        } else {
            diag_log "[GAIT] ACE fatigue movement guard unavailable: installed Advanced Fatigue effects do not match the supported lock layout.";
        };
        _cache = [_original, _guarded];
        missionNamespace setVariable ["GAIT_aceFatigueEffectsCache", _cache];
    };
    _this call (_cache select 1)
};
_this call _loop;
