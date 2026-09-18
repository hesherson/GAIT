/*
    GAIT foundation acceptance recorder: read-only, 10 Hz, one file.
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
    "rows: tick,frame,phase,input,animation,gesture,engine,pace,brace,features",
    "engine: ground,stance,sprintAllowed,forcedWalk,ACEblock,ACEwalk,life,unconscious",
    "pace: coefficient,horizontalMS,grade,walkCoef,sprintCoef,calibrated,walkTargetMS,sprintTargetMS,loadAbs",
    "brace: active,configuredDuration,activeDuration,activeCoefficient,factor,plannedCoefficient,momentumProtected,downhillMomentum,animationStage,endTime",
    "features: GAITenabled,ACEAFenabled,movementEligible,reserveRatio,shiftCoast,exitIssued,exitFailed"]] call _emit;
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
        private _engine = [isTouchingGround _unit, stance _unit, isSprintAllowed _unit, isForcedWalk _unit,
            _unit getVariable ["ace_common_effect_blockSprint", 0], _unit getVariable ["ace_common_effect_forceWalk", 0],
            lifeState _unit, _unit getVariable ["ACE_isUnconscious", false]];
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
            _unit getVariable ["GAIT_slopeBraceStage", ""], missionNamespace getVariable ["GAIT_braceEndTime", -1]];
        private _features = [missionNamespace getVariable ["GAIT_ss_enabled", false], missionNamespace getVariable ["ace_advanced_fatigue_enabled", false], _eligible,
            missionNamespace getVariable ["GAIT_observedReserveRatio", -1], missionNamespace getVariable ["GAIT_shiftReleaseRunTaperActive", false],
            _unit getVariable ["GAIT_slopeExitIssued", false], _unit getVariable ["GAIT_slopeExitFailureReported", false]];
        ["SAMPLE", [diag_tickTime, diag_frameNo, _unit getVariable ["GAIT_locomotionPhase", "native"], _input,
            animationState _unit, gestureState _unit, _engine, _pace, _brace, _features]] call _emit;
    };
    uiSleep 0.1;
    diag_tickTime >= _deadline || {!(missionNamespace getVariable ["GAIT_foundationCaptureEnabled", false])} ||
        {(missionNamespace getVariable ["GAIT_foundationCaptureId", -1]) isNotEqualTo _id}
};
_seq = _seq + 1;
["STOP", [diag_tickTime, _seq]] call _emit;
systemChat "GAIT foundation capture STOP. The RPT is ready.";
