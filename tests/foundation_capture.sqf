/*
    GAIT alpha6 foundation acceptance recorder: read-only, 10 Hz, one file.
    Copy into a saved Eden mission. With GAIT and ACE AF enabled, LOCAL EXEC:
      [60, "foundation first hill"] execVM "foundation_capture.sqf";
    Test step-off, W+Turbo, W+A/W+D, pure A/D, stop/restart and the steep hill.
    Stop early: GAIT_foundationCaptureEnabled = false;
    Keep the preview open until STOP; then send the RPT.
    No movement, stamina, animation, settings or physiology is changed.
*/
if (!hasInterface || {!canSuspend}) exitWith {};
params [["_duration", 60, [0]], ["_label", "foundation", [""]]];
_duration = _duration max 10 min 180;
private _id = (missionNamespace getVariable ["GAIT_foundationCaptureId", 0]) + 1;
missionNamespace setVariable ["GAIT_foundationCaptureId", _id];
missionNamespace setVariable ["GAIT_foundationCaptureEnabled", true];
private _emit = {
    params ["_kind", "_data"];
    private _payload = str _data;
    private _parts = ceil ((count _payload) / 400);
    for "_part" from 0 to (_parts - 1) do {
        diag_log format ["[GAIT_FOUNDATION] %1", [_id, _seq, _kind, _part, _parts, _payload select [_part * 400, 400]]];
    };
};
private _seq = 0;
["START", [_label, missionNamespace getVariable ["GAIT_versionString", "unknown"], productVersion,
    "rows: tick,frame,phase,input,animation,gesture,engine,pace,brace,features,uphillBrake,gearInertia,inputHistory,lockDiagnostics,feedback",
    "engine: ground,stance,sprintAllowed,forcedWalk,ACEblock,ACEwalk,life,unconscious,staminaEnabled,stamina,fatigue",
    "pace: coefficient,horizontalMS,grade,walkCoef,sprintCoef,calibrated,walkTargetMS,sprintTargetMS,loadAbs",
    "brace: active,configuredDuration,activeDuration,activeCoefficient,factor,plannedCoefficient,momentumProtected,downhillMomentum,endTime",
    "features: GAITenabled,ACEAFenabled,movementEligible,reserveRatio,shiftCoast,exitIssued,exitFailed",
    "uphillBrake: active,severity,target,endTime,readyUntil",
    "gearInertia: loadLbs,responseProfile,coastActive,coastPrearmUntil",
    "inputHistory: forwardReleaseSerial,canceledBraceEnd,turboPressedThisFrame,entrySource,entryTarget,exitSource,exitTarget",
    "lockDiagnostics: observation,sprintRequested,nativeStaminaOwned,staminaOwnerMatches,staminaPolicyEligible,ACEbridgeInstalled,clearACElocksEnabled,compatibilityMode,backpack,normalizedLoad",
    "feedback: exhaustion,vignetteAlpha,vignetteHandle,ACEfatigueVisualOwned,pulseState",
    "lock observations describe reported state; unassigned engine restrictions do not establish a stamina or load cause"]] call _emit;
systemChat format ["GAIT foundation capture started for %1 seconds. Stop early with GAIT_foundationCaptureEnabled = false.", _duration];
private _deadline = diag_tickTime + _duration;
waitUntil {
    private _unit = player;
    if (!isNull _unit) then {
        _seq = _seq + 1;
        private _input = [0, 0, false];
        if (!isNil "GAIT_fnc_getMovementInput") then {_input = [] call GAIT_fnc_getMovementInput;};
        private _eligible = false;
        if (!isNil "GAIT_fnc_nativeMovementEligible") then {_eligible = [_unit, false] call GAIT_fnc_nativeMovementEligible;};
        private _velocity = velocity _unit;
        private _horizontal = sqrt (((_velocity select 0) ^ 2) + ((_velocity select 1) ^ 2));
        private _sprintAllowed = isSprintAllowed _unit;
        private _forcedWalk = isForcedWalk _unit;
        private _aceSprintMask = _unit getVariable ["ace_common_effect_blockSprint", 0];
        private _aceWalkMask = _unit getVariable ["ace_common_effect_forceWalk", 0];
        private _engine = [isTouchingGround _unit, stance _unit, _sprintAllowed, _forcedWalk,
            _aceSprintMask, _aceWalkMask,
            lifeState _unit, _unit getVariable ["ACE_isUnconscious", false],
            isStaminaEnabled _unit, getStamina _unit, getFatigue _unit];
        private _pace = [getAnimSpeedCoef _unit, _horizontal,
            missionNamespace getVariable ["GAIT_smoothedSlopeDegrees", 0],
            missionNamespace getVariable ["GAIT_walkPaceTarget", -1], missionNamespace getVariable ["GAIT_sprintPaceTarget", -1],
            missionNamespace getVariable ["GAIT_paceCalibrated", false],
            missionNamespace getVariable ["GAIT_walkTargetMS", -1], missionNamespace getVariable ["GAIT_sprintTargetMS", -1], loadAbs _unit];
        private _brace = [missionNamespace getVariable ["GAIT_braceActive", false],
            missionNamespace getVariable ["GAIT_ss_sprintStartBraceDuration", -1],
            missionNamespace getVariable ["GAIT_activeBraceDuration", -1], missionNamespace getVariable ["GAIT_activeBraceSpeed", -1],
            missionNamespace getVariable ["GAIT_slopeBraceFactor", 0], missionNamespace getVariable ["GAIT_plannedMovementCoefficient", -1],
            missionNamespace getVariable ["GAIT_braceMomentumProtected", false], missionNamespace getVariable ["GAIT_downhillMomentum", 0],
            missionNamespace getVariable ["GAIT_braceEndTime", -1]];
        private _features = [missionNamespace getVariable ["GAIT_ss_enabled", false], missionNamespace getVariable ["ace_advanced_fatigue_enabled", false], _eligible,
            missionNamespace getVariable ["GAIT_observedReserveRatio", -1], missionNamespace getVariable ["GAIT_shiftReleaseRunTaperActive", false],
            _unit getVariable ["GAIT_slopeExitIssued", false], _unit getVariable ["GAIT_slopeExitFailureReported", false]];
        private _uphillBrake = [missionNamespace getVariable ["GAIT_uphillBrakeActive", false],
            missionNamespace getVariable ["GAIT_uphillBrakeSeverity", 0], missionNamespace getVariable ["GAIT_uphillBrakeTarget", -1],
            missionNamespace getVariable ["GAIT_uphillBrakeEndTime", -1], missionNamespace getVariable ["GAIT_uphillBrakeReadyUntil", -1]];
        private _gearInertia = [loadAbs _unit / ((missionNamespace getVariable ["GAIT_ss_loadAbsPerLb", 10]) max 0.01),
            missionNamespace getVariable ["GAIT_gearInertia", []], missionNamespace getVariable ["GAIT_coastActive", false],
            missionNamespace getVariable ["GAIT_coastReadyUntil", -1]];
        private _inputHistory = [_unit getVariable ["GAIT_forwardReleaseSerial", 0],
            _unit getVariable ["GAIT_slopeCanceledBraceEndTime", -2],
            _unit getVariable ["GAIT_turboPressedThisFrame", false],
            _unit getVariable ["GAIT_slopeEntrySource", ""], _unit getVariable ["GAIT_slopeEntryTarget", ""],
            _unit getVariable ["GAIT_slopeExitSource", ""], _unit getVariable ["GAIT_slopeExitTarget", ""]];
        private _sprintRequested = (_input select 0) > 0.05 && {_input select 2};
        private _lockObservation = "no reported permission restriction";
        if (!_sprintAllowed || {_forcedWalk}) then {
            _lockObservation = "engine restriction; source unassigned";
        };
        if (_aceSprintMask > 0 || {_aceWalkMask > 0}) then {
            _lockObservation = "ACE status mask present";
        };
        if (_sprintRequested && {_sprintAllowed} && {!_forcedWalk} && {_aceSprintMask <= 0} && {_aceWalkMask <= 0} &&
            {((toLower animationState _unit) find "mwlk") >= 0}) then {
            _lockObservation = "walk animation without reported permission restriction";
        };
        private _staminaOwnership = missionNamespace getVariable ["GAIT_nativeStaminaOwnership", []];
        private _ownerMatches = (count _staminaOwnership) > 0 && {(_staminaOwnership select 0) isEqualTo _unit};
        private _staminaPolicy = false;
        if (!isNil "GAIT_fnc_ownsNativeStaminaPolicy") then {_staminaPolicy = [_unit] call GAIT_fnc_ownsNativeStaminaPolicy;};
        private _lockDiagnostics = [_lockObservation, _sprintRequested,
            missionNamespace getVariable ["GAIT_nativeStaminaOwned", false], _ownerMatches, _staminaPolicy,
            missionNamespace getVariable ["GAIT_nativeAceBridgeInstalled", false],
            missionNamespace getVariable ["GAIT_ss_clearAceMovementLocks", true],
            missionNamespace getVariable ["GAIT_ss_compatibilityMode", -1], backpack _unit, load _unit];
        private _feedback = [missionNamespace getVariable ["GAIT_exhaustionLevel", 0],
            missionNamespace getVariable ["GAIT_fatigueVignetteAlpha", 0],
            missionNamespace getVariable ["GAIT_fatigueVignetteHandle", -1],
            missionNamespace getVariable ["GAIT_aceFatigueVisualOwned", false],
            missionNamespace getVariable ["GAIT_fatigueVisualPulse", []]];
        ["SAMPLE", [diag_tickTime, diag_frameNo, _unit getVariable ["GAIT_locomotionPhase", "native"], _input,
            animationState _unit, gestureState _unit, _engine, _pace, _brace, _features, _uphillBrake, _gearInertia, _inputHistory, _lockDiagnostics, _feedback]] call _emit;
    };
    uiSleep 0.1;
    diag_tickTime >= _deadline || {!(missionNamespace getVariable ["GAIT_foundationCaptureEnabled", false])} ||
        {(missionNamespace getVariable ["GAIT_foundationCaptureId", -1]) isNotEqualTo _id}
};
_seq = _seq + 1;
["STOP", [diag_tickTime, _seq]] call _emit;
systemChat "GAIT foundation capture STOP. The RPT is ready.";
