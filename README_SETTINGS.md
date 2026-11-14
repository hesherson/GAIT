# GAIT 1.8.0-alpha25 settings reference

This reference covers the 107 current CBA registrations. The table shows registration defaults. Presets and mission or server overrides can change effective values. Select Custom to keep individual tuning.

## Current cleanup and compatibility behavior

Removed the inactive release sustain timer, redundant downhill onset cap, and three switches that allowed lifecycle cleanup to be disabled. Cleanup on player replacement, spectator/control changes and unconsciousness is now unconditional. Movement only is the default. Saved numeric values 0 and 1 enable movement, and the old effects-only modes resolve to Disabled.

The Downhill boost starts control now defaults to 0.5°. Exhausted sprint tapers in the last 20% of the stamina bar, and uphill sprint has a jog-relative floor. Jog deceleration uses the common speed ramp in every direction.

ACE supplies fatigue feedback. Stable same-clip measurements may automatically calibrate sprint pace, and complete manual pace profiles are optional.

## Active controls

### General

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Enable GAIT (`GAIT_ss_enabled`) | true | on / off | Enables GAIT movement and bracing. ACE supplies fatigue feedback. |
| Feature update interval (`GAIT_ss_tickRate`) | 0.05 | 0.01–0.2 | Seconds between terrain, reserve and ordinary acceleration updates. Release interpolation is sampled each rendered frame. Default: 0.05 seconds. |
| Master: trip frequency (`GAIT_ss_masterTripFrequency`) | 1 | 0–3 | Meta-knob that scales downhill trip chance without changing thresholds. 1.00 is baseline. |
### ACE

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Integrate ACE Advanced Fatigue (`GAIT_ss_aceBridgeEnabled`) | true | on / off | Allows GAIT to integrate with the active ACE fatigue model. ACE owns fatigue effects, aerobic fatigue and medical feedback. |
| ACE heartbeat volume (`GAIT_ss_aceHeartbeatVolume`) | 10 | 0–100% | Local volume for ACE’s heartbeat. 0 mutes it, and 100 restores ACE’s usual playback. |
| Use ACE sprint reserve (`GAIT_ss_useAceReserveModel`) | true | on / off | Uses the anaerobic reserve shown in the ACE bar. Sprint spends reserve, rest recovers it, and jogging or walking holds it. GAIT falls back to its own reserve if the installed ACE loop is unsupported. |
| Prevent ACE walk-lock override (`GAIT_ss_clearAceMovementLocks`) | true | on / off | Clears only ACE Advanced Fatigue's forced-walk and block-sprint locks so GAIT movement is not overwritten. |
| Protect GAIT animation speed (`GAIT_ss_registerAceAnimExclusion`) | true | on / off | Adds GAIT to ACE Advanced Fatigue's animation-speed exclusion list so ACE does not reset GAIT speed every fatigue tick. |
| Acidosis sprint penalty (`GAIT_ss_aceAcidosisPenaltyFactor`) | 0.45 | 0–1 | How strongly ACE acidosis shapes the sprint taper during the last 20% of stamina. |
| Muscle-damage sprint penalty (`GAIT_ss_aceMuscleDamagePenaltyFactor`) | 0.25 | 0–1 | How strongly ACE muscle damage shapes the sprint taper during the last 20% of stamina. |
### Move

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Jog movement coefficient (`GAIT_ss_normalSpeed`) | 0.86 | 0.5–1.5 | Base jog animation coefficient before gear and slope modifiers. Arma controls deliberate walk pace. |
| Sustained sprint coefficient (`GAIT_ss_sprintFullSpeed`) | 1.00 | 0.70–2 | Base sprint animation rate after the rested burst. 1.00 is the normal sprint clip speed before slope and animation adjustments. |
| Flat dead sprint peak (`GAIT_ss_flatSprintPeak`) | 1.10 | 1–1.30 | Maximum multiplier over sustained sprint pace at a fully rested start on level ground. Carried mass reduces the bonus. |
| Exhausted run pace midpoint (`GAIT_ss_exhaustedRunPace`) | 0.70 | 0.50–0.95 | Target fraction at empty reserve with a 50 lb kit. Defaults range from 0.75 unloaded to 0.65 at 100 lb or more. Uphill sprint keeps its jog-relative floor. |
| Fallback sprint reserve (`GAIT_ss_sprintReserveMax`) | 40 | 1–120 | Seconds of sprinting on flat ground without a load when using GAIT's fallback reserve. |
| Fallback reserve recovery (`GAIT_ss_sprintRecoverTime`) | 10 | 1–60 | Seconds at rest to recover the GAIT fallback reserve. |
| Speed ramp smoothness (`GAIT_ss_speedLerp`) | 0.05 | 0.01–1 | Base smoothing rate for movement speed changes. Flat sprint acceleration uses 70% of this rate and reaches about 95% of target in 4.1 seconds before the carried-load adjustment. Hills have their own entry response. |
| W-release zero-momentum delay (`GAIT_ss_wReleaseZeroMomentumDelay`) | 0.5 | 0–20 | Seconds after releasing forward movement before the next sprint start is treated as zero momentum. Lower values make brace return sooner. Default: 0.50. |
| Smooth jog deceleration (`GAIT_ss_shiftReleaseRunTaperEnabled`) | true | on / off | Eases speed toward the live jog target in every direction. Turning and strafing use native input. |
| Jog deceleration time (`GAIT_ss_shiftReleaseRunTaperDuration`) | 1.15 | 0.05–4 s | Time for the coefficient to cover 95% of the gap to a steady jog target. |
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
| Load-to-pound divisor (`GAIT_ss_loadAbsPerLb`) | 10 | 1–25 | Converts live carried inventory mass to the pounds used by the load curves. GAIT divides Arma's loadAbs value by this setting. |
| First mass anchor (`GAIT_ss_lightWeightMax`) | 35 | 0–100 | First loaded pace and brace tuning point. |
| Second mass anchor (`GAIT_ss_mediumWeightMax`) | 55 | 0–150 | Middle loaded pace and brace tuning point. |
| Third mass anchor (`GAIT_ss_moderateWeightMax`) | 75 | 0–200 | Heavy pace and brace tuning point. The additional heavy-kit penalty applies above this mass. |
| Zero-load speed multiplier (`GAIT_ss_lightSpeedBonus`) | 1.08 | 0.5–1.5 | Continuous speed curve at zero carried load. Default: 1.08. |
| First-anchor speed multiplier (`GAIT_ss_mediumSpeedBonus`) | 1.02 | 0.5–1.5 | Continuous speed curve at the first load point. |
| Second-anchor speed multiplier (`GAIT_ss_moderateSpeedBonus`) | 0.97 | 0.5–1.5 | Continuous speed curve at the middle load point. |
| Third-anchor speed multiplier (`GAIT_ss_heavySpeedBonus`) | 0.92 | 0.5–1.5 | Continuous speed curve at the heavy load point. Additional mass reduces pace further. |
| Zero-load brace relief (`GAIT_ss_lightBraceRelief`) | 0.55 | 0–1 | First-step brace relief at the light end of the mass curve. The setting is applied at 20% strength. |
| First-anchor brace relief (`GAIT_ss_mediumBraceRelief`) | 0.35 | 0–1 | First-step brace relief at the medium point of the mass curve, applied at 20% strength. |
| Second-anchor brace relief (`GAIT_ss_moderateBraceRelief`) | 0.18 | 0–1 | First-step brace relief at the moderate point of the mass curve, applied at 20% strength. |
| Third-anchor brace relief (`GAIT_ss_heavyBraceRelief`) | 0 | 0–1 | First-step brace relief at the heavy end of the mass curve, applied at 20% strength. |
### Brace

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Enable start brace step (`GAIT_ss_sprintStartBraceEnabled`) | true | on / off | Enables the small weight-scaled first step when beginning ordinary forward movement from rest and the stronger sprint-start brace. |
| Sprint brace duration (`GAIT_ss_sprintStartBraceDuration`) | 0.15 | 0–1 | Base duration for the sprint launch. Sprint launch uses 92% of the assembled duration. |
| Sprint brace speed (`GAIT_ss_sprintStartBraceSpeed`) | 0.44 | 0.10–1.20 | Animation speed target during the sprint-start brace. Lower values deepen the dip. |
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
### Slope

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Enable slope handling (`GAIT_ss_slopeHandlingEnabled`) | true | on / off | Enables GAIT terrain-aware movement. When Arma switches an ordinary jog to a slope walk, GAIT maintains a jog unless walk is selected. Uphill sprinting slows with grade, and downhill sprinting accelerates with sustained descent momentum. ACE medical movement locks still take priority. |
| Slope sample distance (`GAIT_ss_slopeSampleDistance`) | 2 | 0.5–6 | Meters ahead and behind the player used to measure the terrain slope in the current movement direction. Higher values smooth noisy terrain; lower values react faster. Default: 2.0. |
| Smooth slope transitions (`GAIT_ss_slopeTransitionSmoothingEnabled`) | true | on / off | Smooths slope angle and slope-speed target changes so moving between different incline angles ramps speed up/down instead of snapping. Default: enabled. |
| Slope angle rise rate (`GAIT_ss_slopeAngleRiseRateDegPerSecond`) | 35 | 2–120 | Maximum degrees per second the effective slope may increase when entering steeper terrain. Lower values delay the grade response. |
| Slope angle fall rate (`GAIT_ss_slopeAngleFallRateDegPerSecond`) | 30 | 2–160 | Maximum degrees per second the effective slope may relax when terrain becomes flatter. Higher recovers faster. Default: 30 deg/sec. |
| Enable uphill slowdown (`GAIT_ss_uphillSlowdownEnabled`) | true | on / off | When sprinting uphill, GAIT reduces sprint speed as the slope gets steeper. Sprinting remains possible; it just gets slower. |
| Uphill slowdown starts (`GAIT_ss_uphillStartDegrees`) | 2 | 0–45 | Incline angle in degrees where uphill sprint slowdown begins. A higher value makes shallow hills feel closer to flat ground. |
| Uphill reference angle (`GAIT_ss_uphillMaxDegrees`) | 35 | 5–80 | Angle where the reference penalty is reached. Pace continues decreasing above this angle without a walking cutoff. Default: 35 degrees. |
| Uphill penalty at reference angle (`GAIT_ss_uphillMaxPenalty`) | 0.4 | 0–0.95 | Sprint pace reduction at the reference angle for all loads. The curve extends to steeper terrain and respects the uphill sprint floor. |
| Vegetation drag (`GAIT_ss_vegetationDragEnabled`) | true | on / off | Dense bushes bleed movement speed while passing through them. Default: enabled. |
| Vegetation drag max (`GAIT_ss_vegetationDragMax`) | 0.18 | 0–0.75 | Maximum movement speed reduction in dense brush. 0.18 means up to 18% slower. Default: 0.18. |
| Vegetation drag radius (`GAIT_ss_vegetationDragRadius`) | 2.5 | 0.5–6 | Bush proximity radius in meters considered for drag. Default: 2.5 m. |
| Slow jog pace on slopes (`GAIT_ss_hillWalkSlowdownEnabled`) | true | on / off | Reduces jog pace on inclines and declines. Arma controls deliberate walk pace. |
| Hill jog slowdown starts (`GAIT_ss_hillWalkSlowdownStartDegrees`) | 15 | 0–45 | Slope angle where jog begins slowing. Default: 15 degrees. |
| Hill jog reference angle (`GAIT_ss_hillWalkSlowdownMaxDegrees`) | 40 | 5–80 | Slope angle where jog reaches the reference penalty. Pace continues decreasing on steeper terrain. Default: 40 degrees. |
| Uphill jog reference penalty (`GAIT_ss_hillWalkUphillMaxPenalty`) | 0.32 | 0–0.75 | Jog pace loss at the reference angle, adjusted for kit weight. Default: 0.32. |
| Downhill jog max penalty (`GAIT_ss_hillWalkDownhillMaxPenalty`) | 0.08 | 0–0.35 | Small jog pace loss while descending before momentum builds. Default: 0.08. |
| Increase uphill stamina drain (`GAIT_ss_uphillFatigueDrainEnabled`) | true | on / off | Increases fallback reserve drain and raises the ACE sprint drain ceiling on steeper climbs. |
| Uphill drain starts (`GAIT_ss_uphillFatigueDrainStartDegrees`) | 10 | 0–45 | Incline angle where additional uphill fatigue drain begins. Default: 10 degrees. |
| Uphill drain max angle (`GAIT_ss_uphillFatigueDrainMaxDegrees`) | 35 | 5–80 | Incline angle where additional uphill fatigue drain reaches full strength. Default: 35 degrees. |
| Uphill max drain multiplier (`GAIT_ss_uphillFatigueDrainMaxMultiplier`) | 1.75 | 1–4 | Maximum multiplier applied to sprint stamina drain on steep uphill terrain. 1.75 means 75% faster drain. Default: 1.75. |
| Enable downhill acceleration (`GAIT_ss_downhillBoostEnabled`) | true | on / off | Builds pace gradually during grounded descents. Sprinting and heavier gear can gain more. |
| Downhill bonus starts (`GAIT_ss_downhillBoostStartDegrees`) | 0.5 | 0–30 | Decline angle where the downhill speed bonus starts. |
| Downhill base boost angle (`GAIT_ss_downhillBoostMaxDegrees`) | 18 | 5–60 | Decline angle where the configured base bonus reaches full strength. Steeper grades continue adding gravity amplification. Default: 18 degrees. |
| Downhill entry speed boost (`GAIT_ss_downhillMaxBoost`) | 0.03 | 0–0.35 | Small pace gain on entering a descent before sustained momentum builds. |
| Sustained downhill bonus (`GAIT_ss_downhillSustainedExtraBoost`) | 0.10 | 0–0.25 | Additional pace earned during grounded downhill travel. |
| Downhill momentum build time (`GAIT_ss_downhillMomentumBuildSeconds`) | 4.5 | 0.5–8 | Time to earn 95% of the sprint momentum meter. Jog builds a smaller share at a slower rate. |
| Downhill sprint speed cap (`GAIT_ss_downhillSprintCapKmh`) | 30 | 20–45 km/h | Maximum downhill sprint target with a matching animation pace reference. |
| Downhill jog speed cap (`GAIT_ss_downhillJogCapKmh`) | 18 | 8–30 km/h | Maximum downhill jog target with a matching animation pace reference. |
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
| Compatibility mode (`GAIT_ss_compatibilityMode`) | 1 | 1: Movement only, 4: Disabled | Movement only enables GAIT traversal. Disabled releases movement control. |
| Show startup message (`GAIT_ss_showStartupMessage`) | true | on / off | Shows a short systemChat message after mission start with the active preset, compatibility mode, and ACE Advanced Fatigue bridge state. |
| Show server/settings indicator (`GAIT_ss_showServerIndicator`) | true | on / off | In multiplayer, shows a reminder that server or mission CBA settings may override local Addon Options. Useful for units with server-forced presets. |
| Enable RPT logging (`GAIT_ss_rptLogging`) | true | on / off | Writes useful GAIT initialization, preset, lifecycle, and Zeus reset messages to the RPT for troubleshooting. |
| Enable debug HUD (`GAIT_ss_debugHudEnabled`) | false | on / off | Shows grade, real speed, resolved direction, coefficient targets, animation family, reserve and ACE locks. Default: disabled. |
| Debug HUD refresh interval (`GAIT_ss_debugHudInterval`) | 0.1 | 0.05–1 | Seconds between debug HUD updates. Effective range: 0.05-1.00 seconds. Default: 0.10. |
### Weight

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Additional heavy-kit penalty (`GAIT_ss_extraHeavyPenaltyPer50Lb`) | 0.18 | 0.01–1 | Continuous load penalty beyond the heavy threshold: multiplier divided by 1 + value times extra pounds / 50. Default 0.18. Every additional pound continues to reduce walking and sprint pace. |
### Slope

| Control / variable | Default | Allowed values | Implemented behavior |
| --- | --- | --- | --- |
| Dedicated standing sprint animations (`GAIT_ss_slopeLocomotionEnabled`) | true | on / off | Uses scoped native sprint clips for forward/diagonal standing movement and run clips for lateral/reverse movement, with one blended entry/exit. No terrain angle cutoff. Disabling uses native animation selection and disables the calibrated release handoff. |
