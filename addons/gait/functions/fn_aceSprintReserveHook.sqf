/*
    ACE retains its installed fatigue loop and its own effects and stamina bar.
    Capture the anaerobic reserve before ACE debits it, then let GAIT filter
    its net change immediately before ACE publishes percentages and feedback.
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
        private _filter = 'ace_advanced_fatigue_anReserve = [_gaitReserveBefore, ace_advanced_fatigue_anReserve, ACE_player, _anPower / ace_advanced_fatigue_anWattsPerATP] call (missionNamespace getVariable ["GAIT_fnc_filterAceSprintReserve", {_this select 1}]); ';
        _loop = compileFinal ((_source select [0, _beforeOffset]) + _capture +
            (_source select [_beforeOffset, _afterOffset - _beforeOffset]) + _filter + (_source select [_afterOffset]));
    } else {
        diag_log "[GAIT] ACE sprint reserve rules unavailable: installed Advanced Fatigue loop does not match the supported layout.";
        _loop = compileScript [_originalPath, true];
    };
    uiNamespace setVariable ["GAIT_aceSprintReserveLoop", _loop];
    uiNamespace setVariable ["GAIT_aceSprintReserveHookInstalled", _supported];
};
_this call _loop;
