/*
    GAIT
    Standalone client-side sprint/momentum/brace system.

    Workshop/mod scope:
    - Custom sprint speed, reserve bridge, brace step, and momentum ramp
    - ACE Advanced Fatigue integration for physiology/acidosis/muscle damage
    - Native locomotion with scoped ACE fatigue movement-lock integration
    - ACE owns weapon handling and fatigue feedback.

    Removed from mission version:
    - Fast Carry script startup
    - Laptop / PA radio startup
    - Generator sound startup
    - Mission loadout respawn handler
    - Heavy-load blackout test/debug hints
*/

if (!hasInterface) exitWith {};
if (missionNamespace getVariable ["GAIT_system_started", false]) exitWith {};
missionNamespace setVariable ["GAIT_system_started", true];


// =====================================================
// CBA ADDON OPTION HELPERS
// Settings are registered in fn_registerSettings.sqf.
// They are read from missionNamespace so changes made in
// Addon Options can apply during the mission without editing files.
// =====================================================
GAIT_fnc_setting = {
    params [
        ["_name", "", [""]],
        ["_default", nil]
    ];

    missionNamespace getVariable [_name, _default]
};

// =====================================================
// PRESETS / COMPATIBILITY / LIFECYCLE HELPERS
// =====================================================
GAIT_fnc_log = {
    params [["_message", "", [""]]];

    if (missionNamespace getVariable ["GAIT_ss_rptLogging", true]) then {
        diag_log format ["[GAIT] %1", _message];
    };
};

GAIT_fnc_compatModeIndex = {
    private _mode = missionNamespace getVariable ["GAIT_ss_compatibilityMode", 1];
    if (_mode isEqualType "") exitWith {
        [1, 4] select (_mode in ["Disabled", "Effects and hearing", "Visuals and tinnitus", "Minimal Movement Override", "Visuals/Audio Only"])
    };
    [4, 1] select (_mode in [0, 1])
};

GAIT_fnc_compatModeName = {
    ["Movement only", "Disabled"] select ((call GAIT_fnc_compatModeIndex) isEqualTo 4)
};

GAIT_fnc_modeAllowsMovement = {
    (missionNamespace getVariable ["GAIT_ss_enabled", true]) && {(call GAIT_fnc_compatModeIndex) isEqualTo 1}
};

GAIT_fnc_modeAllowsAceLockClearing = {
    (call GAIT_fnc_modeAllowsMovement) && {missionNamespace getVariable ["GAIT_ss_clearAceMovementLocks", true]}
};

// Suspension/context eligibility is defined once in fn_traversalHelpers.sqf.

// =====================================================
// ACE ADVANCED FATIGUE INTEGRATION
// ACE runs its physiology and fatigue feedback. The reserve hook limits its
// anaerobic reserve before ACE publishes the bar and percentages.
// =====================================================
GAIT_fnc_aceAdvancedFatigueActive = {
    (missionNamespace getVariable ["GAIT_ss_aceBridgeEnabled", true]) &&
    {isClass (configFile >> "CfgPatches" >> "ace_advanced_fatigue")} &&
    {missionNamespace getVariable ["ace_advanced_fatigue_enabled", false]}
};

GAIT_fnc_animLooksLikeJog = {
    params [
        ["_animState", "", [""]]
    ];

    private _a = toLower _animState;
    ((_a find "mrun") >= 0) || {((_a find "meva") >= 0) || {((_a find "mtac") >= 0)}}
};

GAIT_fnc_animLooksLikeRaisedCombat = {
    params [
        ["_animState", "", [""]]
    ];

    private _a = toLower _animState;
    // Sras means weapon raised. If the player started sprinting from a raised
    // combat stance, preserve that intent and do not force a post-run correction.
    (_a find "sras") >= 0
};

// Arma 2.18+ engine boundary. Portable tests substitute this read only.
GAIT_fnc_readPaceMoveInfo = {params ["_unit"]; getUnitMovesInfo _unit};

// Traversal helpers are definitions only, loaded before any client loops start.
call compile preprocessFileLineNumbers "\gait\functions\fn_traversalHelpers.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_sprintReserve.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_slopePaceModel.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_locomotionPace.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_braceMomentum.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_gearInertia.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_downhillPace.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_uphillBrake.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_paceCalibration.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_releaseMomentum.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_slopeLocomotion.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_nativeController.sqf";
[] call GAIT_fnc_installLocomotionController;

if (!(missionNamespace getVariable ["GAIT_resetEventInstalled", false]) && {!isNil "CBA_fnc_addEventHandler"}) then {
    ["GAIT_resetEffects", {
        params [["_reason", "network", [""]]];
        [_reason] call GAIT_fnc_resetEffects;
    }] call CBA_fnc_addEventHandler;
    missionNamespace setVariable ["GAIT_resetEventInstalled", true];
};

GAIT_fnc_tripPlayer = {
    params [
        ["_duration", 1.25, [0]]
    ];

    if (isNull player) exitWith {};
    if (player getVariable ["GAIT_isTripping", false]) exitWith {};
    if !(alive player) exitWith {};
    if (player getVariable ["ACE_isUnconscious", false]) exitWith {};

    [] call GAIT_fnc_releaseNativeStaminaOwnership;
    [] call GAIT_fnc_releaseNativeMovement;
    player setVariable ["GAIT_isTripping", true, false];
    missionNamespace setVariable ["GAIT_lastTripTime", time];

    [_duration] spawn {
        params ["_duration"];

        private _unit = player;
        if (isNull _unit) exitWith {};

        private _tripStartTime = time;
        private _minRagdollTime = (_duration max 0.10) min 8.00;
        private _getUpSpeedKmh = missionNamespace getVariable ["GAIT_ss_downhillTripGetUpSpeedKmh", 7.0];
        private _maxRagdollTime = missionNamespace getVariable ["GAIT_ss_downhillTripMaxRagdollDuration", 6.0];
        _getUpSpeedKmh = (_getUpSpeedKmh max 0.5) min 30.0;
        _maxRagdollTime = (_maxRagdollTime max _minRagdollTime) min 12.0;

        // Give the trip a small forward/downward impulse. Recovery is now
        // momentum-aware: GAIT does not force the get-up state purely on a
        // timer if the player is still sliding/ragdolling with real velocity.
        _unit setVelocityModelSpace [0, 2.0, -1.2];
        _unit setUnconscious true;

        waitUntil {
            uiSleep 0.05;
            private _elapsed = time - _tripStartTime;
            private _velTrip = velocity _unit;
            private _tripHorizontalKmh = (sqrt (((_velTrip select 0) ^ 2) + ((_velTrip select 1) ^ 2))) * 3.6;
            private _belowGetUpSpeed = _tripHorizontalKmh <= _getUpSpeedKmh;

            missionNamespace setVariable ["GAIT_tripCurrentMomentumKmh", _tripHorizontalKmh];
            missionNamespace setVariable ["GAIT_tripGetUpThresholdKmh", _getUpSpeedKmh];
            missionNamespace setVariable ["GAIT_tripMomentumRecoveryReady", _belowGetUpSpeed && {_elapsed >= _minRagdollTime}];

            (isNull _unit) || {!alive _unit} || {(_elapsed >= _minRagdollTime && {_belowGetUpSpeed}) || {_elapsed >= _maxRagdollTime}}
        };

        if (!isNull _unit && {alive _unit} && {!(_unit getVariable ["ACE_isUnconscious", false])}) then {
            _unit setUnconscious false;
        };

        if (!isNull _unit) then {
            _unit setVariable ["GAIT_isTripping", false, false];
        };
    };
};

[] spawn {
    waitUntil { sleep 0.25; !isNull player };

    private _lastPlayer = objNull;
    private _lastSuspended = false;
    private _startupShown = false;

    while {true} do {
        if (!isNull player && {player != _lastPlayer}) then {
            [] call GAIT_fnc_releaseNativeStaminaOwnership;
            [] call GAIT_fnc_releaseNativeMovement;
            _lastPlayer = player;

            ["player_object_changed"] call GAIT_fnc_resetEffects;

            if (!_startupShown) then {
                _startupShown = true;

                [] spawn {
                    uiSleep 3;

                    if (missionNamespace getVariable ["GAIT_ss_showStartupMessage", true]) then {
                        private _aceText = ["ACE AF bridge waiting/disabled", "ACE AF bridge active"] select (call GAIT_fnc_aceAdvancedFatigueActive);
                        systemChat format ["GAIT active | Preset: %1 | Mode: %2 | %3", missionNamespace getVariable ["GAIT_ss_preset", "Balanced"], call GAIT_fnc_compatModeName, _aceText];
                    };

                    if (isMultiplayer && {missionNamespace getVariable ["GAIT_ss_showServerIndicator", true]}) then {
                        systemChat "GAIT: Multiplayer CBA settings may be controlled by the server or mission.";
                    };

missionNamespace setVariable ["GAIT_versionString", "1.8.0-alpha24"];
[format ["Initialized v%1. Preset=%2 | Mode=%3 | ACE_AF=%4", missionNamespace getVariable ["GAIT_versionString", "?"], missionNamespace getVariable ["GAIT_ss_preset", "Balanced"], call GAIT_fnc_compatModeName, call GAIT_fnc_aceAdvancedFatigueActive]] call GAIT_fnc_log;

                };
            };
        };

        call GAIT_fnc_installNativeAceBridge;
        private _suspended = call GAIT_fnc_isSuspendedContext;
        if (_suspended && {!_lastSuspended}) then {
            ["suspended_context"] call GAIT_fnc_resetEffects;
        };
        _lastSuspended = _suspended;

        uiSleep 0.50;
    };
};

// Shared movement diagnostics, independent of weapon handling.
[] spawn {
    waitUntil { sleep 0.25; !isNull player };
    waitUntil { sleep 0.25; !isNull findDisplay 46 };

    // =====================================================
    // SETTINGS
    // =====================================================

    missionNamespace setVariable ["GAIT_shiftHeld", false];
    missionNamespace setVariable ["GAIT_lastShiftRelease", -999];
    missionNamespace setVariable ["GAIT_lastForwardKeyRelease", -999];
    missionNamespace setVariable ["GAIT_slopeDegrees", 0];
    missionNamespace setVariable ["GAIT_slopeSpeedMultiplier", 1];
    missionNamespace setVariable ["GAIT_lastTripTime", -999];
    missionNamespace setVariable ["GAIT_tripEligible", false];
    missionNamespace setVariable ["GAIT_downhillTerminalReachedTime", -999];
    missionNamespace setVariable ["GAIT_downhillTerminalVelocityKmh", 35.0];
    missionNamespace setVariable ["GAIT_tripChancePerSecond", 0];
    missionNamespace setVariable ["GAIT_tripCooldownRemaining", 0];
    missionNamespace setVariable ["GAIT_tripImmunityRemaining", 0];
    missionNamespace setVariable ["GAIT_tripSustainedGateReady", false];
    missionNamespace setVariable ["GAIT_tripSustainedSprintSeconds", 0];
    missionNamespace setVariable ["GAIT_tripSustainedHighSpeedSeconds", 0];

    missionNamespace setVariable ["GAIT_guaranteeDropTime", -999];

    missionNamespace setVariable ["GAIT_lastStrafeAnimTime", -999];
};


// Update the movement controller and its ACE or fallback sprint reserve.
[] spawn {
    waitUntil { sleep 0.25; !isNull player };

    private _normalSpeed = missionNamespace getVariable ["GAIT_ss_normalSpeed", 0.86];

    // Sprint reserve settings
    private _sprintReserveMax = missionNamespace getVariable ["GAIT_ss_sprintReserveMax", 40.0];
    private _sprintRecoverTime = missionNamespace getVariable ["GAIT_ss_sprintRecoverTime", 10.0];
    private _sprintReserve = _sprintReserveMax;
    private _reserveUnit = player;

    // Normal sprint speeds
    private _sprintFullSpeed = missionNamespace getVariable ["GAIT_ss_sprintFullSpeed", 1.00];

    // Carry movement speeds
    private _carryWalkSpeed = missionNamespace getVariable ["GAIT_ss_carryWalkSpeed", 0.80];
    private _carrySprintFullSpeed = missionNamespace getVariable ["GAIT_ss_carrySprintFullSpeed", 1.50];
    private _carrySprintExhaustedSpeed = missionNamespace getVariable ["GAIT_ss_carrySprintExhaustedSpeed", 0.9];

    // Unarmed/no-weapon sprint normalizer.
    // This prevents holstering your weapon from making sprint speed much faster.
    private _unarmedSprintNormalizer = missionNamespace getVariable ["GAIT_ss_unarmedSprintNormalizer", 0.725];

    // Read actual carried inventory mass; convert it to the configured gear curve units.
    private _loadAbsPerLb = missionNamespace getVariable ["GAIT_ss_loadAbsPerLb", 10];
    private _lightSpeedBonus = missionNamespace getVariable ["GAIT_ss_lightSpeedBonus", 1.08];
    private _mediumSpeedBonus = missionNamespace getVariable ["GAIT_ss_mediumSpeedBonus", 1.02];
    private _moderateSpeedBonus = missionNamespace getVariable ["GAIT_ss_moderateSpeedBonus", 0.97];
    private _heavySpeedBonus = missionNamespace getVariable ["GAIT_ss_heavySpeedBonus", 0.92];

    private _lightBraceRelief = missionNamespace getVariable ["GAIT_ss_lightBraceRelief", 0.55];
    private _mediumBraceRelief = missionNamespace getVariable ["GAIT_ss_mediumBraceRelief", 0.35];
    private _moderateBraceRelief = missionNamespace getVariable ["GAIT_ss_moderateBraceRelief", 0.18];
    private _heavyBraceRelief = missionNamespace getVariable ["GAIT_ss_heavyBraceRelief", 0.00];

    // Smoothing
    private _tickRate = missionNamespace getVariable ["GAIT_ss_tickRate", 0.05];
    private _speedLerp = missionNamespace getVariable ["GAIT_ss_speedLerp", 0.05];              // lower = smoother/slower ramp, higher = snappier

    // Time without forward input before a stopped restart can brace again.
    private _wReleaseZeroMomentumDelay = missionNamespace getVariable ["GAIT_ss_wReleaseZeroMomentumDelay", 0.50];

    // Sprint start realism / heavy-pack momentum step.
    // This creates a short, significant pace dip when sprint starts,
    // then hands back to the normal sprint ramp instead of jumping to full speed.
    private _sprintStartBraceEnabled = missionNamespace getVariable ["GAIT_ss_sprintStartBraceEnabled", true];
    private _sprintStartBraceDuration = missionNamespace getVariable ["GAIT_ss_sprintStartBraceDuration", 0.15];  // short brace step before the normal ramp resumes
    private _sprintStartBraceSpeed = missionNamespace getVariable ["GAIT_ss_sprintStartBraceSpeed", 0.44];     // exaggerated debug slowdown
    private _sprintStartBraceLerp = missionNamespace getVariable ["GAIT_ss_sprintStartBraceLerp", 0.575];       // Higher = snaps to brace speed faster / more abrupt slowdown
                                               // Lower = eases into brace speed more smoothly / softer slowdown

    // Brace step eligibility.
    // The brace only returns after the player has deliberately settled again.
    private _braceRequiredWalkTime = missionNamespace getVariable ["GAIT_ss_braceRequiredWalkTime", 2.0];      // time standing/slow-walking before brace can fire again
    private _braceRecentSprintCooldown = missionNamespace getVariable ["GAIT_ss_braceRecentSprintCooldown", 3.0];  // keeps momentum if Shift is tapped/released/re-tapped
    private _braceMinReserveRatio = missionNamespace getVariable ["GAIT_ss_braceMinReserveRatio", 0.98];      // no brace while exhausted / partially depleted

    // Momentum check.
    // If current movement speed has decayed back near normal, treat momentum as zero
    // and force the brace on the next sprint start. If speed is still above this,
    // the player keeps momentum and does not brace again.
    private _braceNoMomentumThreshold = missionNamespace getVariable ["GAIT_ss_braceNoMomentumThreshold", 0.04];
    private _braceReadySpeedThreshold = missionNamespace getVariable ["GAIT_ss_braceReadySpeedThreshold", 4.0];
    private _lightWeightMax = missionNamespace getVariable ["GAIT_ss_lightWeightMax", 35];
    private _mediumWeightMax = missionNamespace getVariable ["GAIT_ss_mediumWeightMax", 55];
    private _moderateWeightMax = missionNamespace getVariable ["GAIT_ss_moderateWeightMax", 75];
    private _aceAcidosisPenaltyFactor = missionNamespace getVariable ["GAIT_ss_aceAcidosisPenaltyFactor", 0.45];
    private _aceMuscleDamagePenaltyFactor = missionNamespace getVariable ["GAIT_ss_aceMuscleDamagePenaltyFactor", 0.25];

    // Terrain / slope handling.
    private _slopeHandlingEnabled = missionNamespace getVariable ["GAIT_ss_slopeHandlingEnabled", true];
    private _slopeSampleDistance = missionNamespace getVariable ["GAIT_ss_slopeSampleDistance", 2.0];
    private _slopeTransitionSmoothingEnabled = missionNamespace getVariable ["GAIT_ss_slopeTransitionSmoothingEnabled", true];
    private _slopeAngleRiseRateDegPerSecond = missionNamespace getVariable ["GAIT_ss_slopeAngleRiseRateDegPerSecond", 35.0];
    private _slopeAngleFallRateDegPerSecond = missionNamespace getVariable ["GAIT_ss_slopeAngleFallRateDegPerSecond", 30.0];
    private _uphillSlowdownEnabled = missionNamespace getVariable ["GAIT_ss_uphillSlowdownEnabled", true];
    private _uphillStartDegrees = missionNamespace getVariable ["GAIT_ss_uphillStartDegrees", 2.0];
    private _uphillMaxDegrees = missionNamespace getVariable ["GAIT_ss_uphillMaxDegrees", 35.0];
    private _uphillMaxPenalty = missionNamespace getVariable ["GAIT_ss_uphillMaxPenalty", 0.40];
    private _slopeStopBraceEnabled = missionNamespace getVariable ["GAIT_ss_slopeStopBraceEnabled", true];
    private _slopeStopBraceStartDegrees = missionNamespace getVariable ["GAIT_ss_slopeStopBraceStartDegrees", 15.0];
    private _slopeStopBraceMaxDegrees = missionNamespace getVariable ["GAIT_ss_slopeStopBraceMaxDegrees", 35.0];
    private _slopeStopBraceExtraDuration = missionNamespace getVariable ["GAIT_ss_slopeStopBraceExtraDuration", 0.18];
    private _slopeStopBraceExtraDip = missionNamespace getVariable ["GAIT_ss_slopeStopBraceExtraDip", 0.28];
    private _slopeStopBraceMemoryTime = missionNamespace getVariable ["GAIT_ss_slopeStopBraceMemoryTime", 2.5];
    private _downhillBoostEnabled = missionNamespace getVariable ["GAIT_ss_downhillBoostEnabled", true];
    private _downhillBoostStartDegrees = missionNamespace getVariable ["GAIT_ss_downhillBoostStartDegrees", 0.5];
    private _downhillBoostMaxDegrees = missionNamespace getVariable ["GAIT_ss_downhillBoostMaxDegrees", 18.0];
    private _downhillMaxBoost = missionNamespace getVariable ["GAIT_ss_downhillMaxBoost", 0.03];
    private _downhillTripEnabled = missionNamespace getVariable ["GAIT_ss_downhillTripEnabled", true];
    private _downhillTripThresholdDegrees = missionNamespace getVariable ["GAIT_ss_downhillTripThresholdDegrees", 28.0];
    private _downhillTripMaxDegrees = missionNamespace getVariable ["GAIT_ss_downhillTripMaxDegrees", 45.0];
    private _downhillTripBaseChancePerSecond = missionNamespace getVariable ["GAIT_ss_downhillTripBaseChancePerSecond", 0.005];
    private _downhillTripMaxChancePerSecond = missionNamespace getVariable ["GAIT_ss_downhillTripMaxChancePerSecond", 0.10];
    private _downhillTripCooldown = missionNamespace getVariable ["GAIT_ss_downhillTripCooldown", 10.0];
    private _downhillTripDuration = missionNamespace getVariable ["GAIT_ss_downhillTripDuration", 1.00];
    private _downhillTripMinSpeedKmh = missionNamespace getVariable ["GAIT_ss_downhillTripMinSpeedKmh", 20.0];
    private _downhillTripSpeedMaxKmh = missionNamespace getVariable ["GAIT_ss_downhillTripSpeedMaxKmh", 34.0];
    private _downhillTripSpeedInfluence = missionNamespace getVariable ["GAIT_ss_downhillTripSpeedInfluence", 1.0];
    private _downhillTripWeightInfluence = missionNamespace getVariable ["GAIT_ss_downhillTripWeightInfluence", 1.0];
    private _downhillTripRequireSustainedMovement = missionNamespace getVariable ["GAIT_ss_downhillTripRequireSustainedMovement", true];
    private _downhillTripMinSprintSeconds = missionNamespace getVariable ["GAIT_ss_downhillTripMinSprintSeconds", 5.0];
    private _downhillTripSustainedSpeedKmh = missionNamespace getVariable ["GAIT_ss_downhillTripSustainedSpeedKmh", 20.0];
    private _downhillTripSustainedSpeedSeconds = missionNamespace getVariable ["GAIT_ss_downhillTripSustainedSpeedSeconds", 4.0];
    private _downhillTripPostFallImmunity = missionNamespace getVariable ["GAIT_ss_downhillTripPostFallImmunity", 10.0];
    private _downhillTripGetUpSpeedKmh = missionNamespace getVariable ["GAIT_ss_downhillTripGetUpSpeedKmh", 7.0];
    private _downhillTripMaxRagdollDuration = missionNamespace getVariable ["GAIT_ss_downhillTripMaxRagdollDuration", 6.0];
        _masterTripFrequency = missionNamespace getVariable ["GAIT_ss_masterTripFrequency", 1.00];
        _shiftReleaseRunTaperEnabled = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperEnabled", true];
        _shiftReleaseRunTaperDuration = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperDuration", 1.15];
        _shiftReleaseRunTaperCurve = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperCurve", 1.45];
        _debugHudEnabled = missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false];
        _debugHudInterval = missionNamespace getVariable ["GAIT_ss_debugHudInterval", 0.10];

        // Bound the global trip frequency scale.
        _masterTripFrequency = (_masterTripFrequency max 0.00) min 3.00;
        _downhillTripBaseChancePerSecond = _downhillTripBaseChancePerSecond * _masterTripFrequency;
        _downhillTripMaxChancePerSecond = _downhillTripMaxChancePerSecond * _masterTripFrequency;

    private _activeBraceSpeed = _sprintStartBraceSpeed;
    private _conflictScanDone = false;
    private _debugHudEnabled = missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false];
    private _debugHudInterval = missionNamespace getVariable ["GAIT_ss_debugHudInterval", 0.10];
    private _hillWalkDownhillMaxPenalty = missionNamespace getVariable ["GAIT_ss_hillWalkDownhillMaxPenalty", 0.08];
    private _hillWalkSlowdownEnabled = missionNamespace getVariable ["GAIT_ss_hillWalkSlowdownEnabled", true];
    private _hillWalkSlowdownMaxDegrees = missionNamespace getVariable ["GAIT_ss_hillWalkSlowdownMaxDegrees", 40.0];
    private _hillWalkSlowdownStartDegrees = missionNamespace getVariable ["GAIT_ss_hillWalkSlowdownStartDegrees", 15.0];
    private _hillWalkUphillMaxPenalty = missionNamespace getVariable ["GAIT_ss_hillWalkUphillMaxPenalty", 0.32];
    private _lastDebugHudTime = -999;
    private _lastKnownSlopeDegrees = 0;
    private _lastSprintStopSlopeDegrees = 0;
    private _lastSprintStopTime = -999;
    private _masterTripFrequency = missionNamespace getVariable ["GAIT_ss_masterTripFrequency", 1.00];
    private _shiftReleaseRunTaperCurve = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperCurve", 1.45];
    private _shiftReleaseRunTaperDuration = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperDuration", 1.15];
    private _shiftReleaseRunTaperEnabled = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperEnabled", true];
    private _lastForwardReleaseSerial = -1;
    private _lastForwardPressSerial = player getVariable ["GAIT_forwardPressSerial", 0];
    private _walkStartBraceState = [];
    private _slopeSmoothInitialized = false;
    private _smoothedSlopeDegrees = 0;
    private _uphillPaceExposure = 0;
    private _uphillFatigueDrainEnabled = missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainEnabled", true];
    private _uphillFatigueDrainMaxDegrees = missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainMaxDegrees", 35.0];
    private _uphillFatigueDrainMaxMultiplier = missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainMaxMultiplier", 1.75];
    private _uphillFatigueDrainStartDegrees = missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainStartDegrees", 10.0];

    private _lastTick = time;
    private _currentSpeed = _normalSpeed;
    private _wasSprinting = false;
    private _deadSprintElapsed = -1;
    private _deadSprintIntentHeld = false;
    private _deadSprintReady = true;
    private _lastNonSprintAnimation = "";
    private _preSprintAnimation = "";
    private _preSprintWasJog = false;
    private _preSprintWasRaisedCombat = false;
    private _sprintBraceEndTime = -1;
    private _walkingStartTime = -1;
    private _lastSprintEndTime = -999;
    private _braceArmedFromCrouch = false;
    private _lastForwardInputTime = time;
    private _downhillTripSprintStartTime = -1;
    private _downhillTripHighSpeedStartTime = -1;
    private _lastResetRequestHandled = -1;
    private _braceMomentumState = [false, -999, 0, 0];
    private _downhillMomentum = 0;
    private _uphillBrakeState = [];

    while {true} do {
        private _now = time;
        private _dt = _now - _lastTick;
        _lastTick = _now;

        if (_reserveUnit isNotEqualTo player) then {
            _reserveUnit = player;
            _sprintReserve = _sprintReserveMax;
            _deadSprintReady = true;
        };

        // Per-tick W-release coast state.
        // These are intentionally refreshed from missionNamespace every tick so
        // malformed/older CBA-saved states or branch skips cannot leave the
        // runtime loop with an undefined local variable.

        private _selectedPreset = missionNamespace getVariable ["GAIT_ss_preset", "Balanced"];
        private _lastPresetApplied = missionNamespace getVariable ["GAIT_lastPresetApplied", ""];
        if (_selectedPreset isNotEqualTo _lastPresetApplied) then {
            [_selectedPreset] call GAIT_fnc_applyPreset;
        };

        private _resetRequest = missionNamespace getVariable ["GAIT_resetRequested", -1];
        if (_resetRequest > _lastResetRequestHandled) then {
            _lastResetRequestHandled = _resetRequest;
            _uphillBrakeState = [];
            missionNamespace setVariable ["GAIT_uphillBrakeActive", false];
            missionNamespace setVariable ["GAIT_uphillBrakeEndTime", -1];
            missionNamespace setVariable ["GAIT_uphillBrakeReadyUntil", -1];
            missionNamespace setVariable ["GAIT_uphillBrakeUnit", objNull];
            missionNamespace setVariable ["GAIT_coastUnit", objNull];
            missionNamespace setVariable ["GAIT_coastActive", false];
            missionNamespace setVariable ["GAIT_coastReadyUntil", -1];
            _braceMomentumState = [false, -999, 0, 0];
            _downhillMomentum = 0;
            missionNamespace setVariable ["GAIT_braceActive", false];
            missionNamespace setVariable ["GAIT_braceEndTime", -1];
            _slopeSmoothInitialized = false;
            _smoothedSlopeDegrees = 0;
            _uphillPaceExposure = 0;
            missionNamespace setVariable ["GAIT_uphillPaceExposure", 0];
            missionNamespace setVariable ["GAIT_uphillPaceMultiplier", 1];
            _currentSpeed = _normalSpeed;
            _wasSprinting = false;
            _deadSprintElapsed = -1;
            _deadSprintIntentHeld = false;
            _lastKnownSlopeDegrees = 0;
            _lastSprintStopSlopeDegrees = 0;
            _lastSprintStopTime = -999;
            _activeBraceSpeed = _sprintStartBraceSpeed;
            _sprintBraceEndTime = -1;
            _walkStartBraceState = [];
            _lastForwardReleaseSerial = player getVariable ["GAIT_forwardReleaseSerial", 0];
            _lastForwardPressSerial = player getVariable ["GAIT_forwardPressSerial", 0];
            missionNamespace setVariable ["GAIT_walkStartBraceActive", false];
            missionNamespace setVariable ["GAIT_walkStartBraceFactor", 1];
            missionNamespace setVariable ["GAIT_walkStartBraceTier", -1];
            _walkingStartTime = -1;
            _lastSprintEndTime = -999;
            _braceArmedFromCrouch = false;
            _lastForwardInputTime = time;
            _downhillTripSprintStartTime = -1;
            _downhillTripHighSpeedStartTime = -1;
            [] call GAIT_fnc_releaseNativeMovement;
        };

        // Refresh live Addon Options settings each tick.
        _debugHudEnabled = missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false];
        _debugHudInterval = missionNamespace getVariable ["GAIT_ss_debugHudInterval", 0.10];
        _hillWalkDownhillMaxPenalty = missionNamespace getVariable ["GAIT_ss_hillWalkDownhillMaxPenalty", 0.08];
        _hillWalkSlowdownEnabled = missionNamespace getVariable ["GAIT_ss_hillWalkSlowdownEnabled", true];
        _hillWalkSlowdownMaxDegrees = missionNamespace getVariable ["GAIT_ss_hillWalkSlowdownMaxDegrees", 40.0];
        _hillWalkSlowdownStartDegrees = missionNamespace getVariable ["GAIT_ss_hillWalkSlowdownStartDegrees", 15.0];
        _hillWalkUphillMaxPenalty = missionNamespace getVariable ["GAIT_ss_hillWalkUphillMaxPenalty", 0.32];
        _masterTripFrequency = missionNamespace getVariable ["GAIT_ss_masterTripFrequency", 1.00];
        _shiftReleaseRunTaperCurve = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperCurve", 1.45];
        _shiftReleaseRunTaperDuration = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperDuration", 1.15];
        _shiftReleaseRunTaperEnabled = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperEnabled", true];
        _uphillFatigueDrainEnabled = missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainEnabled", true];
        _uphillFatigueDrainMaxDegrees = missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainMaxDegrees", 35.0];
        _uphillFatigueDrainMaxMultiplier = missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainMaxMultiplier", 1.75];
        _uphillFatigueDrainStartDegrees = missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainStartDegrees", 10.0];
        private _oldSprintReserveMax = _sprintReserveMax;
        _normalSpeed = missionNamespace getVariable ["GAIT_ss_normalSpeed", 0.86];
        _sprintReserveMax = missionNamespace getVariable ["GAIT_ss_sprintReserveMax", 40.0];
        _sprintRecoverTime = missionNamespace getVariable ["GAIT_ss_sprintRecoverTime", 10.0];
        _sprintFullSpeed = missionNamespace getVariable ["GAIT_ss_sprintFullSpeed", 1.00];
        _carryWalkSpeed = missionNamespace getVariable ["GAIT_ss_carryWalkSpeed", 0.80];
        _carrySprintFullSpeed = missionNamespace getVariable ["GAIT_ss_carrySprintFullSpeed", 1.50];
        _carrySprintExhaustedSpeed = missionNamespace getVariable ["GAIT_ss_carrySprintExhaustedSpeed", 0.9];
        _unarmedSprintNormalizer = missionNamespace getVariable ["GAIT_ss_unarmedSprintNormalizer", 0.725];
        _loadAbsPerLb = missionNamespace getVariable ["GAIT_ss_loadAbsPerLb", 10];
        _lightSpeedBonus = missionNamespace getVariable ["GAIT_ss_lightSpeedBonus", 1.08];
        _mediumSpeedBonus = missionNamespace getVariable ["GAIT_ss_mediumSpeedBonus", 1.02];
        _moderateSpeedBonus = missionNamespace getVariable ["GAIT_ss_moderateSpeedBonus", 0.97];
        _heavySpeedBonus = missionNamespace getVariable ["GAIT_ss_heavySpeedBonus", 0.92];
        _lightBraceRelief = missionNamespace getVariable ["GAIT_ss_lightBraceRelief", 0.55];
        _mediumBraceRelief = missionNamespace getVariable ["GAIT_ss_mediumBraceRelief", 0.35];
        _moderateBraceRelief = missionNamespace getVariable ["GAIT_ss_moderateBraceRelief", 0.18];
        _heavyBraceRelief = missionNamespace getVariable ["GAIT_ss_heavyBraceRelief", 0.00];
        _tickRate = missionNamespace getVariable ["GAIT_ss_tickRate", 0.05];
        _speedLerp = missionNamespace getVariable ["GAIT_ss_speedLerp", 0.05];
        _wReleaseZeroMomentumDelay = missionNamespace getVariable ["GAIT_ss_wReleaseZeroMomentumDelay", 0.50];
        // v1.1.32 migration: old v1.1.31 defaults coasted a little too far.
        // Treat unchanged legacy defaults as the shorter new feel, while still allowing custom values.
        _sprintStartBraceEnabled = missionNamespace getVariable ["GAIT_ss_sprintStartBraceEnabled", true];
        _sprintStartBraceDuration = missionNamespace getVariable ["GAIT_ss_sprintStartBraceDuration", 0.15];
        _sprintStartBraceSpeed = missionNamespace getVariable ["GAIT_ss_sprintStartBraceSpeed", 0.44];
        _sprintStartBraceLerp = missionNamespace getVariable ["GAIT_ss_sprintStartBraceLerp", 0.575];
        _braceRequiredWalkTime = missionNamespace getVariable ["GAIT_ss_braceRequiredWalkTime", 2.0];
        _braceRecentSprintCooldown = missionNamespace getVariable ["GAIT_ss_braceRecentSprintCooldown", 3.0];
        _braceMinReserveRatio = missionNamespace getVariable ["GAIT_ss_braceMinReserveRatio", 0.98];
        _braceNoMomentumThreshold = missionNamespace getVariable ["GAIT_ss_braceNoMomentumThreshold", 0.04];
        _braceReadySpeedThreshold = missionNamespace getVariable ["GAIT_ss_braceReadySpeedThreshold", 4.0];
        _lightWeightMax = missionNamespace getVariable ["GAIT_ss_lightWeightMax", 35];
        _mediumWeightMax = missionNamespace getVariable ["GAIT_ss_mediumWeightMax", 55];
        _moderateWeightMax = missionNamespace getVariable ["GAIT_ss_moderateWeightMax", 75];
        _aceAcidosisPenaltyFactor = missionNamespace getVariable ["GAIT_ss_aceAcidosisPenaltyFactor", 0.45];
        _aceMuscleDamagePenaltyFactor = missionNamespace getVariable ["GAIT_ss_aceMuscleDamagePenaltyFactor", 0.25];
        _slopeHandlingEnabled = missionNamespace getVariable ["GAIT_ss_slopeHandlingEnabled", true];
            _slopeSampleDistance = missionNamespace getVariable ["GAIT_ss_slopeSampleDistance", 2.0];
        _slopeTransitionSmoothingEnabled = missionNamespace getVariable ["GAIT_ss_slopeTransitionSmoothingEnabled", true];
        _slopeAngleRiseRateDegPerSecond = missionNamespace getVariable ["GAIT_ss_slopeAngleRiseRateDegPerSecond", 35.0];
        _slopeAngleFallRateDegPerSecond = missionNamespace getVariable ["GAIT_ss_slopeAngleFallRateDegPerSecond", 30.0];
        _uphillSlowdownEnabled = missionNamespace getVariable ["GAIT_ss_uphillSlowdownEnabled", true];
        _uphillStartDegrees = missionNamespace getVariable ["GAIT_ss_uphillStartDegrees", 2.0];
        _uphillMaxDegrees = missionNamespace getVariable ["GAIT_ss_uphillMaxDegrees", 35.0];
        _uphillMaxPenalty = missionNamespace getVariable ["GAIT_ss_uphillMaxPenalty", 0.40];
        _slopeStopBraceEnabled = missionNamespace getVariable ["GAIT_ss_slopeStopBraceEnabled", true];
        _slopeStopBraceStartDegrees = missionNamespace getVariable ["GAIT_ss_slopeStopBraceStartDegrees", 15.0];
        _slopeStopBraceMaxDegrees = missionNamespace getVariable ["GAIT_ss_slopeStopBraceMaxDegrees", 35.0];
        _slopeStopBraceExtraDuration = missionNamespace getVariable ["GAIT_ss_slopeStopBraceExtraDuration", 0.18];
        _slopeStopBraceExtraDip = missionNamespace getVariable ["GAIT_ss_slopeStopBraceExtraDip", 0.28];
        _slopeStopBraceMemoryTime = missionNamespace getVariable ["GAIT_ss_slopeStopBraceMemoryTime", 2.5];
        _downhillBoostEnabled = missionNamespace getVariable ["GAIT_ss_downhillBoostEnabled", true];
        _downhillBoostStartDegrees = missionNamespace getVariable ["GAIT_ss_downhillBoostStartDegrees", 0.5];
        _downhillBoostMaxDegrees = missionNamespace getVariable ["GAIT_ss_downhillBoostMaxDegrees", 18.0];
        _downhillMaxBoost = missionNamespace getVariable ["GAIT_ss_downhillMaxBoost", 0.03];
        _downhillTripEnabled = missionNamespace getVariable ["GAIT_ss_downhillTripEnabled", true];
        _downhillTripThresholdDegrees = missionNamespace getVariable ["GAIT_ss_downhillTripThresholdDegrees", 28.0];
        _downhillTripMaxDegrees = missionNamespace getVariable ["GAIT_ss_downhillTripMaxDegrees", 45.0];
        _downhillTripBaseChancePerSecond = missionNamespace getVariable ["GAIT_ss_downhillTripBaseChancePerSecond", 0.005];
        _downhillTripMaxChancePerSecond = missionNamespace getVariable ["GAIT_ss_downhillTripMaxChancePerSecond", 0.10];
        _downhillTripCooldown = missionNamespace getVariable ["GAIT_ss_downhillTripCooldown", 10.0];
        _downhillTripDuration = missionNamespace getVariable ["GAIT_ss_downhillTripDuration", 1.00];
        _downhillTripMinSpeedKmh = missionNamespace getVariable ["GAIT_ss_downhillTripMinSpeedKmh", 20.0];
        _downhillTripSpeedMaxKmh = missionNamespace getVariable ["GAIT_ss_downhillTripSpeedMaxKmh", 34.0];
        _downhillTripSpeedInfluence = missionNamespace getVariable ["GAIT_ss_downhillTripSpeedInfluence", 1.0];
        _downhillTripWeightInfluence = missionNamespace getVariable ["GAIT_ss_downhillTripWeightInfluence", 1.0];
        _downhillTripRequireSustainedMovement = missionNamespace getVariable ["GAIT_ss_downhillTripRequireSustainedMovement", true];
        _downhillTripMinSprintSeconds = missionNamespace getVariable ["GAIT_ss_downhillTripMinSprintSeconds", 5.0];
        _downhillTripSustainedSpeedKmh = missionNamespace getVariable ["GAIT_ss_downhillTripSustainedSpeedKmh", 20.0];
        _downhillTripSustainedSpeedSeconds = missionNamespace getVariable ["GAIT_ss_downhillTripSustainedSpeedSeconds", 4.0];
        _downhillTripPostFallImmunity = missionNamespace getVariable ["GAIT_ss_downhillTripPostFallImmunity", 10.0];
        _downhillTripGetUpSpeedKmh = missionNamespace getVariable ["GAIT_ss_downhillTripGetUpSpeedKmh", 7.0];
        _downhillTripMaxRagdollDuration = missionNamespace getVariable ["GAIT_ss_downhillTripMaxRagdollDuration", 6.0];
        _masterTripFrequency = missionNamespace getVariable ["GAIT_ss_masterTripFrequency", 1.00];
        _shiftReleaseRunTaperEnabled = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperEnabled", true];
        _shiftReleaseRunTaperDuration = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperDuration", 1.15];
        _shiftReleaseRunTaperCurve = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperCurve", 1.45];
        _debugHudEnabled = missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false];
        _debugHudInterval = missionNamespace getVariable ["GAIT_ss_debugHudInterval", 0.10];

        _masterTripFrequency = (_masterTripFrequency max 0.00) min 3.00;
        _downhillTripBaseChancePerSecond = _downhillTripBaseChancePerSecond * _masterTripFrequency;
        _downhillTripMaxChancePerSecond = _downhillTripMaxChancePerSecond * _masterTripFrequency;

        if (_oldSprintReserveMax > 0 && {_oldSprintReserveMax != _sprintReserveMax}) then {
            private _reserveRatioBeforeChange = (_sprintReserve / _oldSprintReserveMax) max 0 min 1;
            _sprintReserve = _sprintReserveMax * _reserveRatioBeforeChange;
        };

        // Own native stamina before asking the engine for sprint permission.
        // This also restores its saved flag when movement is disabled or the
        // player enters a context owned by another system.
        [player] call GAIT_fnc_updateNativeStaminaOwnership;
        // Scope exits must not display risk from the previous active tick.
        missionNamespace setVariable ["GAIT_tripEligible", false];
        missionNamespace setVariable ["GAIT_tripChancePerSecond", 0];
        if (alive player && {call GAIT_fnc_modeAllowsMovement} && {!(call GAIT_fnc_isSuspendedContext)}) then {
            private _pickupActive = player getVariable ["MAV_fastCarry_pickupActive", false];
            private _gaitMovementEnabled = call GAIT_fnc_modeAllowsMovement;

            if (!_conflictScanDone) then {
                _conflictScanDone = true;
                private _conflicts = [];
                {
                    if (isClass (configFile >> "CfgPatches" >> _x)) then { _conflicts pushBack _x; };
                } forEach [
                    "em_main",
                    "enhanced_movement",
                    "Enhanced_Movement",
                    "lambs_wp",
                    "dzn_extended_jamming"
                ];
                private _aceMovementPresent = isClass (configFile >> "CfgPatches" >> "ace_movement");
                missionNamespace setVariable ["GAIT_aceMovementDetected", _aceMovementPresent];
                missionNamespace setVariable ["GAIT_conflictScanHits", _conflicts];
                if (_conflicts isNotEqualTo [] && {missionNamespace getVariable ["GAIT_ss_rptLogging", true]}) then {
                    diag_log format ["[GAIT] Compatibility scan warning: movement/animation-related addons detected: %1", _conflicts];
                };
            };

            // Do not override the Fast Carry pickup/lift animation speed.
            if (!_pickupActive) then {
                private _isAceCarrying = player getVariable ["ace_dragging_isCarrying", false];
                private _isAceDragging = player getVariable ["ace_dragging_isDragging", false];
                private _carriedObject = player getVariable ["ace_dragging_carriedObject", objNull];
                private _isOnFoot = isNull objectParent player;
                private _movementInput = call GAIT_fnc_getMovementInput;
                private _turboHeld = _movementInput select 2;
                [player] call GAIT_fnc_clearACEAdvancedFatigueMovementLocks;
                private _nativeWalk = !_isAceCarrying && {[player, _turboHeld] call GAIT_fnc_nativeWalkRequested};
                private _stanceYieldActive = [player] call GAIT_fnc_stanceYieldActive;
                // A render-observed stance request owns this transition. Never
                // reassert release/handoff speed during its short native lease.
                if (!_stanceYieldActive && {!_nativeWalk}) then {
                    [player, _movementInput] call GAIT_fnc_observeReleaseMomentum;
                };
                if (_stanceYieldActive && {!_nativeWalk}) then {
                    [player] call GAIT_fnc_clearReleaseMomentum;
                    // Keep the currently applied coefficient through the native
                    // running-to-crouch/prone bend. No writer runs here; the
                    // value simply remains untouched until the lease ends.
                };
                private _releaseResume = player getVariable ["GAIT_releaseResume", []];
                player setVariable ["GAIT_releaseResume", []];
                private _releaseResumed = (count _releaseResume) isEqualTo 2 &&
                    {diag_tickTime - (_releaseResume select 1) <= 0.25};
                if (player isEqualTo (missionNamespace getVariable ["GAIT_nativeOwner", objNull]) &&
                    {abs ((getAnimSpeedCoef player) - (missionNamespace getVariable ["GAIT_nativeLastWritten", -1])) < 0.001}) then {
                    _currentSpeed = missionNamespace getVariable ["GAIT_nativeLastPreVegetation", _currentSpeed];
                };
                if (_releaseResumed) then {_currentSpeed = _releaseResume select 0;};
                private _isForwardHeld = (_movementInput select 0) > 0.05;
                private _externalSprintLock = !(isSprintAllowed player) || {(player getVariable ["ace_common_effect_blockSprint", 0]) > 0};
                private _externalWalkLock = isForcedWalk player || {(player getVariable ["ace_common_effect_forceWalk", 0]) > 0};
                private _movementEligible = [player, _isAceCarrying] call GAIT_fnc_nativeMovementEligible;
                private _sprintIntent = !_stanceYieldActive && {_turboHeld} && {_isForwardHeld} &&
                    {(stance player) isNotEqualTo "PRONE"} && {!_externalSprintLock} && {!_externalWalkLock};
                private _isSprinting = _sprintIntent && {_movementEligible};
                // v1.6.0 (FIX 3 - prone): a real "standing" gate for anim/velocity
                // forcing. `stance` can still report "STAND" on the exact frame the
                // player triggers prone (or crouch) while sprinting; forcing a sprint
                // playMove on that frame pulls the player back upright and runs them
                // forward with no input (the reported bug). animationState already
                // carries the prone (Ppne) / kneel-crouch (Pknl) target during the
                // blend, so reject those here. All GAIT anim-forcing intents below use
                // _gaitStanceOk instead of a bare stance=="STAND" test.
                private _gaitStanceOk = !_stanceYieldActive && {((stance player) isEqualTo "STAND")} && {
                    private _gaitAnimLow = toLower (animationState player);
                    ((_gaitAnimLow find "ppne") < 0) && {(_gaitAnimLow find "pknl") < 0}
                };
                private _isCrouched = (stance player) isEqualTo "CROUCH";
                private _isBackHeld = (_movementInput select 0) < -0.05;
                private _isLateralHeld = abs (_movementInput select 1) > 0.05;

                private _onGroundNow = isTouchingGround player;
                // Track the last pre-sprint animation so post-run correction can be
                // intent-aware. If the player was already jogging or in a raised
                // combat stance before sprinting, do not force a stance correction
                // after sprint release.
                if (!_isSprinting && {_isOnFoot}) then {
                    _lastNonSprintAnimation = animationState player;
                };

                // Store the last real horizontal movement state.
                // W-release coasting must be based on player momentum, not on the W key itself.
                // This sample is refreshed only while the unit actually has horizontal velocity.
                private _velSample = velocity player;
                private _horizontalSpeedMS = sqrt (((_velSample select 0) * (_velSample select 0)) + (((_velSample select 1) * (_velSample select 1))));
                private _actualSpeedKmh = _horizontalSpeedMS * 3.6;

                private _tripMovementEligible = _movementEligible && {_isOnFoot} && {!_isAceCarrying} && {!_isAceDragging} && {_gaitStanceOk} && {_onGroundNow} && {!_externalSprintLock} && {!_externalWalkLock};
                private _tripQualification = [[_downhillTripSprintStartTime, _downhillTripHighSpeedStartTime], time,
                    _tripMovementEligible, _isSprinting, _actualSpeedKmh, _downhillTripSustainedSpeedKmh,
                    _downhillTripMinSpeedKmh, _downhillTripMinSprintSeconds]
                    call GAIT_fnc_stepDownhillTripQualification;
                _downhillTripSprintStartTime = _tripQualification select 0;
                _downhillTripHighSpeedStartTime = _tripQualification select 1;
                private _tripSustainedSprintSeconds = _tripQualification select 2;
                private _tripSustainedHighSpeedSeconds = _tripQualification select 3;

                missionNamespace setVariable ["GAIT_tripSustainedSprintSeconds", _tripSustainedSprintSeconds];
                missionNamespace setVariable ["GAIT_tripSustainedHighSpeedSeconds", _tripSustainedHighSpeedSeconds];

                if (_isForwardHeld) then {_lastForwardInputTime = time;};
                private _forwardReleasedLongEnough = !_isForwardHeld && {((time - _lastForwardInputTime) >= _wReleaseZeroMomentumDelay)};

                // ACE Advanced Fatigue is allowed to run its physiology model,
                // but MAV owns movement. Clear ACE movement locks before brace
                // and momentum logic so standing sprint starts behave like the
                // original MAV system instead of being suppressed by ACE.
                private _aceAdvancedFatigueActive = call GAIT_fnc_aceAdvancedFatigueActive;
                if (_aceAdvancedFatigueActive) then {
                    [player] call GAIT_fnc_clearACEAdvancedFatigueMovementLocks;
                };

                private _gearLbs = (loadAbs player) / (_loadAbsPerLb max 0.01);
                private _loadAnchors = [_lightWeightMax, _mediumWeightMax, _moderateWeightMax];
                private _unloadedSpeedMult = _lightSpeedBonus max 0.01;
                private _weightSpeedMult = [_gearLbs, _loadAnchors,
                    [_unloadedSpeedMult, _mediumSpeedBonus, _moderateSpeedBonus, _heavySpeedBonus],
                    missionNamespace getVariable ["GAIT_ss_extraHeavyPenaltyPer50Lb", 0.18]]
                    call GAIT_fnc_continuousLoadMultiplier;
                private _gearInertia = [_gearLbs,
                    [_lightBraceRelief, _mediumBraceRelief, _moderateBraceRelief, _heavyBraceRelief],
                    _loadAnchors] call GAIT_fnc_gearInertia;
                private _effectiveNormalSpeed = _normalSpeed * _weightSpeedMult;
                private _effectiveBraceRelief = (_gearInertia select 4) * 0.20;
                private _effectiveBraceSpeed = (_sprintStartBraceSpeed + ((_normalSpeed - _sprintStartBraceSpeed) * _effectiveBraceRelief)) * _weightSpeedMult;

                private _accelerationScale = _gearInertia select 0;
                private _coastScale = _gearInertia select 2;
                missionNamespace setVariable ["GAIT_gearInertia", _gearInertia];
                private _forwardReleaseSerial = player getVariable ["GAIT_forwardReleaseSerial", 0];
                private _forwardReleasedSinceTick = _forwardReleaseSerial isNotEqualTo _lastForwardReleaseSerial;
                _lastForwardReleaseSerial = _forwardReleaseSerial;
                private _forwardPressSerial = player getVariable ["GAIT_forwardPressSerial", 0];
                private _forwardPressedSinceTick = _forwardPressSerial isNotEqualTo _lastForwardPressSerial;
                _lastForwardPressSerial = _forwardPressSerial;
                private _forwardPressSnapshot = player getVariable ["GAIT_forwardPressSnapshot", []];
                private _renderReleasedSinceTick = player getVariable ["GAIT_releaseSinceFeatureTick", false];
                player setVariable ["GAIT_releaseSinceFeatureTick", false];
                // Raw input can cancel a launch between feature ticks. Only
                // retire that exact token; a later genuine brace remains valid.
                if (_sprintBraceEndTime >= 0 && {_sprintBraceEndTime isEqualTo (player getVariable ["GAIT_slopeCanceledBraceEndTime", -2])}) then {
                    _sprintBraceEndTime = -1;
                };

                // =====================================================
                // TERRAIN / SLOPE MODIFIER
                // Directional grade scales pace continuously; there is no maximum sprint angle.
                // Downhill entry and sustained travel each contribute to the target.
                // =====================================================
                private _rawSlopeDegrees = 0;
                private _slopeDegrees = 0;
                private _slopeSpeedMultiplier = 1;

                if (_slopeHandlingEnabled && {_isOnFoot} && {!_isAceDragging}) then {
                    _rawSlopeDegrees = [player, _slopeSampleDistance, _movementInput] call GAIT_fnc_getTravelSlopeDegrees;

                    if (_slopeTransitionSmoothingEnabled) then {
                        if (!_slopeSmoothInitialized) then {
                            _smoothedSlopeDegrees = _rawSlopeDegrees;
                            _slopeSmoothInitialized = true;
                        } else {
                            private _slopeDiff = _rawSlopeDegrees - _smoothedSlopeDegrees;
                            private _slopeMagnitudeIncreasing = (abs _rawSlopeDegrees) > (abs _smoothedSlopeDegrees);
                            private _slopeRate = [_slopeAngleFallRateDegPerSecond, _slopeAngleRiseRateDegPerSecond] select _slopeMagnitudeIncreasing;
                            _slopeRate = (_slopeRate max 1.0) min 180.0;
                            private _slopeStep = _slopeRate * ((_dt max 0.001) min 0.20);
                            _slopeDiff = (_slopeDiff max (-_slopeStep)) min _slopeStep;
                            _smoothedSlopeDegrees = _smoothedSlopeDegrees + _slopeDiff;
                        };
                        _slopeDegrees = _smoothedSlopeDegrees;
                    } else {
                        _smoothedSlopeDegrees = _rawSlopeDegrees;
                        _slopeSmoothInitialized = true;
                        _slopeDegrees = _rawSlopeDegrees;
                    };

                    _lastKnownSlopeDegrees = _slopeDegrees;
                    missionNamespace setVariable ["GAIT_rawSlopeDegrees", _rawSlopeDegrees];
                    missionNamespace setVariable ["GAIT_smoothedSlopeDegrees", _smoothedSlopeDegrees];
                    missionNamespace setVariable ["GAIT_slopeTransitionSmoothingEnabled", _slopeTransitionSmoothingEnabled];
                    missionNamespace setVariable ["GAIT_lastKnownSlopeDegrees", _lastKnownSlopeDegrees];

                    private _uphillMaxDegSafe = _uphillMaxDegrees max (_uphillStartDegrees + 0.1);
                    private _uphillBuildContext = _uphillSlowdownEnabled && {_isSprinting} &&
                        {_slopeDegrees > _uphillStartDegrees} && {_isForwardHeld} &&
                        {_movementEligible} && {_gaitStanceOk} && {_onGroundNow};
                    _uphillPaceExposure = [_uphillPaceExposure, _slopeDegrees, _uphillBuildContext,
                        _dt, _uphillStartDegrees, _uphillMaxDegSafe] call GAIT_fnc_stepUphillPaceExposure;
                    missionNamespace setVariable ["GAIT_uphillPaceExposure", _uphillPaceExposure];

                    if (_uphillBuildContext) then {
                        private _fullUphillMultiplier = [_slopeDegrees, _uphillStartDegrees,
                            _uphillMaxDegSafe, _uphillMaxPenalty] call GAIT_fnc_uphillPaceMultiplier;
                        _slopeSpeedMultiplier = [_fullUphillMultiplier, _uphillPaceExposure]
                            call GAIT_fnc_applyUphillPaceExposure;
                    };
                    missionNamespace setVariable ["GAIT_uphillPaceMultiplier", _slopeSpeedMultiplier];

                    private _downhillDegForTrip = abs _slopeDegrees;
                    private _downhillTripMaxDegSafe = _downhillTripMaxDegrees max (_downhillTripThresholdDegrees + 0.1);
                    private _gearTripSeverity = linearConversion [_lightWeightMax, 110, _gearLbs, 0, 1, true];
                    private _tripSlopeSeverity = if (_slopeDegrees < -_downhillTripThresholdDegrees) then {
                        linearConversion [_downhillTripThresholdDegrees, _downhillTripMaxDegSafe, _downhillDegForTrip, 0, 1, true]
                    } else {
                        0
                    };

                    private _tripSpeedFactors = [_actualSpeedKmh, _downhillTripMinSpeedKmh,
                        _downhillTripSpeedMaxKmh, _downhillTripSpeedInfluence] call GAIT_fnc_downhillTripSpeedFactors;
                    private _tripSpeedSeverity = _tripSpeedFactors select 0;
                    private _speedRiskMultiplier = _tripSpeedFactors select 1;

                    private _weightInfluence = (_downhillTripWeightInfluence max 0) min 2;
                    private _weightRiskCurve = 0.75 + (0.85 * _gearTripSeverity);
                    private _weightRiskMultiplier = 1 + (((_weightRiskCurve max 0.10) - 1) * _weightInfluence);
                    _weightRiskMultiplier = _weightRiskMultiplier max 0;

                    private _sustainedGateReady = true;
                    if (_downhillTripRequireSustainedMovement) then {
                        _sustainedGateReady = (_tripSustainedSprintSeconds >= (_downhillTripMinSprintSeconds max 0)) || {_tripSustainedHighSpeedSeconds >= (_downhillTripSustainedSpeedSeconds max 0)};
                    };

                    private _lastTripTime = missionNamespace getVariable ["GAIT_lastTripTime", -999];
                    private _cooldownRemaining = ((_downhillTripCooldown - (time - _lastTripTime)) max 0);
                    private _immunityRemaining = ((_downhillTripPostFallImmunity - (time - _lastTripTime)) max 0);
                    private _tripBlockedByCooldown = (_cooldownRemaining > 0) || {_immunityRemaining > 0};
                    private _tripEligible = _downhillTripEnabled && {_tripMovementEligible} && {_slopeDegrees < -_downhillTripThresholdDegrees} && {_actualSpeedKmh >= _downhillTripMinSpeedKmh} && {_sustainedGateReady};
                    private _chancePerSecond = 0;

                    if (_tripEligible) then {
                        _chancePerSecond = _downhillTripBaseChancePerSecond + ((_downhillTripMaxChancePerSecond - _downhillTripBaseChancePerSecond) * _tripSlopeSeverity);
                        _chancePerSecond = _chancePerSecond * _speedRiskMultiplier * _weightRiskMultiplier;
                        _chancePerSecond = _chancePerSecond max 0 min 1;
                    };

                    missionNamespace setVariable ["GAIT_tripEligible", _tripEligible];
                    missionNamespace setVariable ["GAIT_tripAngleDegrees", _downhillDegForTrip];
                    missionNamespace setVariable ["GAIT_tripEffectiveThreshold", _downhillTripThresholdDegrees];
                    missionNamespace setVariable ["GAIT_tripEffectiveMax", _downhillTripMaxDegSafe];
                    missionNamespace setVariable ["GAIT_tripCooldownRemaining", _cooldownRemaining];
                    missionNamespace setVariable ["GAIT_tripImmunityRemaining", _immunityRemaining];
                    missionNamespace setVariable ["GAIT_tripSpeedKmh", _actualSpeedKmh];
                    missionNamespace setVariable ["GAIT_tripSlopeSeverity", _tripSlopeSeverity];
                    missionNamespace setVariable ["GAIT_tripSpeedSeverity", _tripSpeedSeverity];
                    missionNamespace setVariable ["GAIT_tripWeightSeverity", _gearTripSeverity];
                    missionNamespace setVariable ["GAIT_tripSpeedMultiplier", _speedRiskMultiplier];
                    missionNamespace setVariable ["GAIT_tripWeightMultiplier", _weightRiskMultiplier];
                    missionNamespace setVariable ["GAIT_tripSustainedGateReady", _sustainedGateReady];
                    missionNamespace setVariable ["GAIT_tripGetUpThresholdKmh", _downhillTripGetUpSpeedKmh];
                    missionNamespace setVariable ["GAIT_tripMaxRagdollDuration", _downhillTripMaxRagdollDuration];
                    missionNamespace setVariable ["GAIT_tripChancePerSecond", _chancePerSecond];

                    if (_tripEligible && {!_tripBlockedByCooldown} && {(random 1) < ([_chancePerSecond, _dt] call GAIT_fnc_downhillTripRollChance)}) then {
                        [_downhillTripDuration] call GAIT_fnc_tripPlayer;
                        _currentSpeed = _effectiveNormalSpeed;
                        _sprintBraceEndTime = -1;
                        _wasSprinting = false;
                    };
                };

                private _hillWalkSlowdownMultiplier = 1;
                private _hillWalkSlowdownSeverity = 0;
                if (_hillWalkSlowdownEnabled && {_slopeHandlingEnabled} && {_isOnFoot} && {_isForwardHeld || {_isBackHeld} || {_isLateralHeld}} && {!_isAceDragging}) then {
                    private _walkStartDeg = (_hillWalkSlowdownStartDegrees max 0) min 60;
                    private _walkMaxDeg = (_hillWalkSlowdownMaxDegrees max (_walkStartDeg + 0.1)) min 80;
                    private _absWalkSlope = abs _slopeDegrees;
                    if (_absWalkSlope >= _walkStartDeg) then {
                        _hillWalkSlowdownSeverity = linearConversion [_walkStartDeg, _walkMaxDeg, _absWalkSlope, 0, 1, true];
                        private _walkWeightSeverity = linearConversion [_lightWeightMax, 115, _gearLbs, 0, 1, true];
                        private _walkWeightScale = 0.75 + (0.50 * _walkWeightSeverity);
                        private _walkPenalty = if (_slopeDegrees >= _walkStartDeg) then {
                            ((_hillWalkUphillMaxPenalty max 0) min 0.75) * _walkWeightScale
                        } else {
                            ((_hillWalkDownhillMaxPenalty max 0) min 0.35) * _walkWeightScale
                        };
                        _hillWalkSlowdownMultiplier = [_absWalkSlope, _walkStartDeg, _walkMaxDeg, _walkPenalty] call GAIT_fnc_uphillPaceMultiplier;
                    };
                };

                missionNamespace setVariable ["GAIT_slopeDegrees", _slopeDegrees];
                missionNamespace setVariable ["GAIT_hillWalkSlowdownMultiplier", _hillWalkSlowdownMultiplier];
                missionNamespace setVariable ["GAIT_hillWalkSlowdownSeverity", _hillWalkSlowdownSeverity];

                // Keep W-only terrain jog distinct from intentional walking.
                private _locomotionExternalLock = _externalSprintLock || {_externalWalkLock};
                private _walkToggled = [player, false] call GAIT_fnc_nativeWalkRequested;
                private _slopeJogWasWanted = player getVariable ["GAIT_slopeJogIntent", false];
                private _ordinaryInput = [_movementInput select 0, _movementInput select 1, false];
                private _ordinarySlopeJog = _slopeHandlingEnabled && {_gaitMovementEnabled} &&
                    {_gaitStanceOk} && {_onGroundNow} && {!_isAceCarrying} && {!_isAceDragging} &&
                    {[_ordinaryInput, _slopeDegrees, _externalSprintLock, _externalWalkLock, _walkToggled, _slopeJogWasWanted]
                        call GAIT_fnc_ordinarySlopeJogIntent};
                private _slopeJogWanted = _ordinarySlopeJog && {!_turboHeld};
                player setVariable ["GAIT_slopeJogIntent", _slopeJogWanted];
                private _slopeJogOverride = _slopeJogWanted && {_movementEligible};
                missionNamespace setVariable ["GAIT_slopeJogOverride", _slopeJogOverride];

                private _inputReleasePace = _effectiveNormalSpeed * _hillWalkSlowdownMultiplier;
                if (_isAceCarrying && {!isNull _carriedObject}) then {
                    _inputReleasePace = _carryWalkSpeed * _weightSpeedMult * _hillWalkSlowdownMultiplier;
                };
                // A forward release cancels scalar coast even if W was pressed
                // again between scheduled updates. History may suppress a second
                // launch dip, but cannot restore the cancelled speed or hill bonus.
                if (!_isForwardHeld || {_forwardReleasedSinceTick}) then {
                    _currentSpeed = _inputReleasePace;
                    _downhillMomentum = 0;
                };

                // Sample established motion BEFORE processing a new sprint
                // press. Holding Turbo against a wall cannot establish it.
                // A transient animation blend does not clear physical history.
                private _momentumContextOk = _gaitMovementEnabled && {!_isAceCarrying} && {!_isAceDragging} &&
                    {!_externalSprintLock} && {!_externalWalkLock} && {[player] call GAIT_fnc_fatigueMovementContextEligible};

                // Ordinary W start from a true stop gets one small planted first
                // step. It is independent of sprint momentum and never stacks
                // with Turbo, carry/drag, medical locks, airborne movement or an
                // already-moving re-press. The render snapshot prevents a slow
                // feature tick from mistaking newly acquired speed for momentum.
                if (_forwardPressedSinceTick) then {
                    _walkStartBraceState = [];
                    private _snapshotValid = (count _forwardPressSnapshot) isEqualTo 4 &&
                        {(_forwardPressSnapshot select 0) isEqualTo _forwardPressSerial} &&
                        {diag_tickTime >= (_forwardPressSnapshot select 1)} &&
                        {diag_tickTime - (_forwardPressSnapshot select 1) <= 0.35};
                    if (_sprintStartBraceEnabled && {_snapshotValid} &&
                        {!(_forwardPressSnapshot select 3)} && {!_isSprinting} && {!_nativeWalk} &&
                        {_isForwardHeld} && {_momentumContextOk} && {_gaitStanceOk} &&
                        {_onGroundNow} && {(_forwardPressSnapshot select 2) <= 0.35}) then {
                        _walkStartBraceState = [_forwardPressSnapshot select 1, _gearLbs,
                            _loadAnchors] call GAIT_fnc_walkStartBracePlan;
                    };
                };
                if (!_isForwardHeld || {_isSprinting} || {_nativeWalk} || {!_momentumContextOk} ||
                    {!_gaitStanceOk} || {!_onGroundNow}) then {
                    _walkStartBraceState = [];
                };

                private _continuingSprint = _isSprinting && {_wasSprinting} && {_sprintBraceEndTime <= time} && {!_forwardReleasedSinceTick};
                private _motion = [_braceMomentumState, _continuingSprint, _momentumContextOk,
                    _horizontalSpeedMS, _currentSpeed, _effectiveNormalSpeed * _hillWalkSlowdownMultiplier,
                    time, _dt, _braceRecentSprintCooldown, _braceRequiredWalkTime, _braceNoMomentumThreshold]
                    call GAIT_fnc_stepBraceMomentum;
                _braceMomentumState = _motion select 0;
                private _hasRetainedSprintMomentum = (_motion select 1) || {_releaseResumed};
                missionNamespace setVariable ["GAIT_braceMomentumProtected", _hasRetainedSprintMomentum];

                private _downhillMovementContext = _slopeHandlingEnabled &&
                    {_momentumContextOk} && {_movementEligible} && {_gaitStanceOk} && {_onGroundNow};
                private _downhillTravel = _rawSlopeDegrees < -_downhillBoostStartDegrees &&
                    {_slopeDegrees < -_downhillBoostStartDegrees};
                private _downhillJog = _downhillMovementContext && {_downhillTravel} && {_slopeJogOverride};
                if (!_downhillMovementContext || {!_downhillBoostEnabled} || {!_isForwardHeld} || {_forwardReleasedSinceTick} ||
                    {(_braceMomentumState select 3) >= 0.15}) then {
                    _downhillMomentum = 0;
                } else {
                    // Buildup takes time even on steep descents. Jog earns a smaller share.
                    private _momentumTarget = 0;
                    if (_horizontalSpeedMS > 0.25 && {_downhillTravel}) then {
                        if (_continuingSprint) then {_momentumTarget = 1;};
                        if (_downhillJog) then {_momentumTarget = 0.45;};
                    };
                    private _baseBuildSeconds = missionNamespace getVariable ["GAIT_ss_downhillMomentumBuildSeconds", 4.5];
                    private _buildSeconds = _baseBuildSeconds * ([1, 1.4] select _downhillJog);
                    _downhillMomentum = [_downhillMomentum, _momentumTarget, _dt, _buildSeconds, 1.5]
                        call GAIT_fnc_stepDownhillMomentum;
                };
                missionNamespace setVariable ["GAIT_downhillMomentum", _downhillMomentum];
                private _sustainedBonus = missionNamespace getVariable ["GAIT_ss_downhillSustainedExtraBoost", 0.10];
                private _downhillJogMultiplier = 1;
                if (_downhillBoostEnabled && {_downhillMovementContext} && {_downhillTravel} && {_isSprinting || {_downhillJog}}) then {
                    private _downhillMultiplier = [_slopeDegrees, _gearLbs, _downhillMomentum,
                        _downhillBoostStartDegrees, _downhillBoostMaxDegrees, _downhillMaxBoost,
                        _sustainedBonus, _weightSpeedMult, _unloadedSpeedMult] call GAIT_fnc_downhillPaceMultiplier;
                    if (_isSprinting) then {
                        // Keep a shared flat sprint target and the existing
                        // load-dependent descent gain under the sprint ceiling.
                        _slopeSpeedMultiplier = _downhillMultiplier min 1.15;
                    } else {
                        _downhillJogMultiplier = 1 + (0.35 * (_downhillMultiplier - 1));
                    };
                };
                missionNamespace setVariable ["GAIT_slopeSpeedMultiplier", _slopeSpeedMultiplier];

                // A deliberate uphill release is a braking event, separate
                // from launch-brace eligibility and retained-momentum vetoes.
                private _uphillBrakeEnabled = _slopeHandlingEnabled && {!_nativeWalk} && {_slopeStopBraceEnabled} &&
                    {missionNamespace getVariable ["GAIT_ss_uphillReleaseBraceEnabled", false]};
                private _uphillBrakeContext = _momentumContextOk && {_movementEligible} && {_gaitStanceOk} && {_isForwardHeld} && {!_forwardReleasedSinceTick} && {isTouchingGround player};
                if ((missionNamespace getVariable ["GAIT_uphillBrakeUnit", objNull]) isNotEqualTo player) then {_uphillBrakeState = [];};
                private _uphillBrake = [_uphillBrakeState, _turboHeld && {_isForwardHeld},
                    _isSprinting && {_sprintBraceEndTime <= time}, _isForwardHeld,
                    _uphillBrakeContext, _horizontalSpeedMS, _slopeDegrees, _currentSpeed,
                    _effectiveNormalSpeed * _hillWalkSlowdownMultiplier, time, _uphillBrakeEnabled && {_sprintBraceEndTime <= time},
                    [_slopeStopBraceStartDegrees, _slopeStopBraceMaxDegrees, _sprintStartBraceDuration,
                     _slopeStopBraceExtraDuration, _slopeStopBraceExtraDip, _speedLerp, _sprintStartBraceLerp]]
                    call GAIT_fnc_stepUphillBrake;
                _uphillBrakeState = _uphillBrake select 0;
                private _uphillBrakeActive = _uphillBrake select 1;
                private _uphillBrakeStarted = _uphillBrake select 2;
                private _uphillBrakeSeverity = _uphillBrake select 3;
                private _uphillBrakeTarget = _uphillBrake select 4;
                private _uphillBrakeRamp = _uphillBrake select 5;
                private _uphillBrakeResumed = _uphillBrake select 8;
                if (_uphillBrakeStarted) then {
                    _downhillMomentum = _downhillMomentum * (1 - _uphillBrakeSeverity);
                    missionNamespace setVariable ["GAIT_downhillMomentum", _downhillMomentum];
                };

                // Brace readiness:
                // Standing still or slow deliberate movement for long enough arms the next brace.
                // Active crouch also arms the brace, but this checks real stance only, not the crouch key.
                // Quick Shift releases/re-taps keep momentum and do not re-trigger the brace.
                private _isBraceReadyState =
                    !_sprintIntent &&
                    {!_isAceDragging} &&
                    {_isOnFoot} &&
                    {((abs (speed player)) < _braceReadySpeedThreshold) || {_isCrouched} || {_forwardReleasedLongEnough}};

                if (_isBraceReadyState) then {
                    if (_walkingStartTime < 0) then {
                        _walkingStartTime = time;
                    };

                    // Only arm crouch brace from actual current stance, not from input.
                    _braceArmedFromCrouch = _isCrouched;
                } else {
                    if (!_sprintIntent) then {
                        _walkingStartTime = -1;
                        _braceArmedFromCrouch = false;
                    };
                };

                if (_isSprinting && {!_wasSprinting}) then {
                    _wasSprinting = true;
                    player setVariable ["GAIT_sprintReleaseHandled", false];

                    _preSprintAnimation = _lastNonSprintAnimation;
                    if (_preSprintAnimation isEqualTo "") then {
                        _preSprintAnimation = animationState player;
                    };
                    _preSprintWasJog = [_preSprintAnimation] call GAIT_fnc_animLooksLikeJog;
                    _preSprintWasRaisedCombat = [_preSprintAnimation] call GAIT_fnc_animLooksLikeRaisedCombat;
                    missionNamespace setVariable ["GAIT_preSprintAnimation", _preSprintAnimation];
                    missionNamespace setVariable ["GAIT_preSprintWasJog", _preSprintWasJog];
                    missionNamespace setVariable ["GAIT_preSprintWasRaisedCombat", _preSprintWasRaisedCombat];

                    private _reserveRatioForBrace = if (_sprintReserveMax > 0) then {
                        _sprintReserve / _sprintReserveMax
                    } else {
                        1
                    };

                    // Brace and momentum are movement-transition mechanics, not
                    // ACE metabolic reserve mechanics. With ACE Advanced Fatigue
                    // enabled, ACE can keep reserve below 0.98 for a long time,
                    // which prevented standing brace starts while crouch still
                    // worked because crouch bypassed the reserve gate. When ACE
                    // is active, keep the old MAV standing/crouch brace behavior
                    // by gating brace on movement state only. When ACE is not
                    // active, preserve the original GAIT reserve gate.
                    private _braceReserveGatePass = true;
                    if (!_aceAdvancedFatigueActive) then {
                        _braceReserveGatePass = _reserveRatioForBrace >= _braceMinReserveRatio;
                    };

                    private _normalBraceReady =
                        (_walkingStartTime >= 0) &&
                        ((time - _walkingStartTime) >= _braceRequiredWalkTime) &&
                        ((time - _lastSprintEndTime) >= _braceRecentSprintCooldown) &&
                        _braceReserveGatePass;

                    // Momentum override:
                    // if the player has no built-up sprint momentum, force the brace.
                    // This catches walk-forward -> Shift starts even when the walk timer/cooldown
                    // misses the transition, while still preserving momentum after quick Shift taps.
                    private _hasNoSprintMomentum = !_hasRetainedSprintMomentum && {
                        (_currentSpeed <= (_effectiveNormalSpeed + _braceNoMomentumThreshold)) ||
                        {_horizontalSpeedMS <= 0.25} || {_forwardReleasedLongEnough}
                    };

                    private _zeroMomentumBraceReady =
                        _hasNoSprintMomentum &&
                        _braceReserveGatePass;

                    private _slopeBraceStart = (_slopeStopBraceStartDegrees max 0) min 60;
                    private _slopeBraceMax = (_slopeStopBraceMaxDegrees max (_slopeBraceStart + 0.1)) min 80;
                    private _recentSlopeStop = (time - _lastSprintStopTime) <= ((_slopeStopBraceMemoryTime max 0) min 10);
                    private _slopeForBraceAbs = abs _slopeDegrees;
                    if (_recentSlopeStop) then {
                        _slopeForBraceAbs = _slopeForBraceAbs max (abs _lastSprintStopSlopeDegrees);
                    };
                    private _slopeBraceFactor = if (_slopeStopBraceEnabled && {_slopeForBraceAbs >= _slopeBraceStart}) then {
                        linearConversion [_slopeBraceStart, _slopeBraceMax, _slopeForBraceAbs, 0, 1, true]
                    } else {
                        0
                    };
                    private _slopeBraceReady = _slopeStopBraceEnabled && {_slopeBraceFactor > 0} && {_recentSlopeStop || {_normalBraceReady} || {_zeroMomentumBraceReady}};

                    private _momentumProtectedForBrace = _hasRetainedSprintMomentum || {_uphillBrakeResumed};
                    private _canBrace = [_sprintStartBraceEnabled, _momentumProtectedForBrace,
                        _isCrouched, _braceArmedFromCrouch, _normalBraceReady, _zeroMomentumBraceReady, _slopeBraceReady]
                        call GAIT_fnc_shouldBrace;

                    // Positive-grade, zero-momentum starts exponentially deepen
                    // and lengthen the existing brace. The existing slope-brace
                    // settings remain the tuning knobs; this simply reshapes their
                    // uphill launch contribution. Retained momentum bypasses it.
                    private _uphillLaunchBraceFactor = 0;
                    if (_canBrace && {_slopeStopBraceEnabled}) then {
                        _uphillLaunchBraceFactor = [_slopeDegrees, _momentumProtectedForBrace,
                            _slopeStopBraceMaxDegrees] call GAIT_fnc_uphillLaunchBraceFactor;
                    };
                    private _linearDurationExtra = ((_slopeStopBraceExtraDuration max 0) min 2.0) * _slopeBraceFactor;
                    private _linearDipExtra = ((_slopeStopBraceExtraDip max 0) min 0.90) * _slopeBraceFactor;
                    private _uphillDurationExtra = ((_slopeStopBraceExtraDuration max 0) min 2.0) *
                        3.0 * _uphillLaunchBraceFactor;
                    private _uphillDipExtra = ((_slopeStopBraceExtraDip max 0) min 0.90) *
                        2.1 * _uphillLaunchBraceFactor;
                    private _braceDurationNow = [_sprintStartBraceDuration, _linearDurationExtra, _uphillDurationExtra]
                        call GAIT_fnc_sprintLaunchBraceDuration;
                    private _braceDipNow = (_linearDipExtra max _uphillDipExtra) min 0.90;
                    _activeBraceSpeed = (_effectiveBraceSpeed * (1 - _braceDipNow)) max 0.08;

                    _sprintBraceEndTime = if (_canBrace) then {
                        time + _braceDurationNow
                    } else {
                        -1
                    };

                    missionNamespace setVariable ["GAIT_slopeBraceFactor", _slopeBraceFactor];
                    missionNamespace setVariable ["GAIT_uphillLaunchBraceFactor", _uphillLaunchBraceFactor];
                    missionNamespace setVariable ["GAIT_activeBraceSpeed", _activeBraceSpeed];
                    missionNamespace setVariable ["GAIT_activeBraceDuration", _braceDurationNow];

                    _walkingStartTime = -1;
                    _braceArmedFromCrouch = false;
                };

                if (!_isSprinting && {!_sprintIntent || {_wasSprinting && {!([player] call GAIT_fnc_fatigueMovementContextEligible)}}}) then {
                    if (_wasSprinting || {_renderReleasedSinceTick}) then {
                        _lastSprintEndTime = time;
                        player setVariable ["GAIT_sprintReleaseHandled", true];

                        // The shared finite controller already sampled actual
                        // velocity and applied pace before either scheduler wrote.
                        _lastSprintStopSlopeDegrees = _slopeDegrees;
                        _lastSprintStopTime = time;

                        // v1.1.60: never arm a post-run animation correction. Speed taper stays,
                        // but stance/weapon posture is left to the engine and player input.

                        missionNamespace setVariable ["GAIT_lastSprintStopSlopeDegrees", _lastSprintStopSlopeDegrees];
                        missionNamespace setVariable ["GAIT_postRunJogTransitionArmed", false];
                    };

                    _wasSprinting = false;
                    _sprintBraceEndTime = -1;
                };

                // =====================================================
                // SPRINT RESERVE / ACE ADVANCED FATIGUE BRIDGE
                // =====================================================
                private _reserveRatio = 1;
                private _sprintPaceReserve = 1;

                // Reserve drain is bounded by grade and load. A small delay
                // in animation eligibility cannot create recovery mid-stride.
                private _reserveActivity = [_movementInput, _horizontalSpeedMS, animationState player,
                    _isSprinting, _onGroundNow && {[player] call GAIT_fnc_fatigueMovementContextEligible}]
                    call GAIT_fnc_sprintReserveActivity;
                private _uphillFatigueDrainSeverityNow = 0;
                private _uphillFatigueDrainMultiplierNow = 1;
                if (_uphillFatigueDrainEnabled && {_isSprinting} && {_lastKnownSlopeDegrees > ((_uphillFatigueDrainStartDegrees max 0) min 60)}) then {
                    private _drainStart = (_uphillFatigueDrainStartDegrees max 0) min 60;
                    private _drainMax = (_uphillFatigueDrainMaxDegrees max (_drainStart + 0.1)) min 80;
                    _uphillFatigueDrainSeverityNow = linearConversion [_drainStart, _drainMax, _lastKnownSlopeDegrees, 0, 1, true];
                    _uphillFatigueDrainMultiplierNow = 1 + (((_uphillFatigueDrainMaxMultiplier max 1.0) min 4.0) - 1) * _uphillFatigueDrainSeverityNow;
                };
                missionNamespace setVariable ["GAIT_uphillFatigueDrainSeverity", _uphillFatigueDrainSeverityNow];
                missionNamespace setVariable ["GAIT_uphillFatigueDrainMultiplier", _uphillFatigueDrainMultiplierNow];

                private _aceReserve = -1;
                if (_aceAdvancedFatigueActive && {missionNamespace getVariable ["GAIT_ss_useAceReserveModel", true]} &&
                    {uiNamespace getVariable ["GAIT_aceSprintReserveHookInstalled", false]}) then {
                    _aceReserve = missionNamespace getVariable ["ace_advanced_fatigue_anReservePercentage", -1];
                };
                private _reserveBeforeStep = _sprintReserve / _sprintReserveMax;
                if (_aceReserve >= 0) then {
                    private _aerobic = (missionNamespace getVariable ["ace_advanced_fatigue_aeReservePercentage", 1]) max 0 min 1;
                    private _acidosis = (missionNamespace getVariable ["ace_advanced_fatigue_anFatigue", 0]) max 0 min 1;
                    private _muscleDamage = (missionNamespace getVariable ["ace_advanced_fatigue_muscleDamage", 0]) max 0 min 1;
                    private _acidosisPenalty = 1 - (_aceAcidosisPenaltyFactor * _acidosis);
                    private _musclePenalty = 1 - (_aceMuscleDamagePenaltyFactor * _muscleDamage);
                    // ACE draws the bar from anaerobic reserve. Aerobic fatigue
                    // and its penalties can shape the last bar, never start it early.
                    _reserveRatio = _aceReserve max 0 min 1;
                    _reserveBeforeStep = _reserveRatio;
                    private _perceivedReserve = (_reserveRatio min _aerobic) * _acidosisPenalty * _musclePenalty;
                    private _lastBarProgress = (1 - (_reserveRatio / 0.20)) max 0;
                    _sprintPaceReserve = _reserveRatio + ((_perceivedReserve - _reserveRatio) * _lastBarProgress);
                    _sprintReserve = _sprintReserveMax * _reserveRatio;
                } else {
                    private _drainRate = [_gearLbs, _uphillFatigueDrainMultiplierNow] call GAIT_fnc_sprintReserveDrainRate;
                    _sprintReserve = [_sprintReserve, _reserveActivity, _dt max 0 min 0.25, _sprintReserveMax, _sprintRecoverTime, _drainRate]
                        call GAIT_fnc_stepFallbackSprintReserve;
                    _reserveRatio = _sprintReserve / _sprintReserveMax;
                    _sprintPaceReserve = _reserveRatio;
                };

                _reserveRatio = (_reserveRatio max 0) min 1;
                private _exhaustion = 1 - _reserveRatio;
                _exhaustion = (_exhaustion max 0) min 1;
                missionNamespace setVariable ["GAIT_exhaustionLevel", _exhaustion];

                private _deadSprintIntent = _sprintIntent && {_gaitStanceOk} && {_isOnFoot} &&
                    {!_isAceCarrying} && {!_isAceDragging} && {_horizontalSpeedMS > 0.15};
                if (_renderReleasedSinceTick || {_forwardReleasedSinceTick}) then {_deadSprintElapsed = -1;};
                if (_reserveActivity isEqualTo "rest" && {_reserveRatio >= 0.999}) then {_deadSprintReady = true;};
                private _deadSprintStartReserve = [0, _reserveBeforeStep] select (_deadSprintReady || {_deadSprintIntentHeld});
                _deadSprintElapsed = [_deadSprintElapsed, _deadSprintIntent, _deadSprintIntentHeld, _deadSprintStartReserve, _dt]
                    call GAIT_fnc_stepDeadSprint;
                if (_deadSprintElapsed isEqualTo 0) then {_deadSprintReady = false;};
                _deadSprintIntentHeld = _deadSprintIntent;
                private _flatBurstSetting = missionNamespace getVariable ["GAIT_ss_flatSprintPeak", 1.10];
                private _flatBurstTerrain = 1 - linearConversion [0.20, 1.0, abs _slopeDegrees, 0, 1, true];
                private _deadSprintStrength = 0;
                if (_flatBurstSetting > 1 && {_onGroundNow} && {!_downhillTravel}) then {
                    _deadSprintStrength = ([_deadSprintElapsed, _reserveRatio] call GAIT_fnc_deadSprintStrength) * _flatBurstTerrain;
                };

                // =====================================================
                // SPEED CONTROL
                // =====================================================
                private _flatSprintPace = _sprintFullSpeed;
                if ((currentWeapon player) isEqualTo "") then {
                    _flatSprintPace = _flatSprintPace * _unarmedSprintNormalizer;
                };
                private _walkPace = _effectiveNormalSpeed * _hillWalkSlowdownMultiplier;
                private _nativeWalkPace = if (player isEqualTo (missionNamespace getVariable ["GAIT_nativeOwner", objNull])) then {
                    missionNamespace getVariable ["GAIT_nativePreviousCoef", 1]
                } else {getAnimSpeedCoef player};
                private _freshSprintPace = _flatSprintPace * _slopeSpeedMultiplier;
                private _pacePair = [_walkPace, _freshSprintPace];
                private _targetSpeed = _walkPace;
                private _ordinaryReleaseTarget = _walkPace;
                private _jogFlatCoefficient = _normalSpeed * 1.06;
                private _profiles = missionNamespace getVariable ["GAIT_locomotionPaceProfiles", []];
                private _slopeJogTargetMS = -1;
                private _slopeJogCalibrated = false;

                if (_ordinarySlopeJog && {_movementEligible}) then {
                    private _familyJog = [player] call GAIT_fnc_slopeWeaponFamily;
                    private _directionJog = [_movementInput select 0, _movementInput select 1] call GAIT_fnc_slopeDirection;
                    private _jogResolved = [_normalSpeed, _jogFlatCoefficient,
                        _hillWalkSlowdownMultiplier, _hillWalkSlowdownMultiplier * _downhillJogMultiplier,
                        _weightSpeedMult, 1.06, _profiles, _familyJog, _directionJog, "jog"]
                        call GAIT_fnc_locomotionPaceTargets;
                    _ordinaryReleaseTarget = _jogResolved select 1;
                    if (_slopeJogOverride) then {
                        _pacePair = _jogResolved select [0, 2];
                        _targetSpeed = _ordinaryReleaseTarget;
                        _slopeJogTargetMS = _jogResolved select 3;
                        _slopeJogCalibrated = _jogResolved select 4;
                    };
                    if (_downhillJog) then {
                        private _jogReference = -1;
                        if (_slopeJogCalibrated) then {
                            _jogReference = _slopeJogTargetMS / _targetSpeed;
                        } else {
                            private _jogClip = [_familyJog, _directionJog, false] call GAIT_fnc_slopeStateName;
                            _jogReference = [player, _jogClip, _slopeDegrees] call GAIT_fnc_lookupUnitPaceReference;
                        };
                        _targetSpeed = [_targetSpeed, _jogReference,
                            missionNamespace getVariable ["GAIT_ss_downhillJogCapKmh", 18]]
                            call GAIT_fnc_capDownhillPace;
                        if (_jogReference > 0) then {_slopeJogTargetMS = _targetSpeed * _jogReference;};
                        _pacePair set [1, _targetSpeed];
                        _ordinaryReleaseTarget = _targetSpeed;
                    };
                };
                missionNamespace setVariable ["GAIT_slopeJogTargetMS", _slopeJogTargetMS];
                missionNamespace setVariable ["GAIT_slopeJogCalibrated", _slopeJogCalibrated];

                if (_isAceCarrying && {!isNull _carriedObject}) then {
                    // Carry animations remain owned by ACE; no slope-state remap.
                    _targetSpeed = (if (_isSprinting) then {
                        (_carrySprintExhaustedSpeed + ((_carrySprintFullSpeed - _carrySprintExhaustedSpeed) * _reserveRatio)) * _slopeSpeedMultiplier
                    } else {_carryWalkSpeed * _hillWalkSlowdownMultiplier}) * _weightSpeedMult;
                };

                private _walkReference = -1;
                private _sprintReference = -1;
                if (_isSprinting && {!_isAceCarrying}) then {
                    private _jogReference = -1;
                    private _uphillTravel = _slopeHandlingEnabled && {_slopeDegrees > 0.01};
                    if (_gaitStanceOk && {_slopeHandlingEnabled} && {missionNamespace getVariable ["GAIT_ss_slopeLocomotionEnabled", true]}) then {
                        private _family = [player] call GAIT_fnc_slopeWeaponFamily;
                        private _direction = [_movementInput select 0, _movementInput select 1] call GAIT_fnc_slopeDirection;
                        private _references = [_profiles, _family, _direction, "sprint"] call GAIT_fnc_locomotionPaceReferences;
                        if (_references isEqualTo []) then {
                            private _sprintClip = [_family, _direction, true] call GAIT_fnc_slopeStateName;
                            _sprintReference = [player, _sprintClip, _slopeDegrees] call GAIT_fnc_lookupUnitPaceReference;
                            if (_sprintReference > 0.1) then {
                                private _walkClip = "AmovPercMwlk" + _family + _direction;
                                _walkReference = [player, _walkClip, _slopeDegrees] call GAIT_fnc_lookupUnitPaceReference;
                            };
                        } else {
                            _references params ["_manualWalk", "_manualSprint"];
                            _walkReference = _manualWalk;
                            _sprintReference = _manualSprint;
                        };
                        if (_uphillTravel) then {
                            private _jogReferences = [_profiles, _family, _direction, "jog"] call GAIT_fnc_locomotionPaceReferences;
                            if (_jogReferences isNotEqualTo []) then {
                                _jogReference = _jogReferences select 1;
                            } else {
                                if (_sprintReference > 0.1) then {
                                    private _jogClip = [_family, _direction, false] call GAIT_fnc_slopeStateName;
                                    _jogReference = [player, _jogClip, _slopeDegrees] call GAIT_fnc_lookupUnitPaceReference;
                                };
                            };
                        };
                    };
                    private _uphillMinimum = 0;
                    if (_uphillTravel) then {
                        private _jogPace = _jogFlatCoefficient * _weightSpeedMult * _hillWalkSlowdownMultiplier;
                        _uphillMinimum = [_nativeWalkPace, _jogPace, _walkReference, _jogReference, _sprintReference]
                            call GAIT_fnc_uphillSprintFloor;
                        private _lightWalkSlope = 1;
                        if (_hillWalkSlowdownEnabled) then {
                            private _walkStart = _hillWalkSlowdownStartDegrees max 0 min 60;
                            private _walkMax = (_hillWalkSlowdownMaxDegrees max (_walkStart + 0.1)) min 80;
                            private _lightWalkPenalty = (_hillWalkUphillMaxPenalty max 0 min 0.75) * 0.75;
                            _lightWalkSlope = [_slopeDegrees, _walkStart, _walkMax, _lightWalkPenalty]
                                call GAIT_fnc_uphillPaceMultiplier;
                        };
                        private _lightWalk = _normalSpeed * _unloadedSpeedMult * _lightWalkSlope;
                        private _lightJog = _lightWalk * 1.06;
                        _freshSprintPace = _freshSprintPace max ([_nativeWalkPace, _lightJog, _walkReference,
                            _jogReference, _sprintReference] call GAIT_fnc_uphillSprintFloor);
                    };
                    // Exhaustion uses unboosted pace, with the final fraction
                    // set by load. The uphill minimum still protects gait order.
                    private _normalRun = _flatSprintPace * ([_slopeSpeedMultiplier, 1] select _downhillTravel);
                    _targetSpeed = [_freshSprintPace, _normalRun, _sprintPaceReserve, _gearLbs, _uphillMinimum,
                        missionNamespace getVariable ["GAIT_ss_exhaustedRunPace", 0.70], _deadSprintStrength > 0,
                        _flatBurstSetting, _deadSprintStrength]
                        call GAIT_fnc_sprintReservePace;
                    if (_downhillMovementContext && {_downhillTravel}) then {
                        _targetSpeed = [_targetSpeed, _sprintReference,
                            missionNamespace getVariable ["GAIT_ss_downhillSprintCapKmh", 30]]
                            call GAIT_fnc_capDownhillPace;
                    };
                    _pacePair set [1, _targetSpeed];
                };
                missionNamespace setVariable ["GAIT_walkTargetMS", [-1, _nativeWalkPace * _walkReference] select (_walkReference > 0)];
                missionNamespace setVariable ["GAIT_sprintTargetMS", [-1, _targetSpeed * _sprintReference] select (_sprintReference > 0)];
                missionNamespace setVariable ["GAIT_paceCalibrated", _walkReference > 0 && {_sprintReference > 0}];
                missionNamespace setVariable ["GAIT_sprintReferenceCalibrated", _sprintReference > 0];
                missionNamespace setVariable ["GAIT_walkPaceTarget", _pacePair select 0];
                missionNamespace setVariable ["GAIT_sprintPaceTarget", _pacePair select 1];
                missionNamespace setVariable ["GAIT_loadPaceMultiplier", _weightSpeedMult];

                // Publish a fresh ordinary target for the next raw release.
                // Inventory/grade changes cannot restart an existing finite plan.
                private _releaseWindow = [0, _shiftReleaseRunTaperDuration, _coastScale] call GAIT_fnc_gearCoastWindow;
                private _releasePermission = _momentumContextOk && {!_nativeWalk} && {_movementEligible} && {_gaitStanceOk} &&
                    {_slopeHandlingEnabled} && {missionNamespace getVariable ["GAIT_ss_slopeLocomotionEnabled", true]};
                missionNamespace setVariable ["GAIT_releaseMomentumRequest", [player, _ordinaryReleaseTarget,
                    _releaseWindow select 1, _shiftReleaseRunTaperCurve, _releasePermission,
                    diag_tickTime + ((4 * _tickRate) max 0.15 min 0.50)]];
                // Brake priority is published before the common writer, so a
                // render-started plan cannot override this tick's uphill brake.
                missionNamespace setVariable ["GAIT_uphillBrakeUnit", player];
                missionNamespace setVariable ["GAIT_uphillBrakeActive", _uphillBrakeActive];
                missionNamespace setVariable ["GAIT_uphillBrakeEndTime", if (_uphillBrakeActive) then {_uphillBrakeState select 3} else {-1}];
                if (!_nativeWalk) then {[player, _movementInput] call GAIT_fnc_observeReleaseMomentum;};

                private _walkStartBraceFactor = 1;
                private _walkStartBraceActive = false;
                private _walkStartBraceTier = -1;
                if (_walkStartBraceState isNotEqualTo []) then {
                    private _walkBraceSample = [_walkStartBraceState, diag_tickTime] call GAIT_fnc_walkStartBraceSample;
                    _walkStartBraceFactor = _walkBraceSample select 0;
                    _walkStartBraceActive = _walkBraceSample select 1;
                    _walkStartBraceTier = _walkBraceSample select 2;
                    if (!_walkStartBraceActive) then {_walkStartBraceState = [];};
                };
                missionNamespace setVariable ["GAIT_walkStartBraceActive", _walkStartBraceActive];
                missionNamespace setVariable ["GAIT_walkStartBraceFactor", _walkStartBraceFactor];
                missionNamespace setVariable ["GAIT_walkStartBraceTier", _walkStartBraceTier];

                // Frame-rate independent speed ramp. Direction is never filtered.
                private _hasMovementInput = _isForwardHeld || {_isBackHeld} || {_isLateralHeld};
                switch (true) do {
                    case _nativeWalk: {
                        _currentSpeed = [player, _currentSpeed, false, true] call GAIT_fnc_applyNativeMovement;
                    };
                    case (_gaitMovementEnabled && {_movementEligible} && {_gaitStanceOk} && {_hasMovementInput}): {
                        private _ramp = if (_uphillBrakeActive) then {_uphillBrakeRamp} else {
                            if (_isSprinting && {_sprintBraceEndTime > time}) then {_sprintStartBraceLerp} else {
                                [_speedLerp, 1] select _walkStartBraceActive
                            }
                        };
                        private _rampTarget = if (_uphillBrakeActive) then {_uphillBrakeTarget min _currentSpeed} else {
                            if (_isSprinting && {_sprintBraceEndTime > time}) then {_activeBraceSpeed min _targetSpeed} else {
                                if (_walkStartBraceActive) then {_targetSpeed * _walkStartBraceFactor} else {_targetSpeed}
                            }
                        };
                        if (!_isAceCarrying && {_isSprinting} && {!_uphillBrakeActive} && {_sprintBraceEndTime <= time}) then {
                            private _speedIncreasing = _rampTarget > _currentSpeed;
                            if (_speedIncreasing) then {
                                _ramp = [_ramp, _accelerationScale] call GAIT_fnc_sprintAccelerationRamp;
                                _ramp = [_ramp, 1 + (2 * _deadSprintStrength)] call GAIT_fnc_scaleInertiaRamp;
                            };
                            if (_slopeHandlingEnabled && {_onGroundNow}) then {
                                _ramp = [_ramp, _slopeDegrees, _speedIncreasing, _uphillStartDegrees, _uphillSlowdownEnabled]
                                    call GAIT_fnc_slopeSprintRamp;
                            };
                            if (!_speedIncreasing && {_reserveRatio < 0.20}) then {
                                _ramp = _ramp min 0.045;
                            };
                        };
                        _currentSpeed = [_currentSpeed, _rampTarget, _ramp, _dt] call GAIT_fnc_stepSpeedCoefficient;
                        // Honor walk/injury locks and avoid carrying a sprint boost sideways.
                        private _coef = _currentSpeed;
                        if (!_isForwardHeld || {_externalSprintLock} || {_externalWalkLock}) then {
                            _coef = _coef min _effectiveNormalSpeed;
                        };
                        _currentSpeed = [player, _coef, _isAceCarrying] call GAIT_fnc_applyNativeMovement;

                    };
                    default {
                        if (_stanceYieldActive) then {
                            // Running-to-crouch/prone is still a live movement
                            // transition. Preserve the exact scalar that was already
                            // on the unit and let Arma's inherited stance graph bend
                            // the body without a mid-transition speed reset.
                            private _stanceCarry = player getVariable ["GAIT_stanceCarryCoefficient", []];
                            if ((count _stanceCarry) isEqualTo 2 && {_stanceCarry select 1}) then {
                                _currentSpeed = missionNamespace getVariable ["GAIT_nativeLastPreVegetation", _currentSpeed];
                            };
                        } else {
                            private _keepMovingBlend = _hasMovementInput && {!_locomotionExternalLock} &&
                                {([player, animationState player] call GAIT_fnc_locomotionMayFinishMoveBlend) ||
                                {[player, _movementInput, _locomotionExternalLock] call GAIT_fnc_uphillSprintContactPending}};
                            if (!_keepMovingBlend) then {
                                // No commanded forward movement means no scalar momentum.
                                // The engine handles the stop blend and current side/back input.
                                _currentSpeed = _inputReleasePace;
                                // Speed ownership must not slow the native stop blend.
                                // Render input chooses the body exit independently.
                                if (_gaitMovementEnabled && {!_hasMovementInput} && {_gaitStanceOk} && {_movementEligible} &&
                                    {player isEqualTo (missionNamespace getVariable ["GAIT_nativeOwner", objNull])} &&
                                    {abs ((getAnimSpeedCoef player) - (missionNamespace getVariable ["GAIT_nativeLastWritten", -1])) < 0.001}) then {
                                    // A scheduled tick can relinquish the coefficient
                                    // before Draw3D sees this same stop edge. Hand over
                                    // only this owned release, with a short-lived lease.
                                    player setVariable ["GAIT_nativeStopPaceLease", [diag_tickTime + 0.15, currentWeapon player,
                                        missionNamespace getVariable ["GAIT_nativePreviousCoef", 1]]];
                                };
                                [] call GAIT_fnc_releaseSpeedCoefficient;
                            };
                        };
                    };
                };
                // Read-only acceptance telemetry; these values never feed back
                // into the preserved brace, reserve or momentum calculation.
                missionNamespace setVariable ["GAIT_plannedMovementCoefficient", _currentSpeed];
                missionNamespace setVariable ["GAIT_observedReserveRatio", _reserveRatio];
                // Movement-family ownership is independent of forward sprint
                // effort. Pure A/D keeps native directional selection in the
                // same graph without changing reserve/brace or sideways caps.
                // Publish permission, not a scheduled snapshot of Turbo.
                private _fastMoveIntent = _gaitMovementEnabled && {_gaitStanceOk} && {!_isAceCarrying};
                private _brakePrearm = _uphillBrakeEnabled && {_uphillBrakeContext} && {_isSprinting} &&
                    {_sprintBraceEndTime <= time} && {_horizontalSpeedMS > 0.25} && {_slopeDegrees > _slopeStopBraceStartDegrees};
                // Publish the render-controller request and its brake stage
                // atomically. The bounded prearm covers an earlier raw release.
                isNil {
                    missionNamespace setVariable ["GAIT_coastUnit", player];
                    missionNamespace setVariable ["GAIT_coastActive", player getVariable ["GAIT_releaseMomentumActive", false]];
                    missionNamespace setVariable ["GAIT_coastReadyUntil", -1];
                    missionNamespace setVariable ["GAIT_uphillBrakeUnit", player];
                    missionNamespace setVariable ["GAIT_uphillBrakeActive", _uphillBrakeActive];
                    missionNamespace setVariable ["GAIT_uphillBrakeEndTime", if (_uphillBrakeActive) then {_uphillBrakeState select 3} else {-1}];
                    missionNamespace setVariable ["GAIT_uphillBrakeReadyUntil", if (_brakePrearm) then {diag_tickTime + ((3 * _tickRate) max 0.15 min 0.50)} else {-1}];
                    missionNamespace setVariable ["GAIT_uphillBrakeSeverity", _uphillBrakeSeverity];
                    missionNamespace setVariable ["GAIT_uphillBrakeTarget", _uphillBrakeTarget];
                    missionNamespace setVariable ["GAIT_braceActive", _uphillBrakeActive || {_isSprinting && {_sprintBraceEndTime > time}}];
                    missionNamespace setVariable ["GAIT_braceEndTime", if (_uphillBrakeActive) then {_uphillBrakeState select 3} else {_sprintBraceEndTime}];
                    [player, _fastMoveIntent, _movementInput, _locomotionExternalLock] call GAIT_fnc_updateSlopeLocomotion;
                };
                if (_debugHudEnabled && {(time - _lastDebugHudTime) >= ((_debugHudInterval max 0.05) min 1)}) then {
                    _lastDebugHudTime = time;
                    private _debugFamily = [player] call GAIT_fnc_slopeWeaponFamily;
                    hintSilent parseText format [
                        "<t align='left' size='0.82'>GAIT 1.8.0-alpha24<br/>Travel grade: %1 degrees | Speed: %2 km/h<br/>Input F/R: %3 / %4<br/>Coefficient: %5 | ACE reserve: %6%%<br/>Animation: %7<br/>ACE bridge: %8 | Block sprint / walk: %9 / %10<br/>Family: %11 | Active: %12 | Jog / sprint target: %13 / %14<br/>Foundation: %15 | Sprint ref: %16 | Full profile: %17<br/>Carried load: %18 lb</t>",
                        _slopeDegrees toFixed 1, _actualSpeedKmh toFixed 1,
                        (_movementInput select 0) toFixed 2, (_movementInput select 1) toFixed 2,
                        (getAnimSpeedCoef player) toFixed 2, (_reserveRatio * 100) toFixed 0,
                        animationState player,
                        missionNamespace getVariable ["GAIT_nativeAceBridgeInstalled", false],
                        player getVariable ["ace_common_effect_blockSprint", 0],
                        player getVariable ["ace_common_effect_forceWalk", 0],
                        _debugFamily,
                        missionNamespace getVariable ["GAIT_slopeLocomotionActive", false],
                        (_pacePair select 0) toFixed 2, (_pacePair select 1) toFixed 2,
                        missionNamespace getVariable ["GAIT_locomotionPhase", "native"],
                        missionNamespace getVariable ["GAIT_sprintReferenceCalibrated", false],
                        missionNamespace getVariable ["GAIT_paceCalibrated", false],
                        _gearLbs toFixed 1
                    ];
                };
            } else {
                // Fast Carry pickup/lift owns its animation.
                _deadSprintElapsed = -1;
                _deadSprintIntentHeld = false;
                _uphillPaceExposure = 0;
                missionNamespace setVariable ["GAIT_uphillPaceExposure", 0];
                missionNamespace setVariable ["GAIT_uphillPaceMultiplier", 1];
                _downhillTripSprintStartTime = -1;
                _downhillTripHighSpeedStartTime = -1;
                _uphillBrakeState = [];
                missionNamespace setVariable ["GAIT_uphillBrakeActive", false];
                missionNamespace setVariable ["GAIT_uphillBrakeEndTime", -1];
                missionNamespace setVariable ["GAIT_uphillBrakeReadyUntil", -1];
                missionNamespace setVariable ["GAIT_uphillBrakeUnit", objNull];
            missionNamespace setVariable ["GAIT_coastUnit", objNull];
            missionNamespace setVariable ["GAIT_coastActive", false];
            missionNamespace setVariable ["GAIT_coastReadyUntil", -1];
                _braceMomentumState = [false, -999, 0, 0];
                _downhillMomentum = 0;
                missionNamespace setVariable ["GAIT_braceActive", false];
                missionNamespace setVariable ["GAIT_braceEndTime", -1];
                _currentSpeed = 1;
                [] call GAIT_fnc_releaseNativeMovement;
            };
        } else {
            _downhillTripSprintStartTime = -1;
            _downhillTripHighSpeedStartTime = -1;
            _uphillBrakeState = [];
            missionNamespace setVariable ["GAIT_uphillBrakeActive", false];
            missionNamespace setVariable ["GAIT_uphillBrakeEndTime", -1];
            missionNamespace setVariable ["GAIT_uphillBrakeReadyUntil", -1];
            missionNamespace setVariable ["GAIT_uphillBrakeUnit", objNull];
            missionNamespace setVariable ["GAIT_coastUnit", objNull];
            missionNamespace setVariable ["GAIT_coastActive", false];
            missionNamespace setVariable ["GAIT_coastReadyUntil", -1];
            _braceMomentumState = [false, -999, 0, 0];
            _downhillMomentum = 0;
            missionNamespace setVariable ["GAIT_braceActive", false];
            missionNamespace setVariable ["GAIT_braceEndTime", -1];
            _slopeSmoothInitialized = false;
            _smoothedSlopeDegrees = 0;
            [] call GAIT_fnc_releaseNativeMovement;
            _deadSprintElapsed = -1;
            _deadSprintIntentHeld = false;
            _currentSpeed = _normalSpeed;
            if (alive player && {!(call GAIT_fnc_modeAllowsMovement)}) then {
                [] call GAIT_fnc_releaseNativeMovement;
            };
            _wasSprinting = false;
            _sprintBraceEndTime = -1;
            _walkingStartTime = -1;
            _lastSprintEndTime = -999;
            _braceArmedFromCrouch = false;
            _lastForwardInputTime = time;
            missionNamespace setVariable ["GAIT_exhaustionLevel", 0];
        };


        uiSleep _tickRate;
    };
};
