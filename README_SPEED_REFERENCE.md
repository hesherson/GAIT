# GAIT 1.8.0-alpha19 movement speed reference

This document describes the current target model. Animation-speed coefficients are not interchangeable with km/h because weapon/pose families have different root motion. GAIT therefore distinguishes coefficient fallback behavior from calibrated physical targets.

## Flat sprint and load

Balanced defaults use an armed fresh sprint coefficient of **1.28** before slope and load scaling. The continuous load multiplier interpolates through the existing gear landmarks:

- 0 lb: 1.08
- 35 lb: 1.05
- 55 lb: 1.025
- 75 lb: 1.00
- above 75 lb: continues decreasing as `1 / (1 + 0.18 * extraLb / 50)`

The walk/sprint floor is evaluated after grade and load effects so a steady sprint target remains above the corresponding ordinary movement target.

## Sprint acceleration

General speed smoothing still defaults to `GAIT_ss_speedLerp = 0.05`. **Upward sprint acceleration alone** uses 70% of that rate before the small gear-inertia adjustment.

At default tuning this is approximately:

- generic 95% convergence: ~2.9 s
- sprint build to 95% target: ~4.1 s

Brace, uphill braking, Shift-release taper and ordinary movement keep their own existing timing.

## Uphill

Uphill steady sprint pace begins reducing at the configured onset (default 5°) and reaches the configured reference penalty at 35°. The curve continues beyond 35° rather than imposing a walking cutoff.

The penalty is also exposed progressively through time: shallow inclines build slowly, while steep inclines converge much faster. A zero-momentum uphill sprint start adds the separate exponential brace burden. Retained sprint momentum bypasses that launch burden.

## Ordinary movement on slopes

Standing W-only slope movement uses a custom **Mrun jog** family rather than a custom Mwlk state. There are no custom Mwlk states in the generated graph.

Without a complete physical walk/jog profile, the fallback target is coefficient-space: the jog target uses a 1.06 minimum ratio over the ordinary slope target. That is intentionally only a small coefficient margin; it is not an unsupported claim that every animation family is physically exactly 6% faster in km/h.

## Downhill acceleration

Downhill momentum is earned only by actual descending sprint travel. Flat sprinting does not preload it.

The coefficient-space downhill bonus starts at the configured decline onset (default 4°), reaches the configured base angle response around 18°, and continues increasing on steeper grades rather than tapering. Steep grades transition toward lighter gravity-specific load attenuation, can amplify the configured base+sustained component up to 3x, and cap the final additive coefficient bonus at 65%.

A separate calibrated physical target begins beyond an 8° decline and reaches full grade severity at 35°. At full downhill momentum it approaches **34 km/h** below the heavy-weight band and **32 km/h** at 150 lb and above, with continuous interpolation between those load points.

The physical target is only converted into an animation coefficient when GAIT has a safe reference for the exact current sprint clip/context. A complete manual `GAIT_locomotionPaceProfiles` entry can provide that reference, but alpha19 also reuses automatic passive session calibration. Passive references are scoped to clip/config, character, weapon, surface and ±2° grade, expire after ten minutes, and are collected only during stable, unobstructed, grounded movement without brace/release/vegetation contamination.

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
