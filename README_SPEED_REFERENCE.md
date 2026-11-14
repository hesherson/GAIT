# GAIT 1.8.0-alpha27 movement speed reference

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

The burst settles into normal sprint pace until **50% reserve**. The target then eases toward its empty-reserve pace. The default base fraction ranges from **75% unloaded to 65% at 100 lb or more**. The target also stays **5–8% above matching combat pace**, including at zero reserve. That floor uses measured clip speeds when available, estimates the ratio until then, and takes priority if a custom downhill cap would place sprint below combat pace.

Holding forward sprint in an eligible grounded state spends reserve according to sprint duration, kit weight and grade. Pace can slow while exertion continues to empty the bar. Reserve drains more quickly later in the effort. Stationary rest restores it, and walking or jogging holds it steady. Sprint reserve cost rises gradually through 70 lb and increases more sharply above 120 lb.

| Carried weight | GAIT flat-ground drain multiplier at default settings |
| --- | --- |
| 0 lb | 1.00× |
| 70 lb | 1.04× |
| 110 lb | 1.15× |
| 120 lb | 1.19× |
| 150 lb | 1.50× |

On a climb, grade multiplies the load cost. The default grade multiplier rises from **1.00× at 4°** to **2.10× at 35°**. Moderate descents give up to 15% relief, which fades on steep descents. With default settings, a fully rested sprint takes about 40 seconds to empty unloaded on level ground and about 35 seconds with 110 lb. During a steady 25° climb with 110 lb, the model takes about 20 seconds.

A supported ACE fatigue loop shows this exertion on its stamina bar. ACE Performance Factor scales capacity, Load Factor and Terrain Gradient Factor scale the respective costs, and Recovery Factor controls native recovery at rest. ACE still calculates aerobic fatigue, acidosis, muscle damage, medical duty and feedback through its own physiology. An unsupported ACE loop leaves its own bar behavior in place and GAIT uses its internal reserve for pace.

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

On Shift release during a standing sprint, GAIT hands off once to the native walk or jog in the current direction at the current stride phase. Arma handles subsequent movement and strafing. The speed coefficient eases toward the current jog target across directions. Stopping or selecting walk yields the coefficient immediately.

## Weapon/pose families

The generated graph has five first-class standing pose families:

- raised rifle: `SrasWrfl`
- lowered rifle: `SlowWrfl`
- raised pistol: `SrasWpst`
- lowered pistol: `SlowWpst`
- unarmed: `SnonWnon`

Raised/lowered pistol identity is preserved through GAIT locomotion; the controller does not introduce a `SlowWpst <-> SrasWpst` conversion during acceleration.
