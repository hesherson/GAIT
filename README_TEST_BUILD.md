# GAIT 1.8.0-alpha5: original gear feel and short forward slowdown

Complete HEMTT source based on alpha4. Requires Arma 3 2.18+, CBA_A3 and ACE3. Deployment commands are in README_HEMTT.md. Load only the new GAIT copy and start a fresh mission.

## Correction to alpha4

Alpha4 added a longer speed hold, slower gear-dependent braking and a residual animation coast lasting beyond its target curve. It also deepened lighter-tier brace relief and increased launch duration. Those changes exceeded the requested refinement and have been removed.

* Original tier brace relief is restored exactly: Light 0.55 through 35 lb, Medium 0.35 through 55 lb, Moderate 0.18 through 75 lb, Heavy 0 above 75 lb, with existing custom settings honored.
* Original base launch duration, brace speed, snap and slope addition are restored. Heavier gear already produces a deeper initial dip through its original relief setting.
* Acceleration has only a modest load factor, ranging from the original rate to 90% of that rate at the heaviest endpoint. It changes time to build sprint, never permission to sprint.
* Original steady sprint/load targets, presets and downhill build timing remain. No new gear-based walk lock is applied.

## Forward movement and release

Releasing sprint while W remains held starts one finite smooth curve immediately. It has no speed-hold period, secondary exponential filter or residual six-second tail.

| Load, default thresholds | Forward release duration |
| --- | --- |
| 0 lb | 0.383 seconds |
| 35 lb | 0.404 seconds |
| 55 lb | 0.425 seconds |
| 75 lb | 0.446 seconds |
| 100 lb | 0.468 seconds |
| 125+ lb | 0.489 seconds |

These are coefficient-curve durations, not measured stopping distances. The existing taper setting scales the duration, bounded to 0.20-0.65 seconds. The old sustain setting remains visible as inactive for existing saved profiles; it cannot add a hold period.

W+A/D is still forward movement: directions remain immediate while the short curve runs. Releasing W, choosing pure strafe/back movement, or stopping cancels stored forward coast and downhill speed buildup. A render-time input serial catches even a release/repress between scheduled feature updates. No synthetic input, position or velocity forces the player forward.

Actual movement history is retained only to avoid another launch brace while the body is still moving; it cannot restore cancelled speed. A real stop still rearms the original step-off. Re-pressing sprint during a valid forward coast accelerates from the remaining coefficient.

## Animation and uphill braking

Walking clips are used only for the short brace stages. A raw key release consumes the current brace token so old scheduled state cannot re-enter that walking stage. A sprint re-tap cancels an active uphill-brake stage immediately.

If the one-shot transition from brace to sprint is not observed, GAIT exits through its normal movement cleanup and prevents repeated entry attempts until sprint is released. This avoids an indefinitely owned walking-brace state. The 72-state graph is retained.

The alpha3 uphill brake still acts when sprint is released while W remains held. Its 15-35 degree scaling and strength are unchanged. Stop/pure-strafe input takes precedence over the forward brake animation and coefficient. Uphill braking also shortens the forward coast and cannot restore the pre-brake sprint coefficient.

Existing ACE restrictions from injury or other systems, fatigue reserve, carrying, dragging, sway, sound, hearing, vegetation, landing and trip features retain their existing ownership. See tests/FEATURE_PRESERVATION.md for the exact source-preservation scope.

## Focused in-game check

1. Compare light, medium and heavy kits from walk/jog into sprint. Check the original brief brace, then continued acceleration into the sprint animation.
2. At full sprint, release Shift but hold W. Pace should begin falling promptly and finish its smooth coefficient transition in roughly half a second. Re-tap Shift midway; no second launch brace should occur.
3. Repeat with W+A/D. Then release W completely, choose pure A/D or S, and release every movement key. No forward coast should keep those inputs waiting.
4. Release/repress W quickly during a launch brace and during sprint coast. No stale walking brace or old sprint boost should return.
5. Repeat on the working downhill slope and uphill beyond 32 degrees. Uphill Shift release should still dig in while W remains held. Also check reload, weapon change, crouch and prone.

For a remaining problem, copy tests/foundation_capture.sqf into the saved Eden mission and use Local Exec:

```sqf
[90, "alpha5 responsive forward coast"] execVM "foundation_capture.sqf";
```

Send the RPT after STOP, with the exact key sequence and approximate gear weight.

## Validation limits

HEMTT and SQF-VM check compilation, bounded response, original brace tuning, input policy, cleanup and regression cases. They cannot simulate Arma root motion, camera blending, collision or multiplayer. The final switch between custom and native clips, actual physical stopping and sprint feel remain in-game acceptance checks. No physical speed calibration profiles are invented.
