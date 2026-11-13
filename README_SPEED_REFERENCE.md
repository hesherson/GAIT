# GAIT 1.8.0-alpha20 movement speed reference

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

Below 45% remaining sprint reserve, the sprint target tapers toward a pace just above walking with the same load and grade. At empty reserve the Balanced target ranges from 1.06 times walking pace at 100 lb and above to 1.12 times walking pace unloaded. The taper also reduces the downhill gain as reserve runs out.

Matching walk and sprint clip references let GAIT calculate the target in m/s. When those references are unavailable, it estimates walking root motion at 28% of sprint root motion. Actual fallback speed depends on the active animation.

## Sprint acceleration

General speed smoothing defaults to `GAIT_ss_speedLerp = 0.05`. On flat ground sprint acceleration uses 70% of that rate before the carried-load adjustment.

At default tuning this is approximately:

- generic 95% convergence: ~2.9 s
- sprint build to 95% target: ~4.1 s

Brace, uphill braking, Shift-release taper and ordinary movement keep their own existing timing.

## Uphill

Uphill sprint pace starts dropping at the configured onset, 2° by default. At 35° the configured reference penalty applies to a 75 lb kit. Lighter kits get a smaller penalty and heavier kits get a larger one. The curve continues beyond 35°.

Entering a climb applies the penalty with its own faster ramp. A zero-momentum uphill sprint start also uses the uphill brace.

## Ordinary movement on slopes

Standing W-only slope movement uses the custom **Mrun jog** family. Downhill jogging receives 35% of the sprint bonus at the same momentum and builds toward 45% of maximum descent momentum at a slower rate.

Without a complete physical walk/jog profile, the fallback jog target uses a minimum coefficient of 1.06 times the ordinary slope target. Actual speed depends on the clip.

## Downhill acceleration

The directional downhill bonus begins at 0.5° by default. The base boost takes effect on entry, then sustained descending sprint travel builds a second boost. Mild grades give an early pull and a gradual buildup. Steeper grades build the bonus faster, and heavier kits gain more as they descend.

The configured base angle response reaches full strength at 18°. Steeper descents increase the boost further. The fallback target caps at 150% to 165% of unloaded flat sprint pace depending on carried mass. Continued downhill travel can make a heavily loaded sprint overtake a light kit on a long enough descent.

A separate calibrated physical target grows with downhill momentum beyond an 8° decline and reaches full grade severity at 35°. At full momentum and grade severity, the minimum calibrated target is 34 km/h unloaded and about 37.6 km/h with a 150 lb load.

GAIT converts the physical target into an animation coefficient using a matching sprint clip reference. A complete manual `GAIT_locomotionPaceProfiles` entry or automatic session calibration can supply it. GAIT collects passive references during stable, unobstructed, grounded movement and matches them by clip, configuration, character, weapon, surface and grade within ±2°. References expire after ten minutes.

Until a valid physical reference exists, the coefficient-space downhill model remains active. Current live velocity is never divided back into the target, so collision or wall contact cannot create a feedback accelerator.

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
