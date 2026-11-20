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
    "rows: tick,frame,phase,input,animation,gesture,engine,pace,brace,features,gearInertia,inputHistory,lockDiagnostics,feedback,trip,release,stanceWork,optics,casualty,rawActions,releasePlan,network,burst,inputFrames,effectiveLoadLb,fire",
    "engine: ground,stance,sprintAllowed,forcedWalk,ACEblock,ACEwalk,life,unconscious,staminaEnabled,stamina,fatigue",
    "pace: coefficient,horizontalMS,grade,walkCoef,sprintCoef,calibrated,walkTargetMS,sprintTargetMS,loadAbs,lastPreVegetationCoefficient,currentWeapon,learnedReferences,rawGrade",
    "brace: active,configuredDuration,activeDuration,activeCoefficient,factor,plannedCoefficient,momentumProtected,downhillMomentum,endTime,stopRearm",
    "features: GAITenabled,ACEAFenabled,movementEligible,reserveRatio,exitIssued,exitFailed",
    "gearInertia: loadLbs,responseProfile",
    "inputHistory: forwardReleaseSerial,canceledBraceEnd,turboPressedThisFrame,entrySource,entryTarget,exitSource,exitTarget,uphillLastGrounded,uphillRecoveryUsed",
    "lockDiagnostics: observation,sprintRequested,nativeStaminaOwned,staminaOwnerMatches,staminaPolicyEligible,ACEbridgeInstalled,clearACElocksEnabled,compatibilityMode,backpack,normalizedLoad,ACEreserveHook,ACEeffectsGuard,ACEreserve",
    "feedback: exhaustion,vignetteAlpha,vignetteHandle,ACEfatigueVisualOwned,pulseState",
    "trip: eligible,currentKmh,speedSeverity,speedMultiplier,chancePerSecond,sustainedGate,sprintSeconds,highSpeedSeconds,cooldownRemaining,immunityRemaining,depletedRunSeconds,fatigueFactors",
    "release: elapsed,progress,initialMS,animationBlendFactor,slopeScale",
    "stanceWork: activity,transitionDepth,effortPerSecond,coefficient",
    "optics: cameraView,opticsAction,temporaryOpticsAction",
    "rawActions: forward,back,left,right,turbo,adjustUp,adjustDown,adjustLeft,adjustRight,crouch,stand,moveUp,prone,moveDown,walkToggle,walkTemporary,weaponSlot",
    "releasePlan: sampledAt,start,weapon,destinationClip,plannedMS,destinationMS,strideReference,coefficient,progress",
    "network: serverTime,clientOwner,unitNetId,positionASL,stance,sprintStrideScale,testPhase",
    "burst: active,spendableReserve,strength,braceDuration",
    "inputFrames: tick,sideInput,crouchInput,lateralMS,movingCrouch,stance,valid,turbo,forwardEdgePositionASL",
    "fire: lastBoundPress,defaultAction,fireAction,weaponState,lowered,switching,bodyDisableWeapons,bodyDisableWeaponsLong,gestureDisableWeapons,aceSafety",
    "lock observations describe reported state; unassigned engine restrictions do not establish a stamina or load cause"]] call _emit;
systemChat format ["GAIT foundation capture started for %1 seconds. Stop early with GAIT_foundationCaptureEnabled = false.", _duration];
private _deadline = diag_tickTime + _duration;
// Keep frame observations in the next 10 Hz record. Only the opt-in recorder installs this handler.
private _priorHandler = missionNamespace getVariable ["GAIT_captureFrameHandler", -1];
if (_priorHandler >= 0) then {removeMissionEventHandler ["EachFrame", _priorHandler];};
missionNamespace setVariable ["GAIT_captureFrames", []];
private _frameHandler = addMissionEventHandler ["EachFrame", {
    private _unit = player;
    if (isNull _unit || {isGamePaused}) exitWith {};
    private _frames = missionNamespace getVariable ["GAIT_captureFrames", []];
    if (count _frames >= 120) exitWith {};
    private _side = (inputAction "TurnRight") - (inputAction "TurnLeft");
    private _crouch = (inputAction "Crouch" max inputAction "MoveDown") > 0.05;
    private _velocity = velocityModelSpace _unit;
    private _move = toLower animationState _unit;
    private _movingCrouch = (_move select [4,4]) isEqualTo "pknl" && {(_move select [8,4]) in ["mwlk","mrun","mtac","meva","mspr"]} &&
        {vectorMagnitude [_velocity select 0,_velocity select 1,0] > 0.15};
    private _valid = alive _unit && {isNull objectParent _unit} && {!dialog} && {(_move select [0,4]) isEqualTo "amov"};
    private _forward = inputAction "MoveForward" > 0.05;
    private _launch = [];
    if (_forward && {!(missionNamespace getVariable ["GAIT_captureForwardHeld", true])}) then {
        _launch = getPosASL _unit;
    };
    missionNamespace setVariable ["GAIT_captureForwardHeld", _forward];
    _frames pushBack [diag_tickTime,_side,_crouch,_velocity select 0,_movingCrouch,stance _unit,_valid,inputAction "Turbo" > 0.05,_launch];
}];
missionNamespace setVariable ["GAIT_captureFrameHandler", _frameHandler];
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
            missionNamespace getVariable ["GAIT_walkTargetMS", -1], missionNamespace getVariable ["GAIT_sprintTargetMS", -1], loadAbs _unit,
            missionNamespace getVariable ["GAIT_nativeLastPreVegetation", -1], currentWeapon _unit,
            count (_unit getVariable ["GAIT_paceMeasurements", []]), missionNamespace getVariable ["GAIT_rawSlopeDegrees", 0]];
        private _brace = [missionNamespace getVariable ["GAIT_braceActive", false],
            0.15,
            missionNamespace getVariable ["GAIT_activeBraceDuration", -1], missionNamespace getVariable ["GAIT_activeBraceSpeed", -1],
            missionNamespace getVariable ["GAIT_slopeBraceFactor", 0], missionNamespace getVariable ["GAIT_plannedMovementCoefficient", -1],
            missionNamespace getVariable ["GAIT_braceMomentumProtected", false], missionNamespace getVariable ["GAIT_downhillMomentum", 0],
            missionNamespace getVariable ["GAIT_braceEndTime", -1],
            missionNamespace getVariable ["GAIT_stopBraceRearm", -1]];
        private _features = [missionNamespace getVariable ["GAIT_ss_enabled", false], missionNamespace getVariable ["ace_advanced_fatigue_enabled", false], _eligible,
            missionNamespace getVariable ["GAIT_observedReserveRatio", -1],
            _unit getVariable ["GAIT_slopeExitIssued", false], _unit getVariable ["GAIT_slopeExitFailureReported", false]];
        private _gearInertia = [loadAbs _unit / 10,
            missionNamespace getVariable ["GAIT_gearInertia", []]];
        private _inputHistory = [_unit getVariable ["GAIT_forwardReleaseSerial", 0],
            _unit getVariable ["GAIT_slopeCanceledBraceEndTime", -2],
            _unit getVariable ["GAIT_turboPressedThisFrame", false],
            _unit getVariable ["GAIT_slopeEntrySource", ""], _unit getVariable ["GAIT_slopeEntryTarget", ""],
            _unit getVariable ["GAIT_slopeExitSource", ""], _unit getVariable ["GAIT_slopeExitTarget", ""],
            _unit getVariable ["GAIT_uphillSprintGroundedAt", -1], _unit getVariable ["GAIT_uphillSprintRecoveryUsed", false]];
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
        private _fatiguePolicy = false;
        if (!isNil "GAIT_fnc_ownsFatigueMovementPolicy") then {_fatiguePolicy = [_unit] call GAIT_fnc_ownsFatigueMovementPolicy;};
        private _effectsCache = missionNamespace getVariable ["GAIT_aceFatigueEffectsCache", []];
        private _effectsGuarded = (count _effectsCache) isEqualTo 2 && {(_effectsCache select 0) isNotEqualRef (_effectsCache select 1)};
        private _lockDiagnostics = [_lockObservation, _sprintRequested,
            missionNamespace getVariable ["GAIT_nativeStaminaOwned", false], _ownerMatches, _staminaPolicy,
            missionNamespace getVariable ["GAIT_nativeAceBridgeInstalled", false],
            _fatiguePolicy, [4, 1] select (missionNamespace getVariable ["GAIT_ss_enabled", false]),
            backpack _unit, load _unit,
            uiNamespace getVariable ["GAIT_aceSprintReserveHookInstalled", false], _effectsGuarded,
            missionNamespace getVariable ["ace_advanced_fatigue_anReservePercentage", -1]];
        private _feedback = [missionNamespace getVariable ["GAIT_exhaustionLevel", 0],
            missionNamespace getVariable ["GAIT_fatigueVignetteAlpha", 0],
            missionNamespace getVariable ["GAIT_fatigueVignetteHandle", -1],
            missionNamespace getVariable ["GAIT_aceFatigueVisualOwned", false],
            missionNamespace getVariable ["GAIT_fatigueVisualPulse", []]];
        private _trip = [missionNamespace getVariable ["GAIT_tripEligible", false],
            missionNamespace getVariable ["GAIT_tripSpeedKmh", 0],
            missionNamespace getVariable ["GAIT_tripSpeedSeverity", 0],
            missionNamespace getVariable ["GAIT_tripSpeedMultiplier", 0],
            missionNamespace getVariable ["GAIT_tripChancePerSecond", 0],
            missionNamespace getVariable ["GAIT_tripSustainedGateReady", false],
            missionNamespace getVariable ["GAIT_tripSustainedSprintSeconds", 0],
            missionNamespace getVariable ["GAIT_tripSustainedHighSpeedSeconds", 0],
            missionNamespace getVariable ["GAIT_tripCooldownRemaining", 0],
            missionNamespace getVariable ["GAIT_tripImmunityRemaining", 0],
            missionNamespace getVariable ["GAIT_tripDepletedRunTime", 0],
            missionNamespace getVariable ["GAIT_tripFatigueFactors", []]];
        private _release = [];
        private _releasePace = _unit getVariable ["GAIT_sprintReleasePace", []];
        if ((count _releasePace) >= 2 && {!isNil "GAIT_fnc_sprintWalkProgress"}) then {
            _releasePace params ["_started", "_initialMS", ["_slopeScale", 1]];
            _release = [diag_tickTime - _started, [_started, diag_tickTime, _slopeScale] call GAIT_fnc_sprintWalkProgress,
                _initialMS, (getUnitMovesInfo _unit) param [3, -1], _slopeScale];
        };
        private _stanceWork = missionNamespace getVariable ["GAIT_stanceWork", []];
        private _optics = [cameraView, inputAction "Optics", inputAction "OpticsTemp"];
        private _carrying = _unit getVariable ["ace_dragging_isCarrying", false];
        private _dragging = _unit getVariable ["ace_dragging_isDragging", false];
        private _patient = if (_dragging) then {_unit getVariable ["ace_dragging_draggedObject", objNull]} else {
            _unit getVariable ["ace_dragging_carriedObject", objNull]
        };
        private _casualtyClip = "";
        if ((_carrying || {_dragging}) && {!isNil "GAIT_fnc_activeCasualtyClip"}) then {
            _casualtyClip = [_unit, _patient, animationState _unit, _carrying] call GAIT_fnc_activeCasualtyClip;
        };
        private _casualty = [_carrying, _dragging, !isNull _patient && {(attachedTo _patient) isEqualTo _unit}, _casualtyClip];
        private _rawActions = ["MoveForward", "MoveBack", "TurnLeft", "TurnRight", "Turbo",
            "AdjustUp", "AdjustDown", "AdjustLeft", "AdjustRight", "Crouch", "Stand", "MoveUp",
            "Prone", "MoveDown", "WalkRunToggle", "WalkRunTemp"] apply {inputAction _x};
        _rawActions pushBack (call GAIT_fnc_getWeaponSlotInput);
        private _network = [serverTime, clientOwner, netId _unit, getPosASL _unit, stance _unit,
            missionNamespace getVariable ["GAIT_sprintStrideScale", 1],
            missionNamespace getVariable ["GAIT_comparisonPhase", "free movement"]];
        private _bill = _unit getVariable ["GAIT_burstBill", []];
        private _activeBurst = (_bill param [1, 0]) < 0;
        private _reserve = ((_features select 3) - (_unit getVariable ["GAIT_burstDue", 0])) max 0;
        private _strength = 0;
        if (_activeBurst && {!isNil "GAIT_fnc_burstStrength"}) then {
            _strength = [_reserve] call GAIT_fnc_burstStrength;
        };
        private _burst = [_activeBurst, _reserve, _strength, missionNamespace getVariable ["GAIT_activeBraceDuration", 0]];
        private _frames = missionNamespace getVariable ["GAIT_captureFrames", []];
        missionNamespace setVariable ["GAIT_captureFrames", []];
        private _press = _unit getVariable ["GAIT_firePressedAt",-1];
        private _defaultAction = inputAction "DefaultAction";
        private _fireAction = inputAction "Fire";
        private _fire = [];
        if (_defaultAction > 0 || {_fireAction > 0} || {_press >= 0 && {diag_tickTime - _press < 1}}) then {
            private _body = configFile >> "CfgMovesMaleSdr" >> "States" >> animationState _unit;
            private _safe = !isNil "ace_safemode_fnc_getWeaponSafety" && {
                [_unit,currentWeapon _unit,currentMuzzle _unit] call ace_safemode_fnc_getWeaponSafety};
            _fire = [_press,_defaultAction,_fireAction,weaponState _unit,weaponLowered _unit,
                isSwitchingWeapon _unit,getNumber (_body >> "disableWeapons"),getNumber (_body >> "disableWeaponsLong"),
                getNumber (configFile >> "CfgGesturesMale" >> "States" >> gestureState _unit >> "disableWeapons"),_safe];
        };
        ["SAMPLE", [diag_tickTime, diag_frameNo, _unit getVariable ["GAIT_locomotionPhase", "native"], _input,
            animationState _unit, gestureState _unit, _engine, _pace, _brace, _features, _gearInertia, _inputHistory,
            _lockDiagnostics, _feedback, _trip, _release, _stanceWork, _optics, _casualty, _rawActions,
            _unit getVariable ["GAIT_releasePacePlan", []], _network, _burst, _frames,
            _unit getVariable ["GAIT_effectiveLoadLb", loadAbs _unit / 10],_fire]] call _emit;
    };
    uiSleep 0.1;
    diag_tickTime >= _deadline || {!(missionNamespace getVariable ["GAIT_foundationCaptureEnabled", false])} ||
        {(missionNamespace getVariable ["GAIT_foundationCaptureId", -1]) isNotEqualTo _id}
};
if (_frameHandler isEqualTo (missionNamespace getVariable ["GAIT_captureFrameHandler", -1])) then {
    removeMissionEventHandler ["EachFrame", _frameHandler];
    missionNamespace setVariable ["GAIT_captureFrameHandler", -1];
};
_seq = _seq + 1;
["STOP", [diag_tickTime, _seq]] call _emit;
systemChat "GAIT foundation capture STOP. The RPT is ready.";
