# GAIT 1.8.0-alpha26 movement speed reference

This document describes the current target model. Animation-speed coefficients are not interchangeable with km/h because weapon/pose families have different root motion. GAIT therefore distinguishes coefficient fallback behavior from calibrated physical targets.

## Flat sprint and load

Balanced uses an armed sustained sprint coefficient of **1.00**. A sprint started with full stamina on flat terrain earns a brief burst. Its default peak is **1.14×** sustained pace unloaded and about **1.08×** with 110 lb. The bonus reaches zero after 4.1 seconds or by half reserve, whichever comes first. GAIT reads carried inventory mass from `loadAbs` and applies these tuning points to jog pace.

| Approximate carried weight | Flat jog multiplier |
| --- | --- |
| 0 lb | 1.08 |
| 35 lb | 1.02 |
| 55 lb | 0.97 |
| 75 lb | 0.92 |
| Above 75 lb | `0.92 / (1 + 0.18 * extraLb / 50)` |

Mass between these points changes jog pace proportionally. Ordinary forward jog uses a 0.90 base coefficient and targets at least 4% above the faster of native walk and combat jog. GAIT uses matching passive clip references when available and estimated clip ratios otherwise. Arma handles deliberate and forced walking. First-step brace relief, acceleration, endurance, and release timing also respond to load.

## Stamina and minimum sprint pace

The burst settles into normal sprint pace until **50% reserve**. The target then eases toward **75% unloaded, 70% at 50 lb, and 65% at 100 lb or more** of normal sprint pace. The taper starts gently and GAIT smooths pace across ACE updates.

Only moving sprints drain the reserve. Stationary rest restores it, and walking or jogging holds it steady. With a supported ACE loop, GAIT applies these rules to the anaerobic reserve before ACE draws the stamina bar. Sprint reserve cost rises gradually through 70 lb and increases more sharply above 120 lb.

| Carried weight | GAIT flat-ground drain multiplier at default settings |
| --- | --- |
| 0 lb | 1.00× |
| 70 lb | 1.04× |
| 110 lb | 1.15× |
| 120 lb | 1.19× |
| 150 lb | 1.50× |

On a climb, the additional GAIT grade cost ranges from 1.00× at 10° to 1.75× at 35°. With ACE active, the table and grade multiplier apply to the native work sample after GAIT softens its cargo contribution to the anaerobic bar. Performance Factor, Load Factor, Terrain Gradient Factor, Recovery Factor, animation and medical duty are part of the ACE calculation. ACE's native downhill work uses a smaller grade term than uphill work. The separate GAIT reserve gives moderate descents up to 15% relief, which fades on steep descents. Actual ACE bar drain depends on the player and conditions.

On a climb, sprint also targets at least 8% above the faster of the same-grade, same-load walk and jog. Matching animation references make this a physical pace comparison. Without them, GAIT uses conservative walk-to-sprint and jog-to-sprint clip ratios.

## Sprint acceleration

General speed smoothing defaults to `GAIT_ss_speedLerp = 0.05`. Outside the rested burst, flat sprint acceleration uses 70% of that rate before the carried-load adjustment. A rested burst accelerates faster while the bonus is active.

At default tuning this is approximately:

- generic 95% convergence: ~2.9 s
- sprint build to 95% target: ~4.1 s

Sprint launch bracing ends 8% sooner. The ordinary first step is 20 ms shorter with a slightly shallower dip. Jog deceleration defaults to 1.15 seconds to cover 95% of the coefficient change.

## Uphill

Uphill sprint pace starts dropping at the configured onset, 2° by default. At 35° the configured reference penalty applies to all kits. The curve continues beyond 35°.

Entering a climb applies the penalty with its own faster ramp. A zero-momentum uphill sprint start uses the uphill brace. Pressing Shift while jogging uphill requests the Meva sprint animation, including when W stays held. Medical and explicit movement locks take priority.

## Ordinary movement on slopes

Standing W-only slope movement keeps an active native jog. GAIT requests its **Mrun** jog when terrain has dropped the player to walking. The native walk toggle selects walking. Downhill jogging receives 35% of the sprint bonus at the same momentum and builds toward 45% of maximum descent momentum at a slower rate.

Without a complete physical walk/jog profile, the fallback slope jog starts from 1.06 times the ordinary slope target before applying the walk and combat-jog margin. Actual speed depends on the clip.

## Downhill acceleration

The directional downhill bonus begins at 0.5° by default. The entry boost is small, and the sustained boost grows over several seconds of descending travel. Sustained sprinting takes about 6.5 seconds to reach 95% of the grade target. Gradual buildup follows the grade along the direction of travel. Shallow grades earn less momentum and leveling out lets it decay.

The fallback sprint target is capped at 118% of normal flat sprint pace. Jogging uses a smaller load-dependent bonus. Heavy kits can build more downhill momentum.

With a matching animation pace reference, the default downhill targets also have physical ceilings of **30 km/h sprinting** and **18 km/h jogging**. A manual `GAIT_locomotionPaceProfiles` entry or passive session calibration can supply the reference. Passive references match clip, configuration, character, weapon, surface and grade within ±2°. The cap applies to the settled target. Entry and exit use the movement ramp and native blend.

## Release continuity

On Shift release, Arma handles walking, jogging and direction through its native action map. If the forward release is still queued, the first new direction input redirects that transition to its matching native bridge. The same speed coefficient eases toward the current jog target during forward, diagonal, lateral and backward movement. Stopping or selecting walk yields the coefficient immediately. A change of animation can naturally change ground speed as its stride changes.

## Weapon/pose families

The generated graph has five first-class standing pose families:

- raised rifle: `SrasWrfl`
- lowered rifle: `SlowWrfl`
- raised pistol: `SrasWpst`
- lowered pistol: `SlowWpst`
- unarmed: `SnonWnon`

Raised/lowered pistol identity is preserved through GAIT locomotion; the controller does not introduce a `SlowWpst <-> SrasWpst` conversion during acceleration.
