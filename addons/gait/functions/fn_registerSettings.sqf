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
private _categoryAudio = ["GAIT", "07 Audio and Hearing"];
private _categoryVisual = ["GAIT", "08 Fatigue Vignette"];
private _categorySlope = ["GAIT", "09 Terrain, Slopes, and Tripping"];
private _categoryQoL = ["GAIT", "10 QoL, Presets, and Compatibility"];

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
["GAIT_ss_enabled", "Enable GAIT", "Master switch for runtime movement, brace, fatigue audio and vignette. Disabling releases owned effects. Terrain config and the optional 10% ACE heartbeat patch remain until their PBOs are unloaded.", _categoryGeneral, true] call _addCheckbox;
["GAIT_ss_tickRate", "Feature update interval", "Seconds between terrain, reserve and ordinary acceleration updates. Release interpolation is sampled each rendered frame. Default: 0.05 seconds.", _categoryGeneral, 0.01, 0.20, 0.05, 2] call _addSlider;

["GAIT_ss_masterTripFrequency", "Master: trip frequency", "Meta-knob that scales downhill trip chance without changing thresholds. 1.00 is baseline.", _categoryGeneral, 0.00, 3.00, 1.00, 2] call _addSlider;
["GAIT_ss_masterFxIntensity", "Fatigue effect intensity", "Scales GAIT tinnitus, hearing reduction and vignette strength. Does not scale ACE heartbeat. Vignette opacity remains capped at 14%. Default: 1.00.", _categoryGeneral, 0.00, 2.00, 1.00, 2] call _addSlider;

// -----------------------------------------------------
// 02 ACE Advanced Fatigue Integration
// -----------------------------------------------------
["GAIT_ss_aceBridgeEnabled", "Read ACE Advanced Fatigue", "Allows GAIT to read active ACE Advanced Fatigue reserves and physiological penalties. This does not enable, disable or write ACE physiology. Default: enabled.", _categoryACE, true] call _addCheckbox;
["GAIT_ss_useAceReserveModel", "Use ACE reserve for sprint strength", "Reads ACE anaerobic/aerobic reserves, acidosis, and muscle damage to scale GAIT sprint speed and exhaustion effects.", _categoryACE, true] call _addCheckbox;
["GAIT_ss_clearAceMovementLocks", "Prevent ACE walk-lock override", "Clears only ACE Advanced Fatigue's forced-walk and block-sprint locks so GAIT movement is not overwritten.", _categoryACE, true] call _addCheckbox;
["GAIT_ss_registerAceAnimExclusion", "Protect GAIT animation speed", "Adds GAIT to ACE Advanced Fatigue's animation-speed exclusion list so ACE does not reset GAIT speed every fatigue tick.", _categoryACE, true] call _addCheckbox;
["GAIT_ss_aceAcidosisPenaltyFactor", "Acidosis sprint penalty", "How strongly ACE anaerobic fatigue/acidosis reduces GAIT sprint reserve. Higher means acidosis hurts speed sooner. Default: 0.45.", _categoryACE, 0.00, 1.00, 0.45, 2] call _addSlider;
["GAIT_ss_aceMuscleDamagePenaltyFactor", "Muscle-damage sprint penalty", "How strongly ACE muscle damage reduces GAIT sprint reserve. Higher means long-duration overwork hurts speed more. Default: 0.25.", _categoryACE, 0.00, 1.00, 0.25, 2] call _addSlider;

// -----------------------------------------------------
// 03 Movement and Sprint
// -----------------------------------------------------
["GAIT_ss_normalSpeed", "Ordinary movement coefficient", "Base animation coefficient for non-sprint movement before gear and slope modifiers. 1.00 is the active clip at its native playback rate, not a fixed speed in km/h. Default: 0.86.", _categoryMove, 0.50, 1.50, 0.86, 2] call _addSlider;
["GAIT_ss_sprintFullSpeed", "Fresh sprint coefficient", "Base sprint animation coefficient at full reserve, before gear, slope and minimum pace-ratio modifiers. Not a speed in km/h. Default: 1.28.", _categoryMove, 0.70, 2.00, 1.28, 2] call _addSlider;
["GAIT_ss_sprintExhaustedSpeed", "Exhausted sprint coefficient", "Base sprint animation coefficient at empty reserve, before gear, slope and minimum pace-ratio modifiers. Default: 0.89.", _categoryMove, 0.40, 1.50, 0.89, 2] call _addSlider;
["GAIT_ss_sprintReserveMax", "Fallback sprint reserve", "Seconds of full sprint in the GAIT reserve model when ACE reserve reading is disabled, unavailable or not initialized. Default: 25 seconds.", _categoryMove, 1.00, 120.00, 25.00, 0] call _addSlider;
["GAIT_ss_sprintRecoverTime", "Fallback reserve recovery", "Seconds to recover the GAIT fallback reserve. Does not change ACE recovery. Default: 10 seconds.", _categoryMove, 1.00, 60.00, 10.00, 0] call _addSlider;
["GAIT_ss_speedLerp", "Speed ramp smoothness", "Base smoothing rate for movement speed changes. Lower is smoother/slower; higher is snappier. Upward sprint acceleration intentionally uses 70% of this rate so reaching maximum sprint speed takes longer, while braking/release timing stays unchanged. Default: 0.05.", _categoryMove, 0.01, 1.00, 0.05, 2] call _addSlider;
["GAIT_ss_wReleaseZeroMomentumDelay", "W-release zero-momentum delay", "Seconds after releasing forward movement before the next sprint start is treated as zero momentum. Lower values make brace return sooner. Default: 0.50.", _categoryMove, 0.00, 20.00, 0.50, 2] call _addSlider;
["GAIT_ss_shiftReleaseRunTaperEnabled", "Smooth sprint release", "Release sprint while keeping forward movement held to decelerate from current motion. Uses measured jog pace when a valid reference exists. Stop, direction changes and medical restrictions cancel promptly. Default: enabled.", _categoryMove, true] call _addCheckbox;
["GAIT_ss_shiftReleaseRunTaperDuration", "Sprint release duration scale", "Sets the ceiling for the Shift-release ramp: value x gear factor, bounded to 0.35-1.20 seconds. The measured speed difference uses 75-100% of that window, beginning at the exact current running pace before easing to jog. Default 0.85 gives a ceiling near 0.77-0.98 seconds across the default weight tiers.", _categoryMove, 0.05, 4.00, 0.85, 2] call _addSlider;
["GAIT_ss_shiftReleaseRunTaperCurve", "Sprint release curve", "Shapes the finite slowdown. Higher values lose pace sooner. Effective range: 1-3. Does not add a hold or extend the deadline. Default: 1.45.", _categoryMove, 1.00, 3.00, 1.45, 2] call _addSlider;
["GAIT_ss_unarmedSprintNormalizer", "Unarmed sprint normalizer", "Multiplier applied when sprinting with no weapon out so holstering does not create an unrealistic speed boost. Default: 0.725.", _categoryMove, 0.30, 1.20, 0.725, 3] call _addSlider;

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
["GAIT_ss_lightBraceRelief", "Light kit brace relief", "Small reduction of the shared brace dip for light kits. Applied at 20% strength so every tier keeps a brace. 0 = full dip; 1 = 20% relief. Default: 0.55.", _categoryWeight, 0.00, 1.00, 0.55, 2] call _addSlider;
["GAIT_ss_mediumBraceRelief", "Medium kit brace relief", "Small reduction of the shared brace dip for medium kits, applied at 20% strength. Default: 0.35.", _categoryWeight, 0.00, 1.00, 0.35, 2] call _addSlider;
["GAIT_ss_moderateBraceRelief", "Moderate kit brace relief", "Small reduction of the shared brace dip for moderate kits, applied at 20% strength. Default: 0.18.", _categoryWeight, 0.00, 1.00, 0.18, 2] call _addSlider;
["GAIT_ss_heavyBraceRelief", "Heavy kit brace relief", "Small reduction of the shared brace dip for heavy kits, applied at 20% strength. Default: 0.00.", _categoryWeight, 0.00, 1.00, 0.00, 2] call _addSlider;

// -----------------------------------------------------
// 06 Brace Step and Momentum
// -----------------------------------------------------
["GAIT_ss_sprintStartBraceEnabled", "Enable start brace step", "Enables both the small weight-scaled first step when beginning ordinary forward movement from rest and the stronger sprint-start brace. Default: enabled.", _categoryBrace, true] call _addCheckbox;
["GAIT_ss_sprintStartBraceDuration", "Sprint brace duration", "How long the sprint-start brace slowdown lasts. The smaller walk-start step uses its own short weight-tier curve. Default: 0.15 seconds.", _categoryBrace, 0.00, 1.00, 0.15, 2] call _addSlider;
["GAIT_ss_sprintStartBraceSpeed", "Sprint brace speed", "Animation speed target during the sprint-start brace. Lower is a stronger dip. The walk-start step is automatically shallower. Default: 0.42.", _categoryBrace, 0.10, 1.20, 0.42, 2] call _addSlider;
["GAIT_ss_sprintStartBraceLerp", "Sprint brace snap", "How abruptly speed moves into the sprint-start brace. The walk-start step uses a deterministic finite curve instead. Default: 0.575.", _categoryBrace, 0.01, 1.00, 0.575, 3] call _addSlider;
["GAIT_ss_braceRequiredWalkTime", "Brace settle time", "Non-sprint settle interval used by normal brace readiness and momentum recovery. A true stop can independently rearm the brace; a moving sprint retap is protected. Default: 2 seconds.", _categoryBrace, 0.00, 10.00, 2.00, 1] call _addSlider;
["GAIT_ss_braceRecentSprintCooldown", "Recent sprint grace", "Recent-sprint interval used by normal brace readiness and retained momentum. A real stop can still rearm brace before it expires. Default: 3 seconds.", _categoryBrace, 0.00, 10.00, 3.00, 1] call _addSlider;
["GAIT_ss_braceMinReserveRatio", "Brace reserve gate", "Minimum GAIT reserve ratio needed for brace when ACE reserve is not active. With ACE active, movement state owns brace. Default: 0.98.", _categoryBrace, 0.00, 1.00, 0.98, 2] call _addSlider;
["GAIT_ss_braceNoMomentumThreshold", "No-momentum threshold", "Coefficient margin used to detect settled walking. Established moving sprint momentum overrides all brace triggers until a real stop or settled recovery. Default: 0.04.", _categoryBrace, 0.00, 0.50, 0.04, 2] call _addSlider;
["GAIT_ss_braceReadySpeedThreshold", "Brace-ready movement speed", "Non-sprint speed gate for ordinary brace readiness, in km/h. Crouch and a sufficiently long forward-input release can also arm it. Default: 4 km/h.", _categoryBrace, 0.00, 10.00, 4.00, 1] call _addSlider;
["GAIT_ss_slopeStopBraceEnabled", "Slope-aware brace", "Enables slope effects on sprint-start bracing. Zero-momentum uphill starts gain an exponential brace burden from any positive grade; retained sprint momentum bypasses it. Remembered incline/decline restarts still use the angle controls below. Default: enabled.", _categoryBrace, true] call _addCheckbox;
["GAIT_ss_slopeStopBraceStartDegrees", "Remembered slope brace starts", "Incline/decline angle where the remembered stop/restart brace begins. Zero-momentum uphill launch amplification starts above 0 degrees independently. Default: 15 degrees.", _categoryBrace, 0.00, 60.00, 15.00, 1] call _addSlider;
["GAIT_ss_slopeStopBraceMaxDegrees", "Slope brace reference angle", "Reference angle for full remembered-slope brace strength and for the exponential zero-momentum uphill launch curve. Steeper uphill grades can extend the launch burden modestly beyond this reference. Default: 35 degrees.", _categoryBrace, 5.00, 80.00, 35.00, 1] call _addSlider;
["GAIT_ss_slopeStopBraceExtraDuration", "Slope brace extra duration", "Base extra duration for slope bracing. Zero-momentum uphill launches exponentially amplify this value, up to roughly 3x at the reference angle; momentum-protected starts do not. Default: 0.18 sec.", _categoryBrace, 0.00, 2.00, 0.18, 2] call _addSlider;
["GAIT_ss_slopeStopBraceExtraDip", "Slope brace extra dip", "Base slope-induced brace speed dip. Zero-momentum uphill launches exponentially amplify this value, while retained momentum bypasses the added uphill burden. Default: 0.28.", _categoryBrace, 0.00, 0.90, 0.28, 2] call _addSlider;
["GAIT_ss_slopeStopBraceMemoryTime", "Slope brace memory", "Seconds after stopping sprint on an incline where the next sprint start still uses the slope brace. Default: 2.5 sec.", _categoryBrace, 0.00, 10.00, 2.50, 1] call _addSlider;
["GAIT_ss_uphillReleaseBraceEnabled", "Uphill sprint-release brake", "Brief dig-in braking when releasing a moving uphill sprint. Uses the slope brace angles, duration and dip and takes priority over the ordinary release ramp. Releasing forward movement cancels its animation hold. Default: enabled.", _categoryBrace, true] call _addCheckbox;

// -----------------------------------------------------
// Weapon handling is left to ACE/native systems; no GAIT sway controls.
// -----------------------------------------------------

// -----------------------------------------------------
// 07 Audio and Hearing
// -----------------------------------------------------
["GAIT_ss_tinnitusEnabled", "Enable tinnitus", "Enables GAIT tinnitus at high exhaustion. Separate optional gait_heartbeat.pbo fixes ACE heartbeat gain at 10% of original; this checkbox does not control it.", _categoryAudio, true] call _addCheckbox;
["GAIT_ss_tinnitusStartExhaustion", "Tinnitus starts at exhaustion", "Exhaustion level where tinnitus begins. 0 = immediately, 1 = only at max exhaustion. Default: 0.70.", _categoryAudio, 0.00, 1.00, 0.70, 2] call _addSlider;
["GAIT_ss_audioStopExhaustion", "Tinnitus stop threshold", "GAIT tinnitus fades out below this exhaustion level. Does not stop ACE heartbeat or breathing. Default: 0.10.", _categoryAudio, 0.00, 1.00, 0.10, 2] call _addSlider;
["GAIT_ss_tinnitusMaxVolume", "Tinnitus maximum gain", "Maximum GAIT tinnitus gain before the fatigue effect intensity multiplier. Does not change ACE heartbeat. Default: 0.55.", _categoryAudio, 0.00, 2.00, 0.55, 2] call _addSlider;
["GAIT_ss_audioFadeLerp", "Audio fade smoothness", "How quickly tinnitus volume moves toward its target. Higher changes faster. Default: 0.08.", _categoryAudio, 0.01, 1.00, 0.08, 2] call _addSlider;
["GAIT_ss_hearingEnabled", "Fatigue hearing reduction", "Applies a GAIT hearing-capability contribution through ACE when available. Other ACE hearing effects remain independently owned. Default: enabled.", _categoryAudio, true] call _addCheckbox;
["GAIT_ss_hearingMinVolume", "Minimum hearing volume", "Lowest hearing volume at maximum exhaustion. 1 = no reduction, 0 = muted. Default: 0.20.", _categoryAudio, 0.00, 1.00, 0.20, 2] call _addSlider;
["GAIT_ss_hearingFadeDuration", "Hearing fade duration", "Seconds used when changing hearing volume. Default: 0.20.", _categoryAudio, 0.00, 5.00, 0.20, 2] call _addSlider;

// -----------------------------------------------------
// 09 Intermittent Fatigue Vignette
// -----------------------------------------------------
["GAIT_ss_fatigueVignetteEnabled", "Intermittent fatigue vignette", "Brief, subtle edge darkening when tired, separated by fully clear intervals. Replaces only ACE Advanced Fatigue blackout while active. Clears on recovery, disable or lost updates. Default: enabled.", _categoryVisual, true] call _addCheckbox;
["GAIT_ss_tunnelStartExhaustion", "Visuals start at exhaustion", "Exhaustion level where intermittent vignette pulses begin. Default: 0.18.", _categoryVisual, 0.00, 1.00, 0.18, 2] call _addSlider;
["GAIT_ss_tunnelMaxStrength", "Vignette strength scale", "Scales the fatigue pulse, together with fatigue effect intensity. Resulting strength saturates at 1 and peak edge opacity remains at most 14%. Default: 1.00.", _categoryVisual, 0.00, 2.00, 1.00, 2] call _addSlider;


// -----------------------------------------------------
// 09 Terrain, Slopes, and Tripping
// -----------------------------------------------------
["GAIT_ss_slopeHandlingEnabled", "Enable slope handling", "Enables GAIT terrain-aware movement. Ordinary forward movement on any real slope uses a jog/run animation instead of the engine slope-walk state; uphill sprinting slows progressively, and downhill sprinting accelerates with sustained descent momentum. ACE medical movement locks still take priority.", _categorySlope, true] call _addCheckbox;
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
["GAIT_ss_hillWalkSlowdownEnabled", "Slow ordinary slope pace", "Reduces the pace of normal W movement on inclines/declines before sprinting so hills feel heavy. This does not select a walking animation: slope forward movement remains a custom Mrun jog. Default: enabled.", _categorySlope, true] call _addCheckbox;
["GAIT_ss_hillWalkSlowdownStartDegrees", "Hill walk slowdown starts", "Slope angle where normal walking/jogging begins slowing before sprint. Default: 15 degrees.", _categorySlope, 0.00, 45.00, 15.00, 1] call _addSlider;
["GAIT_ss_hillWalkSlowdownMaxDegrees", "Hill walk reference angle", "Slope angle where walking reaches the reference penalty. Pace continues decreasing on steeper terrain. Default: 40 degrees.", _categorySlope, 5.00, 80.00, 40.00, 1] call _addSlider;
["GAIT_ss_hillWalkUphillMaxPenalty", "Uphill walk reference penalty", "Normal movement loss at the walk reference angle, adjusted for kit weight. Default: 0.32.", _categorySlope, 0.00, 0.75, 0.32, 2] call _addSlider;
["GAIT_ss_hillWalkDownhillMaxPenalty", "Downhill walk max penalty", "Small normal movement speed loss while walking downhill before momentum builds. Default: 0.08.", _categorySlope, 0.00, 0.35, 0.08, 2] call _addSlider;
["GAIT_ss_uphillFatigueDrainEnabled", "Increase uphill stamina drain", "Increases GAIT fallback reserve drain uphill when ACE reserves are unavailable. ACE calculates its own terrain exertion; its reserves and acidosis are read-only. Default: enabled.", _categorySlope, true] call _addCheckbox;
["GAIT_ss_uphillFatigueDrainStartDegrees", "Uphill drain starts", "Incline angle where additional uphill fatigue drain begins. Default: 10 degrees.", _categorySlope, 0.00, 45.00, 10.00, 1] call _addSlider;
["GAIT_ss_uphillFatigueDrainMaxDegrees", "Uphill drain max angle", "Incline angle where additional uphill fatigue drain reaches full strength. Default: 35 degrees.", _categorySlope, 5.00, 80.00, 35.00, 1] call _addSlider;
["GAIT_ss_uphillFatigueDrainMaxMultiplier", "Uphill max drain multiplier", "Maximum multiplier applied to sprint stamina drain on steep uphill terrain. 1.75 means 75% faster drain. Default: 1.75.", _categorySlope, 1.00, 4.00, 1.75, 2] call _addSlider;

["GAIT_ss_downhillBoostEnabled", "Enable downhill acceleration", "Builds real downhill sprint momentum only while descending. Steeper grades accelerate harder instead of tapering the bonus, while trip risk still scales from actual speed. Default: enabled.", _categorySlope, true] call _addCheckbox;
["GAIT_ss_downhillBoostStartDegrees", "Downhill bonus starts", "Decline angle where the downhill speed bonus starts. This is the single onset control. Default: 4 degrees.", _categorySlope, 0.00, 30.00, 4.00, 1] call _addSlider;
["GAIT_ss_downhillBoostMaxDegrees", "Downhill base boost angle", "Decline angle where the configured base downhill bonus reaches full strength. Steeper grades continue adding gravity amplification beyond this point. Default: 18 degrees.", _categorySlope, 5.00, 60.00, 18.00, 1] call _addSlider;
["GAIT_ss_downhillMaxBoost", "Downhill base speed boost", "Base downhill bonus at full momentum, added to the sustained bonus below. Steep grades can amplify the combined configured bonus up to 3x before the final safety cap; heavy kits retain much more of this gravity-driven gain. Default: 0.06.", _categorySlope, 0.00, 0.35, 0.06, 2] call _addSlider;
["GAIT_ss_downhillSustainedExtraBoost", "Sustained downhill bonus", "Additional bonus earned by actual downhill sprint travel. The configured base+sustained component is amplified on steep grades, with final additive acceleration capped at 65%. Zero removes this extra component. Default: 0.12.", _categorySlope, 0.00, 0.25, 0.12, 2] call _addSlider;
["GAIT_ss_downhillMomentumBuildSeconds", "Downhill momentum build time", "Baseline seconds of actual downhill sprint travel to build 95% momentum. Steeper descents shorten this by up to 55%, producing visible acceleration as the hill gets steeper. Flat sprinting no longer preloads downhill momentum. Default: 2.5 seconds.", _categorySlope, 0.50, 8.00, 2.50, 2] call _addSlider;

["GAIT_ss_downhillTripEnabled", "Enable steep downhill trips", "Allows a chance to stumble/ragdoll during fast grounded travel down a steep hill, including sprint deceleration. This does not apply damage by itself. Default: enabled.", _categorySlope, true] call _addCheckbox;
["GAIT_ss_downhillTripThresholdDegrees", "Trip risk starts above decline", "Downhill angle in degrees where trip risk begins during eligible travel above the actual speed minimum. The decline must be steeper than this value. Default: 28 degrees.", _categorySlope, 5.00, 70.00, 28.00, 1] call _addSlider;
["GAIT_ss_downhillTripMaxDegrees", "Trip max-risk decline", "Downhill angle where the slope component reaches its configured maximum, before speed and weight scaling. Default: 45 degrees.", _categorySlope, 10.00, 80.00, 45.00, 1] call _addSlider;
["GAIT_ss_downhillTripBaseChancePerSecond", "Trip base chance per second", "Per-second trip probability near the minimum decline, before current speed and weight scaling. 0.005 means 0.5% per second before scaling. Default: 0.005.", _categorySlope, 0.00, 1.00, 0.005, 3] call _addSlider;
["GAIT_ss_downhillTripMaxChancePerSecond", "Trip max chance per second", "Per-second trip probability at or beyond the max-risk decline, before current speed and weight scaling. 0.10 means 10% per second before scaling. Default: 0.10.", _categorySlope, 0.00, 1.00, 0.10, 2] call _addSlider;
["GAIT_ss_downhillTripCooldown", "Trip cooldown", "Minimum seconds between downhill trip attempts after a trip occurs. Prevents repeated ragdolls on one slope. Default: 10 seconds.", _categorySlope, 0.00, 60.00, 10.00, 1] call _addSlider;
["GAIT_ss_downhillTripDuration", "Minimum trip ragdoll time", "Minimum time down after a GAIT trip. Recovery can take longer until horizontal speed falls below the get-up threshold, subject to the safety timeout. Default: 1 second.", _categorySlope, 0.10, 8.00, 1.00, 2] call _addSlider;
["GAIT_ss_downhillTripMinSpeedKmh", "Trip minimum speed", "Minimum actual horizontal speed for downhill trip checks. With speed scaling enabled, risk rises smoothly from zero above this speed. Default: 20 km/h.", _categorySlope, 0.00, 50.00, 20.00, 1] call _addSlider;
["GAIT_ss_downhillTripSpeedMaxKmh", "Trip reference speed", "Horizontal speed in km/h used to calibrate trip risk. Risk continues rising above this speed. Default: 34 km/h.", _categorySlope, 5.00, 70.00, 34.00, 1] call _addSlider;
["GAIT_ss_downhillTripSpeedInfluence", "Trip speed influence", "Trip risk curve for actual horizontal speed above the minimum. 0 disables speed scaling; 1 is linear; 2 uses a quadratic curve. Default: 1.", _categorySlope, 0.00, 2.00, 1.00, 2] call _addSlider;
["GAIT_ss_downhillTripWeightInfluence", "Trip weight influence", "How strongly carried kit weight scales downhill trip chance. 0 ignores weight; 1 is normal; 2 doubles the influence. Default: 1.", _categorySlope, 0.00, 2.00, 1.00, 2] call _addSlider;
["GAIT_ss_downhillTripRequireSustainedMovement", "Require sustained run for trips", "If enabled, trip rolls only affect the player after sustained sprinting or sustained high speed. Default: enabled.", _categorySlope, true] call _addCheckbox;
["GAIT_ss_downhillTripMinSprintSeconds", "Trip sprint time gate", "Seconds of continuous sprinting required for trip qualification. Earned qualification persists through deceleration while actual speed remains above the trip minimum. Default: 5 seconds.", _categorySlope, 0.00, 20.00, 5.00, 1] call _addSlider;
["GAIT_ss_downhillTripSustainedSpeedKmh", "Trip high-speed gate", "Speed threshold used by the alternate high-speed trip gate. Default: 20 km/h.", _categorySlope, 0.00, 50.00, 20.00, 1] call _addSlider;
["GAIT_ss_downhillTripSustainedSpeedSeconds", "Trip high-speed time gate", "Seconds of actual horizontal movement at or above the high-speed gate. Releasing sprint preserves this history while speed stays high. Default: 4 seconds.", _categorySlope, 0.00, 20.00, 4.00, 1] call _addSlider;
["GAIT_ss_downhillTripPostFallImmunity", "Post-trip immunity", "Seconds after a GAIT trip where another GAIT trip cannot occur. Default: 10 seconds.", _categorySlope, 0.00, 60.00, 10.00, 1] call _addSlider;
["GAIT_ss_downhillTripGetUpSpeedKmh", "Trip get-up speed threshold", "Player stays ragdolled after a trip until horizontal momentum falls below this speed, after the minimum trip duration. Default: 7 km/h.", _categorySlope, 0.50, 30.00, 7.00, 1] call _addSlider;
["GAIT_ss_downhillTripMaxRagdollDuration", "Trip max ragdoll duration", "Safety cap in seconds so a trip cannot keep the player down forever if momentum does not bleed off. Default: 6 seconds.", _categorySlope, 0.50, 12.00, 6.00, 1] call _addSlider;



// -----------------------------------------------------
// 10 QoL, Presets, and Compatibility
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
    "Movement and effects runs the full controller. Effects and hearing disables movement changes. Visuals and tinnitus also disables hearing reduction. Disabled releases runtime effects. The fixed config patches remain loaded.",
    _categoryQoL,
    [1, 2, 3, 4],
    ["Movement and effects", "Effects and hearing", "Visuals and tinnitus", "Disabled"],
    0
] call _addList;

["GAIT_ss_showStartupMessage", "Show startup message", "Shows a short systemChat message after mission start with the active preset, compatibility mode, and ACE Advanced Fatigue bridge state.", _categoryQoL, true] call _addCheckbox;
["GAIT_ss_showServerIndicator", "Show server/settings indicator", "In multiplayer, shows a reminder that server or mission CBA settings may override local Addon Options. Useful for units with server-forced presets.", _categoryQoL, true] call _addCheckbox;
["GAIT_ss_rptLogging", "Enable RPT logging", "Writes useful GAIT initialization, preset, lifecycle, and Zeus reset messages to the RPT for troubleshooting.", _categoryQoL, true] call _addCheckbox;

["GAIT_ss_debugHudEnabled", "Enable debug HUD", "Shows grade, real speed, resolved direction, coefficient targets, animation family, reserve and ACE locks. Default: disabled.", _categoryQoL, false] call _addCheckbox;
["GAIT_ss_debugHudInterval", "Debug HUD refresh interval", "Seconds between debug HUD updates. Effective range: 0.05-1.00 seconds. Default: 0.10.", _categoryQoL, 0.05, 1.00, 0.10, 2] call _addSlider;
["GAIT_ss_hardLandingCamShakeEnabled", "Hard landing camera shake", "Adds a small camera shake when landing hard after a drop. Default: enabled.", _categoryAudio, true] call _addCheckbox;
["GAIT_ss_hardLandingMinVerticalSpeed", "Hard landing threshold", "Downward velocity required before landing shake can trigger. Default: 4 m/s.", _categoryAudio, 0.50, 20.00, 4.00, 1] call _addSlider;
["GAIT_ss_hardLandingShakeStrength", "Hard landing shake strength", "Scales camera shake strength on hard landings. Default: 1.00.", _categoryAudio, 0.00, 3.00, 1.00, 2] call _addSlider;


["GAIT_ss_minSprintWalkRatio", "Minimum sprint / walk target ratio", "Conservative coefficient target floor relative to walking at the same grade and load. 1.20 preserves at least a 20% coefficient advantage after acceleration. Actual clip speeds must be verified in-game. Does not override injury, collision or special actions.", _categorySlope, 1.05, 1.50, 1.20, 2] call _addSlider;
["GAIT_ss_extraHeavyPenaltyPer50Lb", "Additional heavy-kit penalty", "Continuous load penalty beyond the heavy threshold: multiplier divided by 1 + value times extra pounds / 50. Default 0.18. Every additional pound continues to reduce walking and sprint pace.", _categoryWeight, 0.01, 1.00, 0.18, 2] call _addSlider;
["GAIT_ss_slopeLocomotionEnabled", "Dedicated standing sprint animations", "Uses scoped native sprint clips for forward/diagonal standing movement and run clips for lateral/reverse movement, with one blended entry/exit. No terrain angle cutoff. Disabling uses native animation selection and disables the calibrated release handoff.", _categorySlope, true] call _addCheckbox;

["GAIT_ss_freshSprintWalkMargin", "Fresh reserve pace margin", "Extra sprint/walk coefficient ratio at full reserve, fading continuously with fatigue. Keeps reserve affecting speed when the walk-relative floor is active. Default 0.20 adds 20 percentage points to the minimum ratio when fresh.", _categorySlope, 0.01, 0.75, 0.20, 2] call _addSlider;
