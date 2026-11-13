/*
    GAIT - CBA Addon Options
    Registers readable in-game Addon Options for every active tuning value.
*/

if (isNil "CBA_fnc_addSetting") exitWith {};

private _categoryGeneral = ["GAIT", "01 General"];
private _categoryACE = ["GAIT", "02 ACE Advanced Fatigue Integration"];
private _categoryMove = ["GAIT", "03 Movement and Sprint"];
private _categoryCarry = ["GAIT", "04 ACE Carry Movement"];
private _categoryWeight = ["GAIT", "05 Gear Mass"];
private _categoryBrace = ["GAIT", "06 Brace Step and Momentum"];
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
["GAIT_ss_enabled", "Enable GAIT", "Enables GAIT movement and bracing. ACE supplies fatigue feedback.", _categoryGeneral, true] call _addCheckbox;
["GAIT_ss_tickRate", "Feature update interval", "Seconds between terrain, reserve and ordinary acceleration updates. Release interpolation is sampled each rendered frame. Default: 0.05 seconds.", _categoryGeneral, 0.01, 0.20, 0.05, 2] call _addSlider;

["GAIT_ss_masterTripFrequency", "Master: trip frequency", "Meta-knob that scales downhill trip chance without changing thresholds. 1.00 is baseline.", _categoryGeneral, 0.00, 3.00, 1.00, 2] call _addSlider;

// -----------------------------------------------------
// 02 ACE Advanced Fatigue Integration
// -----------------------------------------------------
["GAIT_ss_aceBridgeEnabled", "Read ACE Advanced Fatigue", "Allows GAIT to read active ACE Advanced Fatigue reserves and physiological penalties. This does not enable, disable or write ACE physiology. Default: enabled.", _categoryACE, true] call _addCheckbox;
["GAIT_ss_useAceReserveModel", "Use ACE reserve for sprint strength", "Reads ACE anaerobic and aerobic reserves, acidosis, and muscle damage to scale GAIT sprint speed.", _categoryACE, true] call _addCheckbox;
["GAIT_ss_clearAceMovementLocks", "Prevent ACE walk-lock override", "Clears only ACE Advanced Fatigue's forced-walk and block-sprint locks so GAIT movement is not overwritten.", _categoryACE, true] call _addCheckbox;
["GAIT_ss_registerAceAnimExclusion", "Protect GAIT animation speed", "Adds GAIT to ACE Advanced Fatigue's animation-speed exclusion list so ACE does not reset GAIT speed every fatigue tick.", _categoryACE, true] call _addCheckbox;
["GAIT_ss_aceAcidosisPenaltyFactor", "Acidosis sprint penalty", "How strongly ACE anaerobic fatigue/acidosis reduces GAIT sprint reserve. Higher means acidosis hurts speed sooner. Default: 0.45.", _categoryACE, 0.00, 1.00, 0.45, 2] call _addSlider;
["GAIT_ss_aceMuscleDamagePenaltyFactor", "Muscle-damage sprint penalty", "How strongly ACE muscle damage reduces GAIT sprint reserve. Higher means long-duration overwork hurts speed more. Default: 0.25.", _categoryACE, 0.00, 1.00, 0.25, 2] call _addSlider;

// -----------------------------------------------------
// 03 Movement and Sprint
// -----------------------------------------------------
["GAIT_ss_normalSpeed", "Ordinary movement coefficient", "Base animation coefficient for non-sprint movement before gear and slope modifiers. 1.00 is the active clip at its native playback rate, not a fixed speed in km/h. Default: 0.86.", _categoryMove, 0.50, 1.50, 0.86, 2] call _addSlider;
["GAIT_ss_sprintFullSpeed", "Fresh sprint coefficient", "Base sprint animation coefficient at full reserve, before gear, slope and minimum pace-ratio modifiers. Not a speed in km/h. Default: 1.28.", _categoryMove, 0.70, 2.00, 1.28, 2] call _addSlider;
["GAIT_ss_sprintReserveMax", "Fallback sprint reserve", "Seconds of full sprint in the GAIT reserve model when ACE reserve reading is disabled, unavailable or not initialized. Default: 25 seconds.", _categoryMove, 1.00, 120.00, 25.00, 0] call _addSlider;
["GAIT_ss_sprintRecoverTime", "Fallback reserve recovery", "Seconds to recover the GAIT fallback reserve. Does not change ACE recovery. Default: 10 seconds.", _categoryMove, 1.00, 60.00, 10.00, 0] call _addSlider;
["GAIT_ss_speedLerp", "Speed ramp smoothness", "Base smoothing rate for movement speed changes. Lower is smoother/slower; higher is snappier. Upward sprint acceleration intentionally uses 70% of this rate so reaching maximum sprint speed takes longer, while braking/release timing stays unchanged. Default: 0.05.", _categoryMove, 0.01, 1.00, 0.05, 2] call _addSlider;
["GAIT_ss_wReleaseZeroMomentumDelay", "W-release zero-momentum delay", "Seconds after releasing forward movement before the next sprint start is treated as zero momentum. Lower values make brace return sooner. Default: 0.50.", _categoryMove, 0.00, 20.00, 0.50, 2] call _addSlider;
["GAIT_ss_shiftReleaseRunTaperEnabled", "Smooth sprint release", "Release sprint while keeping forward movement held to decelerate from current motion. Uses measured jog pace when a valid reference exists. Stop, direction changes and medical restrictions cancel promptly. Default: enabled.", _categoryMove, true] call _addCheckbox;
["GAIT_ss_shiftReleaseRunTaperDuration", "Sprint release duration scale", "Sets the ceiling for the Shift-release ramp: value x gear factor, bounded to 0.35-1.20 seconds. The measured speed difference uses 75-100% of that window, beginning at the exact current running pace before easing to jog. Default 0.85 gives a ceiling near 0.77-0.98 seconds across carried loads.", _categoryMove, 0.05, 4.00, 0.85, 2] call _addSlider;
["GAIT_ss_shiftReleaseRunTaperCurve", "Sprint release curve", "Shapes the finite slowdown. Higher values lose pace sooner. Effective range: 1-3. Does not add a hold or extend the deadline. Default: 1.45.", _categoryMove, 1.00, 3.00, 1.45, 2] call _addSlider;
["GAIT_ss_unarmedSprintNormalizer", "Unarmed sprint normalizer", "Multiplier applied when sprinting with no weapon out so holstering does not create an unrealistic speed boost. Default: 0.725.", _categoryMove, 0.30, 1.20, 0.725, 3] call _addSlider;

// -----------------------------------------------------
// 04 ACE Carry Movement
// -----------------------------------------------------
["GAIT_ss_carryWalkSpeed", "Carry walk speed", "Animation speed while carrying a casualty and not sprinting. Default: 0.80.", _categoryCarry, 0.30, 1.50, 0.80, 2] call _addSlider;
["GAIT_ss_carrySprintFullSpeed", "Fresh carry sprint speed", "Carry sprint speed while reserve is high. Default: 1.50.", _categoryCarry, 0.50, 2.50, 1.50, 2] call _addSlider;
["GAIT_ss_carrySprintExhaustedSpeed", "Exhausted carry sprint speed", "Carry sprint speed when reserve is depleted. Default: 0.90.", _categoryCarry, 0.30, 1.50, 0.90, 2] call _addSlider;

// -----------------------------------------------------
// 05 Gear Mass
// -----------------------------------------------------
["GAIT_ss_loadAbsPerLb", "Load-to-pound divisor", "Converts Arma's current inventory mass to pounds for the movement curve. Default: 10.", _categoryWeight, 1.00, 25.00, 10.00, 1] call _addSlider;
["GAIT_ss_lightWeightMax", "First mass anchor", "First interpolation point for movement and brace. Default: 35 lb.", _categoryWeight, 0.00, 100.00, 35.00, 0] call _addSlider;
["GAIT_ss_mediumWeightMax", "Second mass anchor", "Second interpolation point for movement and brace. Default: 55 lb.", _categoryWeight, 0.00, 150.00, 55.00, 0] call _addSlider;
["GAIT_ss_moderateWeightMax", "Third mass anchor", "Third interpolation point for movement and brace. Additional mass keeps reducing flat speed. Default: 75 lb.", _categoryWeight, 0.00, 200.00, 75.00, 0] call _addSlider;
["GAIT_ss_lightSpeedBonus", "Zero-load speed multiplier", "Continuous speed curve at zero carried load. Default: 1.08.", _categoryWeight, 0.50, 1.50, 1.08, 3] call _addSlider;
["GAIT_ss_mediumSpeedBonus", "First-anchor speed multiplier", "Flat speed multiplier at the first mass anchor. Default: 1.02.", _categoryWeight, 0.50, 1.50, 1.02, 3] call _addSlider;
["GAIT_ss_moderateSpeedBonus", "Second-anchor speed multiplier", "Flat speed multiplier at the second mass anchor. Default: 0.97.", _categoryWeight, 0.50, 1.50, 0.97, 3] call _addSlider;
["GAIT_ss_heavySpeedBonus", "Third-anchor speed multiplier", "Flat speed multiplier at the third mass anchor. Additional mass reduces pace further. Default: 0.92.", _categoryWeight, 0.50, 1.50, 0.92, 3] call _addSlider;
["GAIT_ss_lightBraceRelief", "Zero-load brace relief", "Brace relief at zero carried mass. Intermediate loads are interpolated. 0 = full dip; 1 = 20% relief. Default: 0.55.", _categoryWeight, 0.00, 1.00, 0.55, 2] call _addSlider;
["GAIT_ss_mediumBraceRelief", "First-anchor brace relief", "Brace relief at the first mass anchor, applied at 20% strength. Default: 0.35.", _categoryWeight, 0.00, 1.00, 0.35, 2] call _addSlider;
["GAIT_ss_moderateBraceRelief", "Second-anchor brace relief", "Brace relief at the second mass anchor, applied at 20% strength. Default: 0.18.", _categoryWeight, 0.00, 1.00, 0.18, 2] call _addSlider;
["GAIT_ss_heavyBraceRelief", "Third-anchor brace relief", "Brace relief at and above the third mass anchor, applied at 20% strength. Default: 0.00.", _categoryWeight, 0.00, 1.00, 0.00, 2] call _addSlider;

// -----------------------------------------------------
// 06 Brace Step and Momentum
// -----------------------------------------------------
["GAIT_ss_sprintStartBraceEnabled", "Enable start brace step", "Enables both the small weight-scaled first step when beginning ordinary forward movement from rest and the stronger sprint-start brace. Default: enabled.", _categoryBrace, true] call _addCheckbox;
["GAIT_ss_sprintStartBraceDuration", "Sprint brace duration", "How long the sprint-start brace slowdown lasts. The smaller walk-start step uses its own continuous mass curve. Default: 0.15 seconds.", _categoryBrace, 0.00, 1.00, 0.15, 2] call _addSlider;
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
// 09 Terrain, Slopes, and Tripping
// -----------------------------------------------------
["GAIT_ss_slopeHandlingEnabled", "Enable slope handling", "Uses travel direction to adjust sprint pace on hills. Heavy kit slows uphill movement and builds more speed on sustained descents. Ordinary forward movement on slopes uses GAIT's jog animation. ACE medical locks still take priority.", _categorySlope, true] call _addCheckbox;
["GAIT_ss_slopeSampleDistance", "Slope sample distance", "Meters ahead and behind the player used to measure the terrain slope in the current movement direction. Higher values smooth noisy terrain; lower values react faster. Default: 2.0.", _categorySlope, 0.50, 6.00, 2.00, 1] call _addSlider;
["GAIT_ss_slopeTransitionSmoothingEnabled", "Smooth slope transitions", "Smooths slope angle and slope-speed target changes so moving between different incline angles ramps speed up/down instead of snapping. Default: enabled.", _categorySlope, true] call _addCheckbox;
["GAIT_ss_slopeAngleRiseRateDegPerSecond", "Slope angle rise rate", "Maximum degrees per second the effective slope may increase when entering steeper terrain. Higher values respond sooner. Default: 35 deg/sec.", _categorySlope, 2.00, 120.00, 35.00, 0] call _addSlider;
["GAIT_ss_slopeAngleFallRateDegPerSecond", "Slope angle fall rate", "Maximum degrees per second the effective slope may relax when terrain becomes flatter. Higher recovers faster. Default: 30 deg/sec.", _categorySlope, 2.00, 160.00, 30.00, 0] call _addSlider;

["GAIT_ss_uphillSlowdownEnabled", "Enable uphill slowdown", "Sprint pace responds quickly to an incline. The slowdown increases with incline and carried mass.", _categorySlope, true] call _addCheckbox;
["GAIT_ss_uphillStartDegrees", "Uphill slowdown starts", "Incline angle in degrees where uphill sprint slowdown begins. A higher value makes shallow hills feel closer to flat ground. Default: 2 degrees.", _categorySlope, 0.00, 45.00, 2.00, 1] call _addSlider;
["GAIT_ss_uphillMaxDegrees", "Uphill reference angle", "Angle where the reference penalty is reached. Pace continues decreasing above this angle without a walking cutoff. Default: 35 degrees.", _categorySlope, 5.00, 80.00, 35.00, 1] call _addSlider;
["GAIT_ss_uphillMaxPenalty", "Uphill penalty at reference angle", "Sprint pace reduction at the reference angle with 75 lb of gear. Lower carried mass reduces this penalty. The curve extends to steeper angles and respects the walking-relative pace floor. Default: 0.40.", _categorySlope, 0.00, 0.95, 0.40, 2] call _addSlider;
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

["GAIT_ss_downhillBoostEnabled", "Enable downhill acceleration", "Grounded downhill movement gets an immediate boost that grows during sustained descent. Sprinting gets a stronger boost than jogging, and heavy kit builds a larger gain. Trip risk still scales with actual speed. Default: enabled.", _categorySlope, true] call _addCheckbox;
["GAIT_ss_downhillBoostStartDegrees", "Downhill bonus starts", "Decline angle along the direction of travel where the downhill boost starts. Default: 0.5 degrees.", _categorySlope, 0.00, 30.00, 0.50, 1] call _addSlider;
["GAIT_ss_downhillBoostMaxDegrees", "Downhill base boost angle", "Decline angle where the configured base downhill bonus reaches full strength. Steeper grades continue adding gravity amplification beyond this point. Default: 18 degrees.", _categorySlope, 5.00, 60.00, 18.00, 1] call _addSlider;
["GAIT_ss_downhillMaxBoost", "Downhill entry speed boost", "Immediate downhill pace bonus before sustained momentum builds. A steeper decline and more carried mass increase the response. Default: 0.10.", _categorySlope, 0.00, 0.35, 0.10, 2] call _addSlider;
["GAIT_ss_downhillSustainedExtraBoost", "Sustained downhill bonus", "Additional pace earned by moving downhill while sprinting. Sustained descents also offset more of the flat-ground load penalty. The slope coefficient is capped at up to 165% of unloaded flat sprint pace. Default: 0.18.", _categorySlope, 0.00, 0.25, 0.18, 2] call _addSlider;
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
    "Movement only enables GAIT traversal. Disabled releases movement control.",
    _categoryQoL,
    [1, 4],
    ["Movement only", "Disabled"],
    0
] call _addList;

["GAIT_ss_showStartupMessage", "Show startup message", "Shows a short systemChat message after mission start with the active preset, compatibility mode, and ACE Advanced Fatigue bridge state.", _categoryQoL, true] call _addCheckbox;
["GAIT_ss_showServerIndicator", "Show server/settings indicator", "In multiplayer, shows a reminder that server or mission CBA settings may override local Addon Options. Useful for units with server-forced presets.", _categoryQoL, true] call _addCheckbox;
["GAIT_ss_rptLogging", "Enable RPT logging", "Writes useful GAIT initialization, preset, lifecycle, and Zeus reset messages to the RPT for troubleshooting.", _categoryQoL, true] call _addCheckbox;

["GAIT_ss_debugHudEnabled", "Enable debug HUD", "Shows grade, real speed, resolved direction, coefficient targets, animation family, reserve and ACE locks. Default: disabled.", _categoryQoL, false] call _addCheckbox;
["GAIT_ss_debugHudInterval", "Debug HUD refresh interval", "Seconds between debug HUD updates. Effective range: 0.05-1.00 seconds. Default: 0.10.", _categoryQoL, 0.05, 1.00, 0.10, 2] call _addSlider;


["GAIT_ss_minSprintWalkRatio", "Exhausted sprint / walk pace ratio", "Target ratio over walking at empty reserve with heavy kit. Lighter kits add up to 6 percentage points. GAIT uses matching clip references when available and estimates the ratio otherwise. Default: 1.06.", _categorySlope, 1.05, 1.50, 1.06, 2] call _addSlider;
["GAIT_ss_extraHeavyPenaltyPer50Lb", "Additional heavy-kit penalty", "Continuous load penalty beyond the heavy threshold: multiplier divided by 1 + value times extra pounds / 50. Default 0.18. Every additional pound continues to reduce walking and sprint pace.", _categoryWeight, 0.01, 1.00, 0.18, 2] call _addSlider;
["GAIT_ss_slopeLocomotionEnabled", "Dedicated standing sprint animations", "Uses scoped native sprint clips for forward/diagonal standing movement and run clips for lateral/reverse movement, with one blended entry/exit. No terrain angle cutoff. Disabling uses native animation selection and disables the calibrated release handoff.", _categorySlope, true] call _addCheckbox;

["GAIT_ss_freshSprintWalkMargin", "Fresh reserve pace margin", "Extra walk-relative pace for the fresh sprint minimum. The target tapers to the exhausted sprint ratio below 45% reserve. Default: 0.20.", _categorySlope, 0.01, 0.75, 0.20, 2] call _addSlider;
