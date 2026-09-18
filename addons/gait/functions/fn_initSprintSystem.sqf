/*
    GAIT
    Standalone client-side sprint/momentum/brace system.

    Workshop/mod scope:
    - Custom sprint speed, reserve bridge, brace step, and momentum ramp
    - ACE Advanced Fatigue integration for physiology/acidosis/muscle damage
    - Native locomotion with scoped ACE fatigue movement-lock integration
    - Custom weapon sway recovery, tinnitus, and hearing reduction
    - GAIT visual overlays remain disabled as in the supplied 1.6.1 source
    - Heartbeat loop removed; ACE Advanced Fatigue owns pulse/heartbeat audio

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
    if (_mode isEqualType "") then {
        _mode = ["Full GAIT Control", "ACE-Friendly Hybrid", "Minimal Movement Override", "Visuals/Audio Only", "Disabled"] find _mode;
        if (_mode < 0) then {_mode = 1;};
    };

    _mode
};

GAIT_fnc_compatModeName = {
    private _names = ["Full GAIT Control", "ACE-Friendly Hybrid", "Minimal Movement Override", "Visuals/Audio Only", "Disabled"];
    _names param [call GAIT_fnc_compatModeIndex, "ACE-Friendly Hybrid"]
};

GAIT_fnc_modeIsActive = {
    (missionNamespace getVariable ["GAIT_ss_enabled", true]) && {(call GAIT_fnc_compatModeIndex) < 4}
};

GAIT_fnc_modeAllowsMovement = {
    (call GAIT_fnc_modeIsActive) && {(call GAIT_fnc_compatModeIndex) in [0, 1]}
};

GAIT_fnc_modeAllowsSway = {
    (call GAIT_fnc_modeIsActive) && {(call GAIT_fnc_compatModeIndex) in [0, 1, 2]}
};

GAIT_fnc_modeAllowsEffects = {
    (call GAIT_fnc_modeIsActive) && {(call GAIT_fnc_compatModeIndex) in [0, 1, 2, 3]}
};

GAIT_fnc_modeAllowsHearing = {
    (call GAIT_fnc_modeIsActive) && {(call GAIT_fnc_compatModeIndex) in [0, 1, 2]}
};

GAIT_fnc_modeAllowsAceLockClearing = {
    (call GAIT_fnc_modeAllowsMovement) && {missionNamespace getVariable ["GAIT_ss_clearAceMovementLocks", true]}
};

GAIT_fnc_isSuspendedContext = {
    if (isNull player) exitWith {true};
    if (!alive player) exitWith {true};

    if ((missionNamespace getVariable ["GAIT_ss_suspendWhileUnconscious", true]) && {player getVariable ["ACE_isUnconscious", false]}) exitWith {true};

    // v1.6.0 (FIX 2 - Zeus / remote control): GAIT polls inputAction(MoveForward/
    // Turbo) and writes movement to `player`. When the Zeus/curator interface is
    // open, or when the local input is driving a remote-controlled unit, those
    // key states are still readable but the engine is NOT routing them to the
    // avatar - so GAIT was injecting movement the avatar would not otherwise make
    // (the "press W+Shift in Zeus and my body walks off" bug). Suspend GAIT
    // whenever direct first-person/third-person control of the avatar is not in
    // effect. These checks run regardless of the suspendInSpectator toggle so the
    // avatar can never be driven from a delegated context.
    //
    // Zeus / curator display open (RscDisplayCurator == 312).
    if (!isNull (findDisplay 312)) exitWith {true};
    // BIS remote control leaves a back-reference on the controlling avatar.
    if (!isNull (player getVariable ["bis_fnc_moduleRemoteControl_unit", objNull])) exitWith {true};

    if (missionNamespace getVariable ["GAIT_ss_suspendInSpectator", true]) then {
        private _cam = cameraOn;

        // Normal first-person/third-person player camera is player or vehicle player.
        // Spectator/Zeus/remote-control cameras point at a different entity; if the
        // camera is not on our avatar, our input is not driving our avatar.
        if (!isNull _cam && {_cam != player} && {_cam != vehicle player}) exitWith {true};
    };

    false
};

// =====================================================
// SAFE SPRINT AUDIO / HEARING HELPERS
// =====================================================
GAIT_fnc_playCfgSoundIfExists = {
    params [
        ["_soundClass", "", [""]]
    ];

    if (_soundClass isEqualTo "") exitWith {};

    if (isClass (missionConfigFile >> "CfgSounds" >> _soundClass)) then {
        playSound _soundClass;
    };
};

GAIT_fnc_setSprintHearing = {
    params [
        ["_volume", 1, [0]],
        ["_fade", 0.2, [0]],
        ["_enabled", true, [false]]
    ];

    _volume = (_volume max 0) min 1;

    // Avoid ACE _lowestVolume errors by ensuring the map exists and by
    // restoring with volume 1 instead of removing the entry every frame.
    if (!isNil "ace_common_fnc_setHearingCapability") then {
        if (isNil "ace_common_setHearingCapabilityMap") then {
            ace_common_setHearingCapabilityMap = createHashMap;
        };

        if (!_enabled) then {
            _volume = 1;
        };

        ["GAIT_sprint_exhaustion", _volume, true, _fade] call ace_common_fnc_setHearingCapability;
    } else {
        _fade fadeSound _volume;
        _fade fadeRadio _volume;
    };
};

// =====================================================
// ACE ADVANCED FATIGUE INTEGRATION
// ACE keeps its physiology model: anaerobic reserve, aerobic reserve,
// acidosis, muscle damage, breathing, and stamina bar.
// MAV keeps movement feel: sprint speed, brace, momentum, carry speed,
// tunnel vision, tinnitus, and custom weapon sway.
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

// Traversal helpers are definitions only, loaded before any client loops start.
call compile preprocessFileLineNumbers "\gait\functions\fn_traversalHelpers.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_slopePaceModel.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_locomotionPace.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_braceMomentum.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_gearInertia.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_downhillPace.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_uphillBrake.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_slopeLocomotion.sqf";
call compile preprocessFileLineNumbers "\gait\functions\fn_nativeController.sqf";
[] call GAIT_fnc_installLocomotionController;

GAIT_fnc_tripPlayer = {
    params [
        ["_duration", 1.25, [0]]
    ];

    if (isNull player) exitWith {};
    if (player getVariable ["GAIT_isTripping", false]) exitWith {};
    if !(alive player) exitWith {};
    if (player getVariable ["ACE_isUnconscious", false]) exitWith {};

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
            [] call GAIT_fnc_releaseNativeMovement;
            _lastPlayer = player;

            if (missionNamespace getVariable ["GAIT_ss_resetOnRespawn", true]) then {
                ["player_object_changed"] call GAIT_fnc_resetEffects;
            };

            if (!_startupShown) then {
                _startupShown = true;

                [] spawn {
                    uiSleep 3;

                    if (missionNamespace getVariable ["GAIT_ss_showStartupMessage", true]) then {
                        private _aceText = if (call GAIT_fnc_aceAdvancedFatigueActive) then {"ACE AF bridge active"} else {"ACE AF bridge waiting/disabled"};
                        systemChat format ["GAIT active | Preset: %1 | Mode: %2 | %3", missionNamespace getVariable ["GAIT_ss_preset", "Balanced"], call GAIT_fnc_compatModeName, _aceText];
                    };

                    if (isMultiplayer && {missionNamespace getVariable ["GAIT_ss_showServerIndicator", true]}) then {
                        systemChat "GAIT: Multiplayer CBA settings may be controlled by the server or mission.";
                    };

missionNamespace setVariable ["GAIT_versionString", "1.8.0-alpha4"];
[format ["Initialized v%1. Preset=%2 | Mode=%3 | ACE_AF=%4", missionNamespace getVariable ["GAIT_versionString", "?"], missionNamespace getVariable ["GAIT_ss_preset", "Balanced"], call GAIT_fnc_compatModeName, call GAIT_fnc_aceAdvancedFatigueActive]] call GAIT_fnc_log;

                };
            };
        };

        call GAIT_fnc_installNativeAceBridge;
        private _suspended = call GAIT_fnc_isSuspendedContext;
        if (_suspended && {!_lastSuspended}) then {
            if (missionNamespace getVariable ["GAIT_ss_resetOnRespawn", true]) then {
                ["suspended_context"] call GAIT_fnc_resetEffects;
            };
        };
        _lastSuspended = _suspended;

        uiSleep 0.50;
    };
};

// =====================================================
// OLD VIGNETTE UI CLEANUP ONLY
// No GUI overlay is used for tunnel vision anymore.
// This only deletes leftover controls from the previous UI-vignette version.
// =====================================================
GAIT_fnc_clearOldExhaustionVignette = {
    disableSerialization;

    private _ctrls = uiNamespace getVariable ["GAIT_exhaustionVignetteCtrls", []];

    {
        if (!isNull _x) then {
            ctrlDelete _x;
        };
    } forEach _ctrls;

    uiNamespace setVariable ["GAIT_exhaustionVignetteCtrls", []];
};

// v1.6.0 (FIX 4 + CHG 5 - remove ALL post-process FX):
// This function is now a hard no-op that tears down any post-process handles
// GAIT may have created and never recreates them. Two reasons:
//   1) The previous version committed a permanent baseline RadialBlur (0.002)
//      and ChromAberration (0.001) even at strength 0, producing the faint
//      "blurry screen outline" that was visible while completely still.
//   2) ACE Advanced Fatigue owns visual fatigue now, so GAIT's tunnel-vision /
//      blur / color-correction / aberration stack is removed entirely.
// It ignores _strength on purpose: even if a saved profile or server forces
// GAIT_ss_visualFxEnabled = true, no post-process effect can ever be applied.
// REVERT (to bring GAIT post FX back): restore the original body below this
// block from version control, and set GAIT_ss_visualFxEnabled default to true
// in fn_registerSettings.sqf.
GAIT_fnc_setTunnelVisionFX = {
    params [
        ["_strength", 0, [0]],
        ["_instant", false, [false]]
    ];

    // Destroy any post-process handles a prior call/version may have created,
    // returning the screen to a clean, effect-free state.
    {
        if (!isNil _x) then {
            private _h = missionNamespace getVariable [_x, -1];
            if (_h isEqualType 0 && {_h >= 0}) then {
                _h ppEffectEnable false;
                ppEffectDestroy _h;
            };
            missionNamespace setVariable [_x, nil];
        };
    } forEach ["GAIT_ppTunnelCC", "GAIT_ppTunnelRB", "GAIT_ppTunnelDB", "GAIT_ppTunnelCA"];

    // Clean up any leftover GUI vignette controls from the legacy UI version.
    if (!isNil "GAIT_fnc_clearOldExhaustionVignette") then {
        [] call GAIT_fnc_clearOldExhaustionVignette;
    };
};

// v1.6.0 (CHG 5): proactively tear down any post-process handles that may
// already exist this session, so the screen is clean even though the loop no
// longer drives the (now no-op) FX function while visual FX is disabled.
[0, true] call GAIT_fnc_setTunnelVisionFX;


//Squad-like stamina system
[] spawn {
    waitUntil { sleep 0.25; !isNull player };
    waitUntil { sleep 0.25; !isNull findDisplay 46 };

    // =====================================================
    // SETTINGS
    // =====================================================

    private _recoveryTime = 4;          // seconds after releasing Shift
    private _restingAimCoef = 0.02;       // baseline rested aim
    private _runningAimCoef = 2.0;      // initial sprint sway penalty

    missionNamespace setVariable ["GAIT_shiftHeld", false];
    missionNamespace setVariable ["GAIT_lastShiftRelease", -999];
    missionNamespace setVariable ["GAIT_lastForwardKeyRelease", -999];
    missionNamespace setVariable ["GAIT_currentAimCoef", _restingAimCoef];
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







    player setCustomAimCoef _restingAimCoef;

    // =====================================================
    // WEAPON SWAY RECOVERY LOOP
    // Controls sprint sway recovery and reduced walking sway in one place.
    // Do not add another setCustomAimCoef loop elsewhere or they will fight.
    // =====================================================

    [] spawn {
        private _restingAimCoef = missionNamespace getVariable ["GAIT_ss_restingAimCoef", 0.02];       // standing / fully recovered sway
        private _walkingAimCoef = missionNamespace getVariable ["GAIT_ss_walkingAimCoef", 0.01];       // walking sway; lower = steadier while walking
        private _runningAimCoef = missionNamespace getVariable ["GAIT_ss_runningAimCoef", 2.0];        // sprint sway penalty
        private _recoveryTime = missionNamespace getVariable ["GAIT_ss_swayRecoveryTime", 6.0];          // seconds to recover after sprint
        private _walkingSpeedThreshold = missionNamespace getVariable ["GAIT_ss_walkingSpeedThreshold", 0.6]; // any non-sprint movement: slow walk, fast walk, combat pace, jog

        private _recovering = false;
        private _recoveryStartTime = -999;
        private _recoveryStartCoef = _runningAimCoef;

        missionNamespace setVariable ["GAIT_currentAimCoef", _restingAimCoef];
        player setCustomAimCoef _restingAimCoef;

        while {true} do {
            private _swayEnabled = missionNamespace getVariable ["GAIT_ss_swayEnabled", true];
            _restingAimCoef = missionNamespace getVariable ["GAIT_ss_restingAimCoef", 0.02];
            _walkingAimCoef = missionNamespace getVariable ["GAIT_ss_walkingAimCoef", 0.01];
            _runningAimCoef = missionNamespace getVariable ["GAIT_ss_runningAimCoef", 2.0];
            _recoveryTime = missionNamespace getVariable ["GAIT_ss_swayRecoveryTime", 6.0];
            _walkingSpeedThreshold = missionNamespace getVariable ["GAIT_ss_walkingSpeedThreshold", 0.6];

            if (alive player && {call GAIT_fnc_modeAllowsSway} && {_swayEnabled} && {!(call GAIT_fnc_isSuspendedContext)}) then {
                private _isOnFoot = isNull objectParent player;
                private _isForwardHeld = (inputAction "MoveForward") > 0.05;
                private _isSprinting = ((inputAction "Turbo") > 0) && {_isForwardHeld} && {_isOnFoot};
                private _isWalking = _isOnFoot && {!_isSprinting} && {(abs (speed player)) > _walkingSpeedThreshold};

                private _baselineAimCoef = if (_isWalking) then {
                    _walkingAimCoef
                } else {
                    _restingAimCoef
                };

                private _targetAimCoef = _baselineAimCoef;

                if (_isSprinting) then {
                    // While sprinting, force the exact sprint sway penalty.
                    _targetAimCoef = _runningAimCoef;
                    _recovering = false;
                    _recoveryStartTime = -999;
                    _recoveryStartCoef = _runningAimCoef;

                    missionNamespace setVariable ["GAIT_lastShiftRelease", time];
                } else {
                    private _currentStored = missionNamespace getVariable ["GAIT_currentAimCoef", _baselineAimCoef];

                    // Start recovery only once after sprinting, or if we are still above the current baseline.
                    if (!_recovering && {_currentStored > _baselineAimCoef}) then {
                        _recovering = true;
                        _recoveryStartTime = time;
                        _recoveryStartCoef = _currentStored;
                    };

                    if (_recovering) then {
                        private _elapsed = time - _recoveryStartTime;
                        private _progress = _elapsed / _recoveryTime;
                        _progress = (_progress max 0) min 1;

                        // Linear recovery over _recoveryTime from current sprint sway to the active baseline.
                        // The active baseline is lower while walking, so walking stays steadier after recovery.
                        _targetAimCoef = _recoveryStartCoef - ((_recoveryStartCoef - _baselineAimCoef) * _progress);

                        if (_progress >= 1) then {
                            _targetAimCoef = _baselineAimCoef;
                            _recovering = false;
                        };
                    };
                };

                missionNamespace setVariable ["GAIT_currentAimCoef", _targetAimCoef];
                player setCustomAimCoef _targetAimCoef;
            } else {
                missionNamespace setVariable ["GAIT_currentAimCoef", 1];
                player setCustomAimCoef 1;
            };

            uiSleep 0.02;
        };
    };

    // =====================================================
    // OLD FATIGUE LOOP REMOVED
    // The custom sprint endurance system below is now the only
    // block that writes fatigue. This prevents fatigue/sway tug-of-war.
    // =====================================================
};


/////////////////////// SPRINT SETTINGS ////////////////////////////
// - Weight-independent sprint reserve.
// - Uses your existing values.
// - Full sprint reserve lasts 8 seconds.
// - Once empty, speed smoothly drops toward 0.85.
// - Stop sprinting for about 5 seconds to fully recover.
// - Fatigue/panting effects only appear after the sprint reserve is exhausted.
// - Does not override Fast Carry pickup animation.
[] spawn {
    waitUntil { sleep 0.25; !isNull player };

    private _normalSpeed = missionNamespace getVariable ["GAIT_ss_normalSpeed", 0.86];

    // Sprint reserve settings
    private _sprintReserveMax = missionNamespace getVariable ["GAIT_ss_sprintReserveMax", 25.0];        // seconds of full sprint
    private _sprintRecoverTime = missionNamespace getVariable ["GAIT_ss_sprintRecoverTime", 10.0];       // seconds to fully recover when not sprinting
    private _sprintReserve = _sprintReserveMax;

    // Normal sprint speeds
    private _sprintFullSpeed = missionNamespace getVariable ["GAIT_ss_sprintFullSpeed", 1.28];        // full-speed sprint while reserve remains
    private _sprintExhaustedSpeed = missionNamespace getVariable ["GAIT_ss_sprintExhaustedSpeed", 0.89];   // exhausted sprint speed after reserve is empty

    // Carry movement speeds
    private _carryWalkSpeed = missionNamespace getVariable ["GAIT_ss_carryWalkSpeed", 0.80];
    private _carrySprintFullSpeed = missionNamespace getVariable ["GAIT_ss_carrySprintFullSpeed", 1.50];
    private _carrySprintExhaustedSpeed = missionNamespace getVariable ["GAIT_ss_carrySprintExhaustedSpeed", 0.9];

    // Visual fatigue / panting settings
    // These preserve your fatigue cap style while no longer hiding fatigue effects.
    private _freshFatigue = missionNamespace getVariable ["GAIT_ss_freshFatigue", 0.05];           // low visible fatigue during the sprint reserve
    private _exhaustedFatigue = missionNamespace getVariable ["GAIT_ss_exhaustedFatigue", 0.85];       // fatigue effect level after reserve is exhausted
    private _fatigueRecoverRate = (_exhaustedFatigue - _freshFatigue) / _sprintRecoverTime;

    // ACE hearing reduction while sprint reserve is depleted.
    // 1.0 = normal hearing, 0.50 = 50% hearing.
    private _hearingMinVolume = missionNamespace getVariable ["GAIT_ss_hearingMinVolume", 0.20];
    private _hearingFadeDuration = missionNamespace getVariable ["GAIT_ss_hearingFadeDuration", 0.20];
    private _lastHearingVolume = 1.0;

    // Unarmed/no-weapon sprint normalizer.
    // This prevents holstering your weapon from making sprint speed much faster.
    private _unarmedSprintNormalizer = missionNamespace getVariable ["GAIT_ss_unarmedSprintNormalizer", 0.725];

    // Gear-weight speed gate.
    // Arma loadAbs is not literal pounds; this mission uses loadAbs / 10 as displayed pounds.
    // Lower carried weight gets a small overall speed bonus and a less severe brace-step dip.
    private _loadAbsPerLb = missionNamespace getVariable ["GAIT_ss_loadAbsPerLb", 10];
    private _lightSpeedBonus = missionNamespace getVariable ["GAIT_ss_lightSpeedBonus", 1.08];       // 0-35 lb
    private _mediumSpeedBonus = missionNamespace getVariable ["GAIT_ss_mediumSpeedBonus", 1.05];      // 36-55 lb
    private _moderateSpeedBonus = missionNamespace getVariable ["GAIT_ss_moderateSpeedBonus", 1.025];   // 56-75 lb
    private _heavySpeedBonus = missionNamespace getVariable ["GAIT_ss_heavySpeedBonus", 1.00];       // 76+ lb baseline

    private _lightBraceRelief = missionNamespace getVariable ["GAIT_ss_lightBraceRelief", 0.55];      // 0-35 lb, brace dip much less prominent
    private _mediumBraceRelief = missionNamespace getVariable ["GAIT_ss_mediumBraceRelief", 0.35];     // 36-55 lb
    private _moderateBraceRelief = missionNamespace getVariable ["GAIT_ss_moderateBraceRelief", 0.18];   // 56-75 lb
    private _heavyBraceRelief = missionNamespace getVariable ["GAIT_ss_heavyBraceRelief", 0.00];      // 76+ lb baseline

    // Exhaustion audio settings.
    // ACE Advanced Fatigue handles pulse audio.
    // GAIT only keeps tinnitus as a separate exhaustion effect.
    private _tinnitusStartExhaustion = missionNamespace getVariable ["GAIT_ss_tinnitusStartExhaustion", 0.70];   // tinnitus starts near heavy exhaustion
    private _audioStopExhaustion = missionNamespace getVariable ["GAIT_ss_audioStopExhaustion", 0.10];       // audio fades out once recovered below this
    private _tinnitusLoopDelay = 6.624;        // exact length of tinnitus_loop.ogg
    private _tinnitusMaxVolume = missionNamespace getVariable ["GAIT_ss_tinnitusMaxVolume", 0.55];
    private _audioFadeLerp = missionNamespace getVariable ["GAIT_ss_audioFadeLerp", 0.08];             // how smoothly target audio volume fades in/out

    // Tunnel-vision style post-process FX.
    // More prominent exhaustion vignette / tunnel vision effect.
    private _tunnelStartExhaustion = missionNamespace getVariable ["GAIT_ss_tunnelStartExhaustion", 0.18];
    private _tunnelMaxStrength = missionNamespace getVariable ["GAIT_ss_tunnelMaxStrength", 1.0];
    private _lastTunnelStrength = 0.0;

    missionNamespace setVariable ["GAIT_exhaustionLevel", 0];
    missionNamespace setVariable ["GAIT_tinnitusTargetVolume", 0];
    missionNamespace setVariable ["GAIT_tinnitusCurrentVolume", 0];

    private _tinnitusSoundPath = "\gait\sounds\tinnitus_loop.ogg";

    [_tinnitusLoopDelay, _tinnitusSoundPath] spawn {
        params ["_loopDelay", "_soundPath"];

        while {true} do {
            private _vol = missionNamespace getVariable ["GAIT_tinnitusCurrentVolume", 0];

            if (_vol > 0.01 && {!isNull player}) then {
                playSound3D [_soundPath, player, false, getPosASL player, _vol, 1, 4];
                uiSleep _loopDelay;
            } else {
                uiSleep 0.10;
            };
        };
    };

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
    private _sprintStartBraceSpeed = missionNamespace getVariable ["GAIT_ss_sprintStartBraceSpeed", 0.42];     // exaggerated debug slowdown
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
    private _slopeAngleRiseRateDegPerSecond = missionNamespace getVariable ["GAIT_ss_slopeAngleRiseRateDegPerSecond", 22.0];
    private _slopeAngleFallRateDegPerSecond = missionNamespace getVariable ["GAIT_ss_slopeAngleFallRateDegPerSecond", 30.0];
    private _uphillSlowdownEnabled = missionNamespace getVariable ["GAIT_ss_uphillSlowdownEnabled", true];
    private _uphillStartDegrees = missionNamespace getVariable ["GAIT_ss_uphillStartDegrees", 5.0];
    private _uphillMaxDegrees = missionNamespace getVariable ["GAIT_ss_uphillMaxDegrees", 35.0];
    private _uphillMaxPenalty = missionNamespace getVariable ["GAIT_ss_uphillMaxPenalty", 0.40];
    private _slopeStopBraceEnabled = missionNamespace getVariable ["GAIT_ss_slopeStopBraceEnabled", true];
    private _slopeStopBraceStartDegrees = missionNamespace getVariable ["GAIT_ss_slopeStopBraceStartDegrees", 15.0];
    private _slopeStopBraceMaxDegrees = missionNamespace getVariable ["GAIT_ss_slopeStopBraceMaxDegrees", 35.0];
    private _slopeStopBraceExtraDuration = missionNamespace getVariable ["GAIT_ss_slopeStopBraceExtraDuration", 0.18];
    private _slopeStopBraceExtraDip = missionNamespace getVariable ["GAIT_ss_slopeStopBraceExtraDip", 0.28];
    private _slopeStopBraceMemoryTime = missionNamespace getVariable ["GAIT_ss_slopeStopBraceMemoryTime", 2.5];
    private _downhillBoostEnabled = missionNamespace getVariable ["GAIT_ss_downhillBoostEnabled", true];
    private _downhillBoostStartDegrees = missionNamespace getVariable ["GAIT_ss_downhillBoostStartDegrees", 4.0];
    private _downhillBoostMaxDegrees = missionNamespace getVariable ["GAIT_ss_downhillBoostMaxDegrees", 18.0];
    private _downhillMaxBoost = missionNamespace getVariable ["GAIT_ss_downhillMaxBoost", 0.06];
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
        _masterFxIntensity = missionNamespace getVariable ["GAIT_ss_masterFxIntensity", 1.00];
        _downhillMomentumEasyTriggerDegrees = missionNamespace getVariable ["GAIT_ss_downhillMomentumEasyTriggerDegrees", 10.00];
        _shiftReleaseRunTaperEnabled = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperEnabled", true];
        _shiftReleaseRunTaperDuration = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperDuration", 0.85];
        _shiftReleaseRunTaperHoldDuration = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperHoldDuration", 1.00];
        _shiftReleaseRunTaperCurve = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperCurve", 1.45];
        _debugHudEnabled = missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false];
        _debugHudInterval = missionNamespace getVariable ["GAIT_ss_debugHudInterval", 0.10];
        _hardLandingCamShakeEnabled = missionNamespace getVariable ["GAIT_ss_hardLandingCamShakeEnabled", true];
        _hardLandingMinVerticalSpeed = missionNamespace getVariable ["GAIT_ss_hardLandingMinVerticalSpeed", 4.0];
        _hardLandingShakeStrength = missionNamespace getVariable ["GAIT_ss_hardLandingShakeStrength", 1.00];

        // v1.1.44: master knobs scale the important families without forcing
        // admins to touch every single advanced setting. Keep bounds conservative
        // so existing presets remain sane.
        _masterTripFrequency = (_masterTripFrequency max 0.00) min 3.00;
        _masterFxIntensity = (_masterFxIntensity max 0.00) min 2.00;
        _downhillMomentumEasyTriggerDegrees = (_downhillMomentumEasyTriggerDegrees max 0.00) min 30.00;
        if (_downhillMomentumEasyTriggerDegrees > 0) then {
            _downhillBoostStartDegrees = _downhillBoostStartDegrees min _downhillMomentumEasyTriggerDegrees;
        };
        _downhillTripBaseChancePerSecond = _downhillTripBaseChancePerSecond * _masterTripFrequency;
        _downhillTripMaxChancePerSecond = _downhillTripMaxChancePerSecond * _masterTripFrequency;
        _tunnelMaxStrength = _tunnelMaxStrength * _masterFxIntensity;
        _tinnitusMaxVolume = _tinnitusMaxVolume * _masterFxIntensity;
        _hearingMinVolume = (1 - ((1 - _hearingMinVolume) * _masterFxIntensity)) max 0 min 1;

    private _activeBraceSpeed = _sprintStartBraceSpeed;
    private _conflictScanDone = false;
    private _debugHudEnabled = missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false];
    private _debugHudInterval = missionNamespace getVariable ["GAIT_ss_debugHudInterval", 0.10];
    private _downhillMomentumEasyTriggerDegrees = missionNamespace getVariable ["GAIT_ss_downhillMomentumEasyTriggerDegrees", 10.00];
    private _hardLandingCamShakeEnabled = missionNamespace getVariable ["GAIT_ss_hardLandingCamShakeEnabled", true];
    private _hardLandingMinVerticalSpeed = missionNamespace getVariable ["GAIT_ss_hardLandingMinVerticalSpeed", 4.0];
    private _hardLandingShakeStrength = missionNamespace getVariable ["GAIT_ss_hardLandingShakeStrength", 1.00];
    private _hillWalkDownhillMaxPenalty = missionNamespace getVariable ["GAIT_ss_hillWalkDownhillMaxPenalty", 0.08];
    private _hillWalkSlowdownEnabled = missionNamespace getVariable ["GAIT_ss_hillWalkSlowdownEnabled", true];
    private _hillWalkSlowdownMaxDegrees = missionNamespace getVariable ["GAIT_ss_hillWalkSlowdownMaxDegrees", 40.0];
    private _hillWalkSlowdownStartDegrees = missionNamespace getVariable ["GAIT_ss_hillWalkSlowdownStartDegrees", 15.0];
    private _hillWalkUphillMaxPenalty = missionNamespace getVariable ["GAIT_ss_hillWalkUphillMaxPenalty", 0.32];
    private _lastDebugHudTime = -999;
    private _lastKnownSlopeDegrees = 0;
    private _lastOnGround = true;
    private _lastShiftReleaseTime = -999;
    private _lastSprintStopSlopeDegrees = 0;
    private _lastSprintStopTime = -999;
    private _lastVerticalSpeed = 0;
    private _masterFxIntensity = missionNamespace getVariable ["GAIT_ss_masterFxIntensity", 1.00];
    private _masterTripFrequency = missionNamespace getVariable ["GAIT_ss_masterTripFrequency", 1.00];
    private _shiftReleaseRunTaperCurve = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperCurve", 1.45];
    private _shiftReleaseRunTaperDuration = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperDuration", 0.85];
    private _shiftReleaseRunTaperEnabled = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperEnabled", true];
    private _shiftReleaseRunTaperHoldDuration = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperHoldDuration", 1.00];
    private _shiftReleaseTaperActiveUntil = -999;
    private _shiftReleaseTaperStartKmh = _normalSpeed * 18;
    private _shiftReleaseTaperStartSpeed = _normalSpeed;
    // Snapshot the load-scaled window at release, so inventory changes cannot
    // move a running coast deadline or restart its hold phase.
    private _activeCoastHold = 0;
    private _activeCoastDuration = 0.05;
    private _slopeSmoothInitialized = false;
    private _smoothedSlopeDegrees = 0;
    private _uphillFatigueDrainEnabled = missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainEnabled", true];
    private _uphillFatigueDrainMaxDegrees = missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainMaxDegrees", 35.0];
    private _uphillFatigueDrainMaxMultiplier = missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainMaxMultiplier", 1.75];
    private _uphillFatigueDrainStartDegrees = missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainStartDegrees", 10.0];
    private _uphillVanillaFatigueExtraPerSecond = missionNamespace getVariable ["GAIT_ss_uphillVanillaFatigueExtraPerSecond", 0.018];

    private _lastTick = time;
    private _currentSpeed = _normalSpeed;
    private _visualFatigue = _freshFatigue;
    private _wasSprinting = false;
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

        // Per-tick W-release coast state.
        // These are intentionally refreshed from missionNamespace every tick so
        // malformed/older CBA-saved states or branch skips cannot leave the
        // runtime loop with an undefined local variable.

        private _selectedPreset = missionNamespace getVariable ["GAIT_ss_preset", "Balanced"];
        private _lastPresetApplied = missionNamespace getVariable ["GAIT_lastPresetApplied", ""];
        if !(_selectedPreset isEqualTo _lastPresetApplied) then {
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
            _shiftReleaseTaperActiveUntil = -999;
            _lastShiftReleaseTime = -999;
            _sprintReserve = _sprintReserveMax;
            _currentSpeed = _normalSpeed;
            _visualFatigue = _freshFatigue;
            _wasSprinting = false;
            _lastKnownSlopeDegrees = 0;
            _lastSprintStopSlopeDegrees = 0;
            _lastSprintStopTime = -999;
            _activeBraceSpeed = _sprintStartBraceSpeed;
            _sprintBraceEndTime = -1;
            _walkingStartTime = -1;
            _lastSprintEndTime = -999;
            _braceArmedFromCrouch = false;
            _lastForwardInputTime = time;
            _downhillTripSprintStartTime = -1;
            _downhillTripHighSpeedStartTime = -1;
            _lastTunnelStrength = 0;
            [] call GAIT_fnc_releaseNativeMovement;
        };

        // Refresh live Addon Options settings each tick.
        _debugHudEnabled = missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false];
        _debugHudInterval = missionNamespace getVariable ["GAIT_ss_debugHudInterval", 0.10];
        _downhillMomentumEasyTriggerDegrees = missionNamespace getVariable ["GAIT_ss_downhillMomentumEasyTriggerDegrees", 10.00];
        _hardLandingCamShakeEnabled = missionNamespace getVariable ["GAIT_ss_hardLandingCamShakeEnabled", true];
        _hardLandingMinVerticalSpeed = missionNamespace getVariable ["GAIT_ss_hardLandingMinVerticalSpeed", 4.0];
        _hardLandingShakeStrength = missionNamespace getVariable ["GAIT_ss_hardLandingShakeStrength", 1.00];
        _hillWalkDownhillMaxPenalty = missionNamespace getVariable ["GAIT_ss_hillWalkDownhillMaxPenalty", 0.08];
        _hillWalkSlowdownEnabled = missionNamespace getVariable ["GAIT_ss_hillWalkSlowdownEnabled", true];
        _hillWalkSlowdownMaxDegrees = missionNamespace getVariable ["GAIT_ss_hillWalkSlowdownMaxDegrees", 40.0];
        _hillWalkSlowdownStartDegrees = missionNamespace getVariable ["GAIT_ss_hillWalkSlowdownStartDegrees", 15.0];
        _hillWalkUphillMaxPenalty = missionNamespace getVariable ["GAIT_ss_hillWalkUphillMaxPenalty", 0.32];
        _masterFxIntensity = missionNamespace getVariable ["GAIT_ss_masterFxIntensity", 1.00];
        _masterTripFrequency = missionNamespace getVariable ["GAIT_ss_masterTripFrequency", 1.00];
        _shiftReleaseRunTaperCurve = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperCurve", 1.45];
        _shiftReleaseRunTaperDuration = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperDuration", 0.85];
        _shiftReleaseRunTaperEnabled = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperEnabled", true];
        _shiftReleaseRunTaperHoldDuration = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperHoldDuration", 1.00];
        _uphillFatigueDrainEnabled = missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainEnabled", true];
        _uphillFatigueDrainMaxDegrees = missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainMaxDegrees", 35.0];
        _uphillFatigueDrainMaxMultiplier = missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainMaxMultiplier", 1.75];
        _uphillFatigueDrainStartDegrees = missionNamespace getVariable ["GAIT_ss_uphillFatigueDrainStartDegrees", 10.0];
        _uphillVanillaFatigueExtraPerSecond = missionNamespace getVariable ["GAIT_ss_uphillVanillaFatigueExtraPerSecond", 0.018];
        private _oldSprintReserveMax = _sprintReserveMax;
        _normalSpeed = missionNamespace getVariable ["GAIT_ss_normalSpeed", 0.86];
        _sprintReserveMax = missionNamespace getVariable ["GAIT_ss_sprintReserveMax", 25.0];
        _sprintRecoverTime = missionNamespace getVariable ["GAIT_ss_sprintRecoverTime", 10.0];
        _sprintFullSpeed = missionNamespace getVariable ["GAIT_ss_sprintFullSpeed", 1.28];
        _sprintExhaustedSpeed = missionNamespace getVariable ["GAIT_ss_sprintExhaustedSpeed", 0.89];
        _carryWalkSpeed = missionNamespace getVariable ["GAIT_ss_carryWalkSpeed", 0.80];
        _carrySprintFullSpeed = missionNamespace getVariable ["GAIT_ss_carrySprintFullSpeed", 1.50];
        _carrySprintExhaustedSpeed = missionNamespace getVariable ["GAIT_ss_carrySprintExhaustedSpeed", 0.9];
        _freshFatigue = missionNamespace getVariable ["GAIT_ss_freshFatigue", 0.05];
        _exhaustedFatigue = missionNamespace getVariable ["GAIT_ss_exhaustedFatigue", 0.85];
        _fatigueRecoverRate = (_exhaustedFatigue - _freshFatigue) / (_sprintRecoverTime max 0.01);
        _hearingMinVolume = missionNamespace getVariable ["GAIT_ss_hearingMinVolume", 0.20];
        _hearingFadeDuration = missionNamespace getVariable ["GAIT_ss_hearingFadeDuration", 0.20];
        _unarmedSprintNormalizer = missionNamespace getVariable ["GAIT_ss_unarmedSprintNormalizer", 0.725];
        _loadAbsPerLb = missionNamespace getVariable ["GAIT_ss_loadAbsPerLb", 10];
        _lightSpeedBonus = missionNamespace getVariable ["GAIT_ss_lightSpeedBonus", 1.08];
        _mediumSpeedBonus = missionNamespace getVariable ["GAIT_ss_mediumSpeedBonus", 1.05];
        _moderateSpeedBonus = missionNamespace getVariable ["GAIT_ss_moderateSpeedBonus", 1.025];
        _heavySpeedBonus = missionNamespace getVariable ["GAIT_ss_heavySpeedBonus", 1.00];
        _lightBraceRelief = missionNamespace getVariable ["GAIT_ss_lightBraceRelief", 0.55];
        _mediumBraceRelief = missionNamespace getVariable ["GAIT_ss_mediumBraceRelief", 0.35];
        _moderateBraceRelief = missionNamespace getVariable ["GAIT_ss_moderateBraceRelief", 0.18];
        _heavyBraceRelief = missionNamespace getVariable ["GAIT_ss_heavyBraceRelief", 0.00];
        _tinnitusStartExhaustion = missionNamespace getVariable ["GAIT_ss_tinnitusStartExhaustion", 0.70];
        _audioStopExhaustion = missionNamespace getVariable ["GAIT_ss_audioStopExhaustion", 0.10];
        _tinnitusMaxVolume = missionNamespace getVariable ["GAIT_ss_tinnitusMaxVolume", 0.55];
        _audioFadeLerp = missionNamespace getVariable ["GAIT_ss_audioFadeLerp", 0.08];
        _tunnelStartExhaustion = missionNamespace getVariable ["GAIT_ss_tunnelStartExhaustion", 0.18];
        _tunnelMaxStrength = missionNamespace getVariable ["GAIT_ss_tunnelMaxStrength", 1.0];
        _tickRate = missionNamespace getVariable ["GAIT_ss_tickRate", 0.05];
        _speedLerp = missionNamespace getVariable ["GAIT_ss_speedLerp", 0.05];
        _wReleaseZeroMomentumDelay = missionNamespace getVariable ["GAIT_ss_wReleaseZeroMomentumDelay", 0.50];
        // v1.1.32 migration: old v1.1.31 defaults coasted a little too far.
        // Treat unchanged legacy defaults as the shorter new feel, while still allowing custom values.
        _sprintStartBraceEnabled = missionNamespace getVariable ["GAIT_ss_sprintStartBraceEnabled", true];
        _sprintStartBraceDuration = missionNamespace getVariable ["GAIT_ss_sprintStartBraceDuration", 0.15];
        _sprintStartBraceSpeed = missionNamespace getVariable ["GAIT_ss_sprintStartBraceSpeed", 0.42];
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
        _slopeAngleRiseRateDegPerSecond = missionNamespace getVariable ["GAIT_ss_slopeAngleRiseRateDegPerSecond", 22.0];
        _slopeAngleFallRateDegPerSecond = missionNamespace getVariable ["GAIT_ss_slopeAngleFallRateDegPerSecond", 30.0];
        _uphillSlowdownEnabled = missionNamespace getVariable ["GAIT_ss_uphillSlowdownEnabled", true];
        _uphillStartDegrees = missionNamespace getVariable ["GAIT_ss_uphillStartDegrees", 5.0];
        _uphillMaxDegrees = missionNamespace getVariable ["GAIT_ss_uphillMaxDegrees", 35.0];
        _uphillMaxPenalty = missionNamespace getVariable ["GAIT_ss_uphillMaxPenalty", 0.40];
        _slopeStopBraceEnabled = missionNamespace getVariable ["GAIT_ss_slopeStopBraceEnabled", true];
        _slopeStopBraceStartDegrees = missionNamespace getVariable ["GAIT_ss_slopeStopBraceStartDegrees", 15.0];
        _slopeStopBraceMaxDegrees = missionNamespace getVariable ["GAIT_ss_slopeStopBraceMaxDegrees", 35.0];
        _slopeStopBraceExtraDuration = missionNamespace getVariable ["GAIT_ss_slopeStopBraceExtraDuration", 0.18];
        _slopeStopBraceExtraDip = missionNamespace getVariable ["GAIT_ss_slopeStopBraceExtraDip", 0.28];
        _slopeStopBraceMemoryTime = missionNamespace getVariable ["GAIT_ss_slopeStopBraceMemoryTime", 2.5];
        _downhillBoostEnabled = missionNamespace getVariable ["GAIT_ss_downhillBoostEnabled", true];
        _downhillBoostStartDegrees = missionNamespace getVariable ["GAIT_ss_downhillBoostStartDegrees", 4.0];
        _downhillBoostMaxDegrees = missionNamespace getVariable ["GAIT_ss_downhillBoostMaxDegrees", 18.0];
        _downhillMaxBoost = missionNamespace getVariable ["GAIT_ss_downhillMaxBoost", 0.06];
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
        _masterFxIntensity = missionNamespace getVariable ["GAIT_ss_masterFxIntensity", 1.00];
        _downhillMomentumEasyTriggerDegrees = missionNamespace getVariable ["GAIT_ss_downhillMomentumEasyTriggerDegrees", 10.00];
        _shiftReleaseRunTaperEnabled = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperEnabled", true];
        _shiftReleaseRunTaperDuration = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperDuration", 0.85];
        _shiftReleaseRunTaperHoldDuration = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperHoldDuration", 1.00];
        _shiftReleaseRunTaperCurve = missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperCurve", 1.45];
        _debugHudEnabled = missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false];
        _debugHudInterval = missionNamespace getVariable ["GAIT_ss_debugHudInterval", 0.10];
        _hardLandingCamShakeEnabled = missionNamespace getVariable ["GAIT_ss_hardLandingCamShakeEnabled", true];
        _hardLandingMinVerticalSpeed = missionNamespace getVariable ["GAIT_ss_hardLandingMinVerticalSpeed", 4.0];
        _hardLandingShakeStrength = missionNamespace getVariable ["GAIT_ss_hardLandingShakeStrength", 1.00];

        _masterTripFrequency = (_masterTripFrequency max 0.00) min 3.00;
        _masterFxIntensity = (_masterFxIntensity max 0.00) min 2.00;
        _downhillMomentumEasyTriggerDegrees = (_downhillMomentumEasyTriggerDegrees max 0.00) min 30.00;
        if (_downhillMomentumEasyTriggerDegrees > 0) then {
            _downhillBoostStartDegrees = _downhillBoostStartDegrees min _downhillMomentumEasyTriggerDegrees;
        };
        _downhillTripBaseChancePerSecond = _downhillTripBaseChancePerSecond * _masterTripFrequency;
        _downhillTripMaxChancePerSecond = _downhillTripMaxChancePerSecond * _masterTripFrequency;
        _tunnelMaxStrength = _tunnelMaxStrength * _masterFxIntensity;
        _tinnitusMaxVolume = _tinnitusMaxVolume * _masterFxIntensity;
        _hearingMinVolume = (1 - ((1 - _hearingMinVolume) * _masterFxIntensity)) max 0 min 1;

        if (_oldSprintReserveMax > 0 && {_oldSprintReserveMax != _sprintReserveMax}) then {
            private _reserveRatioBeforeChange = (_sprintReserve / _oldSprintReserveMax) max 0 min 1;
            _sprintReserve = _sprintReserveMax * _reserveRatioBeforeChange;
        };

        if (alive player && {call GAIT_fnc_modeIsActive} && {!(call GAIT_fnc_isSuspendedContext)}) then {
            private _pickupActive = player getVariable ["MAV_fastCarry_pickupActive", false];
            private _gaitMovementEnabled = call GAIT_fnc_modeAllowsMovement;
            private _gaitEffectsEnabled = call GAIT_fnc_modeAllowsEffects;
            private _gaitHearingEnabled = call GAIT_fnc_modeAllowsHearing;

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
                if ((count _conflicts) > 0 && {missionNamespace getVariable ["GAIT_ss_rptLogging", true]}) then {
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
                private _isForwardHeld = (_movementInput select 0) > 0.05;
                private _turboHeld = _movementInput select 2;
                [player] call GAIT_fnc_clearACEAdvancedFatigueMovementLocks;
                private _externalSprintLock = !(isSprintAllowed player) || {(player getVariable ["ace_common_effect_blockSprint", 0]) > 0};
                private _externalWalkLock = isForcedWalk player || {(player getVariable ["ace_common_effect_forceWalk", 0]) > 0};
                private _movementEligible = [player, _isAceCarrying] call GAIT_fnc_nativeMovementEligible;
                private _isSprinting = _turboHeld && {_isForwardHeld} && {!((stance player) isEqualTo "PRONE")} && {_movementEligible} && {!_externalSprintLock} && {!_externalWalkLock};
                // v1.6.0 (FIX 3 - prone): a real "standing" gate for anim/velocity
                // forcing. `stance` can still report "STAND" on the exact frame the
                // player triggers prone (or crouch) while sprinting; forcing a sprint
                // playMove on that frame pulls the player back upright and runs them
                // forward with no input (the reported bug). animationState already
                // carries the prone (Ppne) / kneel-crouch (Pknl) target during the
                // blend, so reject those here. All GAIT anim-forcing intents below use
                // _gaitStanceOk instead of a bare stance=="STAND" test.
                private _gaitStanceOk = ((stance player) isEqualTo "STAND") && {
                    private _gaitAnimLow = toLower (animationState player);
                    ((_gaitAnimLow find "ppne") < 0) && {(_gaitAnimLow find "pknl") < 0}
                };
                private _isCrouched = (stance player) isEqualTo "CROUCH";
                private _isBackHeld = (_movementInput select 0) < -0.05;
                private _isLateralHeld = abs (_movementInput select 1) > 0.05;

                private _onGroundNow = isTouchingGround player;
                if (_hardLandingCamShakeEnabled && {_onGroundNow} && {!_lastOnGround} && {_lastVerticalSpeed < -((_hardLandingMinVerticalSpeed max 0.5) min 20)}) then {
                    private _landingSeverity = linearConversion [(_hardLandingMinVerticalSpeed max 0.5), 12, abs _lastVerticalSpeed, 0, 1, true];
                    addCamShake [(_hardLandingShakeStrength max 0) * (0.35 + (1.65 * _landingSeverity)), 0.30 + (0.35 * _landingSeverity), 18];
                    missionNamespace setVariable ["GAIT_hardLandingShakeSeverity", _landingSeverity];
                };
                _lastOnGround = _onGroundNow;
                _lastVerticalSpeed = (velocity player) select 2;

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

                private _tripSustainedSprintSeconds = 0;
                private _tripSustainedHighSpeedSeconds = 0;
                if (_isSprinting && {_isOnFoot} && {!_isAceCarrying} && {!_isAceDragging} && {(stance player) isEqualTo "STAND"}) then {
                    if (_downhillTripSprintStartTime < 0) then {
                        _downhillTripSprintStartTime = time;
                    };
                    _tripSustainedSprintSeconds = time - _downhillTripSprintStartTime;

                    if (_actualSpeedKmh >= (_downhillTripSustainedSpeedKmh max 0)) then {
                        if (_downhillTripHighSpeedStartTime < 0) then {
                            _downhillTripHighSpeedStartTime = time;
                        };
                        _tripSustainedHighSpeedSeconds = time - _downhillTripHighSpeedStartTime;
                    } else {
                        _downhillTripHighSpeedStartTime = -1;
                    };
                } else {
                    _downhillTripSprintStartTime = -1;
                    _downhillTripHighSpeedStartTime = -1;
                };

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
                private _weightSpeedMult = [_gearLbs, [_lightWeightMax, _mediumWeightMax, _moderateWeightMax], [_lightSpeedBonus, _mediumSpeedBonus, _moderateSpeedBonus, _heavySpeedBonus], missionNamespace getVariable ["GAIT_ss_extraHeavyPenaltyPer50Lb", 0.18]] call GAIT_fnc_continuousLoadMultiplier;
                private _gearInertia = [_gearLbs,
                    [_lightBraceRelief, _mediumBraceRelief, _moderateBraceRelief, _heavyBraceRelief],
                    [_lightWeightMax, _mediumWeightMax, _moderateWeightMax]] call GAIT_fnc_gearInertia;
                _gearInertia params ["_accelerationScale", "_decelerationScale", "_coastScale", "_launchDurationScale", "_braceRelief"];
                missionNamespace setVariable ["GAIT_gearInertia", _gearInertia];

                private _effectiveNormalSpeed = _normalSpeed * _weightSpeedMult;
                private _effectiveBraceSpeed = (_sprintStartBraceSpeed + ((_normalSpeed - _sprintStartBraceSpeed) * _braceRelief)) * _weightSpeedMult;

                // =====================================================
                // TERRAIN / SLOPE MODIFIER
                // Directional grade scales pace continuously; there is no maximum sprint angle.
                // Downhill bonus grows with actual sustained travel, scales
                // down with kit weight and tapers on extreme descents.
                // =====================================================
                private _slopeDegrees = 0;
                private _slopeSpeedMultiplier = 1;

                if (_slopeHandlingEnabled && {_isOnFoot} && {!_isAceDragging}) then {
                    private _rawSlopeDegrees = [player, _slopeSampleDistance, _movementInput] call GAIT_fnc_getTravelSlopeDegrees;

                    if (_slopeTransitionSmoothingEnabled) then {
                        if (!_slopeSmoothInitialized) then {
                            _smoothedSlopeDegrees = _rawSlopeDegrees;
                            _slopeSmoothInitialized = true;
                        } else {
                            private _slopeDiff = _rawSlopeDegrees - _smoothedSlopeDegrees;
                            private _slopeMagnitudeIncreasing = (abs _rawSlopeDegrees) > (abs _smoothedSlopeDegrees);
                            private _slopeRate = if (_slopeMagnitudeIncreasing) then {_slopeAngleRiseRateDegPerSecond} else {_slopeAngleFallRateDegPerSecond};
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

                    if (_isSprinting) then {
                        private _uphillMaxDegSafe = _uphillMaxDegrees max (_uphillStartDegrees + 0.1);
                        private _downhillBoostMaxDegSafe = _downhillBoostMaxDegrees max (_downhillBoostStartDegrees + 0.1);

                        if (_uphillSlowdownEnabled && {_slopeDegrees > _uphillStartDegrees}) then {
                            _slopeSpeedMultiplier = [_slopeDegrees, _uphillStartDegrees, _uphillMaxDegSafe, _uphillMaxPenalty] call GAIT_fnc_uphillPaceMultiplier;
                        };

                        if (_downhillBoostEnabled && {_slopeDegrees < -_downhillBoostStartDegrees}) then {
                            private _sustainedBonus = missionNamespace getVariable ["GAIT_ss_downhillSustainedExtraBoost", 0.12];
                            _slopeSpeedMultiplier = _slopeSpeedMultiplier * ([_slopeDegrees, _gearLbs, _downhillMomentum,
                                _downhillBoostStartDegrees, _downhillBoostMaxDegSafe, _downhillMaxBoost + _sustainedBonus]
                                call GAIT_fnc_downhillPaceMultiplier);
                        };

                        private _downhillDegForTrip = abs _slopeDegrees;
                        private _downhillTripMaxDegSafe = _downhillTripMaxDegrees max (_downhillTripThresholdDegrees + 0.1);
                        private _gearTripSeverity = linearConversion [_lightWeightMax, 110, _gearLbs, 0, 1, true];
                        private _tripSlopeSeverity = if (_slopeDegrees < -_downhillTripThresholdDegrees) then {
                            linearConversion [_downhillTripThresholdDegrees, _downhillTripMaxDegSafe, _downhillDegForTrip, 0, 1, true]
                        } else {
                            0
                        };

                        private _tripSpeedMaxSafe = _downhillTripSpeedMaxKmh max (_downhillTripMinSpeedKmh + 0.1);
                        private _tripSpeedSeverity = if (_actualSpeedKmh >= _downhillTripMinSpeedKmh) then {
                            linearConversion [_downhillTripMinSpeedKmh, _tripSpeedMaxSafe, _actualSpeedKmh, 0, 1, true]
                        } else {
                            0
                        };

                        private _speedInfluence = (_downhillTripSpeedInfluence max 0) min 2;
                        private _speedRiskCurve = 0.65 + (0.90 * _tripSpeedSeverity);
                        private _speedRiskMultiplier = 1 + (((_speedRiskCurve max 0.10) - 1) * _speedInfluence);
                        _speedRiskMultiplier = _speedRiskMultiplier max 0;

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
                        private _tripEligible = _downhillTripEnabled && {_movementEligible} && {!_isAceCarrying} && {!_isAceDragging} && {_slopeDegrees < -_downhillTripThresholdDegrees} && {_actualSpeedKmh >= _downhillTripMinSpeedKmh} && {_sustainedGateReady};
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

                        if (_tripEligible && {!_tripBlockedByCooldown} && {(random 1) < (_chancePerSecond * _dt)}) then {
                            [_downhillTripDuration] call GAIT_fnc_tripPlayer;
                            _currentSpeed = _effectiveNormalSpeed;
                            _sprintBraceEndTime = -1;
                            _wasSprinting = false;
                        };
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
                missionNamespace setVariable ["GAIT_slopeSpeedMultiplier", _slopeSpeedMultiplier];
                missionNamespace setVariable ["GAIT_hillWalkSlowdownMultiplier", _hillWalkSlowdownMultiplier];
                missionNamespace setVariable ["GAIT_hillWalkSlowdownSeverity", _hillWalkSlowdownSeverity];

                // Sample established motion BEFORE processing a new sprint
                // press. Holding Turbo against a wall cannot establish it.
                // A transient animation blend does not clear physical history.
                private _momentumContextOk = _gaitMovementEnabled && {!_isAceCarrying} && {!_isAceDragging} &&
                    {!_externalSprintLock} && {!_externalWalkLock} && {[player] call GAIT_fnc_fatigueMovementContextEligible};
                private _continuingSprint = _isSprinting && {_wasSprinting} && {_sprintBraceEndTime <= time};
                private _motion = [_braceMomentumState, _continuingSprint, _momentumContextOk,
                    _horizontalSpeedMS, _currentSpeed, _effectiveNormalSpeed * _hillWalkSlowdownMultiplier,
                    time, _dt, _braceRecentSprintCooldown, _braceRequiredWalkTime, _braceNoMomentumThreshold]
                    call GAIT_fnc_stepBraceMomentum;
                _braceMomentumState = _motion select 0;
                private _hasRetainedSprintMomentum = _motion select 1;
                missionNamespace setVariable ["GAIT_braceMomentumProtected", _hasRetainedSprintMomentum];

                if (!_momentumContextOk || {(_braceMomentumState select 3) >= 0.15}) then {
                    _downhillMomentum = 0;
                } else {
                    private _momentumTarget = 0;
                    if (_continuingSprint && {_horizontalSpeedMS > 0.25}) then {
                        _momentumTarget = 1;
                    } else {
                        if (_hasRetainedSprintMomentum) then {_momentumTarget = _downhillMomentum;};
                    };
                    _downhillMomentum = [_downhillMomentum, _momentumTarget, _dt,
                        (missionNamespace getVariable ["GAIT_ss_downhillMomentumBuildSeconds", 2.5]) / _accelerationScale, 1.5 / _decelerationScale]
                        call GAIT_fnc_stepDownhillMomentum;
                };
                missionNamespace setVariable ["GAIT_downhillMomentum", _downhillMomentum];

                // A deliberate uphill release is a braking event, separate
                // from launch-brace eligibility and retained-momentum vetoes.
                private _uphillBrakeEnabled = _slopeHandlingEnabled && {_slopeStopBraceEnabled} &&
                    {missionNamespace getVariable ["GAIT_ss_uphillReleaseBraceEnabled", true]};
                private _uphillBrakeContext = _momentumContextOk && {_movementEligible} && {_gaitStanceOk} && {isTouchingGround player};
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
                    !_isSprinting &&
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
                    if (!_isSprinting) then {
                        _walkingStartTime = -1;
                        _braceArmedFromCrouch = false;
                    };
                };

                if (_isSprinting && {!_wasSprinting}) then {
                    _wasSprinting = true;

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

                    private _canBrace = [_sprintStartBraceEnabled, _hasRetainedSprintMomentum || {_uphillBrakeResumed},
                        _isCrouched, _braceArmedFromCrouch, _normalBraceReady, _zeroMomentumBraceReady, _slopeBraceReady]
                        call GAIT_fnc_shouldBrace;

                    private _braceDurationNow = (_sprintStartBraceDuration * _launchDurationScale) + (((_slopeStopBraceExtraDuration max 0) min 2.0) * _slopeBraceFactor);
                    private _braceDipNow = ((_slopeStopBraceExtraDip max 0) min 0.90) * _slopeBraceFactor;
                    _activeBraceSpeed = (_effectiveBraceSpeed * (1 - _braceDipNow)) max 0.08;

                    _sprintBraceEndTime = if (_canBrace) then {
                        time + _braceDurationNow
                    } else {
                        -1
                    };

                    missionNamespace setVariable ["GAIT_slopeBraceFactor", _slopeBraceFactor];
                    missionNamespace setVariable ["GAIT_activeBraceSpeed", _activeBraceSpeed];
                    missionNamespace setVariable ["GAIT_activeBraceDuration", _braceDurationNow];

                    _walkingStartTime = -1;
                    _braceArmedFromCrouch = false;
                };

                if (!_isSprinting) then {
                    if (_wasSprinting) then {
                        _lastSprintEndTime = time;

                        // v1.1.49: Shift-release carry is separate from W-release coast.
                        // If Shift is released while W remains held, preserve the actual
                        // running speed briefly, then taper toward W-only speed. This fixes
                        // the exhausted snap from ~16 km/h to walk speed.
                        if (_isForwardHeld && {!_isBackHeld} && {!_isLateralHeld} && {_movementEligible}) then {
                            _lastShiftReleaseTime = time;
                            private _shiftReleaseHVel = velocity player;
                            private _shiftReleaseHSpeedMS = sqrt (((_shiftReleaseHVel select 0) * (_shiftReleaseHVel select 0)) + (((_shiftReleaseHVel select 1) * (_shiftReleaseHVel select 1))));
                            _shiftReleaseTaperStartKmh = (_shiftReleaseHSpeedMS * 3.6) max 0;
                            _shiftReleaseTaperStartSpeed = _currentSpeed;
                            private _coastWindow = [_shiftReleaseRunTaperHoldDuration, _shiftReleaseRunTaperDuration, _coastScale] call GAIT_fnc_gearCoastWindow;
                            _activeCoastHold = _coastWindow select 0;
                            _activeCoastDuration = _coastWindow select 1;
                            _shiftReleaseTaperActiveUntil = time + _activeCoastHold + _activeCoastDuration;

                        } else {
                            _lastShiftReleaseTime = -999;
                            _shiftReleaseTaperActiveUntil = -999;
                        };

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
                // Shallower releases retain proportionally more of the old
                // coast; full uphill braking removes it. Backdate the same
                // taper instead of creating a speed-hold discontinuity at 15 degrees.
                if (_uphillBrakeStarted && {_shiftReleaseTaperActiveUntil >= time}) then {
                    private _coastWindow = [_uphillBrakeSeverity, _activeCoastHold, _activeCoastDuration]
                        call GAIT_fnc_uphillBrakeCoastWindow;
                    _lastShiftReleaseTime = time - (_coastWindow select 0);
                    _shiftReleaseTaperActiveUntil = time + (_coastWindow select 1);
                };
                private _reserveRatio = 1;

                // v1.1.36 uphill fatigue drain:
                // Use the last measured travel slope so stamina drain can react before
                // the next terrain block finishes. Uphill traversals become more costly
                // as the incline approaches the configured max angle.
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

                if (_aceAdvancedFatigueActive && {missionNamespace getVariable ["GAIT_ss_useAceReserveModel", true]}) then {

                    // ACE Advanced Fatigue writes these globals on the client.
                    // anReservePercentage = short-burst ATP reserve.
                    // aeReservePercentage = longer aerobic reserve.
                    // anFatigue = acidosis / anaerobic fatigue.
                    // muscleDamage = long-duration overwork penalty.
                    private _aceAnReservePct = missionNamespace getVariable ["ace_advanced_fatigue_anReservePercentage", -1];
                    private _aceAeReservePct = missionNamespace getVariable ["ace_advanced_fatigue_aeReservePercentage", 1];
                    private _aceAnFatigue = missionNamespace getVariable ["ace_advanced_fatigue_anFatigue", 0];
                    private _aceMuscleDamage = missionNamespace getVariable ["ace_advanced_fatigue_muscleDamage", 0];

                    if (_aceAnReservePct >= 0) then {
                        _aceAnReservePct = (_aceAnReservePct max 0) min 1;
                        _aceAeReservePct = (_aceAeReservePct max 0) min 1;
                        _aceAnFatigue = (_aceAnFatigue max 0) min 1;
                        _aceMuscleDamage = (_aceMuscleDamage max 0) min 1;

                        private _reserveFromAce = _aceAnReservePct min _aceAeReservePct;
                        private _acidosisPenalty = 1 - (_aceAcidosisPenaltyFactor * _aceAnFatigue);
                        private _musclePenalty = 1 - (_aceMuscleDamagePenaltyFactor * _aceMuscleDamage);

                        _reserveRatio = (_reserveFromAce * _acidosisPenalty * _musclePenalty) max 0;
                        _reserveRatio = _reserveRatio min 1;

                        // Keep the old GAIT reserve variable synced for the rest
                        // of the script, but ACE is the source of truth now.
                        _sprintReserve = _sprintReserveMax * _reserveRatio;
                    } else {
                        // First second after mission start / respawn: ACE may not
                        // have completed its first fatigue tick yet. Use GAIT reserve
                        // as a temporary fallback so there is no divide/jump.
                        if (_isSprinting) then {
                            _sprintReserve = _sprintReserve - (_dt * _uphillFatigueDrainMultiplierNow);
                            if (_sprintReserve < 0) then {_sprintReserve = 0;};
                        } else {
                            _sprintReserve = _sprintReserve + ((_sprintReserveMax / _sprintRecoverTime) * _dt);
                            if (_sprintReserve > _sprintReserveMax) then {_sprintReserve = _sprintReserveMax;};
                        };

                        _reserveRatio = _sprintReserve / _sprintReserveMax;
                    };
                } else {
                    // No ACE Advanced Fatigue: use the original GAIT reserve model.
                    if (_isSprinting) then {
                        _sprintReserve = _sprintReserve - (_dt * _uphillFatigueDrainMultiplierNow);

                        if (_sprintReserve < 0) then {
                            _sprintReserve = 0;
                        };
                    } else {
                        _sprintReserve = _sprintReserve + ((_sprintReserveMax / _sprintRecoverTime) * _dt);

                        if (_sprintReserve > _sprintReserveMax) then {
                            _sprintReserve = _sprintReserveMax;
                        };
                    };

                    _reserveRatio = _sprintReserve / _sprintReserveMax;
                };

                _reserveRatio = (_reserveRatio max 0) min 1;
                private _exhaustion = 1 - _reserveRatio;
                _exhaustion = (_exhaustion max 0) min 1;
                missionNamespace setVariable ["GAIT_exhaustionLevel", _exhaustion];

                // =====================================================
                // EXHAUSTION AUDIO: TINNITUS ONLY
                // ACE Advanced Fatigue owns pulse audio.
                // =====================================================
                private _tinnitusTargetVolume = 0;
                if (_gaitEffectsEnabled && {missionNamespace getVariable ["GAIT_ss_tinnitusEnabled", true]} && {_exhaustion > _tinnitusStartExhaustion}) then {
                    private _tinnitusStrength = linearConversion [_tinnitusStartExhaustion, 1, _exhaustion, 0, 1, true];
                    _tinnitusTargetVolume = _tinnitusMaxVolume * _tinnitusStrength;
                };
                if (_exhaustion < _audioStopExhaustion) then {
                    _tinnitusTargetVolume = 0;
                };

                missionNamespace setVariable ["GAIT_tinnitusTargetVolume", _tinnitusTargetVolume];

                private _tinnitusCurrentVolume = missionNamespace getVariable ["GAIT_tinnitusCurrentVolume", 0];
                _tinnitusCurrentVolume = _tinnitusCurrentVolume + ((_tinnitusTargetVolume - _tinnitusCurrentVolume) * _audioFadeLerp);
                if (abs _tinnitusCurrentVolume < 0.005) then {
                    _tinnitusCurrentVolume = 0;
                };
                missionNamespace setVariable ["GAIT_tinnitusCurrentVolume", _tinnitusCurrentVolume];

                // =====================================================
                // TUNNEL VISION FX (ACM-LIKE APPROXIMATION)
                // =====================================================
                private _tunnelStrength = 0;
                if (_gaitEffectsEnabled && {missionNamespace getVariable ["GAIT_ss_visualFxEnabled", true]} && {_exhaustion > _tunnelStartExhaustion}) then {
                    _tunnelStrength = linearConversion [_tunnelStartExhaustion, 1, _exhaustion, 0, _tunnelMaxStrength, true];
                };

                if (abs (_tunnelStrength - _lastTunnelStrength) > 0.02) then {
                    [_tunnelStrength] call GAIT_fnc_setTunnelVisionFX;
                    _lastTunnelStrength = _tunnelStrength;
                };

                // =====================================================
                // FATIGUE / PANTING EFFECTS
                // =====================================================
                if (_isSprinting && {_sprintReserve <= 0}) then {
                    // Immediately show max fatigue effects after sprint reserve is exhausted
                    _visualFatigue = _exhaustedFatigue;
                } else {
                    // Recover fatigue effects when not exhausted
                    _visualFatigue = _visualFatigue - (_fatigueRecoverRate * _dt);

                    if (_visualFatigue < _freshFatigue) then {
                        _visualFatigue = _freshFatigue;
                    };
                };

                if (_uphillFatigueDrainSeverityNow > 0) then {
                    _visualFatigue = (_visualFatigue + ((_uphillVanillaFatigueExtraPerSecond max 0) * _uphillFatigueDrainSeverityNow * _dt)) min _exhaustedFatigue;
                };

                if (!_aceAdvancedFatigueActive && {_gaitMovementEnabled} && {_movementEligible}) then {
                    player setFatigue _visualFatigue;
                };

                // =====================================================
                // ACE HEARING REDUCTION
                // Ramps down as sprint reserve approaches empty.
                // Resets to normal when reserve fully recovers.
                // =====================================================
                if (_gaitHearingEnabled && {missionNamespace getVariable ["GAIT_ss_hearingEnabled", true]} && {!isNil "ace_common_fnc_setHearingCapability"}) then {
                    private _hearingVolume = 1 - ((1 - _hearingMinVolume) * (1 - _reserveRatio));

                    if (_hearingVolume < _hearingMinVolume) then {
                        _hearingVolume = _hearingMinVolume;
                    };

                    if (_hearingVolume > 1) then {
                        _hearingVolume = 1;
                    };

                    if (_sprintReserve >= (_sprintReserveMax - 0.05)) then {
                        if (_lastHearingVolume < 0.99) then {
                            [1, _hearingFadeDuration, false] call GAIT_fnc_setSprintHearing;
                            _lastHearingVolume = 1;
                        };
                    } else {
                        if (abs (_hearingVolume - _lastHearingVolume) > 0.02) then {
                            [_hearingVolume, _hearingFadeDuration, true] call GAIT_fnc_setSprintHearing;
                            _lastHearingVolume = _hearingVolume;
                        };
                    };
                } else {
                    if (!isNil "ace_common_fnc_setHearingCapability") then {
                        if (_lastHearingVolume < 0.99) then {
                            [1, _hearingFadeDuration, false] call GAIT_fnc_setSprintHearing;
                            _lastHearingVolume = 1;
                        };
                    };
                };

                // =====================================================
                // SPEED CONTROL
                // =====================================================
                private _flatSprintPace = _sprintExhaustedSpeed + ((_sprintFullSpeed - _sprintExhaustedSpeed) * _reserveRatio);
                if ((currentWeapon player) isEqualTo "") then {
                    _flatSprintPace = _flatSprintPace * _unarmedSprintNormalizer;
                };
                // Conservative coefficient floor: assume equal base root motion
                // for the run and walking reference, until measured in Arma.
                // Selected running clips must exceed walking at equal coefficient.
                // This is a target relation, not measured metres per second.
                private _paceFloorRatio = (missionNamespace getVariable ["GAIT_ss_minSprintWalkRatio", 1.20]) + (_reserveRatio * (missionNamespace getVariable ["GAIT_ss_freshSprintWalkMargin", 0.20]));
                private _pacePair = [_normalSpeed, _flatSprintPace, _hillWalkSlowdownMultiplier, _slopeSpeedMultiplier, _weightSpeedMult, _paceFloorRatio] call GAIT_fnc_slopePaceModel;
                private _targetSpeed = _pacePair select (if (_isSprinting) then {1} else {0});
                missionNamespace setVariable ["GAIT_walkPaceTarget", _pacePair select 0];
                missionNamespace setVariable ["GAIT_sprintPaceTarget", _pacePair select 1];
                missionNamespace setVariable ["GAIT_loadPaceMultiplier", _weightSpeedMult];

                if (_isAceCarrying && {!isNull _carriedObject}) then {
                    // Carry animations remain owned by ACE; no slope-state remap.
                    _targetSpeed = (if (_isSprinting) then {
                        (_carrySprintExhaustedSpeed + ((_carrySprintFullSpeed - _carrySprintExhaustedSpeed) * _reserveRatio)) * _slopeSpeedMultiplier
                    } else {_carryWalkSpeed * _hillWalkSlowdownMultiplier}) * _weightSpeedMult;
                };

                // Optional measured-clip interface. No unverified speed
                // profiles ship; absent calibration is exactly the legacy pair.
                // Steady targets are resolved BEFORE the unchanged brace/ramp.
                missionNamespace setVariable ["GAIT_paceCalibrated", false];
                missionNamespace setVariable ["GAIT_walkTargetMS", -1];
                missionNamespace setVariable ["GAIT_sprintTargetMS", -1];
                if (_isSprinting && {_sprintBraceEndTime <= time} && {_gaitStanceOk} && {!_isAceCarrying} && {_slopeHandlingEnabled} && {missionNamespace getVariable ["GAIT_ss_slopeLocomotionEnabled", true]}) then {
                    private _family = [player] call GAIT_fnc_slopeWeaponFamily;
                    private _direction = [_movementInput select 0, _movementInput select 1] call GAIT_fnc_slopeDirection;
                    private _resolved = [_normalSpeed, _flatSprintPace, _hillWalkSlowdownMultiplier, _slopeSpeedMultiplier, _weightSpeedMult, _paceFloorRatio,
                        missionNamespace getVariable ["GAIT_locomotionPaceProfiles", []], _family, _direction, "sprint"] call GAIT_fnc_locomotionPaceTargets;
                    _pacePair = _resolved select [0, 2];
                    _targetSpeed = _pacePair select 1;
                    missionNamespace setVariable ["GAIT_walkPaceTarget", _pacePair select 0];
                    missionNamespace setVariable ["GAIT_sprintPaceTarget", _pacePair select 1];
                    missionNamespace setVariable ["GAIT_walkTargetMS", _resolved select 2];
                    missionNamespace setVariable ["GAIT_sprintTargetMS", _resolved select 3];
                    missionNamespace setVariable ["GAIT_paceCalibrated", _resolved select 4];
                };

                // v1.1.49: releasing Shift while still holding W should not snap from
                // run speed to walk speed, especially at max exhaustion. Hold the last
                // real run speed for a short sustain window, then taper toward W-only speed.
                private _shiftReleaseTaperActiveNow = false;
                private _shiftReleaseTaperHoldActiveNow = false;
                private _shiftReleaseTaperKeepNow = 0;
                private _shiftReleaseTaperTargetKmhNow = 0;
                if (_shiftReleaseRunTaperEnabled && {!_isSprinting} && {_movementEligible} && {!_externalWalkLock} && {!_externalSprintLock} && {!_isLateralHeld} && {_isForwardHeld} && {!_isBackHeld} && {time <= _shiftReleaseTaperActiveUntil}) then {
                    private _holdDuration = _activeCoastHold;
                    private _taperDuration = _activeCoastDuration;
                    private _elapsedSinceShift = (time - _lastShiftReleaseTime) max 0;
                    private _taperKeep = 1;
                    if (_elapsedSinceShift <= _holdDuration) then {
                        _shiftReleaseTaperHoldActiveNow = true;
                    } else {
                        private _taperRaw = ((_elapsedSinceShift - _holdDuration) / _taperDuration) max 0 min 1;
                        private _taperCurve = (_shiftReleaseRunTaperCurve max 0.25) min 5.0;
                        _taperKeep = (1 - _taperRaw) ^ _taperCurve;
                    };
                    private _taperStart = _shiftReleaseTaperStartSpeed max _targetSpeed;
                    _targetSpeed = _targetSpeed max (_targetSpeed + ((_taperStart - _targetSpeed) * _taperKeep));
                    _shiftReleaseTaperActiveNow = true;
                    _shiftReleaseTaperKeepNow = _taperKeep;
                    _shiftReleaseTaperTargetKmhNow = _actualSpeedKmh; // measured speed
                } else {
                    if (!_isForwardHeld || {_isBackHeld} || {_isLateralHeld} || {_isSprinting} || {!_movementEligible} || {_externalWalkLock} || {_externalSprintLock}) then {
                        _shiftReleaseTaperActiveUntil = -999;
                    };
                };
                missionNamespace setVariable ["GAIT_shiftReleaseRunTaperActive", _shiftReleaseTaperActiveNow];
                missionNamespace setVariable ["GAIT_shiftReleaseRunTaperHoldActive", _shiftReleaseTaperHoldActiveNow];
                missionNamespace setVariable ["GAIT_shiftReleaseRunTaperKeep", _shiftReleaseTaperKeepNow];
                missionNamespace setVariable ["GAIT_shiftReleaseRunTaperStartSpeed", _shiftReleaseTaperStartSpeed];
                missionNamespace setVariable ["GAIT_shiftReleaseRunTaperStartKmh", _shiftReleaseTaperStartKmh];
                missionNamespace setVariable ["GAIT_shiftReleaseRunTaperTargetKmh", _shiftReleaseTaperTargetKmhNow];

                // Frame-rate independent speed ramp. Direction is never filtered.
                private _hasMovementInput = _isForwardHeld || {_isBackHeld} || {_isLateralHeld};
                if (_gaitMovementEnabled && {_movementEligible} && {_hasMovementInput}) then {
                    private _ramp = if (_uphillBrakeActive) then {_uphillBrakeRamp} else {
                        if (_isSprinting && {_sprintBraceEndTime > time}) then {_sprintStartBraceLerp} else {_speedLerp}
                    };
                    private _rampTarget = if (_uphillBrakeActive) then {_uphillBrakeTarget min _currentSpeed} else {
                        if (_isSprinting && {_sprintBraceEndTime > time}) then {_activeBraceSpeed min _targetSpeed} else {_targetSpeed}
                    };
                    // Load changes response time, never requested direction.
                    // Launch/braking steps retain their own calibrated snap rate.
                    if (!_isAceCarrying && {!_uphillBrakeActive} && {!(_isSprinting && {_sprintBraceEndTime > time})}) then {
                        _ramp = [_ramp, [_decelerationScale, _accelerationScale] select (_rampTarget > _currentSpeed)] call GAIT_fnc_scaleInertiaRamp;
                    };
                    _currentSpeed = [_currentSpeed, _rampTarget, _ramp, _dt] call GAIT_fnc_stepSpeedCoefficient;
                    // Honor walk/injury locks and avoid carrying a sprint boost sideways.
                    private _coef = _currentSpeed;
                    if (!_isForwardHeld || {_externalSprintLock} || {_externalWalkLock}) then {
                        _coef = _coef min _effectiveNormalSpeed;
                    };
                    [player, _coef, _isAceCarrying] call GAIT_fnc_applyNativeMovement;

                } else {
                    // Keep internal momentum through a short W release while
                    // the body is still moving. No velocity is added or forced.
                    if (_uphillBrakeActive) then {
                        _currentSpeed = [_currentSpeed, _uphillBrakeTarget min _currentSpeed, _uphillBrakeRamp, _dt] call GAIT_fnc_stepSpeedCoefficient;
                    } else {
                        if (_hasRetainedSprintMomentum) then {
                            // No-input history decays too. It may protect a fast
                            // re-tap, but cannot retain a sprint multiplier forever.
                            _currentSpeed = [_currentSpeed, (_effectiveNormalSpeed * _hillWalkSlowdownMultiplier) min _currentSpeed,
                                [_speedLerp, _decelerationScale] call GAIT_fnc_scaleInertiaRamp, _dt] call GAIT_fnc_stepSpeedCoefficient;
                        } else {_currentSpeed = _effectiveNormalSpeed;};
                    };
                    _shiftReleaseTaperActiveUntil = -999;
                    if (_gaitMovementEnabled && {_movementEligible} && {_turboHeld || {_uphillBrakeActive}} && {_gaitStanceOk} && {!_isAceCarrying}) then {
                        // Only preserve the numerical brake while it sheds speed.
                        // Draw3D selects native idle from the current stop input.
                        if (_uphillBrakeActive) then {
                            [player, _currentSpeed, false] call GAIT_fnc_applyNativeMovement;
                        } else {[] call GAIT_fnc_releaseSpeedCoefficient;};
                    } else {
                        // Draw3D consumes current direction for the body exit.
                        // A scheduled no-input sample must not preempt a newer
                        // sprint/strafe input with an obsolete animation release.
                        [] call GAIT_fnc_releaseSpeedCoefficient;
                    };
                };
                // A remaining shallow-slope coast may hold only the speed
                // left after braking, never resurrect the pre-brake sprint.
                if (_uphillBrakeActive) then {
                    _shiftReleaseTaperStartSpeed = _shiftReleaseTaperStartSpeed min _currentSpeed;
                };
                // Read-only acceptance telemetry; these values never feed back
                // into the preserved brace, reserve or momentum calculation.
                missionNamespace setVariable ["GAIT_plannedMovementCoefficient", _currentSpeed];
                missionNamespace setVariable ["GAIT_observedReserveRatio", _reserveRatio];
                // Movement-family ownership is independent of forward sprint
                // effort. Pure A/D keeps native directional selection in the
                // same graph without changing reserve/brace or sideways caps.
                private _coastActive = [_shiftReleaseRunTaperEnabled, _isSprinting, _isForwardHeld, _isLateralHeld,
                    _hasRetainedSprintMomentum, _horizontalSpeedMS > 0.25, _currentSpeed, _pacePair select 0,
                    time, _shiftReleaseTaperActiveUntil, _shiftReleaseTaperActiveNow] call GAIT_fnc_gearCoastActive;
                _coastActive = _coastActive && {!_uphillBrakeActive} && {_movementEligible} && {!_externalSprintLock} && {!_externalWalkLock};
                private _fastMoveIntent = _gaitMovementEnabled && {_turboHeld || {_uphillBrakeActive} || {_coastActive}} && {_gaitStanceOk} && {!_isAceCarrying};
                private _coastPrearm = _shiftReleaseRunTaperEnabled && {_momentumContextOk} && {_isSprinting} &&
                    {_sprintBraceEndTime <= time} && {_horizontalSpeedMS > 0.25};
                private _brakePrearm = _uphillBrakeEnabled && {_uphillBrakeContext} && {_isSprinting} &&
                    {_sprintBraceEndTime <= time} && {_horizontalSpeedMS > 0.25} && {_slopeDegrees > _slopeStopBraceStartDegrees};
                // Publish the render-controller request and its brake stage
                // atomically. The bounded prearm covers an earlier raw release.
                isNil {
                    missionNamespace setVariable ["GAIT_coastUnit", player];
                    missionNamespace setVariable ["GAIT_coastActive", _coastActive];
                    missionNamespace setVariable ["GAIT_coastReadyUntil", if (_coastPrearm) then {diag_tickTime + ((3 * _tickRate) max 0.10 min 0.15)} else {-1}];
                    missionNamespace setVariable ["GAIT_uphillBrakeUnit", player];
                    missionNamespace setVariable ["GAIT_uphillBrakeActive", _uphillBrakeActive];
                    missionNamespace setVariable ["GAIT_uphillBrakeEndTime", if (_uphillBrakeActive) then {_uphillBrakeState select 3} else {-1}];
                    missionNamespace setVariable ["GAIT_uphillBrakeReadyUntil", if (_brakePrearm) then {diag_tickTime + ((3 * _tickRate) max 0.15 min 0.50)} else {-1}];
                    missionNamespace setVariable ["GAIT_uphillBrakeSeverity", _uphillBrakeSeverity];
                    missionNamespace setVariable ["GAIT_uphillBrakeTarget", _uphillBrakeTarget];
                    missionNamespace setVariable ["GAIT_braceActive", _uphillBrakeActive || {_isSprinting && {_sprintBraceEndTime > time}}];
                    missionNamespace setVariable ["GAIT_braceEndTime", if (_uphillBrakeActive) then {_uphillBrakeState select 3} else {_sprintBraceEndTime}];
                    [player, _fastMoveIntent, _movementInput, _externalSprintLock || {_externalWalkLock}] call GAIT_fnc_updateSlopeLocomotion;
                };
                if (_debugHudEnabled && {(time - _lastDebugHudTime) >= ((_debugHudInterval max 0.05) min 1)}) then {
                    _lastDebugHudTime = time;
                    hintSilent parseText format [
                        "<t align='left' size='0.82'>GAIT 1.8.0-alpha4<br/>Travel grade: %1 degrees | Speed: %2 km/h<br/>Input F/R: %3 / %4<br/>Coefficient: %5 | ACE reserve: %6%%<br/>Animation: %7<br/>ACE bridge: %8 | Block sprint / walk: %9 / %10<br/>Slope family: %11 | Walk / sprint target: %12 / %13<br/>Foundation: %14 | Measured pace profile: %15</t>",
                        _slopeDegrees toFixed 1, _actualSpeedKmh toFixed 1,
                        (_movementInput select 0) toFixed 2, (_movementInput select 1) toFixed 2,
                        (getAnimSpeedCoef player) toFixed 2, (_reserveRatio * 100) toFixed 0,
                        animationState player,
                        missionNamespace getVariable ["GAIT_nativeAceBridgeInstalled", false],
                        player getVariable ["ace_common_effect_blockSprint", 0],
                        player getVariable ["ace_common_effect_forceWalk", 0],
                        missionNamespace getVariable ["GAIT_slopeLocomotionActive", false],
                        (_pacePair select 0) toFixed 2, (_pacePair select 1) toFixed 2,
                        missionNamespace getVariable ["GAIT_locomotionPhase", "native"],
                        missionNamespace getVariable ["GAIT_paceCalibrated", false]
                    ];
                };
            } else {
                // Fast Carry pickup/lift owns its animation.
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
            _shiftReleaseTaperActiveUntil = -999;
            _lastShiftReleaseTime = -999;
            [] call GAIT_fnc_releaseNativeMovement;
            _sprintReserve = _sprintReserveMax;
            _currentSpeed = _normalSpeed;
            if (alive player && {!(call GAIT_fnc_modeIsActive)}) then {
                [] call GAIT_fnc_releaseNativeMovement;
                player setCustomAimCoef 1;
            };
            _visualFatigue = _freshFatigue;
            _wasSprinting = false;
            _sprintBraceEndTime = -1;
            _walkingStartTime = -1;
            _lastSprintEndTime = -999;
            _braceArmedFromCrouch = false;
            _lastForwardInputTime = time;
            missionNamespace setVariable ["GAIT_exhaustionLevel", 0];
            missionNamespace setVariable ["GAIT_tinnitusTargetVolume", 0];
            missionNamespace setVariable ["GAIT_tinnitusCurrentVolume", 0];

            if (!isNil "ace_common_fnc_setHearingCapability") then {
                [1, 0.1, false] call GAIT_fnc_setSprintHearing;
            };

            [0, true] call GAIT_fnc_setTunnelVisionFX;
            _lastTunnelStrength = 0;
            _lastHearingVolume = 1;
        };


        uiSleep _tickRate;
    };
};
