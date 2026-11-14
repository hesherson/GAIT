# GAIT 1.8.0-alpha21 movement speed reference

This document describes the current target model. Animation-speed coefficients are not interchangeable with km/h because weapon/pose families have different root motion. GAIT therefore distinguishes coefficient fallback behavior from calibrated physical targets.

## Flat sprint and load

Balanced uses an armed fresh sprint coefficient of **1.28** before slope and load scaling. GAIT reads live carried inventory mass from `loadAbs` and uses these tuning points.

| Approximate carried weight | Flat pace multiplier |
| --- | --- |
| 0 lb | 1.08 |
| 35 lb | 1.02 |
| 55 lb | 0.97 |
| 75 lb | 0.92 |
| Above 75 lb | `0.92 / (1 + 0.18 * extraLb / 50)` |

Mass between these points changes speed proportionally. First-step brace relief, acceleration, and release timing also respond continuously to load.

## Stamina and minimum sprint pace

Below 45% remaining sprint reserve, GAIT smoothly tapers toward **85% of the current loadout’s normal, unboosted run pace**. Every loadout uses the same ratio, so heavier kits still have a lower settled pace. ACE supplies endurance when its reserve model is active. With the GAIT fallback, heavier kits consume reserve faster.

On a climb, sprint also targets at least 8% above the faster of the same-grade, same-load walk and jog. Matching animation references make this a physical pace comparison. Without them, GAIT uses conservative walk-to-sprint and jog-to-sprint clip ratios.

## Sprint acceleration

General speed smoothing defaults to `GAIT_ss_speedLerp = 0.05`. On flat ground sprint acceleration uses 70% of that rate before the carried-load adjustment.

At default tuning this is approximately:

- generic 95% convergence: ~2.9 s
- sprint build to 95% target: ~4.1 s

Sprint launch bracing ends 8% sooner. The ordinary first step is 20 ms shorter with a slightly shallower dip. Uphill release braking and the Shift-release taper keep their existing timing.

## Uphill

Uphill sprint pace starts dropping at the configured onset, 2° by default. At 35° the configured reference penalty applies to a 75 lb kit. Lighter kits get a smaller penalty and heavier kits get a larger one. The curve continues beyond 35°.

Entering a climb applies the penalty with its own faster ramp. A zero-momentum uphill sprint start uses the uphill brace. Pressing Shift while jogging uphill requests the Meva sprint animation, including when W stays held. Medical and explicit movement locks take priority.

## Ordinary movement on slopes

Standing W-only slope movement uses the custom **Mrun jog** family. The native walk toggle selects walking. Downhill jogging receives 35% of the sprint bonus at the same momentum and builds toward 45% of maximum descent momentum at a slower rate.

Without a complete physical walk/jog profile, the fallback jog target uses a minimum coefficient of 1.06 times the ordinary slope target. Actual speed depends on the clip.

## Downhill acceleration

The directional downhill bonus begins at 0.5° by default. The entry boost is small, and the sustained boost grows over several seconds of descending travel. Sprint momentum takes about 4.5 seconds to reach 95% of its meter. Steeper slopes do not shorten that timer.

The fallback sprint target is bounded by 115% of unloaded flat pace and 142% of the same kit’s flat pace. The smaller jog bonus uses the same bounded model. Heavy kits can gain more speed relative to their own flat pace.

With a matching animation pace reference, the default downhill targets also have physical ceilings of **30 km/h sprinting** and **18 km/h jogging**. A manual `GAIT_locomotionPaceProfiles` entry or passive session calibration can supply the reference. Passive references match clip, configuration, character, weapon, surface and grade within ±2°. The cap applies to the settled target. Entry and exit use the movement ramp and native blend.

## Release continuity

Shift release captures the current applied coefficient and observed horizontal velocity, then follows one finite W-held taper toward ordinary movement. When a safe destination jog reference exists, the handoff compensates for changing source/destination root-motion weights. A/D direction changes remain independent of that speed taper.

## Weapon/pose families

The generated graph has five first-class standing pose families:

- raised rifle: `SrasWrfl`
- lowered rifle: `SlowWrfl`
- raised pistol: `SrasWpst`
- lowered pistol: `SlowWpst`
- unarmed: `SnonWnon`

Raised/lowered pistol identity is preserved through GAIT locomotion; the controller does not introduce a `SlowWpst <-> SrasWpst` conversion during acceleration.
