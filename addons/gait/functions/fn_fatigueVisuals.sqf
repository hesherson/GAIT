/*
    Brief peripheral fatigue cues. These helpers create one local vignette and
    delegate ACE's fatigue-only blackout policy to the narrow ACE bridge. They
    never alter medical, pain, unconsciousness or mission PP handles.

    Update the request every simulation tick; the independent render guardian
    expires it after 0.75 seconds if that caller stops or skips a branch.
    Each 1.30-second pulse ends by destroying the effect, with 5-12 seconds
    completely clear before another pulse can start. Recovery and context
    changes tear it down immediately. No blur, aberration or aim commands.

    Radial ColorCorrections parameters documented by Bohemia:
    https://community.bohemia.net/wiki/Post_process_effects#ColorCorrections
*/

GAIT_fnc_fatigueVisualClock = {diag_tickTime};

// Pure timing model: [state, alpha], state = [start, nextAllowed, strength].
// A missed frame completes the old pulse and starts a full clear interval;
// it never catches up by immediately starting another visible pulse.
GAIT_fnc_stepFatigueVisualPulse = {
    params [
        ["_state", [], [[]]],
        ["_now", 0, [0]],
        ["_strength", 0, [0]]
    ];
    _strength = (_strength max 0) min 1;
    if (_strength <= 0) exitWith {
        // Zero input cancels a visible pulse but preserves a full clear gap.
        // An already clear state keeps its existing deadline; repeated zero
        // updates cannot extend it or erase a longer low-fatigue interval.
        if ((count _state) != 3) exitWith {[[-1, _now, 0], 0]};
        if ((_state # 0) >= 0) exitWith {[[-1, _now + 5, 0], 0]};
        [_state, 0]
    };
    if ((count _state) != 3) then {_state = [_now, -1, _strength];};
    _state params ["_start", "_nextAllowed", "_peakStrength"];
    if (_start < 0) then {
        if (_now >= _nextAllowed) then {
            _start = _now;
            _peakStrength = _strength;
        };
    };
    if (_start < 0) exitWith {[[_start, _nextAllowed, _peakStrength], 0]};
    private _elapsed = _now - _start;
    if (_elapsed < 0 || {_elapsed >= 1.30}) exitWith {
        private _clearDuration = 12 - (7 * _strength);
        [[-1, _now + _clearDuration, 0], 0]
    };

    // A recovery can soften the current pulse, but a rising input cannot
    // cause an abrupt mid-pulse increase or extend its fixed deadline.
    _peakStrength = _peakStrength min _strength;
    private _envelope = 1;
    if (_elapsed < 0.40) then {
        private _fraction = _elapsed / 0.40;
        _envelope = _fraction * _fraction * (3 - 2 * _fraction);
    } else {
        if (_elapsed >= 0.65) then {
            private _fraction = ((_elapsed - 0.65) / 0.65) min 1;
            _envelope = 1 - (_fraction * _fraction * (3 - 2 * _fraction));
        };
    };
    [[_start, _nextAllowed, _peakStrength], 0.14 * _peakStrength * _envelope]
};

GAIT_fnc_fatigueVisualContextEligible = {
    params [["_unit", objNull, [objNull]]];
    if (isNull _unit || {!hasInterface} || {_unit isNotEqualTo player} || {!local _unit} || {!alive _unit}) exitWith {false};
    if (!(missionNamespace getVariable ["GAIT_ss_fatigueVignetteEnabled", true])) exitWith {false};
    if (isNil "GAIT_fnc_modeAllowsEffects" || {!(call GAIT_fnc_modeAllowsEffects)}) exitWith {false};
    if (isNil "GAIT_fnc_isSuspendedContext" || {call GAIT_fnc_isSuspendedContext}) exitWith {false};
    if (_unit getVariable ["ACE_isUnconscious", false] || {(lifeState _unit) isEqualTo "INCAPACITATED"} || {_unit getVariable ["GAIT_isTripping", false]}) exitWith {false};
    private _camera = cameraOn;
    if (!isNull _camera && {_camera isNotEqualTo _unit} && {_camera isNotEqualTo vehicle _unit}) exitWith {false};
    true
};

// Engine boundaries remain small so the production lifecycle can be exercised
// under SQF-VM without pretending to simulate rendered PP pixels.
GAIT_fnc_createFatigueVignette = {
    ppEffectCreate ["ColorCorrections", 1586]
};

GAIT_fnc_writeFatigueVignette = {
    params ["_handle", "_alpha"];
    _handle ppEffectAdjust [
        1, 1, 0,
        [0, 0, 0, (_alpha max 0) min 0.14],
        [1, 1, 1, 1],
        [0.299, 0.587, 0.114, 0],
        [0.65, 0.65, 0, 0, 0, 0.65, 1]
    ];
    _handle ppEffectCommit 0;
    _handle ppEffectEnable true;
};

GAIT_fnc_destroyFatigueVignette = {
    params ["_handle"];
    _handle ppEffectEnable false;
    ppEffectDestroy _handle;
};

GAIT_fnc_dropFatigueVignette = {
    private _handle = missionNamespace getVariable ["GAIT_fatigueVignetteHandle", -1];
    missionNamespace setVariable ["GAIT_fatigueVignetteHandle", -1];
    missionNamespace setVariable ["GAIT_fatigueVignetteAlpha", 0];
    if (_handle isEqualType 0 && {_handle >= 0}) then {
        [_handle] call GAIT_fnc_destroyFatigueVignette;
    };
};

GAIT_fnc_releaseFatigueVisuals = {
    missionNamespace setVariable ["GAIT_fatigueVisualRequest", []];
    private _clearedPulse = [missionNamespace getVariable ["GAIT_fatigueVisualPulse", []], call GAIT_fnc_fatigueVisualClock, 0] call GAIT_fnc_stepFatigueVisualPulse;
    missionNamespace setVariable ["GAIT_fatigueVisualPulse", _clearedPulse # 0];
    [] call GAIT_fnc_dropFatigueVignette;
    if (!isNil "GAIT_fnc_releaseACEFatigueVisualOwnership") then {
        [] call GAIT_fnc_releaseACEFatigueVisualOwnership;
    };
};

GAIT_fnc_updateFatigueVisuals = {
    params [
        ["_unit", objNull, [objNull]],
        ["_strength", 0, [0]]
    ];
    _strength = (_strength max 0) min 1;
    if (!([_unit] call GAIT_fnc_fatigueVisualContextEligible)) exitWith {
        [] call GAIT_fnc_releaseFatigueVisuals;
    };
    private _request = missionNamespace getVariable ["GAIT_fatigueVisualRequest", []];
    if ((count _request) == 3 && {(_request # 0) isNotEqualTo _unit}) then {
        [] call GAIT_fnc_releaseFatigueVisuals;
    };
    if (_strength <= 0) then {
        private _clearedPulse = [missionNamespace getVariable ["GAIT_fatigueVisualPulse", []], call GAIT_fnc_fatigueVisualClock, 0] call GAIT_fnc_stepFatigueVisualPulse;
        missionNamespace setVariable ["GAIT_fatigueVisualPulse", _clearedPulse # 0];
        [] call GAIT_fnc_dropFatigueVignette;
    };
    missionNamespace setVariable ["GAIT_fatigueVisualRequest", [_unit, _strength, (call GAIT_fnc_fatigueVisualClock) + 0.75]];
};

GAIT_fnc_fatigueVisualFrame = {
    private _request = missionNamespace getVariable ["GAIT_fatigueVisualRequest", []];
    if ((count _request) != 3) exitWith {[] call GAIT_fnc_releaseFatigueVisuals;};
    _request params ["_unit", "_strength", "_expires"];
    private _now = call GAIT_fnc_fatigueVisualClock;
    if (_now >= _expires || {!([_unit] call GAIT_fnc_fatigueVisualContextEligible)}) exitWith {
        [] call GAIT_fnc_releaseFatigueVisuals;
    };
    if (!isNil "GAIT_fnc_updateACEFatigueVisualOwnership") then {
        [_unit] call GAIT_fnc_updateACEFatigueVisualOwnership;
    };
    private _pulse = [missionNamespace getVariable ["GAIT_fatigueVisualPulse", []], _now, _strength] call GAIT_fnc_stepFatigueVisualPulse;
    _pulse params ["_state", "_alpha"];
    missionNamespace setVariable ["GAIT_fatigueVisualPulse", _state];
    if (_alpha <= 0) exitWith {[] call GAIT_fnc_dropFatigueVignette;};
    private _handle = missionNamespace getVariable ["GAIT_fatigueVignetteHandle", -1];
    if (_handle < 0) then {
        _handle = call GAIT_fnc_createFatigueVignette;
        missionNamespace setVariable ["GAIT_fatigueVignetteHandle", _handle];
    };
    // A priority collision or unsupported PP creation is harmless and costs
    // one attempt per pulse, not a retry loop on every rendered frame.
    if (_handle < 0) exitWith {
        missionNamespace setVariable ["GAIT_fatigueVisualPulse", [-1, _now + 12, 0]];
        [] call GAIT_fnc_dropFatigueVignette;
    };
    missionNamespace setVariable ["GAIT_fatigueVignetteAlpha", _alpha];
    [_handle, _alpha] call GAIT_fnc_writeFatigueVignette;
};

GAIT_fnc_startFatigueVisualWatchdog = {
    if (!hasInterface) exitWith {};
    if ((missionNamespace getVariable ["GAIT_fatigueVisualFrameEH", -1]) < 0) then {
        private _frameEH = addMissionEventHandler ["EachFrame", {[] call GAIT_fnc_fatigueVisualFrame;}];
        missionNamespace setVariable ["GAIT_fatigueVisualFrameEH", _frameEH];
    };
    if ((missionNamespace getVariable ["GAIT_fatigueVisualEndedEH", -1]) < 0) then {
        private _endedEH = addMissionEventHandler ["Ended", {[] call GAIT_fnc_releaseFatigueVisuals;}];
        missionNamespace setVariable ["GAIT_fatigueVisualEndedEH", _endedEH];
    };
};
