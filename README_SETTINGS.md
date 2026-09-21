# GAIT 1.8.0-alpha11 settings reference

This reference is generated from the 122 current CBA registrations. Defaults below are registration defaults; presets and mission/server overrides can change effective values. Select Custom to keep individual tuning instead of having a preset reapply its values.

## Cleanup in alpha11

Removed the inactive release sustain timer, redundant downhill onset cap, and three switches that allowed lifecycle cleanup to be disabled. Cleanup on player replacement, spectator/control changes and unconsciousness is now unconditional. The duplicate Full/Hybrid movement choice is one Movement and effects choice; saved legacy numeric values 0 and 1 still select movement and effects.

For a custom old downhill onset cap, set the remaining Downhill boost starts control to the smaller of your previous onset and cap. Defaults are unchanged. The release curve slider now exposes its effective 1–3 range; HUD interval starts at the existing 0.05-second minimum.

Heartbeat gain is fixed at 10% by the optional heartbeat PBO, independently of the tinnitus switch. Removing that PBO restores ACE’s original heartbeat gain. There is no sway control. Automatic pace calibration has no extra user settings.

## Active controls

### General

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Enable GAIT (`GAIT_ss_enabled`) | true | on / off | Master switch for runtime movement, brace, fatigue audio and vignette. Disabling releases owned effects. Terrain config and the optional 10% ACE heartbeat patch remain until their PBOs are unloaded. |
| Feature update interval (`GAIT_ss_tickRate`) | 0.05 | 0.01–0.2 | Seconds between terrain, reserve and ordinary acceleration updates. Release interpolation is sampled each rendered frame. Default: 0.05 seconds. |
| Master: trip frequency (`GAIT_ss_masterTripFrequency`) | 1 | 0–3 | Meta-knob that scales downhill trip chance without changing thresholds. 1.00 is baseline. |
| Fatigue effect intensity (`GAIT_ss_masterFxIntensity`) | 1 | 0–2 | Scales GAIT tinnitus, hearing reduction and vignette strength. Does not scale ACE heartbeat. Vignette opacity remains capped at 14%. Default: 1.00. |
### ACE

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Read ACE Advanced Fatigue (`GAIT_ss_aceBridgeEnabled`) | true | on / off | Allows GAIT to read active ACE Advanced Fatigue reserves and physiological penalties. This does not enable, disable or write ACE physiology. Default: enabled. |
| Use ACE reserve for sprint strength (`GAIT_ss_useAceReserveModel`) | true | on / off | Reads ACE anaerobic/aerobic reserves, acidosis, and muscle damage to scale GAIT sprint speed and exhaustion effects. |
| Prevent ACE walk-lock override (`GAIT_ss_clearAceMovementLocks`) | true | on / off | Clears only ACE Advanced Fatigue's forced-walk and block-sprint locks so GAIT movement is not overwritten. |
| Protect GAIT animation speed (`GAIT_ss_registerAceAnimExclusion`) | true | on / off | Adds GAIT to ACE Advanced Fatigue's animation-speed exclusion list so ACE does not reset GAIT speed every fatigue tick. |
| Acidosis sprint penalty (`GAIT_ss_aceAcidosisPenaltyFactor`) | 0.45 | 0–1 | How strongly ACE anaerobic fatigue/acidosis reduces GAIT sprint reserve. Higher means acidosis hurts speed sooner. Default: 0.45. |
| Muscle-damage sprint penalty (`GAIT_ss_aceMuscleDamagePenaltyFactor`) | 0.25 | 0–1 | How strongly ACE muscle damage reduces GAIT sprint reserve. Higher means long-duration overwork hurts speed more. Default: 0.25. |
### Move

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Ordinary movement coefficient (`GAIT_ss_normalSpeed`) | 0.86 | 0.5–1.5 | Base animation coefficient for non-sprint movement before gear and slope modifiers. 1.00 is the active clip at its native playback rate, not a fixed speed in km/h. Default: 0.86. |
| Fresh sprint coefficient (`GAIT_ss_sprintFullSpeed`) | 1.28 | 0.7–2 | Base sprint animation coefficient at full reserve, before gear, slope and minimum pace-ratio modifiers. Not a speed in km/h. Default: 1.28. |
| Exhausted sprint coefficient (`GAIT_ss_sprintExhaustedSpeed`) | 0.89 | 0.4–1.5 | Base sprint animation coefficient at empty reserve, before gear, slope and minimum pace-ratio modifiers. Default: 0.89. |
| Fallback sprint reserve (`GAIT_ss_sprintReserveMax`) | 25 | 1–120 | Seconds of full sprint in the GAIT reserve model when ACE reserve reading is disabled, unavailable or not initialized. Default: 25 seconds. |
| Fallback reserve recovery (`GAIT_ss_sprintRecoverTime`) | 10 | 1–60 | Seconds to recover the GAIT fallback reserve. Does not change ACE recovery. Default: 10 seconds. |
| Speed ramp smoothness (`GAIT_ss_speedLerp`) | 0.05 | 0.01–1 | How quickly current speed moves toward target speed. Lower is smoother/slower; higher is snappier. Default: 0.05. |
| W-release zero-momentum delay (`GAIT_ss_wReleaseZeroMomentumDelay`) | 0.5 | 0–20 | Seconds after releasing forward movement before the next sprint start is treated as zero momentum. Lower values make brace return sooner. Default: 0.50. |
| Smooth sprint release (`GAIT_ss_shiftReleaseRunTaperEnabled`) | true | on / off | Release sprint while keeping forward movement held to decelerate from current motion. Uses measured jog pace when a valid reference exists. Stop, direction changes and medical restrictions cancel promptly. Default: enabled. |
| Sprint release duration scale (`GAIT_ss_shiftReleaseRunTaperDuration`) | 0.85 | 0.05–4 | Sets the ceiling for the Shift-release ramp: value x gear factor, bounded to 0.35–1.20 seconds. The measured speed difference uses 75–100% of that window, beginning at the exact current running pace before easing to jog. Default 0.85 gives a ceiling near 0.77–0.98 seconds across the default weight tiers. |
| Sprint release curve (`GAIT_ss_shiftReleaseRunTaperCurve`) | 1.45 | 1–3 | Shapes the finite slowdown. Higher values lose pace sooner. Effective range: 1-3. Does not add a hold or extend the deadline. Default: 1.45. |
| Unarmed sprint normalizer (`GAIT_ss_unarmedSprintNormalizer`) | 0.725 | 0.3–1.2 | Multiplier applied when sprinting with no weapon out so holstering does not create an unrealistic speed boost. Default: 0.725. |
### Carry

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Carry walk speed (`GAIT_ss_carryWalkSpeed`) | 0.8 | 0.3–1.5 | Animation speed while carrying a casualty and not sprinting. Default: 0.80. |
| Fresh carry sprint speed (`GAIT_ss_carrySprintFullSpeed`) | 1.5 | 0.5–2.5 | Carry sprint speed while reserve is high. Default: 1.50. |
| Exhausted carry sprint speed (`GAIT_ss_carrySprintExhaustedSpeed`) | 0.9 | 0.3–1.5 | Carry sprint speed when reserve is depleted. Default: 0.90. |
### Weight

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Load-to-pound divisor (`GAIT_ss_loadAbsPerLb`) | 10 | 1–25 | Conversion used for display-style gear weight. Gear pounds = loadAbs divided by this value. Default: 10. |
| Light kit max weight (`GAIT_ss_lightWeightMax`) | 35 | 0–100 | Upper weight for the light-kit speed/brace tier. Default: 35 lb. |
| Medium kit max weight (`GAIT_ss_mediumWeightMax`) | 55 | 0–150 | Upper weight for the medium-kit speed/brace tier. Default: 55 lb. |
| Moderate kit max weight (`GAIT_ss_moderateWeightMax`) | 75 | 0–200 | Upper weight for the moderate-kit speed/brace tier. Above this uses heavy baseline. Default: 75 lb. |
| Zero-load speed multiplier (`GAIT_ss_lightSpeedBonus`) | 1.08 | 0.5–1.5 | Continuous speed curve at zero carried load. Default: 1.08. |
| Light threshold speed multiplier (`GAIT_ss_mediumSpeedBonus`) | 1.05 | 0.5–1.5 | Continuous speed curve at the light weight threshold. Default: 1.05. |
| Medium threshold speed multiplier (`GAIT_ss_moderateSpeedBonus`) | 1.025 | 0.5–1.5 | Continuous speed curve at the medium weight threshold. Default: 1.025. |
| Heavy threshold speed multiplier (`GAIT_ss_heavySpeedBonus`) | 1 | 0.5–1.5 | Continuous speed curve at the heavy weight threshold; extra weight reduces pace further. Default: 1.00. |
| Light kit brace relief (`GAIT_ss_lightBraceRelief`) | 0.55 | 0–1 | Small reduction of the shared brace dip for light kits. Applied at 20% strength so every tier keeps a brace. 0 = full dip; 1 = 20% relief. Default: 0.55. |
| Medium kit brace relief (`GAIT_ss_mediumBraceRelief`) | 0.35 | 0–1 | Small reduction of the shared brace dip for medium kits, applied at 20% strength. Default: 0.35. |
| Moderate kit brace relief (`GAIT_ss_moderateBraceRelief`) | 0.18 | 0–1 | Small reduction of the shared brace dip for moderate kits, applied at 20% strength. Default: 0.18. |
| Heavy kit brace relief (`GAIT_ss_heavyBraceRelief`) | 0 | 0–1 | Small reduction of the shared brace dip for heavy kits, applied at 20% strength. Default: 0.00. |
### Brace

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Enable start brace step (`GAIT_ss_sprintStartBraceEnabled`) | true | on / off | Enables the small weight-scaled first step when beginning ordinary forward movement from rest and the stronger sprint-start brace. |
| Sprint brace duration (`GAIT_ss_sprintStartBraceDuration`) | 0.15 | 0–1 | How long the sprint-start brace lasts. The smaller walk-start step uses a fixed short tier curve: light 0.28 s, medium 0.32 s, moderate 0.36 s, heavy 0.40 s. |
| Sprint brace speed (`GAIT_ss_sprintStartBraceSpeed`) | 0.42 | 0.1–1.2 | Animation speed target during the sprint-start brace. The walk-start step automatically uses a shallower 14%–26% initial pace reduction by kit tier. |
| Sprint brace snap (`GAIT_ss_sprintStartBraceLerp`) | 0.575 | 0.01–1 | How abruptly speed moves into the sprint-start brace. The walk-start step uses a deterministic smooth finite recovery instead. |
| Brace settle time (`GAIT_ss_braceRequiredWalkTime`) | 2 | 0–10 | Non-sprint settle interval used by normal brace readiness and momentum recovery. A true stop can independently rearm the brace; a moving sprint retap is protected. Default: 2 seconds. |
| Recent sprint grace (`GAIT_ss_braceRecentSprintCooldown`) | 3 | 0–10 | Recent-sprint interval used by normal brace readiness and retained momentum. A real stop can still rearm brace before it expires. Default: 3 seconds. |
| Brace reserve gate (`GAIT_ss_braceMinReserveRatio`) | 0.98 | 0–1 | Minimum GAIT reserve ratio needed for brace when ACE reserve is not active. With ACE active, movement state owns brace. Default: 0.98. |
| No-momentum threshold (`GAIT_ss_braceNoMomentumThreshold`) | 0.04 | 0–0.5 | Coefficient margin used to detect settled walking. Established moving sprint momentum overrides all brace triggers until a real stop or settled recovery. Default: 0.04. |
| Brace-ready movement speed (`GAIT_ss_braceReadySpeedThreshold`) | 4 | 0–10 | Non-sprint speed gate for ordinary brace readiness, in km/h. Crouch and a sufficiently long forward-input release can also arm it. Default: 4 km/h. |
| Slope-aware brace (`GAIT_ss_slopeStopBraceEnabled`) | true | on / off | Enables slope effects on sprint-start bracing. Zero-momentum uphill starts gain an exponential brace burden from any positive grade; retained sprint momentum bypasses it. Remembered incline/decline restarts still use the angle controls below. Default: enabled. |
| Remembered slope brace starts (`GAIT_ss_slopeStopBraceStartDegrees`) | 15 | 0–60 | Incline/decline angle where the remembered stop/restart brace begins. Zero-momentum uphill launch amplification starts above 0 degrees independently. Default: 15 degrees. |
| Slope brace reference angle (`GAIT_ss_slopeStopBraceMaxDegrees`) | 35 | 5–80 | Reference angle for full remembered-slope brace strength and the exponential zero-momentum uphill launch curve. Steeper uphill grades can extend the launch burden modestly beyond it. Default: 35 degrees. |
| Slope brace extra duration (`GAIT_ss_slopeStopBraceExtraDuration`) | 0.18 | 0–2 | Base extra duration for slope bracing. Zero-momentum uphill launches exponentially amplify this value to roughly 3x at the reference angle; momentum-protected starts bypass it. Default: 0.18 sec. |
| Slope brace extra dip (`GAIT_ss_slopeStopBraceExtraDip`) | 0.28 | 0–0.9 | Base slope-induced brace speed dip. Zero-momentum uphill launches exponentially amplify it; retained momentum bypasses the added uphill burden. Default: 0.28. |
| Slope brace memory (`GAIT_ss_slopeStopBraceMemoryTime`) | 2.5 | 0–10 | Seconds after stopping sprint on an incline where the next sprint start still uses the slope brace. Default: 2.5 sec. |
| Uphill sprint-release brake (`GAIT_ss_uphillReleaseBraceEnabled`) | true | on / off | Brief dig-in braking when releasing a moving uphill sprint. Uses the slope brace angles, duration and dip and takes priority over the ordinary release ramp. Releasing forward movement cancels its animation hold. Default: enabled. |
### Audio

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Enable tinnitus (`GAIT_ss_tinnitusEnabled`) | true | on / off | Enables GAIT tinnitus at high exhaustion. Separate optional gait_heartbeat.pbo fixes ACE heartbeat gain at 10% of original; this checkbox does not control it. |
| Tinnitus starts at exhaustion (`GAIT_ss_tinnitusStartExhaustion`) | 0.7 | 0–1 | Exhaustion level where tinnitus begins. 0 = immediately, 1 = only at max exhaustion. Default: 0.70. |
| Tinnitus stop threshold (`GAIT_ss_audioStopExhaustion`) | 0.1 | 0–1 | GAIT tinnitus fades out below this exhaustion level. Does not stop ACE heartbeat or breathing. Default: 0.10. |
| Tinnitus maximum gain (`GAIT_ss_tinnitusMaxVolume`) | 0.55 | 0–2 | Maximum GAIT tinnitus gain before the fatigue effect intensity multiplier. Does not change ACE heartbeat. Default: 0.55. |
| Audio fade smoothness (`GAIT_ss_audioFadeLerp`) | 0.08 | 0.01–1 | How quickly tinnitus volume moves toward its target. Higher changes faster. Default: 0.08. |
| Fatigue hearing reduction (`GAIT_ss_hearingEnabled`) | true | on / off | Applies a GAIT hearing-capability contribution through ACE when available. Other ACE hearing effects remain independently owned. Default: enabled. |
| Minimum hearing volume (`GAIT_ss_hearingMinVolume`) | 0.2 | 0–1 | Lowest hearing volume at maximum exhaustion. 1 = no reduction, 0 = muted. Default: 0.20. |
| Hearing fade duration (`GAIT_ss_hearingFadeDuration`) | 0.2 | 0–5 | Seconds used when changing hearing volume. Default: 0.20. |
### Visual

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Intermittent fatigue vignette (`GAIT_ss_fatigueVignetteEnabled`) | true | on / off | Brief, subtle edge darkening when tired, separated by fully clear intervals. Replaces only ACE Advanced Fatigue blackout while active. Clears on recovery, disable or lost updates. Default: enabled. |
| Visuals start at exhaustion (`GAIT_ss_tunnelStartExhaustion`) | 0.18 | 0–1 | Exhaustion level where intermittent vignette pulses begin. Default: 0.18. |
| Vignette strength scale (`GAIT_ss_tunnelMaxStrength`) | 1 | 0–2 | Scales the fatigue pulse, together with fatigue effect intensity. Resulting strength saturates at 1 and peak edge opacity remains at most 14%. Default: 1.00. |
### Slope

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Enable slope handling (`GAIT_ss_slopeHandlingEnabled`) | true | on / off | Enables GAIT terrain-aware sprint behavior. Uphill sprinting slows progressively instead of being blocked; downhill sprinting can give a small speed boost and optional trip risk on steep descents. |
| Slope sample distance (`GAIT_ss_slopeSampleDistance`) | 2 | 0.5–6 | Meters ahead and behind the player used to measure the terrain slope in the current movement direction. Higher values smooth noisy terrain; lower values react faster. Default: 2.0. |
| Smooth slope transitions (`GAIT_ss_slopeTransitionSmoothingEnabled`) | true | on / off | Smooths slope angle and slope-speed target changes so moving between different incline angles ramps speed up/down instead of snapping. Default: enabled. |
| Slope angle rise rate (`GAIT_ss_slopeAngleRiseRateDegPerSecond`) | 22 | 2–120 | Maximum degrees per second the effective slope may increase when entering steeper terrain. Lower is smoother/heavier. Default: 22 deg/sec. |
| Slope angle fall rate (`GAIT_ss_slopeAngleFallRateDegPerSecond`) | 30 | 2–160 | Maximum degrees per second the effective slope may relax when terrain becomes flatter. Higher recovers faster. Default: 30 deg/sec. |
| Enable uphill slowdown (`GAIT_ss_uphillSlowdownEnabled`) | true | on / off | When sprinting uphill, GAIT reduces sprint speed as the slope gets steeper. Sprinting remains possible; it just gets slower. |
| Uphill slowdown starts (`GAIT_ss_uphillStartDegrees`) | 5 | 0–45 | Incline angle in degrees where uphill sprint slowdown begins. A higher value makes shallow hills feel closer to flat ground. Default: 5 degrees. |
| Uphill reference angle (`GAIT_ss_uphillMaxDegrees`) | 35 | 5–80 | Angle where the reference penalty is reached. Pace continues decreasing above this angle without a walking cutoff. Default: 35 degrees. |
| Uphill penalty at reference angle (`GAIT_ss_uphillMaxPenalty`) | 0.4 | 0–0.95 | Sprint pace reduction at the reference angle. 0.40 means 40% slower there. The continuous curve extends to steeper angles; a walk-relative target floor preserves sprint advantage. Default: 0.40. |
| Vegetation drag (`GAIT_ss_vegetationDragEnabled`) | true | on / off | Dense bushes bleed movement speed while passing through them. Default: enabled. |
| Vegetation drag max (`GAIT_ss_vegetationDragMax`) | 0.18 | 0–0.75 | Maximum movement speed reduction in dense brush. 0.18 means up to 18% slower. Default: 0.18. |
| Vegetation drag radius (`GAIT_ss_vegetationDragRadius`) | 2.5 | 0.5–6 | Bush proximity radius in meters considered for drag. Default: 2.5 m. |
| Slow walking on hills (`GAIT_ss_hillWalkSlowdownEnabled`) | true | on / off | Slows normal W movement on inclines/declines before sprinting so starting uphill already feels heavy. Default: enabled. |
| Hill walk slowdown starts (`GAIT_ss_hillWalkSlowdownStartDegrees`) | 15 | 0–45 | Slope angle where normal walking/jogging begins slowing before sprint. Default: 15 degrees. |
| Hill walk reference angle (`GAIT_ss_hillWalkSlowdownMaxDegrees`) | 40 | 5–80 | Slope angle where walking reaches the reference penalty. Pace continues decreasing on steeper terrain. Default: 40 degrees. |
| Uphill walk reference penalty (`GAIT_ss_hillWalkUphillMaxPenalty`) | 0.32 | 0–0.75 | Normal movement loss at the walk reference angle, adjusted for kit weight. Default: 0.32. |
| Downhill walk max penalty (`GAIT_ss_hillWalkDownhillMaxPenalty`) | 0.08 | 0–0.35 | Small normal movement speed loss while walking downhill before momentum builds. Default: 0.08. |
| Increase uphill stamina drain (`GAIT_ss_uphillFatigueDrainEnabled`) | true | on / off | Increases GAIT fallback reserve drain uphill when ACE reserves are unavailable. ACE calculates its own terrain exertion; its reserves and acidosis are read-only. Default: enabled. |
| Uphill drain starts (`GAIT_ss_uphillFatigueDrainStartDegrees`) | 10 | 0–45 | Incline angle where additional uphill fatigue drain begins. Default: 10 degrees. |
| Uphill drain max angle (`GAIT_ss_uphillFatigueDrainMaxDegrees`) | 35 | 5–80 | Incline angle where additional uphill fatigue drain reaches full strength. Default: 35 degrees. |
| Uphill max drain multiplier (`GAIT_ss_uphillFatigueDrainMaxMultiplier`) | 1.75 | 1–4 | Maximum multiplier applied to sprint stamina drain on steep uphill terrain. 1.75 means 75% faster drain. Default: 1.75. |
| Enable downhill acceleration (`GAIT_ss_downhillBoostEnabled`) | true | on / off | Builds downhill momentum only while actually descending. Steeper grades accelerate harder instead of tapering the bonus. Default: enabled. |
| Downhill bonus starts (`GAIT_ss_downhillBoostStartDegrees`) | 4 | 0–30 | Decline angle where the downhill speed bonus starts. This is the single onset control. Default: 4 degrees. |
| Downhill base boost angle (`GAIT_ss_downhillBoostMaxDegrees`) | 18 | 5–60 | Decline angle where the configured base bonus reaches full strength. Steeper grades continue adding gravity amplification. Default: 18 degrees. |
| Downhill base speed boost (`GAIT_ss_downhillMaxBoost`) | 0.06 | 0–0.35 | Base downhill bonus at full momentum, added to the sustained bonus below. Steep grades can amplify the configured component up to 3x before the final cap, with stronger retention under heavy kit. Default: 0.06. |
| Sustained downhill bonus (`GAIT_ss_downhillSustainedExtraBoost`) | 0.12 | 0–0.25 | Additional bonus earned by actual downhill sprint travel. Base+sustained boost is amplified on steep grades, with final additive acceleration capped at 65%. Default: 0.12. |
| Downhill momentum build time (`GAIT_ss_downhillMomentumBuildSeconds`) | 2.5 | 0.5–8 | Baseline seconds of actual downhill sprint travel to build 95% momentum. Steeper descents shorten this by up to 55%; flat sprinting does not preload downhill momentum. Default: 2.5 seconds. |
| Enable steep downhill trips (`GAIT_ss_downhillTripEnabled`) | true | on / off | Allows a chance to stumble/ragdoll during fast grounded travel down a steep hill, including sprint deceleration. This does not apply damage by itself. Default: enabled. |
| Trip risk starts above decline (`GAIT_ss_downhillTripThresholdDegrees`) | 28 | 5–70 | Downhill angle in degrees where trip risk begins during eligible travel above the actual speed minimum. The decline must be steeper than this value. Default: 28 degrees. |
| Trip max-risk decline (`GAIT_ss_downhillTripMaxDegrees`) | 45 | 10–80 | Downhill angle where the slope component reaches its configured maximum, before speed and weight scaling. Default: 45 degrees. |
| Trip base chance per second (`GAIT_ss_downhillTripBaseChancePerSecond`) | 0.005 | 0–1 | Per-second trip probability near the minimum decline, before current speed and weight scaling. 0.005 means 0.5% per second before scaling. Default: 0.005. |
| Trip max chance per second (`GAIT_ss_downhillTripMaxChancePerSecond`) | 0.1 | 0–1 | Per-second trip probability at or beyond the max-risk decline, before current speed and weight scaling. 0.10 means 10% per second before scaling. Default: 0.10. |
| Trip cooldown (`GAIT_ss_downhillTripCooldown`) | 10 | 0–60 | Minimum seconds between downhill trip attempts after a trip occurs. Prevents repeated ragdolls on one slope. Default: 10 seconds. |
| Minimum trip ragdoll time (`GAIT_ss_downhillTripDuration`) | 1 | 0.1–8 | Minimum time down after a GAIT trip. Recovery can take longer until horizontal speed falls below the get-up threshold, subject to the safety timeout. Default: 1 second. |
| Trip minimum speed (`GAIT_ss_downhillTripMinSpeedKmh`) | 20 | 0–50 | Minimum actual horizontal speed for downhill trip checks. With speed scaling enabled, risk rises smoothly from zero above this speed. Default: 20 km/h. |
| Trip reference speed (`GAIT_ss_downhillTripSpeedMaxKmh`) | 34 | 5–70 | Horizontal speed in km/h used to calibrate trip risk. Risk continues rising above this speed. Default: 34 km/h. |
| Trip speed influence (`GAIT_ss_downhillTripSpeedInfluence`) | 1 | 0–2 | Trip risk curve for actual horizontal speed above the minimum. 0 disables speed scaling; 1 is linear; 2 uses a quadratic curve. Default: 1. |
| Trip weight influence (`GAIT_ss_downhillTripWeightInfluence`) | 1 | 0–2 | How strongly carried kit weight scales downhill trip chance. 0 ignores weight; 1 is normal; 2 doubles the influence. Default: 1. |
| Require sustained run for trips (`GAIT_ss_downhillTripRequireSustainedMovement`) | true | on / off | If enabled, trip rolls only affect the player after sustained sprinting or sustained high speed. Default: enabled. |
| Trip sprint time gate (`GAIT_ss_downhillTripMinSprintSeconds`) | 5 | 0–20 | Seconds of continuous sprinting required for trip qualification. Earned qualification persists through deceleration while actual speed remains above the trip minimum. Default: 5 seconds. |
| Trip high-speed gate (`GAIT_ss_downhillTripSustainedSpeedKmh`) | 20 | 0–50 | Speed threshold used by the alternate high-speed trip gate. Default: 20 km/h. |
| Trip high-speed time gate (`GAIT_ss_downhillTripSustainedSpeedSeconds`) | 4 | 0–20 | Seconds of actual horizontal movement at or above the high-speed gate. Releasing sprint preserves this history while speed stays high. Default: 4 seconds. |
| Post-trip immunity (`GAIT_ss_downhillTripPostFallImmunity`) | 10 | 0–60 | Seconds after a GAIT trip where another GAIT trip cannot occur. Default: 10 seconds. |
| Trip get-up speed threshold (`GAIT_ss_downhillTripGetUpSpeedKmh`) | 7 | 0.5–30 | Player stays ragdolled after a trip until horizontal momentum falls below this speed, after the minimum trip duration. Default: 7 km/h. |
| Trip max ragdoll duration (`GAIT_ss_downhillTripMaxRagdollDuration`) | 6 | 0.5–12 | Safety cap in seconds so a trip cannot keep the player down forever if momentum does not bleed off. Default: 6 seconds. |
### QoL

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Tuning preset (`GAIT_ss_preset`) | Balanced | Custom: Custom; Balanced: Balanced; Realistic: Realistic; Arcade: Arcade; Training: Training; Light Infantry: Light Infantry; Heavy Infantry: Heavy Infantry | Applies a readable starting point for GAIT tuning. Choose Custom after applying a preset if you want to hand-tune individual values without the preset reapplying on change. |
| Compatibility mode (`GAIT_ss_compatibilityMode`) | 1 | 1: Movement and effects; 2: Effects and hearing; 3: Visuals and tinnitus; 4: Disabled | Movement and effects runs the full controller. Effects and hearing disables movement changes. Visuals and tinnitus also disables hearing reduction. Disabled releases runtime effects. The fixed config patches remain loaded. |
| Show startup message (`GAIT_ss_showStartupMessage`) | true | on / off | Shows a short systemChat message after mission start with the active preset, compatibility mode, and ACE Advanced Fatigue bridge state. |
| Show server/settings indicator (`GAIT_ss_showServerIndicator`) | true | on / off | In multiplayer, shows a reminder that server or mission CBA settings may override local Addon Options. Useful for units with server-forced presets. |
| Enable RPT logging (`GAIT_ss_rptLogging`) | true | on / off | Writes useful GAIT initialization, preset, lifecycle, and Zeus reset messages to the RPT for troubleshooting. |
| Enable debug HUD (`GAIT_ss_debugHudEnabled`) | false | on / off | Shows grade, real speed, resolved direction, coefficient targets, animation family, reserve and ACE locks. Default: disabled. |
| Debug HUD refresh interval (`GAIT_ss_debugHudInterval`) | 0.1 | 0.05–1 | Seconds between debug HUD updates. Effective range: 0.05-1.00 seconds. Default: 0.10. |
### Audio

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Hard landing camera shake (`GAIT_ss_hardLandingCamShakeEnabled`) | true | on / off | Adds a small camera shake when landing hard after a drop. Default: enabled. |
| Hard landing threshold (`GAIT_ss_hardLandingMinVerticalSpeed`) | 4 | 0.5–20 | Downward velocity required before landing shake can trigger. Default: 4 m/s. |
| Hard landing shake strength (`GAIT_ss_hardLandingShakeStrength`) | 1 | 0–3 | Scales camera shake strength on hard landings. Default: 1.00. |
### Slope

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Minimum sprint / walk target ratio (`GAIT_ss_minSprintWalkRatio`) | 1.2 | 1.05–1.5 | Conservative coefficient target floor relative to walking at the same grade and load. 1.20 preserves at least a 20% coefficient advantage after acceleration. Actual clip speeds must be verified in-game. Does not override injury, collision or special actions. |
### Weight

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Additional heavy-kit penalty (`GAIT_ss_extraHeavyPenaltyPer50Lb`) | 0.18 | 0.01–1 | Continuous load penalty beyond the heavy threshold: multiplier divided by 1 + value times extra pounds / 50. Default 0.18. Every additional pound continues to reduce walking and sprint pace. |
### Slope

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Dedicated standing sprint animations (`GAIT_ss_slopeLocomotionEnabled`) | true | on / off | Uses scoped native sprint clips for forward/diagonal standing movement and run clips for lateral/reverse movement, with one blended entry/exit. No terrain angle cutoff. Disabling uses native animation selection and disables the calibrated release handoff. |
| Fresh reserve pace margin (`GAIT_ss_freshSprintWalkMargin`) | 0.2 | 0.01–0.75 | Extra sprint/walk coefficient ratio at full reserve, fading continuously with fatigue. Keeps reserve affecting speed when the walk-relative floor is active. Default 0.20 adds 20 percentage points to the minimum ratio when fresh. |
