/*
    GAIT - CBA Addon Options
    Registers readable in-game Addon Options for every active tuning value.
*/

if (isNil "CBA_fnc_addSetting") exitWith {};

private _categoryGeneral = ["GAIT", "01 General"];
private _categoryACE = ["GAIT", "02 ACE Advanced Fatigue Integration"];
private _categoryMove = ["GAIT", "03 Movement and Sprint"];
private _categoryCarry = ["GAIT", "04 ACE Carry Movement"];
private _categoryWeight = ["GAIT", "05 Gear Weight Gates"];
private _categoryBrace = ["GAIT", "06 Brace Step and Momentum"];
private _categorySway = ["GAIT", "07 Weapon Sway"];
private _categoryAudio = ["GAIT", "08 Audio and Hearing"];
private _categoryVisual = ["GAIT", "09 Tunnel Vision Visuals"];
private _categorySlope = ["GAIT", "10 Terrain, Slopes, and Tripping"];
private _categoryQoL = ["GAIT", "11 QoL, Presets, and Compatibility"];

private _addCheckbox = {
    params ["_name", "_title", "_tooltip", "_category", "_default"];
    [
        _name,
        "CHECKBOX",
        [_title, _tooltip],
        _category,
        _default,
        true,
        {},
        false
    ] call CBA_fnc_addSetting;
};

private _addSlider = {
    params ["_name", "_title", "_tooltip", "_category", "_min", "_max", "_default", ["_decimals", 2]];
    [
        _name,
        "SLIDER",
        [_title, _tooltip],
        _category,
        [_min, _max, _default, _decimals],
        true,
        {},
        false
    ] call CBA_fnc_addSetting;
};

private _addList = {
    params ["_name", "_title", "_tooltip", "_category", "_values", "_labels", "_defaultIndex"];
    [
        _name,
        "LIST",
        [_title, _tooltip],
        _category,
        [_values, _labels, _defaultIndex],
        true,
        {},
        false
    ] call CBA_fnc_addSetting;
};

// -----------------------------------------------------
// 01 General
// -----------------------------------------------------
["GAIT_ss_enabled", "Enable GAIT", "Master switch for GAIT's sprint, brace, momentum, sway, audio, and visual systems. Turn off to release GAIT runtime control. The addon terrainSpeedCoef config remains until the addon is unloaded.", _categoryGeneral, true] call _addCheckbox;
["GAIT_ss_tickRate", "Update rate", "Movement update interval in seconds. Acceleration timing stays consistent across update rates. Default: 0.05.", _categoryGeneral, 0.01, 0.20, 0.05, 2] call _addSlider;

["GAIT_ss_masterTripFrequency", "Master: trip frequency", "Meta-knob that scales downhill trip chance without changing thresholds. 1.00 is baseline.", _categoryGeneral, 0.00, 3.00, 1.00, 2] call _addSlider;
["GAIT_ss_masterFxIntensity", "Master: FX intensity", "Meta-knob that scales tinnitus/hearing/visual exhaustion effects. 1.00 is baseline.", _categoryGeneral, 0.00, 2.00, 1.00, 2] call _addSlider;

// -----------------------------------------------------
// 02 ACE Advanced Fatigue Integration
// -----------------------------------------------------
["GAIT_ss_aceBridgeEnabled", "Use ACE Advanced Fatigue physiology", "Lets ACE Advanced Fatigue provide the endurance/acidosis/muscle-damage model while GAIT controls movement feel.", _categoryACE, true] call _addCheckbox;
["GAIT_ss_useAceReserveModel", "Use ACE reserve for sprint strength", "Reads ACE anaerobic/aerobic reserves, acidosis, and muscle damage to scale GAIT sprint speed and exhaustion effects.", _categoryACE, true] call _addCheckbox;
["GAIT_ss_clearAceMovementLocks", "Prevent ACE walk-lock override", "Clears only ACE Advanced Fatigue's forced-walk and block-sprint locks so GAIT movement is not overwritten.", _categoryACE, true] call _addCheckbox;
["GAIT_ss_registerAceAnimExclusion", "Protect GAIT animation speed", "Adds GAIT to ACE Advanced Fatigue's animation-speed exclusion list so ACE does not reset GAIT speed every fatigue tick.", _categoryACE, true] call _addCheckbox;
["GAIT_ss_aceAcidosisPenaltyFactor", "Acidosis sprint penalty", "How strongly ACE anaerobic fatigue/acidosis reduces GAIT sprint reserve. Higher means acidosis hurts speed sooner. Default: 0.45.", _categoryACE, 0.00, 1.00, 0.45, 2] call _addSlider;
["GAIT_ss_aceMuscleDamagePenaltyFactor", "Muscle-damage sprint penalty", "How strongly ACE muscle damage reduces GAIT sprint reserve. Higher means long-duration overwork hurts speed more. Default: 0.25.", _categoryACE, 0.00, 1.00, 0.25, 2] call _addSlider;

// -----------------------------------------------------
// 03 Movement and Sprint
// -----------------------------------------------------
["GAIT_ss_normalSpeed", "Normal movement speed", "Base animation speed while not sprinting. 1.00 is normal Arma speed. Default: 0.86.", _categoryMove, 0.50, 1.50, 0.86, 2] call _addSlider;
["GAIT_ss_sprintFullSpeed", "Fresh sprint speed", "Sprint speed multiplier while reserve is high. Default: 1.28.", _categoryMove, 0.70, 2.00, 1.28, 2] call _addSlider;
["GAIT_ss_sprintExhaustedSpeed", "Exhausted sprint speed", "Sprint speed multiplier when reserve is depleted. Default: 0.89.", _categoryMove, 0.40, 1.50, 0.89, 2] call _addSlider;
["GAIT_ss_sprintReserveMax", "Fallback sprint reserve", "Seconds of full sprint used when ACE Advanced Fatigue is unavailable or has not initialized yet. Default: 25.", _categoryMove, 1.00, 120.00, 25.00, 0] call _addSlider;
["GAIT_ss_sprintRecoverTime", "Fallback recovery time", "Seconds to fully recover the fallback GAIT reserve when ACE Advanced Fatigue is unavailable. Default: 10.", _categoryMove, 1.00, 60.00, 10.00, 0] call _addSlider;
["GAIT_ss_speedLerp", "Speed ramp smoothness", "How quickly current speed moves toward target speed. Lower is smoother/slower; higher is snappier. Default: 0.05.", _categoryMove, 0.01, 1.00, 0.05, 2] call _addSlider;
["GAIT_ss_wReleaseZeroMomentumDelay", "W-release zero-momentum delay", "Seconds after releasing forward movement before the next sprint start is treated as zero momentum. Lower values make brace return sooner. Default: 0.50.", _categoryMove, 0.00, 20.00, 0.50, 2] call _addSlider;
["GAIT_ss_shiftReleaseRunTaperEnabled", "Smooth Shift-release taper", "When Shift is released but W remains held, GAIT keeps current running speed briefly and smoothly tapers to normal W movement instead of snapping down. Default: enabled.", _categoryMove, true] call _addCheckbox;
["GAIT_ss_shiftReleaseRunTaperDuration", "Shift-release taper duration", "Seconds used to taper from sustained run speed to W-only speed after releasing Shift while holding W. Default: 0.85 sec.", _categoryMove, 0.05, 4.00, 0.85, 2] call _addSlider;
["GAIT_ss_shiftReleaseRunTaperHoldDuration", "Shift-release sustain", "Seconds to hold the previous running speed after releasing Shift while W remains held before tapering down. Default: 1.00 sec.", _categoryMove, 0.00, 3.00, 1.00, 2] call _addSlider;
["GAIT_ss_shiftReleaseRunTaperCurve", "Shift-release taper curve", "Higher values hold speed briefly then brake later; lower values taper more linearly. Default: 1.45.", _categoryMove, 0.25, 5.00, 1.45, 2] call _addSlider;
["GAIT_ss_unarmedSprintNormalizer", "Unarmed sprint normalizer", "Multiplier applied when sprinting with no weapon out so holstering does not create an unrealistic speed boost. Default: 0.725.", _categoryMove, 0.30, 1.20, 0.725, 3] call _addSlider;
["GAIT_ss_freshFatigue", "Rested visual fatigue", "Lowest vanilla fatigue value used when ACE Advanced Fatigue is not active. Default: 0.05.", _categoryMove, 0.00, 0.50, 0.05, 2] call _addSlider;
["GAIT_ss_exhaustedFatigue", "Exhausted visual fatigue", "Highest vanilla fatigue value used when ACE Advanced Fatigue is not active. Default: 0.85.", _categoryMove, 0.10, 1.00, 0.85, 2] call _addSlider;

// -----------------------------------------------------
// 04 ACE Carry Movement
// -----------------------------------------------------
["GAIT_ss_carryWalkSpeed", "Carry walk speed", "Animation speed while carrying a casualty and not sprinting. Default: 0.80.", _categoryCarry, 0.30, 1.50, 0.80, 2] call _addSlider;
["GAIT_ss_carrySprintFullSpeed", "Fresh carry sprint speed", "Carry sprint speed while reserve is high. Default: 1.50.", _categoryCarry, 0.50, 2.50, 1.50, 2] call _addSlider;
["GAIT_ss_carrySprintExhaustedSpeed", "Exhausted carry sprint speed", "Carry sprint speed when reserve is depleted. Default: 0.90.", _categoryCarry, 0.30, 1.50, 0.90, 2] call _addSlider;

// -----------------------------------------------------
// 05 Gear Weight Gates
// -----------------------------------------------------
["GAIT_ss_loadAbsPerLb", "Load-to-pound divisor", "Conversion used for display-style gear weight. Gear pounds = loadAbs divided by this value. Default: 10.", _categoryWeight, 1.00, 25.00, 10.00, 1] call _addSlider;
["GAIT_ss_lightWeightMax", "Light kit max weight", "Upper weight for the light-kit speed/brace tier. Default: 35 lb.", _categoryWeight, 0.00, 100.00, 35.00, 0] call _addSlider;
["GAIT_ss_mediumWeightMax", "Medium kit max weight", "Upper weight for the medium-kit speed/brace tier. Default: 55 lb.", _categoryWeight, 0.00, 150.00, 55.00, 0] call _addSlider;
["GAIT_ss_moderateWeightMax", "Moderate kit max weight", "Upper weight for the moderate-kit speed/brace tier. Above this uses heavy baseline. Default: 75 lb.", _categoryWeight, 0.00, 200.00, 75.00, 0] call _addSlider;
["GAIT_ss_lightSpeedBonus", "Zero-load speed multiplier", "Continuous speed curve at zero carried load. Default: 1.08.", _categoryWeight, 0.50, 1.50, 1.08, 3] call _addSlider;
["GAIT_ss_mediumSpeedBonus", "Light threshold speed multiplier", "Continuous speed curve at the light weight threshold. Default: 1.05.", _categoryWeight, 0.50, 1.50, 1.05, 3] call _addSlider;
["GAIT_ss_moderateSpeedBonus", "Medium threshold speed multiplier", "Continuous speed curve at the medium weight threshold. Default: 1.025.", _categoryWeight, 0.50, 1.50, 1.025, 3] call _addSlider;
["GAIT_ss_heavySpeedBonus", "Heavy threshold speed multiplier", "Continuous speed curve at the heavy weight threshold; extra weight reduces pace further. Default: 1.00.", _categoryWeight, 0.50, 1.50, 1.00, 3] call _addSlider;
["GAIT_ss_lightBraceRelief", "Light kit brace relief", "How much the brace-step slowdown is softened for light kits. 0 = full brace; 1 = almost no brace dip. Default: 0.55.", _categoryWeight, 0.00, 1.00, 0.55, 2] call _addSlider;
["GAIT_ss_mediumBraceRelief", "Medium kit brace relief", "How much the brace-step slowdown is softened for medium kits. Default: 0.35.", _categoryWeight, 0.00, 1.00, 0.35, 2] call _addSlider;
["GAIT_ss_moderateBraceRelief", "Moderate kit brace relief", "How much the brace-step slowdown is softened for moderate kits. Default: 0.18.", _categoryWeight, 0.00, 1.00, 0.18, 2] call _addSlider;
["GAIT_ss_heavyBraceRelief", "Heavy kit brace relief", "How much the brace-step slowdown is softened for heavy kits. Default: 0.00.", _categoryWeight, 0.00, 1.00, 0.00, 2] call _addSlider;

// -----------------------------------------------------
// 06 Brace Step and Momentum
// -----------------------------------------------------
["GAIT_ss_sprintStartBraceEnabled", "Enable brace step", "Enables the initial heavy step/pace dip when starting sprint from zero or settled momentum.", _categoryBrace, true] call _addCheckbox;
["GAIT_ss_sprintStartBraceDuration", "Brace duration", "How long the start-brace slowdown lasts, in seconds. Default: 0.15.", _categoryBrace, 0.00, 1.00, 0.15, 2] call _addSlider;
["GAIT_ss_sprintStartBraceSpeed", "Brace speed", "Animation speed target during the brace step. Lower is a stronger dip. Default: 0.42.", _categoryBrace, 0.10, 1.20, 0.42, 2] call _addSlider;
["GAIT_ss_sprintStartBraceLerp", "Brace snap", "How abruptly speed moves into the brace step. Higher is sharper; lower is smoother. Default: 0.575.", _categoryBrace, 0.01, 1.00, 0.575, 3] call _addSlider;
["GAIT_ss_braceRequiredWalkTime", "Settle time before brace", "Seconds standing or slow-walking before the next sprint start is eligible for brace. Default: 2.", _categoryBrace, 0.00, 10.00, 2.00, 1] call _addSlider;
["GAIT_ss_braceRecentSprintCooldown", "Momentum grace time", "Seconds after a sprint where re-pressing Shift preserves momentum and avoids another brace. Default: 3.", _categoryBrace, 0.00, 10.00, 3.00, 1] call _addSlider;
["GAIT_ss_braceMinReserveRatio", "Brace reserve gate", "Minimum GAIT reserve ratio needed for brace when ACE reserve is not active. With ACE active, movement state owns brace. Default: 0.98.", _categoryBrace, 0.00, 1.00, 0.98, 2] call _addSlider;
["GAIT_ss_braceNoMomentumThreshold", "No-momentum threshold", "If current speed is within this amount of normal speed, next sprint start is treated as zero momentum and braces. Default: 0.04.", _categoryBrace, 0.00, 0.50, 0.04, 2] call _addSlider;
["GAIT_ss_braceReadySpeedThreshold", "Brace-ready movement speed", "Maximum non-sprint movement speed that can arm the next brace. Higher makes walking/slow movement more likely to re-arm brace. Default: 4.0.", _categoryBrace, 0.00, 10.00, 4.00, 1] call _addSlider;
["GAIT_ss_slopeStopBraceEnabled", "Slope stop brace", "If enabled, stopping and restarting sprint on an incline makes the initial brace step more pronounced based on slope angle. Default: enabled.", _categoryBrace, true] call _addCheckbox;
["GAIT_ss_slopeStopBraceStartDegrees", "Slope brace starts", "Incline/decline angle where slope-aware brace begins. Default: 15 degrees.", _categoryBrace, 0.00, 60.00, 15.00, 1] call _addSlider;
["GAIT_ss_slopeStopBraceMaxDegrees", "Slope brace max angle", "Slope angle where the extra brace reaches full strength. Default: 35 degrees.", _categoryBrace, 5.00, 80.00, 35.00, 1] call _addSlider;
["GAIT_ss_slopeStopBraceExtraDuration", "Slope brace extra duration", "Extra brace duration added on steep inclines/declines. Default: 0.18 sec.", _categoryBrace, 0.00, 2.00, 0.18, 2] call _addSlider;
["GAIT_ss_slopeStopBraceExtraDip", "Slope brace extra dip", "Additional speed dip applied to the brace step on steep slopes. Default: 0.28.", _categoryBrace, 0.00, 0.90, 0.28, 2] call _addSlider;
["GAIT_ss_slopeStopBraceMemoryTime", "Slope brace memory", "Seconds after stopping sprint on an incline where the next sprint start still uses the slope brace. Default: 2.5 sec.", _categoryBrace, 0.00, 10.00, 2.50, 1] call _addSlider;

// -----------------------------------------------------
// 07 Weapon Sway
// -----------------------------------------------------
["GAIT_ss_swayEnabled", "Enable GAIT weapon sway", "Lets GAIT control sprint sway, walking steadiness, and recovery. Turn off to leave custom aim coefficient at vanilla.", _categorySway, true] call _addCheckbox;
["GAIT_ss_restingAimCoef", "Rested aim coefficient", "Aim sway coefficient when fully recovered and not moving. Lower is steadier. Default: 0.02.", _categorySway, 0.00, 2.00, 0.02, 2] call _addSlider;
["GAIT_ss_walkingAimCoef", "Walking aim coefficient", "Aim sway coefficient while moving but not sprinting. Default: 0.01.", _categorySway, 0.00, 2.00, 0.01, 2] call _addSlider;
["GAIT_ss_runningAimCoef", "Sprint aim penalty", "Aim sway coefficient while sprinting. Higher is more sway. Default: 2.0.", _categorySway, 0.00, 10.00, 2.00, 2] call _addSlider;
["GAIT_ss_swayRecoveryTime", "Sway recovery time", "Seconds for sway to recover after sprinting. Default: 6.", _categorySway, 0.10, 30.00, 6.00, 1] call _addSlider;
["GAIT_ss_walkingSpeedThreshold", "Walking sway speed threshold", "Minimum movement speed needed to use the walking aim coefficient. Default: 0.6.", _categorySway, 0.00, 5.00, 0.60, 2] call _addSlider;

// -----------------------------------------------------
// 08 Audio and Hearing
// -----------------------------------------------------
["GAIT_ss_tinnitusEnabled", "Enable tinnitus loop", "Enables GAIT tinnitus at high exhaustion. ACE Advanced Fatigue already owns heartbeat/pulse audio.", _categoryAudio, true] call _addCheckbox;
["GAIT_ss_tinnitusStartExhaustion", "Tinnitus starts at exhaustion", "Exhaustion level where tinnitus begins. 0 = immediately, 1 = only at max exhaustion. Default: 0.70.", _categoryAudio, 0.00, 1.00, 0.70, 2] call _addSlider;
["GAIT_ss_audioStopExhaustion", "Audio stops below exhaustion", "Exhaustion level below which GAIT exhaustion audio fades out. Default: 0.10.", _categoryAudio, 0.00, 1.00, 0.10, 2] call _addSlider;
["GAIT_ss_tinnitusMaxVolume", "Tinnitus max volume", "Maximum volume of the GAIT tinnitus loop. Default: 0.55.", _categoryAudio, 0.00, 2.00, 0.55, 2] call _addSlider;
["GAIT_ss_audioFadeLerp", "Audio fade smoothness", "How quickly tinnitus volume moves toward its target. Higher changes faster. Default: 0.08.", _categoryAudio, 0.01, 1.00, 0.08, 2] call _addSlider;
["GAIT_ss_hearingEnabled", "Enable hearing reduction", "Reduces hearing as exhaustion rises using ACE hearing capability. Default: enabled.", _categoryAudio, true] call _addCheckbox;
["GAIT_ss_hearingMinVolume", "Minimum hearing volume", "Lowest hearing volume at maximum exhaustion. 1 = no reduction, 0 = muted. Default: 0.20.", _categoryAudio, 0.00, 1.00, 0.20, 2] call _addSlider;
["GAIT_ss_hearingFadeDuration", "Hearing fade duration", "Seconds used when changing hearing volume. Default: 0.20.", _categoryAudio, 0.00, 5.00, 0.20, 2] call _addSlider;

// -----------------------------------------------------
// 09 Tunnel Vision Visuals
// -----------------------------------------------------
["GAIT_ss_visualFxEnabled", "Enable tunnel vision visuals", "v1.6.0: GAIT post-process FX (tunnel vision, blur, chromatic aberration, color correction) are removed; ACE Advanced Fatigue owns visual fatigue. This toggle no longer applies any screen effect. Default: disabled.", _categoryVisual, false] call _addCheckbox;
["GAIT_ss_tunnelStartExhaustion", "Visuals start at exhaustion", "Exhaustion level where tunnel vision begins. Default: 0.18.", _categoryVisual, 0.00, 1.00, 0.18, 2] call _addSlider;
["GAIT_ss_tunnelMaxStrength", "Maximum visual strength", "Overall cap for exhaustion visual strength. Default: 1.0.", _categoryVisual, 0.00, 2.00, 1.00, 2] call _addSlider;


// -----------------------------------------------------
// 10 Terrain, Slopes, and Tripping
// -----------------------------------------------------
["GAIT_ss_slopeHandlingEnabled", "Enable slope handling", "Enables GAIT terrain-aware sprint behavior. Uphill sprinting slows progressively instead of being blocked; downhill sprinting can give a small speed boost and optional trip risk on steep descents.", _categorySlope, true] call _addCheckbox;
["GAIT_ss_slopeSampleDistance", "Slope sample distance", "Meters ahead and behind the player used to measure the terrain slope in the current movement direction. Higher values smooth noisy terrain; lower values react faster. Default: 2.0.", _categorySlope, 0.50, 6.00, 2.00, 1] call _addSlider;
["GAIT_ss_slopeTransitionSmoothingEnabled", "Smooth slope transitions", "Smooths slope angle and slope-speed target changes so moving between different incline angles ramps speed up/down instead of snapping. Default: enabled.", _categorySlope, true] call _addCheckbox;
["GAIT_ss_slopeAngleRiseRateDegPerSecond", "Slope angle rise rate", "Maximum degrees per second the effective slope may increase when entering steeper terrain. Lower is smoother/heavier. Default: 22 deg/sec.", _categorySlope, 2.00, 120.00, 22.00, 0] call _addSlider;
["GAIT_ss_slopeAngleFallRateDegPerSecond", "Slope angle fall rate", "Maximum degrees per second the effective slope may relax when terrain becomes flatter. Higher recovers faster. Default: 30 deg/sec.", _categorySlope, 2.00, 160.00, 30.00, 0] call _addSlider;

["GAIT_ss_uphillSlowdownEnabled", "Enable uphill slowdown", "When sprinting uphill, GAIT reduces sprint speed as the slope gets steeper. Sprinting remains possible; it just gets slower.", _categorySlope, true] call _addCheckbox;
["GAIT_ss_uphillStartDegrees", "Uphill slowdown starts", "Incline angle in degrees where uphill sprint slowdown begins. A higher value makes shallow hills feel closer to flat ground. Default: 5 degrees.", _categorySlope, 0.00, 45.00, 5.00, 1] call _addSlider;
["GAIT_ss_uphillMaxDegrees", "Uphill reference angle", "Angle where the reference penalty is reached. Pace continues decreasing above this angle without a walking cutoff. Default: 35 degrees.", _categorySlope, 5.00, 80.00, 35.00, 1] call _addSlider;
["GAIT_ss_uphillMaxPenalty", "Uphill penalty at reference angle", "Sprint pace reduction at the reference angle. 0.40 means 40% slower there. The continuous curve extends to steeper angles; a walk-relative target floor preserves sprint advantage. Default: 0.40.", _categorySlope, 0.00, 0.95, 0.40, 2] call _addSlider;
["GAIT_ss_vegetationDragEnabled", "Vegetation drag", "Dense bushes bleed movement speed while passing through them. Default: enabled.", _categorySlope, true] call _addCheckbox;
["GAIT_ss_vegetationDragMax", "Vegetation drag max", "Maximum movement speed reduction in dense brush. 0.18 means up to 18% slower. Default: 0.18.", _categorySlope, 0.00, 0.75, 0.18, 2] call _addSlider;
["GAIT_ss_vegetationDragRadius", "Vegetation drag radius", "Bush proximity radius in meters considered for drag. Default: 2.5 m.", _categorySlope, 0.50, 6.00, 2.50, 1] call _addSlider;
["GAIT_ss_hillWalkSlowdownEnabled", "Slow walking on hills", "Slows normal W movement on inclines/declines before sprinting so starting uphill already feels heavy. Default: enabled.", _categorySlope, true] call _addCheckbox;
["GAIT_ss_hillWalkSlowdownStartDegrees", "Hill walk slowdown starts", "Slope angle where normal walking/jogging begins slowing before sprint. Default: 15 degrees.", _categorySlope, 0.00, 45.00, 15.00, 1] call _addSlider;
["GAIT_ss_hillWalkSlowdownMaxDegrees", "Hill walk reference angle", "Slope angle where walking reaches the reference penalty. Pace continues decreasing on steeper terrain. Default: 40 degrees.", _categorySlope, 5.00, 80.00, 40.00, 1] call _addSlider;
["GAIT_ss_hillWalkUphillMaxPenalty", "Uphill walk reference penalty", "Normal movement loss at the walk reference angle, adjusted for kit weight. Default: 0.32.", _categorySlope, 0.00, 0.75, 0.32, 2] call _addSlider;
["GAIT_ss_hillWalkDownhillMaxPenalty", "Downhill walk max penalty", "Small normal movement speed loss while walking downhill before momentum builds. Default: 0.08.", _categorySlope, 0.00, 0.35, 0.08, 2] call _addSlider;
["GAIT_ss_downhillMomentumEasyTriggerDegrees", "Downhill momentum starts", "Downhill angle where gravity-speed gain may begin. Lower values make downhill acceleration easier to trigger. Default: 10 degrees.", _categorySlope, 0.00, 30.00, 10.00, 1] call _addSlider;
["GAIT_ss_uphillFatigueDrainEnabled", "Increase uphill stamina drain", "Increases GAIT fallback reserve drain uphill when ACE reserves are unavailable. ACE calculates its own terrain exertion; its reserves and acidosis are read-only. Default: enabled.", _categorySlope, true] call _addCheckbox;
["GAIT_ss_uphillFatigueDrainStartDegrees", "Uphill drain starts", "Incline angle where additional uphill fatigue drain begins. Default: 10 degrees.", _categorySlope, 0.00, 45.00, 10.00, 1] call _addSlider;
["GAIT_ss_uphillFatigueDrainMaxDegrees", "Uphill drain max angle", "Incline angle where additional uphill fatigue drain reaches full strength. Default: 35 degrees.", _categorySlope, 5.00, 80.00, 35.00, 1] call _addSlider;
["GAIT_ss_uphillFatigueDrainMaxMultiplier", "Uphill max drain multiplier", "Maximum multiplier applied to sprint stamina drain on steep uphill terrain. 1.75 means 75% faster drain. Default: 1.75.", _categorySlope, 1.00, 4.00, 1.75, 2] call _addSlider;
["GAIT_ss_uphillVanillaFatigueExtraPerSecond", "Uphill visual fatigue gain", "Extra vanilla/visual fatigue added per second at max uphill drain severity. Default: 0.018.", _categorySlope, 0.00, 0.20, 0.018, 3] call _addSlider;

["GAIT_ss_downhillBoostEnabled", "Enable downhill boost", "When sprinting downhill, GAIT gives a small speed bonus as the descent gets steeper. Keep this subtle to avoid arcade movement. Default: enabled.", _categorySlope, true] call _addCheckbox;
["GAIT_ss_downhillBoostStartDegrees", "Downhill boost starts", "Decline angle in degrees where the downhill speed boost begins. Default: 4 degrees.", _categorySlope, 0.00, 30.00, 4.00, 1] call _addSlider;
["GAIT_ss_downhillBoostMaxDegrees", "Downhill max boost angle", "Decline angle where the downhill speed boost reaches its maximum configured value. Default: 18 degrees.", _categorySlope, 5.00, 60.00, 18.00, 1] call _addSlider;
["GAIT_ss_downhillMaxBoost", "Downhill max speed boost", "Maximum sprint speed increase when running downhill. 0.06 means up to 6% faster. Default: 0.06.", _categorySlope, 0.00, 0.35, 0.06, 2] call _addSlider;

["GAIT_ss_downhillTripEnabled", "Enable steep downhill trips", "Allows a chance to stumble/ragdoll briefly when sprinting down a steep enough hill. This does not apply damage by itself. Default: enabled.", _categorySlope, true] call _addCheckbox;
["GAIT_ss_downhillTripThresholdDegrees", "Trip risk starts above decline", "Downhill angle in degrees where trip risk begins. The player must be sprinting down a slope steeper than this value. Default: 28 degrees.", _categorySlope, 5.00, 70.00, 28.00, 1] call _addSlider;
["GAIT_ss_downhillTripMaxDegrees", "Trip max-risk decline", "Downhill angle where trip chance reaches its configured maximum. Default: 32 degrees.", _categorySlope, 10.00, 80.00, 45.00, 1] call _addSlider;
["GAIT_ss_downhillTripBaseChancePerSecond", "Trip base chance per second", "Chance per second to trip at the trip threshold. 0.005 means about 0.5% per second. Default: 0.005.", _categorySlope, 0.00, 1.00, 0.005, 3] call _addSlider;
["GAIT_ss_downhillTripMaxChancePerSecond", "Trip max chance per second", "Chance per second to trip at or beyond the max-risk decline. 0.10 means about 10% per second. Default: 0.10.", _categorySlope, 0.00, 1.00, 0.10, 2] call _addSlider;
["GAIT_ss_downhillTripCooldown", "Trip cooldown", "Minimum seconds between downhill trip attempts after a trip occurs. Prevents repeated ragdolls on one slope. Default: 10 seconds.", _categorySlope, 0.00, 60.00, 10.00, 1] call _addSlider;
["GAIT_ss_downhillTripDuration", "Trip ragdoll duration", "How long the character stays ragdolled/unconscious after a downhill trip. Default: 1.00 second.", _categorySlope, 0.10, 8.00, 1.00, 2] call _addSlider;
["GAIT_ss_downhillTripMinSpeedKmh", "Trip minimum speed", "Minimum actual movement speed in km/h required before downhill trip checks can happen. Prevents stumbles while barely moving. Default: 20 km/h.", _categorySlope, 0.00, 50.00, 20.00, 1] call _addSlider;
["GAIT_ss_downhillTripSpeedMaxKmh", "Trip max-risk speed", "Horizontal speed in km/h where speed reaches full trip-risk scaling. Default: 34 km/h.", _categorySlope, 5.00, 70.00, 34.00, 1] call _addSlider;
["GAIT_ss_downhillTripSpeedInfluence", "Trip speed influence", "How strongly real movement speed scales downhill trip chance. 0 ignores speed; 1 is normal; 2 doubles the influence. Default: 1.", _categorySlope, 0.00, 2.00, 1.00, 2] call _addSlider;
["GAIT_ss_downhillTripWeightInfluence", "Trip weight influence", "How strongly carried kit weight scales downhill trip chance. 0 ignores weight; 1 is normal; 2 doubles the influence. Default: 1.", _categorySlope, 0.00, 2.00, 1.00, 2] call _addSlider;
["GAIT_ss_downhillTripRequireSustainedMovement", "Require sustained run for trips", "If enabled, trip rolls only affect the player after sustained sprinting or sustained high speed. Default: enabled.", _categorySlope, true] call _addCheckbox;
["GAIT_ss_downhillTripMinSprintSeconds", "Trip sprint time gate", "Seconds of continuous sprinting required before downhill trip rolls can affect the player. Default: 5 seconds.", _categorySlope, 0.00, 20.00, 5.00, 1] call _addSlider;
["GAIT_ss_downhillTripSustainedSpeedKmh", "Trip high-speed gate", "Speed threshold used by the alternate high-speed trip gate. Default: 20 km/h.", _categorySlope, 0.00, 50.00, 20.00, 1] call _addSlider;
["GAIT_ss_downhillTripSustainedSpeedSeconds", "Trip high-speed time gate", "Seconds at or above the high-speed gate required before downhill trip rolls can affect the player. Default: 4 seconds.", _categorySlope, 0.00, 20.00, 4.00, 1] call _addSlider;
["GAIT_ss_downhillTripPostFallImmunity", "Post-trip immunity", "Seconds after a GAIT trip where another GAIT trip cannot occur. Default: 10 seconds.", _categorySlope, 0.00, 60.00, 10.00, 1] call _addSlider;
["GAIT_ss_downhillTripGetUpSpeedKmh", "Trip get-up speed threshold", "Player stays ragdolled after a trip until horizontal momentum falls below this speed, after the minimum trip duration. Default: 7 km/h.", _categorySlope, 0.50, 30.00, 7.00, 1] call _addSlider;
["GAIT_ss_downhillTripMaxRagdollDuration", "Trip max ragdoll duration", "Safety cap in seconds so a trip cannot keep the player down forever if momentum does not bleed off. Default: 6 seconds.", _categorySlope, 0.50, 12.00, 6.00, 1] call _addSlider;



// -----------------------------------------------------
// 11 QoL, Presets, and Compatibility
// -----------------------------------------------------
[
    "GAIT_ss_preset",
    "Tuning preset",
    "Applies a readable starting point for GAIT tuning. Choose Custom after applying a preset if you want to hand-tune individual values without the preset reapplying on change.",
    _categoryQoL,
    ["Custom", "Balanced", "Realistic", "Arcade", "Training", "Light Infantry", "Heavy Infantry"],
    ["Custom", "Balanced", "Realistic", "Arcade", "Training", "Light Infantry", "Heavy Infantry"],
    1
] call _addList;

[
    "GAIT_ss_compatibilityMode",
    "Compatibility mode",
    "Controls how aggressively GAIT overrides movement. Full/Hybrid are intended modes. Minimal keeps fatigue effects but avoids movement control. Visuals Only avoids movement, sway, and hearing changes. Disabled safely resets GAIT effects.",
    _categoryQoL,
    [0, 1, 2, 3, 4],
    ["Full GAIT Control", "ACE-Friendly Hybrid", "Minimal Movement Override", "Visuals/Audio Only", "Disabled"],
    1
] call _addList;

["GAIT_ss_resetOnRespawn", "Reset effects on respawn", "Automatically clears GAIT movement speed, sway, hearing, tinnitus, and visual effects when the local player respawns or changes player object. Recommended: enabled.", _categoryQoL, true] call _addCheckbox;
["GAIT_ss_suspendInSpectator", "Suspend while spectating", "Suspends GAIT movement and effect writes when your camera is no longer attached to your player. Helps prevent stuck visuals during spectator, Zeus camera, or remote-control edge cases.", _categoryQoL, true] call _addCheckbox;
["GAIT_ss_suspendWhileUnconscious", "Suspend while unconscious", "Suspends GAIT movement control while ACE reports the player unconscious. This avoids fighting ACE medical states and clears local fatigue effects cleanly.", _categoryQoL, true] call _addCheckbox;
["GAIT_ss_showStartupMessage", "Show startup message", "Shows a short systemChat message after mission start with the active preset, compatibility mode, and ACE Advanced Fatigue bridge state.", _categoryQoL, true] call _addCheckbox;
["GAIT_ss_showServerIndicator", "Show server/settings indicator", "In multiplayer, shows a reminder that server or mission CBA settings may override local Addon Options. Useful for units with server-forced presets.", _categoryQoL, true] call _addCheckbox;
["GAIT_ss_rptLogging", "Enable RPT logging", "Writes useful GAIT initialization, preset, lifecycle, and Zeus reset messages to the RPT for troubleshooting.", _categoryQoL, true] call _addCheckbox;

["GAIT_ss_debugHudEnabled", "Enable debug HUD", "Shows grade, real speed, resolved direction, coefficient targets, animation family, reserve and ACE locks. Default: disabled.", _categoryQoL, false] call _addCheckbox;
["GAIT_ss_debugHudInterval", "Debug HUD refresh", "Seconds between debug HUD updates. Default: 0.10.", _categoryQoL, 0.03, 1.00, 0.10, 2] call _addSlider;
["GAIT_ss_hardLandingCamShakeEnabled", "Hard landing camera shake", "Adds a small camera shake when landing hard after a drop. Default: enabled.", _categoryAudio, true] call _addCheckbox;
["GAIT_ss_hardLandingMinVerticalSpeed", "Hard landing threshold", "Downward velocity required before landing shake can trigger. Default: 4 m/s.", _categoryAudio, 0.50, 20.00, 4.00, 1] call _addSlider;
["GAIT_ss_hardLandingShakeStrength", "Hard landing shake strength", "Scales camera shake strength on hard landings. Default: 1.00.", _categoryAudio, 0.00, 3.00, 1.00, 2] call _addSlider;


["GAIT_ss_minSprintWalkRatio", "Minimum sprint / walk target ratio", "Conservative coefficient target floor relative to walking at the same grade and load. 1.20 preserves at least a 20% coefficient advantage after acceleration. Actual clip speeds must be verified in-game. Does not override injury, collision or special actions.", _categorySlope, 1.05, 1.50, 1.20, 2] call _addSlider;
["GAIT_ss_extraHeavyPenaltyPer50Lb", "Additional heavy-kit penalty", "Continuous load penalty beyond the heavy threshold: multiplier divided by 1 + value times extra pounds / 50. Default 0.18. Every additional pound continues to reduce walking and sprint pace.", _categoryWeight, 0.01, 1.00, 0.18, 2] call _addSlider;
["GAIT_ss_slopeLocomotionEnabled", "Enable dedicated sprint animation family", "Uses a dedicated native direction map throughout standing sprint, keeping the same sprint family when terrain gets steeper. Forward and diagonal selections use sprint animations; lateral and reverse selections use native running animations. Experimental until tested in Arma; no maximum slope angle.", _categorySlope, true] call _addCheckbox;

["GAIT_ss_freshSprintWalkMargin", "Fresh reserve pace margin", "Extra sprint/walk coefficient ratio at full reserve, fading continuously with fatigue. Keeps reserve affecting speed when the walk-relative floor is active. Default 0.20 adds 20 percentage points to the minimum ratio when fresh.", _categorySlope, 0.01, 0.75, 0.20, 2] call _addSlider;
