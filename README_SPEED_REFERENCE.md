# GAIT 1.8.0-alpha74 movement speed reference

## Double-tap dead sprint

The double tap uses the fresh flat sprint for the current kit and stance as its baseline. Its target bonus rises smoothly to 9% over 1.4 seconds, holds through 2.8 seconds, and eases to 3.5% by 4.2 seconds. Actual acceleration follows the target over several steps and takes longer with weight. Running uphill increases the stamina cost. Earned downhill momentum can briefly raise the normal 30 km/h limit to 30.8 km/h. Speed and effort blend back to ordinary sprint levels across the final 20% of reserve.


Animation-speed coefficients scale the active clip. Physical targets use measured reference speeds because weapon poses use different strides.

## Flat sprint and load

The base armed sustained sprint coefficient is **1.00**. A sprint started with full stamina on flat terrain earns a brief burst. It peaks at **1.05×** sustained pace unloaded and about **1.03×** with 110 lb. The bonus reaches zero after 4.1 seconds or by half reserve, whichever comes first. GAIT reads carried inventory mass from `loadAbs` and applies these tuning points to jog pace.

| Approximate carried weight | Flat jog multiplier |
| --- | --- |
| 0 lb | 1.03 |
| 35 lb | 1.00 |
| 55 lb | 0.97 |
| 75 lb | 0.92 |
| Above 75 lb | `0.92 / (1 + 0.18 * extraLb / 50)` |

Mass between these points changes jog pace proportionally. Ordinary forward jog uses a 0.90 base coefficient and targets at least 4% above the faster of native walk and combat jog. GAIT uses matching passive clip references when available and estimated clip ratios otherwise. Deliberate walking and sprint-to-walk use the same load curve, normalized to native unloaded walking pace and capped at 150 lb. Forced walking remains under Arma or ACE control. First-step brace relief, acceleration, and endurance also respond to load.

GAIT keeps weapon-lowered walking and combat pace at or above 0.89× the original clip speed after its movement modifiers.

A light kit also gets a small pace bonus when walking, combat pacing, jogging, sprinting, or moving in a low stance. The bonus scales from zero at 150 lb to 1% unloaded at the start of movement. It eases toward 1.8% unloaded after eight seconds of continuous travel, or up to 2% on a sustained climb. Stopping sheds the sustained portion over two seconds.

## Stamina and minimum sprint pace

The burst settles into normal sprint pace until **50% reserve**. The target then eases toward its empty-reserve pace. The base fraction ranges from **75% unloaded to 65% at 100 lb or more**. The target also stays **5–8% above matching combat pace**, including at zero reserve. That floor uses measured clip speeds when available, estimates the ratio until then, within the sprint speed ceiling.

Holding forward sprint in an eligible grounded state spends reserve according to sprint duration, kit weight and grade. Pace can slow while exertion continues to empty the bar. Reserve drains more quickly later in the effort. Stationary rest restores it, and upright walking or jogging holds it steady. Sprint reserve cost rises gradually through 70 lb and increases more sharply above 120 lb.

| Carried weight | GAIT flat-ground drain multiplier at default settings |
| --- | --- |
| 0 lb | 1.00× |
| 70 lb | 1.04× |
| 110 lb | 1.15× |
| 120 lb | 1.19× |
| 150 lb | 1.50× |

On a climb, grade multiplies the load cost. The default grade multiplier rises from **1.00× at 4°** to **2.10× at 35°**, with the cost increasing faster as the grade steepens. Downhill gravity assistance reduces effort by up to 20% between 13° and 18° of descent. Braking progressively removes that relief from 18° to 45°.

| Route at default settings | Approximate full-to-empty sprint with 110 lb |
| --- | --- |
| Flat | 52 s |
| 5° climb | 52 s |
| 25° climb | 32 s |
| 35° climb | 25 s |
| 13–18° descent | 65 s |

Unloaded flat sprint takes roughly 60 seconds. These are gameplay model timings for sustained effort.

A supported ACE fatigue loop shows this exertion on its stamina bar. ACE Performance Factor scales capacity, Load Factor and Terrain Gradient Factor scale the respective costs, and Recovery Factor controls native recovery at rest. ACE still calculates aerobic fatigue, acidosis, muscle damage, medical duty and feedback through its own physiology. An unsupported ACE loop leaves its own bar behavior in place and GAIT uses its internal reserve for pace.

On a climb, sprint also targets at least 8% above the faster of the same-grade, same-load walk and jog. Matching animation references make this a physical pace comparison. Without them, GAIT uses conservative walk-to-sprint and jog-to-sprint clip ratios.

## Sprint acceleration

General speed smoothing defaults to `GAIT_ss_speedLerp = 0.05`. Outside the rested burst, flat sprint acceleration uses 70% of that rate before the carried-load adjustment. A rested burst accelerates faster while the bonus is active.

At default tuning this is approximately:

- generic 95% convergence: ~2.9 s
- sprint build to 95% target: ~4.1 s

Sprint launch bracing ends 8% sooner. The ordinary first step is 20 ms shorter with a slightly shallower dip. Ordinary jog deceleration defaults to 1.50 seconds to cover 95% of the coefficient change. After movement halts, the first 0.15 seconds retain sprint momentum. Over the next 0.60 seconds the next launch brace gradually regains its full depth and duration.

## Uphill

Uphill sprint pace starts dropping at 2°. At 35° the reference penalty applies to all kits. The curve continues beyond 35°.

Entering a climb applies the penalty with its own faster ramp. A zero-momentum uphill sprint start uses the uphill brace. Pressing Shift while jogging uphill requests the Meva sprint animation, including when W stays held. Medical and explicit movement locks take priority.

## Ordinary movement on slopes

Standing W-only slope movement keeps an active native jog. GAIT requests its **Mrun** jog when terrain has dropped the player to walking. The native walk toggle selects walking. Downhill jogging receives 35% of the sprint bonus at the same momentum and builds toward 45% of maximum descent momentum at a slower rate.

Without a complete physical walk/jog profile, the fallback slope jog starts from 1.06 times the ordinary slope target before applying the walk and combat-jog margin. Actual speed depends on the clip.

## Downhill acceleration

With default settings, walking gains about 4% at a 5° descent and reaches a 10% bonus at 18°. This applies to deliberate walking and the walk pace after sprint release.

Unloaded runners begin gaining speed at a 0.5° descent. Additional downhill pull starts at about 0.15° and grows with carried load. The entry boost is small, and the sustained boost grows over several seconds. Sustained sprinting takes about 6.5 seconds to reach 95% of the grade target. Shallow grades earn less momentum and leveling out lets it decay.

The fallback sprint target is capped at 118% of the kit's normal flat sprint pace. The descent multiplier applies to the fatigue-adjusted sprint target, including at zero reserve. Jogging uses a smaller downhill bonus. Lighter kits retain a higher target at the same reserve and grade.

With a matching animation pace reference, the default downhill targets also have physical ceilings of **30 km/h sprinting** and **18 km/h jogging**. A manual `GAIT_locomotionPaceProfiles` entry or passive session calibration can supply the reference. Passive references match clip, configuration, character, weapon, surface and grade within ±2°. The cap applies to the settled target. Entry and exit use the movement ramp and native blend.

Sprint targets also have a 6 m/s level-ground ceiling before the small light-kit bonus. Matching clip references convert this to the active animation's playback rate. Unmeasured clips retain a bounded coefficient. Each sprint press drops any playback rate carried over from a slower gait.

## ACE casualty movement

A shoulder carry or backward drag follows the grade in the actual travel direction. Downhill assistance reaches up to 7.5% for a walking carry, 10% for a running carry, or 4.5% for a drag. Uphill travel slows both. These multipliers apply to the medic's native movement clips while the patient is attached. During a shoulder carry, GAIT handles ACE Advanced Fatigue's slope restriction through the same bridge as ordinary movement. ACE handles pickup, drop, drag speed limits and medical restrictions.

## Release continuity

Shift release restores the recorded weapon posture and the selected walking, jogging, or combat pace in the current direction. The default taper lasts 3 seconds on level ground, up to about 4.65 seconds at a 24° descent, and as little as 1.2 seconds at a 32° climb. The grade is sampled along the direction of travel at release. Releasing the last movement key blends the outgoing stride into native idle, where fresh movement input can act immediately.

Walking and tactical clips begin when the remaining travel speed fits within 115% of their native cadence. Release playback is capped at 1.20? for jogging and 1.15? for walking or tactical movement.

## Stance effort

Stance changes, moving while crouched, and crawling spend more stamina with heavier kit. GAIT scales native stance adjustments and transitions, with the largest effect when getting into or out of prone. At 120 lb, the prone transition plays at about 0.86× speed with full reserve and 0.72× when empty. The minimum is 0.65× at 150 lb and empty reserve.

## Downhill trips

Downhill grade, actual speed, and kit weight set the base risk during eligible travel. Low reserve raises the chance by up to 1.65×. Continuing to run on empty raises it by another factor that reaches 1.35× after 12 seconds.

## Weapon/pose families

The generated graph has five first-class standing pose families:

- raised rifle: `SrasWrfl`
- lowered rifle: `SlowWrfl`
- raised pistol: `SrasWpst`
- lowered pistol: `SlowWpst`
- unarmed: `SnonWnon`

GAIT preserves raised or lowered pistol posture during acceleration. The native Optics action can raise the weapon and enter the sights while walking.
