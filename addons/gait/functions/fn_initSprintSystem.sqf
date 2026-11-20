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


missionNamespace setVariable ["GAIT_versionString", getText (configFile >> "CfgPatches" >> "gait" >> "versionStr")];

GAIT_fnc_log = {
    params [["_message", "", [""]]];
    if (missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false]) then {
        diag_log format ["[GAIT] %1", _message];
    };
};

GAIT_fnc_modeAllowsMovement = {
    missionNamespace getVariable ["GAIT_ss_enabled", true]
};

// Suspension/context eligibility is defined once in fn_traversalHelpers.sqf.

// =====================================================
// ACE ADVANCED FATIGUE INTEGRATION
// ACE runs physiology and feedback. The hook applies GAIT sprint exertion
// before ACE publishes the anaerobic reserve.
// =====================================================
GAIT_fnc_aceAdvancedFatigueActive = {
    (isClass (configFile >> "CfgPatches" >> "ace_advanced_fatigue")) &&
    {missionNamespace getVariable ["ace_advanced_fatigue_enabled", false]}
};

// Arma 2.18+ animation commands. The portable tests substitute these engine calls.
GAIT_fnc_readPaceMoveInfo = {params ["_unit"]; getUnitMovesInfo _unit};
GAIT_fnc_readWalkableSurface = {
    params ["_unit", "_feet"];
    private _cache = _unit getVariable ["GAIT_supportNormal", [-1, []]];
    if ((_cache select 0) isEqualTo diag_frameNo) exitWith {_cache select 1};
    private _normal = [];
    if (isTouchingGround _unit) then {
        private _hits = lineIntersectsSurfaces [_feet vectorAdd [0,0,0.23], _feet vectorDiff [0,0,0.27],
            _unit, attachedTo _unit, true, 1, "ROADWAY", "NONE"];
        if (_hits isNotEqualTo []) then {
            (_hits select 0) params ["_point","_surfaceNormal","_object","_parent"];
            if (!isNull _object || {!isNull _parent}) then {_normal = _surfaceNormal;};
        };
    };
    _unit setVariable ["GAIT_supportNormal", [diag_frameNo, _normal]];
    _normal
};
GAIT_fnc_readCombatPace = {""};
GAIT_fnc_readWeaponSwitching = {false};
if ((productVersion select 2) >= 220) then {
    GAIT_fnc_readWeaponSwitching = compileFinal 'params ["_unit"]; isSwitchingWeapon _unit';
};
if ((productVersion select 2) >= 222) then {
    // Read the local player's selection. Compile only on engines with this command.
    GAIT_fnc_readCombatPace = compileFinal 'params ["_unit"]; _unit combatPace []';
};

// Traversal helpers are definitions only, loaded before any client loops start.
call compile preprocessFileLineNumbers "\gait\functions\fn_traversalHelpers.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_sprintReserve.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_burstSprint.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_slopePaceModel.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_locomotionPace.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_braceMomentum.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_gearInertia.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_downhillPace.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_paceCalibration.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_slopeLocomotion.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_nativeController.sqf";
private _patches = configFile >> "CfgPatches";
private _nswg2AnimationsLoaded = isClass (_patches >> "gait_nswg2_animations");
private _animateWalkLoaded = isClass (_patches >> "gait_animate_walk");
missionNamespace setVariable ["GAIT_nswg2AnimationsLoaded", _nswg2AnimationsLoaded];
missionNamespace setVariable ["GAIT_animateWalkLoaded", _animateWalkLoaded];
if (_nswg2AnimationsLoaded || {_animateWalkLoaded}) then {
    [format ["Animation compatibility active. 10th SFG rifle idle=%1, Animate lowered combat=%2.",
        _nswg2AnimationsLoaded, _animateWalkLoaded]] call GAIT_fnc_log;
};
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
        private _getUpSpeedKmh = 7.0;
        private _maxRagdollTime = 6.0;
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

                    if (call GAIT_fnc_modeAllowsMovement) then {
                        private _aceText = ["ACE AF bridge waiting/disabled", "ACE AF bridge active"] select (call GAIT_fnc_aceAdvancedFatigueActive);
                        systemChat format ["GAIT active | %1", _aceText];
                    };

                    [format ["Initialized v%1. Movement=%2 | ACE_AF=%3",
                        missionNamespace getVariable ["GAIT_versionString", "?"],
                        call GAIT_fnc_modeAllowsMovement, call GAIT_fnc_aceAdvancedFatigueActive]] call GAIT_fnc_log;
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

    private _normalSpeed = 0.90;

    // Sprint reserve settings
    private _sprintReserveMax = 60.0;
    private _sprintRecoverTime = 10.0;
    private _sprintReserve = _sprintReserveMax;
    private _reserveUnit = player;

    // Normal sprint speeds
    private _sprintFullSpeed = 1.00;

    // Carry movement speeds
    private _carryWalkSpeed = 0.80;
    private _carrySprintFullSpeed = 1.50;
    private _carrySprintExhaustedSpeed = 0.9;

    // Unarmed/no-weapon sprint normalizer.
    // This prevents holstering your weapon from making sprint speed much faster.
    private _unarmedSprintNormalizer = 0.725;

    // Read actual carried inventory mass; convert it to the configured gear curve units.
    private _loadAbsPerLb = 10;
    private _lightSpeedBonus = 1.03;
    private _mediumSpeedBonus = 1.00;
    private _moderateSpeedBonus = 0.97;
    private _heavySpeedBonus = 0.92;

    private _lightBraceRelief = 0.55;
    private _mediumBraceRelief = 0.35;
    private _moderateBraceRelief = 0.18;
    private _heavyBraceRelief = 0.00;

    // Smoothing
    private _tickRate = 0.05;
    private _speedLerp = 0.05;              // lower = smoother/slower ramp, higher = snappier

    // Time without forward input before a stopped restart can brace again.
    private _wReleaseZeroMomentumDelay = 0.50;

    // Sprint start realism / heavy-pack momentum step.
    // This creates a short, significant pace dip when sprint starts,
    // then hands back to the normal sprint ramp instead of jumping to full speed.
    private _sprintStartBraceDuration = 0.15;  // short brace step before the normal ramp resumes
    private _sprintStartBraceSpeed = 0.44;     // exaggerated debug slowdown
    private _sprintStartBraceLerp = 0.575;       // Higher = snaps to brace speed faster / more abrupt slowdown
                                               // Lower = eases into brace speed more smoothly / softer slowdown

    // Brace step eligibility.
    // The brace only returns after the player has deliberately settled again.
    private _braceRequiredWalkTime = 2.0;      // time standing/slow-walking before brace can fire again
    private _braceRecentSprintCooldown = 3.0;  // keeps momentum if Shift is tapped/released/re-tapped
    private _braceMinReserveRatio = 0.98;      // no brace while exhausted / partially depleted

    // Momentum check.
    // If current movement speed has decayed back near normal, treat momentum as zero
    // and force the brace on the next sprint start. If speed is still above this,
    // the player keeps momentum and does not brace again.
    private _braceNoMomentumThreshold = 0.04;
    private _braceReadySpeedThreshold = 4.0;
    private _lightWeightMax = 35;
    private _mediumWeightMax = 55;
    private _moderateWeightMax = 75;
    private _aceAcidosisPenaltyFactor = 0.45;
    private _aceMuscleDamagePenaltyFactor = 0.25;

    // Terrain / slope handling.
    private _slopeSampleDistance = 2.0;
    private _slopeAngleRiseRateDegPerSecond = 35.0;
    private _slopeAngleFallRateDegPerSecond = 30.0;
    private _uphillStartDegrees = 2.0;
    private _uphillMaxDegrees = 35.0;
    private _uphillMaxPenalty = 0.40;
    private _slopeStopBraceStartDegrees = 15.0;
    private _slopeStopBraceMaxDegrees = 35.0;
    private _slopeStopBraceExtraDuration = 0.18;
    private _slopeStopBraceExtraDip = 0.28;
    private _slopeStopBraceMemoryTime = 2.5;
    private _downhillBoostStartDegrees = 0.5;
    private _downhillBoostMaxDegrees = 18.0;
    private _downhillMaxBoost = 0.03;
    private _downhillTripThresholdDegrees = 28.0;
    private _downhillTripMaxDegrees = 45.0;
    private _downhillTripBaseChancePerSecond = 0.005;
    private _downhillTripMaxChancePerSecond = 0.10;
    private _downhillTripCooldown = 10.0;
    private _downhillTripDuration = 1.00;
    private _downhillTripMinSpeedKmh = 20.0;
    private _downhillTripSpeedMaxKmh = 34.0;
    private _downhillTripSpeedInfluence = 1.0;
    private _downhillTripWeightInfluence = 1.0;
    private _downhillTripMinSprintSeconds = 5.0;
    private _downhillTripSustainedSpeedKmh = 20.0;
    private _downhillTripSustainedSpeedSeconds = 4.0;
    private _downhillTripPostFallImmunity = 10.0;
    private _downhillTripGetUpSpeedKmh = 7.0;
    private _downhillTripMaxRagdollDuration = 6.0;
    private _activeBraceSpeed = _sprintStartBraceSpeed;
    private _conflictScanDone = false;
    private _hillWalkDownhillMaxPenalty = 0.08;
    private _hillWalkSlowdownMaxDegrees = 40.0;
    private _hillWalkSlowdownStartDegrees = 15.0;
    private _hillWalkUphillMaxPenalty = 0.32;
    private _lastDebugHudTime = -999;
    private _lastKnownSlopeDegrees = 0;
    private _lastSprintStopSlopeDegrees = 0;
    private _lastSprintStopTime = -999;
    private _lastForwardReleaseSerial = -1;
    private _lastForwardPressSerial = player getVariable ["GAIT_forwardPressSerial", 0];
    private _walkStartBraceState = [];
    private _slopeSmoothInitialized = false;
    private _smoothedSlopeDegrees = 0;
    private _uphillPaceExposure = 0;

    private _lastTick = time;
    private _currentSpeed = _normalSpeed;
    private _wasSprinting = false;
    private _deadSprintElapsed = -1;
    private _deadSprintIntentHeld = false;
    private _deadSprintReady = true;
    private _sprintBraceEndTime = -1;
    private _walkingStartTime = -1;
    private _lastSprintEndTime = -999;
    private _braceArmedFromCrouch = false;
    private _lastForwardInputTime = time;
    private _downhillTripSprintStartTime = -1;
    private _downhillTripHighSpeedStartTime = -1;
    private _depletedRunTime = 0;
    private _wroteStanceSpeed = false;
    private _wroteMovingStanceSpeed = false;
    private _lastSprintPressUsed = -1;
    private _lastResetRequestHandled = -1;
    private _braceMomentumState = [false, -999, 0, 0, 0];
    private _burstOverLimitUntil = -1;
    private _downhillMomentum = 0;
    private _loadPaceTime = 0;
    private _lastCarriedPatient = objNull;
    private _carryPaceSprint = false;
    private _carryRelease = [];

    private _rifleTracking = false;
    private _rifleYielded = false;
    private _reserveHandoff = false;
    private _shuffle = "";
    private _normalBraceUntil = -1;
    while {true} do {
        private _rifleBurst = false;
        private _keepNormalBrace = false;
        private _allowRifleCatch = false;
        private _keepShuffle = false;
        private _now = time;
        call GAIT_fnc_watchBurstKeys;
        private _dt = _now - _lastTick;
        _lastTick = _now;

        if (_reserveUnit isNotEqualTo player) then {
            if (_normalBraceUntil >= 0 && {!isNull _reserveUnit} && {local _reserveUnit} &&
                {toLower gestureState _reserveUnit == "gait_normalbrace"}) then {
                _reserveUnit playActionNow "GAIT_EndSprintGesture";
            };
            _normalBraceUntil = -1;
            if (_shuffle != "" && {!isNull _reserveUnit} && {local _reserveUnit} && {toLower gestureState _reserveUnit == _shuffle}) then {
                _reserveUnit playActionNow "GAIT_EndSprintGesture";
            };
            _shuffle = "";
            _reserveHandoff = false;
            if (_rifleTracking) then {[_reserveUnit,false] call GAIT_fnc_updateRifleRun};
            _rifleTracking = false;
            _rifleYielded = false;
            [_reserveUnit] call GAIT_fnc_endBurst;
            _burstOverLimitUntil = -1;
            _reserveUnit = player;
            _sprintReserve = _sprintReserveMax;
            _depletedRunTime = 0;
            _wroteStanceSpeed = false;
            _wroteMovingStanceSpeed = false;
            _lastSprintPressUsed = -1;
            _deadSprintReady = true;
            _loadPaceTime = 0;
            _lastCarriedPatient = objNull;
            _carryPaceSprint = false;
            _carryRelease = [];
        };

        private _burstBilledThisTick = (player getVariable ["GAIT_burstBill", []]) isNotEqualTo [];
        private _normalReserveShare = 1;
        if (_burstBilledThisTick) then {
            private _budget = _sprintReserve / _sprintReserveMax;
            if ((call GAIT_fnc_aceAdvancedFatigueActive) && {uiNamespace getVariable ["GAIT_aceSprintReserveHookInstalled", false]}) then {
                _budget = missionNamespace getVariable ["ace_advanced_fatigue_anReservePercentage", _budget];
            };
            private _burstLoad = player getVariable ["GAIT_effectiveLoadLb", (loadAbs player) / _loadAbsPerLb];
            _normalReserveShare = [player, _now, _burstLoad, _budget, _lastKnownSlopeDegrees] call GAIT_fnc_accrueBurstCost;
        };
        // A paid launch still settles if the player stops, enters a dialog or
        // starts another action. ACE settles at its normal publication point.
        if ((player getVariable ["GAIT_burstDue", 0]) > 0 &&
            {!(call GAIT_fnc_aceAdvancedFatigueActive) ||
                {!(uiNamespace getVariable ["GAIT_aceSprintReserveHookInstalled", false])} ||
                {isNil "ace_advanced_fatigue_anReservePercentage"}}) then {
            _sprintReserve = (_sprintReserve - _sprintReserveMax * ([player] call GAIT_fnc_takeBurstCost)) max 0;
        };
        private _resetRequest = missionNamespace getVariable ["GAIT_resetRequested", -1];
        if (_resetRequest > _lastResetRequestHandled) then {
            _burstOverLimitUntil = -1;
            _lastResetRequestHandled = _resetRequest;
            _braceMomentumState = [false, -999, 0, 0, 0];
            _downhillMomentum = 0;
            _loadPaceTime = 0;
            _carryPaceSprint = false;
            _carryRelease = [];
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
            _depletedRunTime = 0;
            _wroteStanceSpeed = false;
            _wroteMovingStanceSpeed = false;
            _lastSprintPressUsed = -1;
            [] call GAIT_fnc_releaseNativeMovement;
        };

        // Refresh live Addon Options settings each tick.
        private _debugHudEnabled = missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false];
        private _tripFrequency = (missionNamespace getVariable ["GAIT_ss_masterTripFrequency", 1]) max 0 min 1.5;

        // Own native stamina before asking the engine for sprint permission.
        // This also restores its saved flag when movement is disabled or the
        // player enters a context owned by another system.
        [player] call GAIT_fnc_updateNativeStaminaOwnership;
        // Scope exits must not display risk from the previous active tick.
        missionNamespace setVariable ["GAIT_tripEligible", false];
        missionNamespace setVariable ["GAIT_tripChancePerSecond", 0];
        if (alive player && {call GAIT_fnc_modeAllowsMovement} && {!(call GAIT_fnc_locomotionInputSuspended)}) then {
            if ((player getVariable ["GAIT_burstRequest", []]) isNotEqualTo []) then {
                private _budget = _sprintReserve / _sprintReserveMax;
                if ((call GAIT_fnc_aceAdvancedFatigueActive) && {uiNamespace getVariable ["GAIT_aceSprintReserveHookInstalled", false]}) then {
                    _budget = missionNamespace getVariable ["ace_advanced_fatigue_anReservePercentage", _budget];
                };
                [player, _budget] call GAIT_fnc_prepareBurst;
            };
            private _pickupActive = player getVariable ["MAV_fastCarry_pickupActive", false];
            if (_pickupActive) then {_loadPaceTime = 0;};
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
                if (_conflicts isNotEqualTo [] && {_debugHudEnabled}) then {
                    diag_log format ["[GAIT] Compatibility scan warning: movement/animation-related addons detected: %1", _conflicts];
                };
            };

            // Do not override the Fast Carry pickup/lift animation speed.
            if (!_pickupActive) then {
                private _isAceCarrying = player getVariable ["ace_dragging_isCarrying", false];
                private _isAceDragging = player getVariable ["ace_dragging_isDragging", false];
                private _carriedObject = player getVariable ["ace_dragging_carriedObject", objNull];
                private _patientHandling = _isAceDragging || {_isAceCarrying && {_carriedObject isKindOf "CAManBase"}};
                private _isOnFoot = isNull objectParent player;
                private _movementInput = call GAIT_fnc_getMovementInput;
                private _turboHeld = _movementInput select 2;
                private _turboPress = player getVariable ["GAIT_turboPressSerial", 0];
                [player] call GAIT_fnc_clearACEAdvancedFatigueMovementLocks;
                private _nativeWalk = !_isAceCarrying && {[player, _turboHeld] call GAIT_fnc_nativeWalkRequested};
                private _stanceYieldActive = [player] call GAIT_fnc_stanceYieldActive;
                private _weaponYieldActive = [player] call GAIT_fnc_weaponYieldActive;
                private _stanceTravel = player getVariable ["GAIT_stanceTravel", []];
                private _movingStanceYield = _stanceYieldActive && {_stanceTravel isNotEqualTo []} &&
                    {diag_tickTime <= (player getVariable ["GAIT_stanceYieldUntil", -1])} &&
                    {(_stanceTravel select 3) isEqualTo currentWeapon player};
                if (player isEqualTo (missionNamespace getVariable ["GAIT_nativeOwner", objNull]) &&
                    {abs ((getAnimSpeedCoef player) - (missionNamespace getVariable ["GAIT_nativeLastWritten", -1])) < 0.001}) then {
                    _currentSpeed = missionNamespace getVariable ["GAIT_nativeLastPreVegetation", _currentSpeed];
                };
                private _isForwardHeld = (_movementInput select 0) > 0.05;
                private _externalSprintLock = !(isSprintAllowed player) || {(player getVariable ["ace_common_effect_blockSprint", 0]) > 0};
                private _externalWalkLock = isForcedWalk player || {(player getVariable ["ace_common_effect_forceWalk", 0]) > 0};
                private _movementEligible = [player, _isAceCarrying || {_isAceDragging}] call GAIT_fnc_nativeMovementEligible;
                private _sprintRequested = (!_stanceYieldActive || {_movingStanceYield}) &&
                    {!_weaponYieldActive} && {_turboHeld} && {_isForwardHeld} &&
                    {(stance player) isNotEqualTo "PRONE"} && {!_externalSprintLock} && {!_externalWalkLock};
                private _stance = stance player;
                private _isCrouched = _stance isEqualTo "CROUCH";
                private _isProne = _stance isEqualTo "PRONE";
                private _gaitPose = ["Perc", "Pknl"] select _isCrouched;
                private _movingAnimation = toLower animationState player;
                private _carriedPatient = [objNull, _carriedObject] select (_patientHandling && {!_isAceDragging});
                private _casualtyClip = if (_isAceDragging) then {
                    [player, player getVariable ["ace_dragging_draggedObject", objNull], _movingAnimation, false]
                        call GAIT_fnc_activeCasualtyClip
                } else {
                    [player, _carriedPatient, _movingAnimation, true, true] call GAIT_fnc_activeCasualtyClip
                };
                private _carryContext = _casualtyClip in ["carryIdle", "carryWalk", "carryRun"];
                private _sprintIntent = _sprintRequested && {!_patientHandling || {_carryContext}};
                private _isSprinting = _sprintIntent && {_movementEligible};
                if (_carriedPatient isNotEqualTo _lastCarriedPatient) then {
                    _lastCarriedPatient = _carriedPatient;
                    _wasSprinting = false;
                    _sprintBraceEndTime = -1;
                    _walkingStartTime = -1;
                    _walkStartBraceState = [];
                    _braceMomentumState = [false, -999, 0, 0, 0];
                    _downhillMomentum = 0;
                    _uphillPaceExposure = 0;
                    _loadPaceTime = 0;
                    _deadSprintElapsed = -1;
                    _deadSprintIntentHeld = false;
                    _carryPaceSprint = false;
                    _carryRelease = [];
                    _currentSpeed = _normalSpeed;
                    [] call GAIT_fnc_releaseSpeedCoefficient;
                };
                // A moving stance blend preserves the existing sprint request.
                private _gaitStanceOk = (!_stanceYieldActive || {_movingStanceYield}) &&
                    {!_weaponYieldActive} && {_stance in ["STAND", "CROUCH"]} &&
                    {(_movingAnimation select [4, 4]) isEqualTo toLower _gaitPose};
                private _isBackHeld = (_movementInput select 0) < -0.05;
                private _isLateralHeld = abs (_movementInput select 1) > 0.05;
                private _hasMovementInput = _isForwardHeld || {_isBackHeld} || {_isLateralHeld};

                private _onGroundNow = isTouchingGround player;
                private _stanceDepth = [_movingAnimation] call GAIT_fnc_stanceAnimationDepth;
                if (_stanceYieldActive && {_stanceDepth <= 0}) then {
                    private _blending = (([player] call GAIT_fnc_readPaceMoveInfo) param [3, 1]) < 0.995;
                    private _recentAdjust = diag_tickTime - (player getVariable ["GAIT_stanceYieldStarted", -1]) < 0.35;
                    _stanceDepth = [_movingAnimation, _blending || {_recentAdjust}] call GAIT_fnc_stanceAnimationDepth;
                    private _fromStance = player getVariable ["GAIT_stanceYieldFrom", ""];
                    if (_stanceDepth <= 0 && {_blending} && {_fromStance isNotEqualTo _stance} &&
                        {_fromStance in ["STAND", "CROUCH", "PRONE"]} &&
                        {_stance in ["STAND", "CROUCH", "PRONE"]} && {(_movingAnimation select [0, 4]) isEqualTo "amov"}) then {
                        _stanceDepth = [0.85, 1] select (_isProne || {_fromStance isEqualTo "PRONE"});
                    };
                };
                private _stanceMotion = _stanceDepth > 0 && {!_externalWalkLock} && {!_isAceCarrying} &&
                    {[player, false, true] call GAIT_fnc_nativeMovementEligible};
                // Actual horizontal movement drives the brace and trip checks.
                private _velSample = velocity player;
                private _horizontalSpeedMS = sqrt (((_velSample select 0) * (_velSample select 0)) + (((_velSample select 1) * (_velSample select 1))));
                private _actualSpeedKmh = _horizontalSpeedMS * 3.6;

                private _aceAdvancedFatigueActive = call GAIT_fnc_aceAdvancedFatigueActive;
                if (_aceAdvancedFatigueActive) then {
                    [player] call GAIT_fnc_clearACEAdvancedFatigueMovementLocks;
                };
                private _aceReserve = -1;
                if (_aceAdvancedFatigueActive &&
                    {uiNamespace getVariable ["GAIT_aceSprintReserveHookInstalled", false]}) then {
                    _aceReserve = missionNamespace getVariable ["ace_advanced_fatigue_anReservePercentage", -1];
                };
                private _availableReserve = [_sprintReserve / _sprintReserveMax, _aceReserve] select (_aceReserve >= 0);
                private _tripMovementEligible = _movementEligible && {_isOnFoot} && {!_isAceCarrying} && {!_isAceDragging} &&
                    {_gaitStanceOk} && {_onGroundNow} && {!_externalWalkLock} &&
                    {(player getVariable ["ace_common_effect_blockSprint", 0]) <= 0};
                private _running = _hasMovementInput && {_horizontalSpeedMS > 0.8} &&
                    {_isSprinting || {(_movingAnimation select [8, 4]) in ["mrun", "mtac"]}};
                _depletedRunTime = [_depletedRunTime, _availableReserve, _running, _tripMovementEligible, _dt]
                    call GAIT_fnc_stepDepletedRunTime;
                private _tripFatigue = [_availableReserve, _depletedRunTime] call GAIT_fnc_downhillTripFatigueFactors;
                private _tripMinSpeed = _downhillTripMinSpeedKmh * (_tripFatigue select 2);
                private _tripQualification = [[_downhillTripSprintStartTime, _downhillTripHighSpeedStartTime], time,
                    _tripMovementEligible, _isSprinting, _actualSpeedKmh, _downhillTripSustainedSpeedKmh * (_tripFatigue select 2),
                    _tripMinSpeed, _downhillTripMinSprintSeconds]
                    call GAIT_fnc_stepDownhillTripQualification;
                _downhillTripSprintStartTime = _tripQualification select 0;
                _downhillTripHighSpeedStartTime = _tripQualification select 1;
                private _tripSustainedSprintSeconds = _tripQualification select 2;
                private _tripSustainedHighSpeedSeconds = _tripQualification select 3;

                missionNamespace setVariable ["GAIT_tripSustainedSprintSeconds", _tripSustainedSprintSeconds];
                missionNamespace setVariable ["GAIT_tripSustainedHighSpeedSeconds", _tripSustainedHighSpeedSeconds];
                missionNamespace setVariable ["GAIT_tripDepletedRunTime", _depletedRunTime];
                missionNamespace setVariable ["GAIT_tripFatigueFactors", _tripFatigue];

                if (_isForwardHeld) then {_lastForwardInputTime = time;};
                private _forwardReleasedLongEnough = !_isForwardHeld && {((time - _lastForwardInputTime) >= _wReleaseZeroMomentumDelay)};

                private _loadPatient = if (_isAceDragging) then {player getVariable ["ace_dragging_draggedObject", objNull]} else {_carriedPatient};
                private _gearLbs = [player, _loadPatient, _isAceDragging, _dt] call GAIT_fnc_effectiveTravelLoad;
                player setVariable ["GAIT_effectiveLoadLb", _gearLbs];
                private _loadAnchors = [_lightWeightMax, _mediumWeightMax, _moderateWeightMax];
                private _unloadedSpeedMult = _lightSpeedBonus max 0.01;
                private _paceAnchors = [_unloadedSpeedMult, _mediumSpeedBonus, _moderateSpeedBonus, _heavySpeedBonus];
                private _extraHeavyPenalty = 0.18;
                private _weightSpeedMult = [_gearLbs, _loadAnchors, _paceAnchors, _extraHeavyPenalty]
                    call GAIT_fnc_continuousLoadMultiplier;
                private _gearInertia = [_gearLbs,
                    [_lightBraceRelief, _mediumBraceRelief, _moderateBraceRelief, _heavyBraceRelief],
                    _loadAnchors] call GAIT_fnc_gearInertia;
                private _effectiveNormalSpeed = _normalSpeed * _weightSpeedMult;
                private _effectiveBraceRelief = (_gearInertia select 1) * 0.20;
                private _effectiveBraceSpeed = (_sprintStartBraceSpeed + ((_normalSpeed - _sprintStartBraceSpeed) * _effectiveBraceRelief)) * _weightSpeedMult;

                private _accelerationScale = _gearInertia select 0;
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

                if (_isOnFoot && {!_isAceDragging || {_casualtyClip isEqualTo "drag"}}) then {
                    // Once moving, gravity follows actual displacement through a turn.
                    private _sampleInput = [_movementInput, [0, 0]] select
                        (_horizontalSpeedMS > 0.5 || {_casualtyClip isNotEqualTo "" && {_horizontalSpeedMS > 0.15}});
                    _rawSlopeDegrees = [player, _slopeSampleDistance, _sampleInput] call GAIT_fnc_getTravelSlopeDegrees;

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

                    _lastKnownSlopeDegrees = _slopeDegrees;
                    missionNamespace setVariable ["GAIT_rawSlopeDegrees", _rawSlopeDegrees];
                    missionNamespace setVariable ["GAIT_smoothedSlopeDegrees", _smoothedSlopeDegrees];
                    missionNamespace setVariable ["GAIT_slopeTransitionSmoothingEnabled", true];
                    missionNamespace setVariable ["GAIT_lastKnownSlopeDegrees", _lastKnownSlopeDegrees];

                    private _uphillMaxDegSafe = _uphillMaxDegrees max (_uphillStartDegrees + 0.1);
                    private _uphillBuildContext = _isSprinting &&
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
                    private _tripBill = player getVariable ["GAIT_burstBill", []];
                    private _burstRisk = 0;
                    if (_isSprinting && {_tripBill isNotEqualTo []} && {(_tripBill select 1) < 0}) then {
                        _burstRisk = [_availableReserve - (player getVariable ["GAIT_burstDue", 0])] call GAIT_fnc_burstStrength;
                    };
                    private _tripStart = _downhillTripThresholdDegrees - 14 * _burstRisk;
                    private _downhillTripMaxDegSafe = _downhillTripMaxDegrees max (_tripStart + 0.1);
                    private _gearTripSeverity = linearConversion [_lightWeightMax, 110, _gearLbs, 0, 1, true];
                    private _tripSlopeSeverity = if (_slopeDegrees < -_tripStart) then {
                        linearConversion [_tripStart, _downhillTripMaxDegSafe, _downhillDegForTrip, 0, 1, true]
                    } else {
                        0
                    };

                    private _tripSpeedFactors = [_actualSpeedKmh, _tripMinSpeed,
                        _downhillTripSpeedMaxKmh, _downhillTripSpeedInfluence] call GAIT_fnc_downhillTripSpeedFactors;
                    private _tripSpeedSeverity = _tripSpeedFactors select 0;
                    private _speedRiskMultiplier = _tripSpeedFactors select 1;

                    private _weightInfluence = (_downhillTripWeightInfluence max 0) min 2;
                    private _weightRiskCurve = 0.75 + (0.85 * _gearTripSeverity);
                    private _weightRiskMultiplier = 1 + (((_weightRiskCurve max 0.10) - 1) * _weightInfluence);
                    _weightRiskMultiplier = _weightRiskMultiplier max 0;

                    private _sustainedGateReady = (_tripSustainedSprintSeconds >= _downhillTripMinSprintSeconds) ||
                        {_tripSustainedHighSpeedSeconds >= _downhillTripSustainedSpeedSeconds};

                    private _lastTripTime = missionNamespace getVariable ["GAIT_lastTripTime", -999];
                    private _cooldownRemaining = ((_downhillTripCooldown - (time - _lastTripTime)) max 0);
                    private _immunityRemaining = ((_downhillTripPostFallImmunity - (time - _lastTripTime)) max 0);
                    private _tripBlockedByCooldown = (_cooldownRemaining > 0) || {_immunityRemaining > 0};
                    private _tripEligible = _tripFrequency > 0 && {_tripMovementEligible} && {_slopeDegrees < -_tripStart} && {_actualSpeedKmh >= _tripMinSpeed} && {_sustainedGateReady};
                    private _chancePerSecond = 0;

                    if (_tripEligible) then {
                        _chancePerSecond = _downhillTripBaseChancePerSecond + ((_downhillTripMaxChancePerSecond - _downhillTripBaseChancePerSecond) * _tripSlopeSeverity);
                        _chancePerSecond = _chancePerSecond * _tripFrequency * _speedRiskMultiplier * _weightRiskMultiplier *
                            (_tripFatigue select 0) * (_tripFatigue select 1);
                        _chancePerSecond = _chancePerSecond max 0 min 1;
                    };

                    missionNamespace setVariable ["GAIT_tripEligible", _tripEligible];
                    missionNamespace setVariable ["GAIT_tripAngleDegrees", _downhillDegForTrip];
                    missionNamespace setVariable ["GAIT_tripEffectiveThreshold", _tripStart];
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
                        _depletedRunTime = 0;
                        _currentSpeed = _effectiveNormalSpeed;
                        _sprintBraceEndTime = -1;
                        _wasSprinting = false;
                    };
                };

                private _hillWalkSlowdownMultiplier = 1;
                private _hillWalkSlowdownSeverity = 0;
                if (_isOnFoot && {_isForwardHeld || {_isBackHeld} || {_isLateralHeld}} && {!_isAceDragging}) then {
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
                private _ordinarySlopeJog = _gaitMovementEnabled &&
                    {_gaitStanceOk} && {_onGroundNow} && {!_isAceCarrying} && {!_isAceDragging} &&
                    {[_ordinaryInput, _slopeDegrees, _externalSprintLock, _externalWalkLock, _walkToggled, _slopeJogWasWanted]
                        call GAIT_fnc_ordinarySlopeJogIntent};
                private _slopeJogWanted = _ordinarySlopeJog && {!_turboHeld};
                player setVariable ["GAIT_slopeJogIntent", _slopeJogWanted];
                private _slopeJogOverride = _slopeJogWanted && {_movementEligible};
                missionNamespace setVariable ["GAIT_slopeJogOverride", _slopeJogOverride];

                private _nativeWalkPace = if (player isEqualTo (missionNamespace getVariable ["GAIT_nativeOwner", objNull])) then {
                    missionNamespace getVariable ["GAIT_nativePreviousCoef", 1]
                } else {getAnimSpeedCoef player};
                // Existing manual profiles have standing-clip references.
                private _profiles = [missionNamespace getVariable ["GAIT_locomotionPaceProfiles", []], []] select _isCrouched;
                private _animationPrefix = "Amov" + _gaitPose;
                private _jogReference = -1;
                private _jogMinimum = 0;

                if (!_patientHandling && {!_nativeWalk} && {!_turboHeld} && {_isForwardHeld} && {_gaitStanceOk} && {_movementEligible} &&
                    {(_movingAnimation select [8, 4]) isEqualTo "mrun" || {_slopeJogOverride && {(_movingAnimation select [8, 4]) isEqualTo "mwlk"}}}) then {
                    private _jogFamily = [player] call GAIT_fnc_slopeWeaponFamily;
                    if (_jogFamily isNotEqualTo "") then {
                        private _jogDirection = [_movementInput select 0, _movementInput select 1] call GAIT_fnc_slopeDirection;
                        private _jogReferences = [_profiles, _jogFamily, _jogDirection, "jog"] call GAIT_fnc_locomotionPaceReferences;
                        private _walkReference = -1;
                        private _jogClip = [_animationPrefix + "Mrun" + _jogFamily + _jogDirection, _movingAnimation]
                            select ((_movingAnimation select [8, 4]) isEqualTo "mrun");
                        if (_jogReferences isEqualTo []) then {
                            _jogReference = [player, _jogClip, _slopeDegrees] call GAIT_fnc_lookupUnitPaceReference;
                            _walkReference = [player, _animationPrefix + "Mwlk" + _jogFamily + _jogDirection, _slopeDegrees]
                                call GAIT_fnc_lookupUnitPaceReference;
                        } else {
                            _walkReference = _jogReferences select 0;
                            _jogReference = _jogReferences select 1;
                        };
                        private _combatReference = [player, _jogFamily, _jogDirection, _slopeDegrees, _jogClip, _jogReference, _gaitPose]
                            call GAIT_fnc_combatPaceReference;
                        _jogMinimum = [_nativeWalkPace, _walkReference, _combatReference, _jogReference]
                            call GAIT_fnc_ordinaryJogFloor;
                    };
                };

                private _idlePace = _effectiveNormalSpeed * _hillWalkSlowdownMultiplier;
                if (_isAceCarrying && {!isNull _carriedObject}) then {
                    _idlePace = _carryWalkSpeed * _weightSpeedMult * _hillWalkSlowdownMultiplier;
                };
                // Losing forward input clears downhill buildup independently
                // of the speed coefficient used in the next direction.
                if (!_isForwardHeld || {_forwardReleasedSinceTick}) then {
                    _downhillMomentum = 0;
                };

                // Sample established motion BEFORE processing a new sprint
                // press. Holding Turbo against a wall cannot establish it.
                // A transient animation blend does not clear physical history.
                private _ordinaryMovementContext = _gaitMovementEnabled && {!_isAceCarrying} && {!_isAceDragging} &&
                    {!_externalWalkLock} && {[player] call GAIT_fnc_fatigueMovementContextEligible};
                private _carryMovementContext = _carryContext && {!_externalWalkLock} &&
                    {[player, true] call GAIT_fnc_fatigueMovementContextEligible};
                private _paceMovementContext = _ordinaryMovementContext || {_carryMovementContext};
                private _momentumContextOk = _paceMovementContext && {!_externalSprintLock};
                private _sprintPoseBridge = _ordinaryMovementContext && {_wasSprinting} && {_sprintIntent} && {_onGroundNow} && {_momentumContextOk} &&
                    {!_forwardReleasedSinceTick} && {!_renderReleasedSinceTick} &&
                    {([_movingAnimation, "mstp"] call GAIT_fnc_riflePoseBlendTarget) isNotEqualTo ""};

                // Ordinary W start from a true stop gets one small planted first
                // step. It is independent of sprint momentum and never stacks
                // with Turbo, dragging, medical locks, airborne movement or an
                // already-moving re-press. The render snapshot prevents a slow
                // feature tick from mistaking newly acquired speed for momentum.
                if (_forwardPressedSinceTick) then {
                    _walkStartBraceState = [];
                    private _snapshotValid = (count _forwardPressSnapshot) isEqualTo 4 &&
                        {(_forwardPressSnapshot select 0) isEqualTo _forwardPressSerial} &&
                        {diag_tickTime >= (_forwardPressSnapshot select 1)} &&
                        {diag_tickTime - (_forwardPressSnapshot select 1) <= 0.35};
                    if (_snapshotValid &&
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

                private _sprintResumedAfterStop = _isSprinting && {_wasSprinting} && {_horizontalSpeedMS > 0.25} &&
                    {(_braceMomentumState param [3, 0]) > 0} && {(_braceMomentumState param [4, 0]) >= 0.000001};
                private _continuingSprint = _isSprinting && {_wasSprinting} && {_sprintBraceEndTime <= time} &&
                    {!_forwardReleasedSinceTick} && {!_sprintResumedAfterStop};
                private _motion = [_braceMomentumState, _continuingSprint, _momentumContextOk,
                    _horizontalSpeedMS, _currentSpeed, _idlePace max _jogMinimum,
                    time, [_dt, 0] select _sprintPoseBridge, _braceRecentSprintCooldown,
                    _braceRequiredWalkTime, _braceNoMomentumThreshold]
                    call GAIT_fnc_stepBraceMomentum;
                _braceMomentumState = _motion select 0;
                private _hasRetainedSprintMomentum = _motion select 1;
                private _stopRearm = _motion select 2;
                missionNamespace setVariable ["GAIT_braceMomentumProtected", _hasRetainedSprintMomentum];
                missionNamespace setVariable ["GAIT_stopBraceRearm", _stopRearm];

                private _downhillMovementContext = _paceMovementContext && {_movementEligible} && {_gaitStanceOk} && {_onGroundNow};
                private _loadShare = (_gearLbs / 150) max 0 min 1;
                private _steadyTravel = (_ordinaryMovementContext || {_casualtyClip isNotEqualTo ""}) && {_movementEligible} &&
                    {_hasMovementInput} && {_horizontalSpeedMS > 0.15};
                _loadPaceTime = [_loadPaceTime, _steadyTravel, _dt] call GAIT_fnc_stepLoadPaceTime;
                private _lightPaceBonus = [_loadPaceTime, _slopeDegrees] call GAIT_fnc_lightLoadPaceBonus;
                private _loadPaceScale = 1 + ((1 - _loadShare) * _lightPaceBonus);
                private _loadPaceRatio = 1 - (0.025 * _loadShare);
                private _downhillGrade = _rawSlopeDegrees max _slopeDegrees;
                private _runAngles = [_downhillBoostStartDegrees, _downhillBoostMaxDegrees]
                    call GAIT_fnc_downhillRunAngles;
                _runAngles params ["_downhillRunStart", "_downhillRunPeak"];
                private _downhillTravel = _downhillGrade < -_downhillRunStart;
                private _downhillJog = _ordinaryMovementContext && {_downhillMovementContext} && {_downhillTravel} &&
                    {_isForwardHeld} && {!_isSprinting} && {!_nativeWalk};
                if (!_downhillMovementContext || {!_isForwardHeld} || {_forwardReleasedSinceTick} ||
                    {(_braceMomentumState select 3) >= 0.15}) then {
                    _downhillMomentum = 0;
                } else {
                    // Buildup takes time even on steep descents. Jog earns a smaller share.
                    private _momentumTarget = 0;
                    if (_horizontalSpeedMS > 0.25 && {_downhillTravel}) then {
                        private _earnedByGrade = [_downhillGrade, _downhillRunStart, _downhillRunPeak]
                            call GAIT_fnc_downhillMomentumTarget;
                        if (_continuingSprint) then {_momentumTarget = _earnedByGrade;};
                        if (_downhillJog) then {_momentumTarget = 0.45 * _earnedByGrade;};
                    };
                    private _baseBuildSeconds = 6.5;
                    private _buildSeconds = _baseBuildSeconds * ([1, 1.4] select _downhillJog);
                    _downhillMomentum = [_downhillMomentum, _momentumTarget, _dt, _buildSeconds, 1.5]
                        call GAIT_fnc_stepDownhillMomentum;
                };
                if (_downhillGrade >= -2 && {_downhillMomentum < 0.15}) then {_burstOverLimitUntil = -1;};
                missionNamespace setVariable ["GAIT_downhillMomentum", _downhillMomentum];
                private _sustainedBonus = 0.14;
                private _downhillJogMultiplier = 1;
                private _turnBonus = 0;
                if (_downhillMovementContext && {_isForwardHeld} && {!_nativeWalk} && {_horizontalSpeedMS > 0.25} &&
                    {!_forwardReleasedSinceTick} && {_isSprinting || {_ordinaryMovementContext}}) then {
                    private _earned = 0;
                    if (_downhillTravel) then {
                        _earned = ([_downhillGrade, _loadShare, _downhillMomentum, _downhillBoostStartDegrees,
                            _downhillBoostMaxDegrees, _downhillMaxBoost, _sustainedBonus] call GAIT_fnc_downhillPaceMultiplier) - 1;
                    };
                    private _previous = player getVariable ["GAIT_turnBonus", [0,-1]];
                    private _prior = [0, _previous select 0] select (time - (_previous select 1) <= 0.25);
                    _turnBonus = [_prior, _earned, _rawSlopeDegrees, _dt] call GAIT_fnc_turnDownhillBonus;
                    if (_isSprinting) then {
                        _slopeSpeedMultiplier = _slopeSpeedMultiplier * (1 + _turnBonus);
                    } else {
                        _downhillJogMultiplier = 1 + (0.35 * _turnBonus);
                    };
                };
                player setVariable ["GAIT_turnBonus", [_turnBonus, time]];
                missionNamespace setVariable ["GAIT_slopeSpeedMultiplier", _slopeSpeedMultiplier];

                // Brace readiness:
                // Standing still or slow deliberate movement for long enough arms the next brace.
                // Active crouch also arms the brace, but this checks real stance only, not the crouch key.
                // Quick Shift releases/re-taps keep momentum and do not re-trigger the brace.
                private _isBraceReadyState =
                    !_sprintIntent &&
                    {!_patientHandling || {_carryMovementContext}} &&
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

                private _burst = false;
                private _burstStarted = false;
                if ((player getVariable ["GAIT_burstRequest", []]) isNotEqualTo [] ||
                    {(player getVariable ["GAIT_burstBill", []]) isNotEqualTo []}) then {
                    private _canStartBurst = (player getVariable ["GAIT_burstBill", []]) isEqualTo [];
                    private _burstEligible = _isSprinting && {_gaitStanceOk} && {!_nativeWalk} &&
                        {!_isAceCarrying} && {!_isAceDragging} && {!_stanceYieldActive} &&
                        {!(player getVariable ["GAIT_isTripping", false])} &&
                        {!(call GAIT_fnc_readAimInput)} && {!(call GAIT_fnc_getWeaponSlotInput)} &&
                        {!([player] call GAIT_fnc_readWeaponSwitching)};
                    _burst = [player, _burstEligible, _availableReserve, _turboPress, currentWeapon player] call GAIT_fnc_updateBurst;
                    _burstStarted = _canStartBurst && {_burst};
                };
                private _newNormalBrace = false;
                if (_isSprinting && {_burstStarted || {!_wasSprinting} || {_sprintResumedAfterStop}}) then {
                    _wasSprinting = true;

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
                        (_currentSpeed <= (([_effectiveNormalSpeed, _idlePace] select _carryContext) + _braceNoMomentumThreshold)) ||
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
                    private _slopeBraceFactor = if (_slopeForBraceAbs >= _slopeBraceStart) then {
                        linearConversion [_slopeBraceStart, _slopeBraceMax, _slopeForBraceAbs, 0, 1, true]
                    } else {
                        0
                    };
                    private _slopeBraceReady = _slopeBraceFactor > 0 && {_recentSlopeStop || {_normalBraceReady} || {_zeroMomentumBraceReady}};


                    private _canBrace = [true, _hasRetainedSprintMomentum,
                        _isCrouched, _braceArmedFromCrouch, _normalBraceReady, _zeroMomentumBraceReady, _slopeBraceReady]
                        call GAIT_fnc_shouldBrace;
                    private _braceStrength = [0, 1] select (_canBrace || _burstStarted);
                    if (_stopRearm >= 0.000001) then {
                        if (!_burstStarted) then {_braceStrength = _stopRearm;};
                        _braceMomentumState set [4, 0];
                    };

                    // Positive-grade, zero-momentum starts exponentially deepen
                    // and lengthen the existing brace. The existing slope-brace
                    // settings remain the tuning knobs; this simply reshapes their
                    // uphill launch contribution. Retained momentum bypasses it.
                    private _uphillLaunchBraceFactor = 0;
                    if (_braceStrength > 0) then {
                        _uphillLaunchBraceFactor = [_slopeDegrees, _hasRetainedSprintMomentum,
                            _slopeStopBraceMaxDegrees] call GAIT_fnc_uphillLaunchBraceFactor;
                    };
                    private _linearDurationExtra = ((_slopeStopBraceExtraDuration max 0) min 2.0) * _slopeBraceFactor;
                    private _linearDipExtra = ((_slopeStopBraceExtraDip max 0) min 0.90) * _slopeBraceFactor;
                    private _uphillDurationExtra = ((_slopeStopBraceExtraDuration max 0) min 2.0) *
                        3.0 * _uphillLaunchBraceFactor;
                    private _uphillDipExtra = ((_slopeStopBraceExtraDip max 0) min 0.90) *
                        2.1 * _uphillLaunchBraceFactor;
                    private _braceDurationNow = _braceStrength *
                        ([_sprintStartBraceDuration, _linearDurationExtra, _uphillDurationExtra, _accelerationScale, _burst] call GAIT_fnc_sprintLaunchBraceDuration);
                    private _braceDipNow = (_linearDipExtra max _uphillDipExtra) min 0.90;
                    _newNormalBrace = !_burst && {_braceDurationNow >= 0.035};
                    private _fullBraceSpeed = (_effectiveBraceSpeed * (1 - _braceDipNow)) max 0.08;
                    _activeBraceSpeed = _effectiveNormalSpeed + ((_fullBraceSpeed - _effectiveNormalSpeed) * _braceStrength);

                    _sprintBraceEndTime = if (_braceDurationNow > 0) then {
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

                if (!_isSprinting && {!_sprintIntent || {_wasSprinting && {!([player, _carryContext] call GAIT_fnc_fatigueMovementContextEligible)}}}) then {
                    if (_wasSprinting || {_renderReleasedSinceTick}) then {
                        _lastSprintEndTime = time;

                        _lastSprintStopSlopeDegrees = _slopeDegrees;
                        _lastSprintStopTime = time;

                        missionNamespace setVariable ["GAIT_lastSprintStopSlopeDegrees", _lastSprintStopSlopeDegrees];
                    };

                    _wasSprinting = false;
                    _sprintBraceEndTime = -1;
                };

                // =====================================================
                // SPRINT RESERVE / ACE ADVANCED FATIGUE BRIDGE
                // =====================================================
                private _reserveRatio = 1;
                private _sprintPaceReserve = 1;

                // A small delay in animation eligibility cannot create recovery mid-stride.
                private _stanceActivity = "";
                if (_stanceMotion) then {_stanceActivity = "stance";} else {
                    if (_movementEligible && {_hasMovementInput} && {!_externalWalkLock} && {!_isAceCarrying}) then {
                        if (_isCrouched) then {_stanceActivity = "crouch";};
                        if (_isProne) then {_stanceActivity = "crawl";};
                    };
                };
                private _walkingForRecovery = _movementEligible && {
                    if (_carryContext) then {!_carryPaceSprint && {_carryRelease isEqualTo []}} else {
                        (_movingAnimation select [8, 4]) isEqualTo "mwlk"
                    }
                };
                private _reserveActivity = [_movementInput, _horizontalSpeedMS, _sprintIntent && {!_nativeWalk},
                    _onGroundNow && {[player, _carryContext, _casualtyClip isEqualTo "drag"] call GAIT_fnc_fatigueMovementContextEligible}, _stanceActivity, _walkingForRecovery]
                    call GAIT_fnc_sprintReserveActivity;
                if (_casualtyClip isEqualTo "drag" && {_movementEligible} && {_onGroundNow} && {_hasMovementInput} &&
                    {_horizontalSpeedMS > 0.15} && {[player,false,true] call GAIT_fnc_fatigueMovementContextEligible}) then {
                    _reserveActivity = "drag";
                };
                private _walkRecoveryShare = [_gearLbs, _carryContext] call GAIT_fnc_walkRecoveryShare;
                private _stanceRate = [_reserveActivity, _gearLbs, _stanceDepth] call GAIT_fnc_stanceReserveDrainRate;
                if (_reserveActivity isEqualTo "drag") then {
                    _stanceRate = 0.30 * ([_gearLbs, [_slopeDegrees] call GAIT_fnc_sprintReserveGradeMultiplier] call GAIT_fnc_sprintReserveDrainRate);
                };
                private _reserveBeforeStep = _sprintReserve / _sprintReserveMax;
                private _burstStrength = 0;
                if (_burst) then {
                    _burstStrength = [_availableReserve - (player getVariable ["GAIT_burstDue", 0])] call GAIT_fnc_burstStrength;
                    if (_burstStarted) then {_normalReserveShare = 0;};
                };
                if (_aceReserve >= 0) then {
                    [player, _reserveActivity, _dt max 0 min 0.25, _slopeDegrees, _stanceRate, _walkRecoveryShare, _normalReserveShare, _gearLbs]
                        call GAIT_fnc_accumulateAceSprintEffort;
                    private _aerobic = (missionNamespace getVariable ["ace_advanced_fatigue_aeReservePercentage", 1]) max 0 min 1;
                    private _acidosis = (missionNamespace getVariable ["ace_advanced_fatigue_anFatigue", 0]) max 0 min 1;
                    private _muscleDamage = (missionNamespace getVariable ["ace_advanced_fatigue_muscleDamage", 0]) max 0 min 1;
                    private _acidosisPenalty = 1 - (_aceAcidosisPenaltyFactor * _acidosis);
                    private _musclePenalty = 1 - (_aceMuscleDamagePenaltyFactor * _muscleDamage);
                    // Anaerobic reserve sets the onset. Other ACE fatigue
                    // factors make a progressively larger contribution below half.
                    _reserveRatio = _aceReserve max 0 min 1;
                    _reserveBeforeStep = _reserveRatio;
                    private _perceivedReserve = (_reserveRatio min _aerobic) * _acidosisPenalty * _musclePenalty;
                    private _fatigueProgress = (1 - (_reserveRatio / 0.50)) max 0;
                    _sprintPaceReserve = _reserveRatio + ((_perceivedReserve - _reserveRatio) * _fatigueProgress ^ 2);
                    _sprintReserve = _sprintReserveMax * _reserveRatio;
                } else {
                    [] call GAIT_fnc_clearAceSprintEffort;
                    private _gradeMultiplier = [_slopeDegrees] call GAIT_fnc_sprintReserveGradeMultiplier;
                    private _drainRate = [_gearLbs, _gradeMultiplier] call GAIT_fnc_sprintReserveDrainRate;
                    if (_stanceRate > 0) then {_drainRate = _stanceRate;};
                    _sprintReserve = [_sprintReserve, _reserveActivity, (_dt max 0 min 0.25) * _normalReserveShare, _sprintReserveMax, _sprintRecoverTime, _drainRate, _walkRecoveryShare]
                        call GAIT_fnc_stepFallbackSprintReserve;
                    _reserveRatio = _sprintReserve / _sprintReserveMax;
                    _sprintPaceReserve = _reserveRatio;
                };

                _reserveRatio = (_reserveRatio max 0) min 1;
                private _exhaustion = 1 - _reserveRatio;
                _exhaustion = (_exhaustion max 0) min 1;
                missionNamespace setVariable ["GAIT_exhaustionLevel", _exhaustion];

                private _deadSprintIntent = _sprintIntent && {_gaitStanceOk} && {_isOnFoot} &&
                    {!_isAceCarrying || {_carryContext}} && {!_isAceDragging} && {_horizontalSpeedMS > 0.15};
                if (_renderReleasedSinceTick || {_forwardReleasedSinceTick}) then {_deadSprintElapsed = -1;};
                if (_reserveActivity isEqualTo "rest" && {_reserveRatio >= 0.999}) then {_deadSprintReady = true;};
                private _deadSprintStartReserve = [0, _reserveBeforeStep] select (_deadSprintReady || {_deadSprintIntentHeld});
                _deadSprintElapsed = [_deadSprintElapsed, _deadSprintIntent, _deadSprintIntentHeld, _deadSprintStartReserve, _dt]
                    call GAIT_fnc_stepDeadSprint;
                if (_deadSprintElapsed isEqualTo 0) then {_deadSprintReady = false;};
                _deadSprintIntentHeld = _deadSprintIntent;
                private _flatBurstSetting = 1.05;
                private _flatBurstTerrain = 1 - linearConversion [0.20, 1.0, abs _slopeDegrees, 0, 1, true];
                private _deadSprintStrength = 0;
                if (_flatBurstSetting > 1 && {_onGroundNow} && {!_downhillTravel}) then {
                    _deadSprintStrength = ([_deadSprintElapsed, _reserveRatio] call GAIT_fnc_deadSprintStrength) * _flatBurstTerrain;
                };

                // =====================================================
                // SPEED CONTROL
                // =====================================================
                private _sprintClipScale = [1, _unarmedSprintNormalizer] select ((currentWeapon player) isEqualTo "");
                if (_isSprinting && {!_isAceCarrying} && {_gaitStanceOk}) then {
                    private _family = [player] call GAIT_fnc_slopeWeaponFamily;
                    private _direction = [_movementInput select 0, _movementInput select 1] call GAIT_fnc_slopeDirection;
                    if (_family isNotEqualTo "") then {
                        private _weaponClip = [_family, _direction, true, _gaitPose] call GAIT_fnc_slopeStateName;
                        private _standardClip = ["SrasWrfl", _direction, true, _gaitPose] call GAIT_fnc_slopeStateName;
                        _sprintClipScale = [
                            [player, _standardClip, _slopeDegrees] call GAIT_fnc_releaseClipReference,
                            [player, _weaponClip, _slopeDegrees] call GAIT_fnc_releaseClipReference,
                            _sprintClipScale] call GAIT_fnc_weaponStrideScale;
                    };
                };
                missionNamespace setVariable ["GAIT_sprintStrideScale", _sprintClipScale];
                private _flatSprintPace = _sprintFullSpeed * _sprintClipScale;
                private _walkPace = _effectiveNormalSpeed * _hillWalkSlowdownMultiplier;
                private _freshSprintPace = _flatSprintPace * ([_slopeSpeedMultiplier, 1] select _downhillTravel);
                private _pacePair = [_walkPace, _freshSprintPace];
                private _targetSpeed = (_walkPace max _jogMinimum) * _loadPaceScale;
                private _jogFlatCoefficient = _normalSpeed * 1.06;
                private _slopeJogTargetMS = -1;
                private _slopeJogCalibrated = false;

                if (_slopeJogOverride || {_downhillJog}) then {
                    private _familyJog = [player] call GAIT_fnc_slopeWeaponFamily;
                    private _directionJog = [_movementInput select 0, _movementInput select 1] call GAIT_fnc_slopeDirection;
                    private _jogResolved = [_normalSpeed, _jogFlatCoefficient,
                        _hillWalkSlowdownMultiplier, _hillWalkSlowdownMultiplier * _downhillJogMultiplier,
                        _weightSpeedMult, 1.06, _profiles, _familyJog, _directionJog, "jog"]
                        call GAIT_fnc_locomotionPaceTargets;
                    _pacePair = _jogResolved select [0, 2];
                    _targetSpeed = ((_jogResolved select 1) max _jogMinimum) * _loadPaceScale;
                    _slopeJogTargetMS = [(_jogResolved select 3) * _loadPaceScale, _targetSpeed * _jogReference]
                        select (_jogReference > 0);
                    _slopeJogCalibrated = _jogResolved select 4;
                    if (_downhillJog) then {
                        if (_slopeJogCalibrated && {_jogReference <= 0}) then {
                            _jogReference = _slopeJogTargetMS / _targetSpeed;
                        };
                        if (_jogReference <= 0) then {
                            private _jogClip = [_familyJog, _directionJog, false, _gaitPose] call GAIT_fnc_slopeStateName;
                            _jogReference = [player, _jogClip, _slopeDegrees] call GAIT_fnc_lookupUnitPaceReference;
                        };
                        _targetSpeed = [_targetSpeed, _jogReference,
                            18, _loadPaceRatio]
                            call GAIT_fnc_capDownhillPace;
                        if (_jogReference > 0) then {_slopeJogTargetMS = _targetSpeed * _jogReference;};
                        _pacePair set [1, _targetSpeed];
                    };
                };
                missionNamespace setVariable ["GAIT_slopeJogTargetMS", _slopeJogTargetMS];
                missionNamespace setVariable ["GAIT_slopeJogCalibrated", _slopeJogCalibrated];
                if (!_isSprinting && {!_isAceCarrying} && {!_isAceDragging} && {!_nativeWalk} &&
                    {!_slopeJogCalibrated} && {_gaitStanceOk} &&
                    {(_movingAnimation select [8, 4]) isEqualTo "mrun"}) then {
                    private _family = [player] call GAIT_fnc_slopeWeaponFamily;
                    private _direction = [_movementInput select 0, _movementInput select 1] call GAIT_fnc_slopeDirection;
                    if (_family isNotEqualTo "" && {_direction isNotEqualTo "Dnon"}) then {
                        private _weaponClip = [_family, _direction, false, _gaitPose] call GAIT_fnc_slopeStateName;
                        private _standardClip = ["SrasWrfl", _direction, false, _gaitPose] call GAIT_fnc_slopeStateName;
                        private _scale = [
                            [player, _standardClip, _slopeDegrees] call GAIT_fnc_releaseClipReference,
                            [player, _weaponClip, _slopeDegrees] call GAIT_fnc_releaseClipReference]
                            call GAIT_fnc_weaponStrideScale;
                        _targetSpeed = _targetSpeed * _scale;
                    };
                };

                if (_isAceCarrying && {!_patientHandling} && {!isNull _carriedObject}) then {
                    // Carry animations remain owned by ACE; no slope-state remap.
                    _targetSpeed = (if (_isSprinting) then {
                        (_carrySprintExhaustedSpeed + ((_carrySprintFullSpeed - _carrySprintExhaustedSpeed) * _reserveRatio)) * _slopeSpeedMultiplier
                    } else {_carryWalkSpeed * _hillWalkSlowdownMultiplier}) * _weightSpeedMult * _loadPaceScale;
                };

                private _walkReference = -1;
                private _sprintReference = -1;
                private _sprintPlaybackCeiling = -1;
                if (_isSprinting && {!_isAceCarrying}) then {
                    private _sprintJogReference = -1;
                    private _combatReference = -1;
                    private _uphillTravel = _slopeDegrees > 0.01;
                    if (_gaitStanceOk) then {
                        private _family = [player] call GAIT_fnc_slopeWeaponFamily;
                        private _direction = [_movementInput select 0, _movementInput select 1] call GAIT_fnc_slopeDirection;
                        private _references = [_profiles, _family, _direction, "sprint"] call GAIT_fnc_locomotionPaceReferences;
                        if (_references isEqualTo []) then {
                            private _sprintClip = _animationPrefix + "Meva" + _family + _direction;
                            if ((_movingAnimation select [8, 4]) in ["meva", "mspr"] &&
                                {(_movingAnimation find "_amov") < 0} &&
                                {([_movingAnimation] call GAIT_fnc_locomotionTargetDirection) isEqualTo (toLower _direction)}) then {
                                _sprintClip = _movingAnimation;
                            };
                            _sprintReference = [player, _sprintClip, _slopeDegrees] call GAIT_fnc_lookupUnitPaceReference;
                            if (_sprintReference <= 0) then {
                                _sprintClip = [_family, _direction, true, _gaitPose] call GAIT_fnc_slopeStateName;
                                _sprintReference = [player, _sprintClip, _slopeDegrees] call GAIT_fnc_lookupUnitPaceReference;
                            };
                            if (_sprintReference > 0.1) then {
                                private _walkClip = _animationPrefix + "Mwlk" + _family + _direction;
                                _walkReference = [player, _walkClip, _slopeDegrees] call GAIT_fnc_lookupUnitPaceReference;
                            };
                        } else {
                            _references params ["_manualWalk", "_manualSprint"];
                            _walkReference = _manualWalk;
                            _sprintReference = _manualSprint;
                        };
                        if (_family isNotEqualTo "" && {_sprintReference > 0}) then {
                            private _jogClip = _animationPrefix + "Mrun" + _family + _direction;
                            private _jogReferences = [_profiles, _family, _direction, "jog"] call GAIT_fnc_locomotionPaceReferences;
                            if (_jogReferences isNotEqualTo []) then {
                                _sprintJogReference = _jogReferences select 1;
                            } else {
                                _sprintJogReference = [player, _jogClip, _slopeDegrees] call GAIT_fnc_lookupUnitPaceReference;
                                if (_sprintJogReference <= 0) then {
                                    _jogClip = [_family, _direction, false, _gaitPose] call GAIT_fnc_slopeStateName;
                                    _sprintJogReference = [player, _jogClip, _slopeDegrees] call GAIT_fnc_lookupUnitPaceReference;
                                };
                            };
                            _combatReference = [player, _family, _direction, _slopeDegrees, _jogClip, _sprintJogReference, _gaitPose]
                                call GAIT_fnc_combatPaceReference;
                        };
                    };
                    private _combatPace = _walkPace max (_nativeWalkPace * _hillWalkSlowdownMultiplier) max 0.89;
                    private _combatMinimum = [_combatPace, _combatReference, _sprintReference, _sprintClipScale, _gearLbs]
                        call GAIT_fnc_combatRelativeSprintFloor;
                    private _uphillMinimum = 0;
                    if (_uphillTravel) then {
                        private _jogPace = (_jogFlatCoefficient * _weightSpeedMult * _hillWalkSlowdownMultiplier)
                            max ([_nativeWalkPace, _walkReference, _combatReference, _sprintJogReference] call GAIT_fnc_ordinaryJogFloor);
                        _uphillMinimum = [_nativeWalkPace, _jogPace, _walkReference, _sprintJogReference, _sprintReference]
                            call GAIT_fnc_uphillSprintFloor;
                        private _lightWalkPenalty = _hillWalkUphillMaxPenalty * 0.75;
                        private _lightWalkSlope = [_slopeDegrees, _hillWalkSlowdownStartDegrees,
                            _hillWalkSlowdownMaxDegrees, _lightWalkPenalty] call GAIT_fnc_uphillPaceMultiplier;
                        private _lightWalk = _normalSpeed * _unloadedSpeedMult * _lightWalkSlope;
                        private _lightJog = (_lightWalk * 1.06) max _jogPace;
                        _freshSprintPace = _freshSprintPace max ([_nativeWalkPace, _lightJog, _walkReference,
                            _sprintJogReference, _sprintReference] call GAIT_fnc_uphillSprintFloor);
                    };
                    private _normalRun = _flatSprintPace * ([_slopeSpeedMultiplier, 1] select _downhillTravel);
                    private _sprintMinimum = _combatMinimum max _uphillMinimum;
                    _targetSpeed = [_freshSprintPace, _normalRun, _sprintPaceReserve, _gearLbs, _sprintMinimum,
                        0.70, _deadSprintStrength > 0,
                        _flatBurstSetting, _deadSprintStrength]
                        call GAIT_fnc_sprintReservePace;
                    _targetSpeed = _targetSpeed * _loadPaceScale;
                    if (_downhillMovementContext && {_downhillTravel}) then {
                        _targetSpeed = [_targetSpeed * _slopeSpeedMultiplier, _sprintReference,
                            30, _loadPaceRatio]
                            call GAIT_fnc_capDownhillPace;
                        _targetSpeed = _targetSpeed max (_sprintMinimum * _loadPaceScale);
                    };
                    private _sprintCeilingReference = _sprintReference;
                    if (_sprintCeilingReference <= 0) then {
                        private _ceilingFamily = [player] call GAIT_fnc_slopeWeaponFamily;
                        private _ceilingDirection = [_movementInput select 0, _movementInput select 1] call GAIT_fnc_slopeDirection;
                        private _ceilingClip = [_ceilingFamily, _ceilingDirection, true, _gaitPose] call GAIT_fnc_slopeStateName;
                        _sprintCeilingReference = [player, _ceilingClip, _slopeDegrees] call GAIT_fnc_releaseClipReference;
                    };
                    _sprintPlaybackCeiling = [100, _sprintCeilingReference, _sprintClipScale,
                        _slopeSpeedMultiplier, _loadPaceScale] call GAIT_fnc_capSprintPace;
                    _targetSpeed = _targetSpeed min _sprintPlaybackCeiling;
                    if (_burst) then {
                        private _gravity = [_downhillGrade, _downhillMomentum] call GAIT_fnc_burstGravity;
                        private _stride = _sprintCeilingReference;
                        if !([_stride] call GAIT_fnc_paceReferenceValid) then {
                            _stride = [5.1,4.08] select _isCrouched;
                        };
                        private _loadBurst = 1 - 0.8 * _gearLbs / ((_gearLbs max 0) + 110);
                        private _flatPeak = _flatSprintPace * _loadPaceScale * (1 + (_flatBurstSetting - 1) * _loadBurst);
                        _flatPeak = [_flatPeak, _stride, _sprintClipScale, 1, _loadPaceScale] call GAIT_fnc_capSprintPace;
                        private _age = time - ((player getVariable ["GAIT_burstBill", []]) param [0,time]);
                        private _earnedKmh = [_flatPeak * 3.6 * _stride, _age, _gravity, _targetSpeed * 3.6 * _stride]
                            call GAIT_fnc_burstTargetKmh;
                        if (_burstOverLimitUntil < 0 && {_actualSpeedKmh >= 28} && {_earnedKmh > 30} && {_burstStrength >= 0.98}) then {
                            _burstOverLimitUntil = time + 3;
                        };
                        // Full headroom for two seconds, then one second back to 30.
                        private _allowance = (_burstOverLimitUntil - time) max 0 min 1;
                        _targetSpeed = [_targetSpeed, _burstStrength, _stride,
                            _earnedKmh, _allowance] call GAIT_fnc_burstPace;
                        _sprintPlaybackCeiling = _targetSpeed;
                    };
                    _pacePair set [1, _targetSpeed];
                    private _settledSprint = _gaitStanceOk && {_onGroundNow} &&
                        {(_movingAnimation select [8, 4]) in ["meva", "mspr"] ||
                            {"gaitsprint" in (_movingAnimation splitString "_")}} &&
                        {(_movingAnimation find "_amov") < 0} &&
                        {(([player] call GAIT_fnc_readPaceMoveInfo) param [3, 0]) >= 0.99} &&
                        {_horizontalSpeedMS > 0.3};
                    if (_settledSprint) then {
                        private _sample = [player getVariable ["GAIT_sprintReleaseSample", []], _turboPress,
                            diag_tickTime, _horizontalSpeedMS, getAnimSpeedCoef player, _targetSpeed]
                            call GAIT_fnc_stepSprintReleaseSample;
                        player setVariable ["GAIT_sprintReleaseSample", _sample];
                    };
                };
                missionNamespace setVariable ["GAIT_walkTargetMS", [-1, _nativeWalkPace * _walkReference] select (_walkReference > 0)];
                missionNamespace setVariable ["GAIT_sprintTargetMS", [-1, _targetSpeed * _sprintReference] select (_sprintReference > 0)];
                missionNamespace setVariable ["GAIT_paceCalibrated", _walkReference > 0 && {_sprintReference > 0}];
                missionNamespace setVariable ["GAIT_sprintReferenceCalibrated", _sprintReference > 0];
                missionNamespace setVariable ["GAIT_loadPaceMultiplier", _weightSpeedMult];

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
                private _releasePace = player getVariable ["GAIT_sprintReleasePace", []];
                private _releaseTaper = _releasePace isNotEqualTo [] && {!_turboHeld} &&
                    {!_locomotionExternalLock} && {!_isAceCarrying} && {_hasMovementInput};
                private _movingStance = _movingStanceYield &&
                    {_hasMovementInput} && {!_externalWalkLock} && {!_weaponYieldActive} &&
                    {[player, false, true] call GAIT_fnc_nativeMovementEligible};
                if (!_movingStance && {_stanceTravel isNotEqualTo []}) then {
                    player setVariable ["GAIT_stanceTravel", []];
                };
                private _weightedWalkPace = _nativeWalkPace;
                private _downhillWalkMultiplier = 1;
                if (_nativeWalk || {_releaseTaper} || {_carryContext}) then {
                    _weightedWalkPace = _nativeWalkPace * _loadPaceScale *
                        ([_gearLbs, _loadAnchors, _paceAnchors, _extraHeavyPenalty] call GAIT_fnc_walkingLoadMultiplier);
                    if (_downhillMovementContext) then {
                        _downhillWalkMultiplier = [_downhillGrade, _downhillBoostStartDegrees, _downhillBoostMaxDegrees]
                            call GAIT_fnc_downhillWalkMultiplier;
                    };
                };
                if (_isCrouched && {!_isSprinting} && {!_isAceCarrying}) then {
                    // The normal crouch and walk targets already include kit
                    // weight. Add only the fatigue component here.
                    private _rested = [_gearLbs, 1, 0.85] call GAIT_fnc_stancePaceCoefficient;
                    private _stanceFactor = ([_gearLbs, _reserveRatio, 0.85] call GAIT_fnc_stancePaceCoefficient) / _rested;
                    _targetSpeed = _targetSpeed * _stanceFactor;
                    _weightedWalkPace = _weightedWalkPace * _stanceFactor;
                };
                if (_wroteStanceSpeed && {!_stanceMotion} && {_stanceYieldActive} && {!_movingStance}) then {
                    [] call GAIT_fnc_releaseSpeedCoefficient;
                };
                _wroteStanceSpeed = _stanceMotion && {!_movingStance};
                private _resumingFromMovingStance = _wroteMovingStanceSpeed && {!_movingStance};
                _wroteMovingStanceSpeed = _movingStance;
                private _stanceCoefficient = 1;
                private _movingCarry = _carryMovementContext && {_movementEligible} && {_hasMovementInput};
                if (!_movingCarry) then {
                    _carryPaceSprint = false;
                    _carryRelease = [];
                } else {
                    private _walkGrade = [_hillWalkSlowdownMultiplier, _downhillWalkMultiplier] select (_downhillGrade < 0);
                    _targetSpeed = _carryWalkSpeed * _weightedWalkPace * _walkGrade;
                    _pacePair set [0, _targetSpeed];
                    if (_isSprinting) then {
                        private _carryScale = _nativeWalkPace * _weightSpeedMult * _loadPaceScale;
                        _freshSprintPace = _carrySprintFullSpeed * _carryScale * ([_slopeSpeedMultiplier, 1] select _downhillTravel);
                        private _carryFloor = (_carrySprintExhaustedSpeed * _carryScale * _walkGrade) max (1.06 * _targetSpeed);
                        _targetSpeed = [_freshSprintPace, _freshSprintPace, _sprintPaceReserve, _gearLbs, _carryFloor,
                            0.60, _deadSprintStrength > 0, _flatBurstSetting, _deadSprintStrength]
                            call GAIT_fnc_sprintReservePace;
                        if (_downhillTravel) then {_targetSpeed = _targetSpeed * _slopeSpeedMultiplier;};
                    };
                    _pacePair set [1, _targetSpeed];
                };
                missionNamespace setVariable ["GAIT_walkPaceTarget", _pacePair select 0];
                missionNamespace setVariable ["GAIT_sprintPaceTarget", _pacePair select 1];

                private _stanceReference = -1;
                if (_movingStance) then {
                    _stanceReference = [player, _movingAnimation, _stanceTravel, _slopeDegrees]
                        call GAIT_fnc_stanceTravelReference;
                };
                private _releaseCoefficient = -1;
                private _releasePlan = [];
                if (_releaseTaper) then {
                    private _releaseMode = player getVariable ["GAIT_sprintReleaseMode", "jog"];
                    private _direction = [_movementInput select 0, _movementInput select 1] call GAIT_fnc_slopeDirection;
                    private _releaseFamily = [player, [player] call GAIT_fnc_slopeWeaponFamily] call GAIT_fnc_sprintReturnFamily;
                    private _releasePose = _gaitPose;
                    if ((_releasePace param [3, -1]) >= 0) then {
                        private _observed = [_movingAnimation, _stanceTravel param [1, ""]] select _movingStance;
                        private _presentation = [currentWeapon player, _observed, [], _nativeWalk] call GAIT_fnc_locomotionPoseSnapshot;
                        _releaseFamily = _presentation param [1, _releaseFamily];
                        _releasePose = ["Perc", "Pknl"] select ((toLower _observed select [4, 4]) isEqualTo "pknl");
                    };
                    if (_releaseFamily isNotEqualTo "") then {
                        private _releaseClip = [_releaseFamily, _direction, _releasePose, _releaseMode] call GAIT_fnc_sprintReturnClip;
                        private _releaseFloor = ([_releaseClip] call GAIT_fnc_nativePaceFloor) * _loadPaceScale;
                        private _destinationPace = _targetSpeed;
                        if (_releaseMode isEqualTo "walk") then {
                            _destinationPace = _weightedWalkPace * _hillWalkSlowdownMultiplier;
                            if (_downhillWalkMultiplier > 1) then {
                                _destinationPace = (_weightedWalkPace max _releaseFloor) * _downhillWalkMultiplier;
                            };
                        };
                        _destinationPace = _destinationPace max _releaseFloor;
                        private _destinationReference = [player, _releaseClip, _slopeDegrees] call GAIT_fnc_releaseClipReference;
                        private _progress = [_releasePace select 0, diag_tickTime, _releasePace param [2, 1]]
                            call GAIT_fnc_sprintWalkProgress;
                        private _destinationMS = _destinationPace * _destinationReference;
                        private _plannedMS = [_releasePace, _destinationMS, _progress] call GAIT_fnc_sprintReleaseSpeed;
                        if (_stanceReference <= 0) then {
                            _stanceReference = [player, _movingAnimation, _slopeDegrees] call GAIT_fnc_releaseStrideReference;
                        };
                        _releaseCoefficient = [player, _releasePace, _movingAnimation, _releaseClip, _slopeDegrees,
                            _destinationPace, _stanceReference, _plannedMS] call GAIT_fnc_sprintReleaseCoefficient;
                        _releasePlan = [diag_tickTime, _releasePace select 0, currentWeapon player,
                            _releaseClip, _plannedMS, _destinationMS, _stanceReference, _releaseCoefficient, _progress];
                    };
                };
                player setVariable ["GAIT_releasePacePlan", _releasePlan];
                switch (true) do {
                    case (_patientHandling && {!_movingCarry}): {
                        if (_casualtyClip isEqualTo "drag" && {_movementEligible} && {_hasMovementInput}) then {
                            private _terrainPace = [_downhillGrade, "drag"] call GAIT_fnc_casualtyTerrainMultiplier;
                            _targetSpeed = _nativeWalkPace * (1 - (0.10 * _loadShare)) * _loadPaceScale * _terrainPace;
                            _currentSpeed = [player, _targetSpeed, true] call GAIT_fnc_applyNativeMovement;
                        } else {
                            [] call GAIT_fnc_releaseSpeedCoefficient;
                        };
                    };
                    case _movingStance: {
                        private _coefficient = _releaseCoefficient;
                        if (_coefficient < 0) then {
                            _coefficient = ((_stanceTravel select 2) / (_stanceReference max 0.1)) min 2.5;
                        };
                        if (_sprintPlaybackCeiling > 0) then {_coefficient = _coefficient min _sprintPlaybackCeiling;};
                        _currentSpeed = [player, _coefficient, false, false, true, _loadPaceScale, true]
                            call GAIT_fnc_applyNativeMovement;
                    };
                    case _stanceMotion: {
                        _stanceCoefficient = [_gearLbs, _reserveRatio, _stanceDepth] call GAIT_fnc_stancePaceCoefficient;
                        _currentSpeed = [player, _stanceCoefficient * _loadPaceScale, false, false, true]
                            call GAIT_fnc_applyNativeMovement;
                    };
                    case (_isProne && {_hasMovementInput} && {_movementEligible} && {!_externalWalkLock}): {
                        _stanceCoefficient = [_gearLbs, _reserveRatio, 1] call GAIT_fnc_stancePaceCoefficient;
                        _currentSpeed = [player, _stanceCoefficient * _loadPaceScale, false, false, false, _loadPaceScale]
                            call GAIT_fnc_applyNativeMovement;
                    };
                    case (_nativeWalk && {!_releaseTaper}): {
                        if (_hasMovementInput && {_movementEligible} && {_gaitStanceOk} && {!_externalWalkLock} &&
                            {(_movingAnimation select [8, 4]) in ["mwlk", "mtac"]}) then {
                            private _walkFloor = ([_movingAnimation] call GAIT_fnc_nativePaceFloor) * _loadPaceScale;
                            private _walkTarget = (_weightedWalkPace max _walkFloor) * _downhillWalkMultiplier;
                            _currentSpeed = [player, _walkTarget, false, false, false, _loadPaceScale] call GAIT_fnc_applyNativeMovement;
                        } else {
                            _currentSpeed = [player] call GAIT_fnc_releaseNativeWalkPace;
                        };
                    };
                    case (_movingCarry || {_gaitMovementEnabled && {_movementEligible} && {_gaitStanceOk} && {_hasMovementInput}}): {
                        private _startingSprint = _isSprinting && {_sprintBraceEndTime > time};
                        if (_movingCarry && {player isNotEqualTo (missionNamespace getVariable ["GAIT_nativeOwner", objNull])}) then {
                            _currentSpeed = _nativeWalkPace * _idlePace * _loadPaceScale;
                        };
                        private _ramp = if (_startingSprint) then {_sprintStartBraceLerp} else {
                            [_speedLerp, 1] select _walkStartBraceActive
                        };
                        private _rampTarget = if (_startingSprint) then {
                            (_activeBraceSpeed * ([1, _nativeWalkPace] select _movingCarry)) min _targetSpeed
                        } else {
                            if (_walkStartBraceActive) then {_targetSpeed * _walkStartBraceFactor} else {_targetSpeed}
                        };
                        private _sharedSprintRamp = !_isAceCarrying || {_movingCarry};
                        if (_isSprinting && {_resumingFromMovingStance}) then {
                            // A slower stride can need a much higher rate to
                            // carry speed. Never apply that rate to a sprint.
                            _currentSpeed = _currentSpeed min _rampTarget;
                        };
                        if (_isSprinting && {_sharedSprintRamp} && {_turboPress isNotEqualTo _lastSprintPressUsed}) then {
                            _lastSprintPressUsed = _turboPress;
                            // An elevated jog playback rate cannot carry over
                            // to the faster sprint clip after a re-press at any grade.
                            _currentSpeed = _currentSpeed min _rampTarget;
                        };
                        if (_sharedSprintRamp && {_isSprinting} && {!_startingSprint}) then {
                            private _speedIncreasing = _rampTarget > _currentSpeed;
                            if (_speedIncreasing) then {
                                _ramp = [_ramp, _accelerationScale] call GAIT_fnc_sprintAccelerationRamp;
                                _ramp = [_ramp, 1 + (2 * _deadSprintStrength)] call GAIT_fnc_scaleInertiaRamp;
                            };
                            if (_onGroundNow) then {
                                _ramp = [_ramp, _slopeDegrees, _speedIncreasing, _uphillStartDegrees, true]
                                    call GAIT_fnc_slopeSprintRamp;
                            };
                            // A new climb still brakes promptly to fresh uphill pace.
                            if (!_speedIncreasing && {_reserveRatio < 0.50} &&
                                {_slopeDegrees <= _uphillStartDegrees || {_currentSpeed <= _freshSprintPace}}) then {
                                _ramp = _ramp min 0.04;
                            };
                        };
                        if (!_turboHeld && {_sharedSprintRamp} && {!_locomotionExternalLock} &&
                            {!_walkStartBraceActive} && {_rampTarget < _currentSpeed}) then {
                            // The same scalar decays toward the current jog
                            // target for every direction. Input has no timer.
                            _ramp = [1.50, true]
                                call GAIT_fnc_jogDecelerationRamp;
                        };
                        // Heavier kits take a few more steps to reach the burst target.
                        if (_burst && {!_startingSprint}) then {_ramp = [1.35 + 0.40 * _loadShare, true] call GAIT_fnc_jogDecelerationRamp;};
                        if (_movingCarry) then {
                            // ACE chooses the carry clip and direction throughout the taper.
                            if (_turboHeld || {_locomotionExternalLock} || {_horizontalSpeedMS < 0.15}) then {
                                _carryRelease = [];
                            } else {
                                if (_carryPaceSprint && {_horizontalSpeedMS > 0.25}) then {
                                    private _releaseGrade = [_downhillGrade, _slopeDegrees] select (_slopeDegrees >= 0);
                                    _carryRelease = [diag_tickTime, _currentSpeed, [_releaseGrade] call GAIT_fnc_sprintReleaseSlopeScale];
                                };
                            };
                            _carryPaceSprint = _isSprinting;
                        };
                        if (_movingCarry && {_carryRelease isNotEqualTo []}) then {
                            _carryRelease params ["_releaseStart", "_releaseSpeed", "_releaseScale"];
                            private _progress = [_releaseStart, diag_tickTime, _releaseScale] call GAIT_fnc_sprintWalkProgress;
                            _currentSpeed = [_releaseSpeed, _targetSpeed, _progress] call GAIT_fnc_sprintWalkPace;
                            if (_progress >= 1) then {_carryRelease = [];};
                        } else {
                            if (_releaseCoefficient < 0) then {
                                _currentSpeed = [_currentSpeed, _rampTarget, _ramp, _dt] call GAIT_fnc_stepSpeedCoefficient;
                            } else {
                                _currentSpeed = _releaseCoefficient;
                            };
                        };
                        private _coef = _currentSpeed;
                        if (_sprintPlaybackCeiling > 0) then {_coef = _coef min _sprintPlaybackCeiling;};
                        if (_locomotionExternalLock || {_turboHeld && {!_isForwardHeld}}) then {
                            private _limit = [_effectiveNormalSpeed * _downhillJogMultiplier * _loadPaceScale, _targetSpeed] select _movingCarry;
                            _coef = _coef min _limit;
                        };
                        _currentSpeed = [player, _coef, _isAceCarrying, false, false, _loadPaceScale]
                            call GAIT_fnc_applyNativeMovement;

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
                                {_sprintPoseBridge || {([player, animationState player] call GAIT_fnc_locomotionMayFinishMoveBlend)} ||
                                {[player, _movementInput, _locomotionExternalLock] call GAIT_fnc_uphillSprintContactPending}};
                            if (!_keepMovingBlend) then {
                                // No commanded movement means no scalar momentum.
                                // The engine handles the stop blend and current side/back input.
                                _currentSpeed = _idlePace;
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
                missionNamespace setVariable ["GAIT_stanceWork", [_stanceActivity, _stanceDepth, _stanceRate, _stanceCoefficient]];
                // Movement-family ownership is independent of forward sprint
                // effort. Pure A/D keeps native directional selection in the
                // same graph without changing reserve/brace or sideways caps.
                // Publish permission, not a scheduled snapshot of Turbo.
                private _fastMoveIntent = _gaitMovementEnabled && {_gaitStanceOk} && {!_isAceCarrying} && {!_isAceDragging};
                isNil {
                    missionNamespace setVariable ["GAIT_braceActive", _isSprinting && {_sprintBraceEndTime > time}];
                    missionNamespace setVariable ["GAIT_braceEndTime", _sprintBraceEndTime];
                    [player, _fastMoveIntent, _movementInput, _locomotionExternalLock] call GAIT_fnc_updateSlopeLocomotion;
                };
                if (_newNormalBrace || {_normalBraceUntil >= 0}) then {
                    _keepNormalBrace = !_burst && {_isSprinting} && {_isForwardHeld} && {_onGroundNow} &&
                        {_movementEligible} && {!_nativeWalk} && {!_patientHandling} && {!_locomotionExternalLock} &&
                        {!_stanceYieldActive} && {!_weaponYieldActive} && {!(player getVariable ["GAIT_isTripping",false])} &&
                        {!(call GAIT_fnc_readAimInput)} && {!(call GAIT_fnc_getWeaponSlotInput)} &&
                        {!([player] call GAIT_fnc_readFireInput)} &&
                        {!([player getVariable ["NAVSPECWARGRU2_CQB_ReadyAnim",""]] call GAIT_fnc_preserveLocomotionGesture)};
                    if (_newNormalBrace && {_keepNormalBrace} && {_normalBraceUntil < 0} &&
                        {[toLower gestureState player] call GAIT_fnc_rifleGestureFree}) then {
                        player playActionNow "GAIT_NormalBrace";
                        _normalBraceUntil = time + 0.38;
                    };
                };
                private _burstReserve = _availableReserve - (player getVariable ["GAIT_burstDue",0]);
                if (_burstStarted) then {_reserveHandoff = false; _rifleYielded = false};
                if (_burst && {_burstReserve < 0.20} && {currentWeapon player != ""} &&
                    {currentWeapon player == primaryWeapon player}) then {_reserveHandoff = true};
                if (_rifleTracking && {!_burst || {_reserveHandoff}}) then {
                    _allowRifleCatch = _isForwardHeld && {_horizontalSpeedMS > 1.5} && {_movementEligible} &&
                        {!_locomotionExternalLock} && {!_patientHandling} && {!_weaponYieldActive} &&
                        {!_stanceYieldActive} && {stance player == "STAND"} && {!(call GAIT_fnc_readAimInput)} &&
                        {!(call GAIT_fnc_getWeaponSlotInput)} && {!([player] call GAIT_fnc_readFireInput)} &&
                        {!(player getVariable ["GAIT_isTripping",false])} && {!([player] call GAIT_fnc_readWeaponSwitching)};
                };
                if (_burst) then {
                    _rifleBurst = true;
                    if (!_rifleYielded) then {
                        _rifleTracking = [player,!_reserveHandoff,_gearLbs,_burstReserve,
                            _slopeDegrees,_horizontalSpeedMS,_movementInput select 1,_allowRifleCatch,_reserveHandoff] call GAIT_fnc_updateRifleRun;
                        if (!_rifleTracking) then {
                            [player,false] call GAIT_fnc_updateRifleRun;
                            _rifleYielded = true;
                        };
                    };
                };
                if (_downhillGrade <= ([-22,-16] select (_shuffle != "")) && {_walkingForRecovery} &&
                    {_gaitMovementEnabled} && {_isOnFoot} && {_onGroundNow} && {_stance == "STAND"} &&
                    {_isForwardHeld} && {abs (_movementInput select 1) < 0.2} && {!_turboHeld} &&
                    {_horizontalSpeedMS > 0.25} && {!_isAceCarrying} && {!_isAceDragging} && {!_slopeJogOverride} &&
                    {!_locomotionExternalLock} && {!_stanceYieldActive} && {!_weaponYieldActive} && {!_rifleTracking} &&
                    {(_movingAnimation select [12,8]) in ["slowwrfl","slowwpst","slowwlnr"]} &&
                    {(_movingAnimation select [20]) in ["df","df_gait","df_ver2"]} && {currentWeapon player != ""} &&
                    {!(player getVariable ["GAIT_isTripping",false])} &&
                    {!(call GAIT_fnc_readAimInput)} && {!([player] call GAIT_fnc_readFireInput)} &&
                    {!([player getVariable ["NAVSPECWARGRU2_CQB_ReadyAnim",""]] call GAIT_fnc_preserveLocomotionGesture)}) then {
                    private _gesture = toLower gestureState player;
                    if ([_gesture] call GAIT_fnc_rifleGestureFree && {_gesture != "gait_normalbrace"}) then {
                        private _moves = getUnitMovesInfo player;
                        private _cycles = ((round ((_moves select 2)/1.18)) max 1) min 5;
                        private _phase = ((_moves select 0)*_cycles + 1 - 0.332) mod 1;
                        // Change the lead foot or the depth of the step at a plant.
                        if (_shuffle == "" || {_phase < 0.13} || {_phase > 0.91}) then {
                            private _normal = surfaceNormal (getPosWorld player);
                            private _crossfall = (_normal select 0)*cos(getDir player) - (_normal select 1)*sin(getDir player);
                            _shuffle = [-_downhillGrade,_crossfall,_shuffle] call GAIT_fnc_shufflePose;
                        };
                        private _drift = abs (((_phase-(_moves select 5)+1.5) mod 1)-0.5);
                        if (_gesture != _shuffle || {_drift > 0.065}) then {
                            player switchGesture [_shuffle,_phase,[0,_moves select 8] select (_gesture find "gait_shuffle" == 0),false];
                        };
                        _keepShuffle = true;
                    };
                };
                if (_debugHudEnabled && {(time - _lastDebugHudTime) >= 0.10}) then {
                    _lastDebugHudTime = time;
                    private _debugFamily = [player] call GAIT_fnc_slopeWeaponFamily;
                    hintSilent parseText format [
                        "<t align='left' size='0.82'>GAIT %19<br/>Travel grade: %1 degrees | Speed: %2 km/h<br/>Input F/R: %3 / %4<br/>Coefficient: %5 | Sprint reserve: %6%%<br/>Animation: %7<br/>ACE bridge: %8 | Block sprint / walk: %9 / %10<br/>Family: %11 | Active: %12 | Jog / sprint target: %13 / %14<br/>Foundation: %15 | Sprint ref: %16 | Full profile: %17<br/>Carried load: %18 lb</t>",
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
                        _gearLbs toFixed 1,
                        missionNamespace getVariable ["GAIT_versionString", "?"]
                    ];
                };
            } else {
                // Fast Carry pickup/lift owns its animation.
                [player] call GAIT_fnc_endBurst;
                _deadSprintElapsed = -1;
                _deadSprintIntentHeld = false;
                _uphillPaceExposure = 0;
                missionNamespace setVariable ["GAIT_uphillPaceExposure", 0];
                missionNamespace setVariable ["GAIT_uphillPaceMultiplier", 1];
                _downhillTripSprintStartTime = -1;
                _downhillTripHighSpeedStartTime = -1;
                _depletedRunTime = 0;
                _wroteStanceSpeed = false;
                _wroteMovingStanceSpeed = false;
                _braceMomentumState = [false, -999, 0, 0, 0];
                _downhillMomentum = 0;
                _loadPaceTime = 0;
                _wasSprinting = false;
                _sprintBraceEndTime = -1;
                _carryPaceSprint = false;
                _carryRelease = [];
                missionNamespace setVariable ["GAIT_braceActive", false];
                missionNamespace setVariable ["GAIT_braceEndTime", -1];
                missionNamespace setVariable ["GAIT_stopBraceRearm", 0];
                _currentSpeed = 1;
                [] call GAIT_fnc_releaseNativeMovement;
            };
        } else {
            [player] call GAIT_fnc_endBurst;
            _downhillTripSprintStartTime = -1;
            _downhillTripHighSpeedStartTime = -1;
            _depletedRunTime = 0;
            _wroteStanceSpeed = false;
            _wroteMovingStanceSpeed = false;
            _lastSprintPressUsed = -1;
            _braceMomentumState = [false, -999, 0, 0, 0];
            _downhillMomentum = 0;
            _loadPaceTime = 0;
            _carryPaceSprint = false;
            _carryRelease = [];
            missionNamespace setVariable ["GAIT_braceActive", false];
            missionNamespace setVariable ["GAIT_braceEndTime", -1];
            missionNamespace setVariable ["GAIT_stopBraceRearm", 0];
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


        if (_normalBraceUntil >= 0 && {!_keepNormalBrace || {time >= _normalBraceUntil}}) then {
            if (toLower gestureState player == "gait_normalbrace") then {player playActionNow "GAIT_EndSprintGesture"};
            _normalBraceUntil = -1;
        };
        if (_shuffle != "" && {!_keepShuffle}) then {
            if (toLower gestureState player == _shuffle) then {player playActionNow "GAIT_EndSprintGesture"};
            _shuffle = "";
        };
        if (!_rifleBurst) then {
            _reserveHandoff = false;
            if (_rifleTracking) then {
                _rifleTracking = [player,false,0,1,0,0,0,_allowRifleCatch] call GAIT_fnc_updateRifleRun;
            };
            _rifleYielded = false;
        };
        uiSleep _tickRate;
    };
};
