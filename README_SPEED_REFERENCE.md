# GAIT 1.8.0-alpha24 movement speed reference

This document describes the current target model. Animation-speed coefficients are not interchangeable with km/h because weapon/pose families have different root motion. GAIT therefore distinguishes coefficient fallback behavior from calibrated physical targets.

## Flat sprint and load

Balanced uses an armed sustained sprint coefficient of **1.00**. A sprint started with full stamina on flat terrain earns a brief burst. Its default peak is **1.10×** sustained pace unloaded and **1.06×** with 110 lb. The bonus reaches zero within about 6 seconds or by half reserve, whichever comes first. GAIT reads carried inventory mass from `loadAbs` and applies these tuning points to jog pace.

| Approximate carried weight | Flat jog multiplier |
| --- | --- |
| 0 lb | 1.08 |
| 35 lb | 1.02 |
| 55 lb | 0.97 |
| 75 lb | 0.92 |
| Above 75 lb | `0.92 / (1 + 0.18 * extraLb / 50)` |

Mass between these points changes jog pace proportionally. Deliberate and forced walking yield to Arma's animation speed and terrain behavior. First-step brace relief, acceleration, endurance, and release timing also respond to load.

## Stamina and minimum sprint pace

The burst settles into normal sprint pace until the last **20% of stamina**. The target then eases toward **75% unloaded, 70% at 50 lb, and 65% at 100 lb or more** of normal sprint pace. GAIT limits deceleration across ACE updates.

Only moving sprints drain the reserve. Stationary rest restores it, and walking or jogging holds it steady. With a supported ACE loop, GAIT applies these rules to the anaerobic reserve before ACE draws the stamina bar. Flat drain has a ceiling of about **3 percentage points per second at 110 lb**. ACE's metabolic output determines actual drain within that ceiling. ACE retains aerobic fatigue and recovery, breathing, and medical feedback. The fallback reserve lasts about **33 seconds** of flat sprinting with the same load.

On a climb, sprint also targets at least 8% above the faster of the same-grade, same-load walk and jog. Matching animation references make this a physical pace comparison. Without them, GAIT uses conservative walk-to-sprint and jog-to-sprint clip ratios.

## Sprint acceleration

General speed smoothing defaults to `GAIT_ss_speedLerp = 0.05`. Outside the rested burst, flat sprint acceleration uses 70% of that rate before the carried-load adjustment. A rested burst accelerates faster while the bonus is active.

At default tuning this is approximately:

- generic 95% convergence: ~2.9 s
- sprint build to 95% target: ~4.1 s

Sprint launch bracing ends 8% sooner. The ordinary first step is 20 ms shorter with a slightly shallower dip. Shift release defaults to a 1.15-second window before load scaling. The optional uphill release brake defaults off.

## Uphill

Uphill sprint pace starts dropping at the configured onset, 2° by default. At 35° the configured reference penalty applies to all kits. The curve continues beyond 35°.

Entering a climb applies the penalty with its own faster ramp. A zero-momentum uphill sprint start uses the uphill brace. Pressing Shift while jogging uphill requests the Meva sprint animation, including when W stays held. Medical and explicit movement locks take priority.

## Ordinary movement on slopes

Standing W-only slope movement keeps an active native jog. GAIT requests its **Mrun** jog when terrain has dropped the player to walking. The native walk toggle selects walking. Downhill jogging receives 35% of the sprint bonus at the same momentum and builds toward 45% of maximum descent momentum at a slower rate.

Without a complete physical walk/jog profile, the fallback jog target uses a minimum coefficient of 1.06 times the ordinary slope target. Actual speed depends on the clip.

## Downhill acceleration

The directional downhill bonus begins at 0.5° by default. The entry boost is small, and the sustained boost grows over several seconds of descending travel. Sprint momentum takes about 4.5 seconds to reach 95% of its meter. Steeper slopes do not shorten that timer.

The fallback sprint target is capped at 115% of normal flat sprint pace. Jogging uses a smaller load-dependent bonus. Heavy kits can build more downhill momentum.

With a matching animation pace reference, the default downhill targets also have physical ceilings of **30 km/h sprinting** and **18 km/h jogging**. A manual `GAIT_locomotionPaceProfiles` entry or passive session calibration can supply the reference. Passive references match clip, configuration, character, weapon, surface and grade within ±2°. The cap applies to the settled target. Entry and exit use the movement ramp and native blend.

## Release continuity

Shift release immediately requests the jog selected by live input. A bounded speed taper can continue through the blend and native jog while W remains held, using clip reference speeds to compensate for the change in root motion. Stop, strafe, stance changes and deliberate walk can interrupt the taper immediately.

## Weapon/pose families

The generated graph has five first-class standing pose families:

- raised rifle: `SrasWrfl`
- lowered rifle: `SlowWrfl`
- raised pistol: `SrasWpst`
- lowered pistol: `SlowWpst`
- unarmed: `SnonWnon`

Raised/lowered pistol identity is preserved through GAIT locomotion; the controller does not introduce a `SlowWpst <-> SrasWpst` conversion during acceleration.
