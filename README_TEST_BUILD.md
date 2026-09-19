# GAIT 1.8.0-alpha10: pistol startup and release momentum

Requires Arma 3 2.18+, CBA_A3 and ACE3. Build/deploy commands are in README_HEMTT.md. Load only the new GAIT copy and start a fresh mission.

## Corrected issues

### Pistol startup interruption

Alpha9 omitted lowered-pistol movement sources from the sprint graph and its strict blend validator. A legitimate lowered-pistol entry could therefore appear ineligible for one part of the blend. That dropped movement ownership and sprint bookkeeping, allowing a second start/brace when the run resumed.

The graph now connects the ordinary lowered-pistol sources to the existing pistol sprint family, and the validator accepts their exact movement blends. Brace timing and depth are unchanged. Weapon changes, stance transitions, reloads, medical animations and unsupported launcher poses retain their separate handling.

### Sprint release from current motion

Alpha9 recorded velocity but still tapered only an animation coefficient while immediately switching from the sprint clip to the slower native clip. The coefficient did not represent the same physical speed across that switch.

The new release controller captures current horizontal velocity and the currently applied movement coefficient before the handoff. It retains the current GAIT running clip for one short deceleration, samples the finite curve every rendered frame through the existing movement writer, then makes a single normal graph blend into native movement. The actual speed to shed determines the duration, with an 80 ms minimum and the existing gear-scaled window as its ceiling.

Repressing Shift during this interval resumes from the remaining pace without restarting the animation. Releasing W, changing direction, weapon or movement context cancels the release plan promptly. Uphill dig-in braking keeps priority. Releasing during a low-speed brace does not create a slow-speed hold.

The captured speed conversion is local to the current clip and terrain. It is not a calibrated speed for the destination jog/walk animation. There is no forced velocity or continuous feedback that accelerates against obstacles.

## Retained changes

- Shorter stop blends from alpha9, including immediate stop/direction redirection during an unfinished jog handoff.
- A brief launch brace for every gear tier, with the existing slight acceleration differences and heavy backpack sprint access.
- Modest heavy downhill improvement: about 2% more peak target speed at 100 displayed lb and 3.3% at 150 lb. Loads through 55 lb remain unchanged.
- Downhill trip risk follows actual horizontal velocity, including deceleration, with sustained-travel qualification, cooldown and immunity retained.
- ACE heartbeat gain remains 20% of the original for all seven variants. Samples, rhythm, pitch and other audio remain unchanged.
- GAIT does not control weapon sway or write native fatigue/recoil coefficients.
- Fatigue vignette remains intermittent: a 1.3-second pulse, at most 14% edge opacity, then 5-12 seconds fully clear. Context changes and stale requests clear the effect. Other ACE medical effects remain separate.
- The alpha8 PBO path correction and deployment checks remain included.

## In-game checks

1. With a pistol selected, start sprinting from stationary and from lowered-pistol jogging. Repeat with the pistol raised. The run should enter once, with one brief brace and no run/skip/run interruption. Compare with rifle and unarmed starts.
2. Hold W and release Shift at partial acceleration, full speed, after exhaustion, and on a descent. The initial deceleration should begin at the pace reached at release. It should not change to the slower jog clip first.
3. Rapidly tap Shift while W remains held, including halfway through deceleration. Check for smooth continuation without a new brace, animation restart or recovery of a previous full-speed value.
4. Release W during deceleration; then repeat with A, D and S. Movement and direction changes must take effect promptly. Repeat while stopping ordinary jogging, with heavy gear, and on an incline.
5. Check uphill braking, turning, changing weapons, reload, crouch/prone, carry, medical actions, unconsciousness, respawn and disabling GAIT. No stale release curve or held sprint animation should survive an invalid context.
6. Confirm the 20% heartbeat, light-tier brace, heavy downhill pace, velocity-based trips and fully clear intervals between fatigue vignette pulses remain as in alpha9.

For diagnostics, copy tests/foundation_capture.sqf into a saved Eden mission and run locally:

```sqf
[90, "alpha10 pistol startup and release momentum"] execVM "foundation_capture.sqf";
```

The recorder is read-only. Send the RPT after STOP and approximate event times for any remaining issue.

## Packaging and verification

The ZIP contains complete HEMTT source and a standalone mod under `ready_to_load/GAIT`. Run VERIFY_READY.ps1 to check the bundled build. Core prefix remains `gait`; heartbeat prefix remains `z\gait\addons\heartbeat`.

Automated results are in tests/VALIDATION_FOUNDATION.txt. The tests reproduce the old lowered-pistol blend failures and exercise the release planner/controller. They do not render Arma or measure actual stopping distance, final cross-clip velocity, perceived loudness or visual appearance; those remain in-game acceptance checks.
