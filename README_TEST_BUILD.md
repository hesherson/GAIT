# GAIT 1.7.0-rc2

Continuous slope sprint candidate, based on GAIT 1.6.1 and the RC1 cleanup.

The goal is to keep standing sprint faster than walking at the same slope and packed weight, without an angle that deliberately forces walking. Slope and load reduce pace continuously. This build implements a dedicated animation action family to address Arma's terrain walking selection. **It requires in-game verification; compilation and mathematical tests cannot establish that the engine honors the new movement graph.**

## Install

1. Build from `F:\GAIT` with `hemtt build`, add `.hemttout\build` as a local mod in the Arma launcher, and load CBA_A3 + ACE3. See README_HEMTT.md for setup.
2. Unload every earlier GAIT PBO. Start a fresh editor mission.
3. In Options > Addon Options > GAIT, use Full GAIT Control or ACE-Friendly Hybrid with the ACE movement-lock override enabled. Keep the dedicated sprint animation family and slope handling enabled.
4. Enable the debug HUD. Test the slopes where A/D previously failed.

HEMTT build output is unsigned for local testing. Sign your eventual release with your own key before using a signature-enforcing server. Old signatures cannot authenticate this changed PBO.

## Changes from RC1

* Removed the 38-degree ACE override cutoff. GAIT removes only the Advanced Fatigue movement restriction source, preserving medical and other owners.
* Added four custom action families with eight directions each: rifle raised/lowered, pistol and unarmed. Native Walk/Slow/Fast/Tactical direction requests resolve to their matching running states during an eligible standing sprint.
* The same family is used throughout the sprint, including flat ground. There is no scripted family change at the terrain walking threshold.
* Script enters/exits the family at context boundaries. Direction changes within it use the engine's action graph. No KeyUp forward handoff, recurring animation rescue, or slope velocity injection is used.
* Uphill slowdown is a continuous curve. The old 35-degree maximum becomes a reference angle, and slowdown continues above it.
* Weight multipliers interpolate between existing tuning points and continue declining past the heavy threshold. At default tuning, 75/100/150/250 lb give multipliers 1.000/0.917/0.787/0.613.
* The sprint coefficient target stays above the matching walk target. The default exhausted ratio is 1.20; fresh reserve adds up to 0.20. Reserve therefore still affects pace when the minimum target is active.
* Brace and acceleration remain gradual. The target relationship applies after launch and acceleration; it does not teleport a stationary character to running speed.

ACE physiology remains read-only to GAIT. ACE calculates exertion, reserves, acidosis and medical consequences. The inherited 1.6.1 visual-effects implementation was already disabled and remains so.

## Pace model

Above the uphill start angle:

`gradeFactor = (1 - referencePenalty) ^ ((grade - startAngle) / (referenceAngle - startAngle))`

Walking has its own continuous grade curve. Both walk and sprint receive the same continuously decreasing load multiplier. The steady sprint coefficient is the larger of the reserve-based candidate and:

`walkCoefficient * (minimumRatio + reserveRatio * freshMargin)`

This is a conservative **coefficient** floor. Actual metres per second depend on each animation's root motion and the engine's terrain handling. It assumes the chosen running clip is faster than its corresponding walking clip at the same coefficient. Unarmed normalization can be clipped by this floor. In-game matching passes must confirm physical speed before calling the requirement verified.

The old absolute minimum uphill multiplier is retired. Saved values of the removed maximum-slope or minimum-multiplier settings no longer affect the controller. Presets respect forced CBA mission/server values.

## Acceptance test

Use open traversable terrain, the same heading, weapon, kit and reserve level for each paired walk/sprint pass. Allow brace and acceleration to settle. Compare surface speed, not just animation names or coefficients.

| Test | Required result |
| --- | --- |
| Walk and sprint at 15, 20, 25, 30, 40, 50 degrees, plus the original failing location | Sprint remains running and faster than matching walking; steeper uphill is slower |
| Repeat at 35, 75, 100 and 150 lb, fresh and tired | Extra kit decreases pace beyond 75 lb; fatigue still affects sprint |
| Hold W+Turbo; alternate A/D and overlap both | Direction follows live input with no forward kick or delayed queued turn |
| W+A to W+D; release A while D remains held | Rightward movement survives the release of A |
| Release W while holding A/D; press both and release one | Lateral movement stays lateral; opposing inputs cancel |
| Release Turbo, stop, crouch/prone, reload, treat, climb, enter vehicle | Family releases without forcing standing or overriding special actions |
| Rifle raised/lowered, pistol, unarmed | Every directional family works; verify clip-specific physical speeds |
| Disable/re-enable GAIT, respawn, Zeus/spectator, remote player view | No stale ownership, movement or visible animation cycling |

Launcher/binocular poses, crouched sprint and casualty carry keep their native animation maps; they are not covered by the new standing animation family. Collision, cliffs and nontraversable geometry remain engine-controlled. Terrain pace sampling skips elevated structures to avoid applying the ground slope beneath a bridge.

If the engine rejects or unexpectedly exits the custom family, the controller logs the failure and avoids repeatedly forcing it. Release sprint to reset the entry attempt. This is a test failure to investigate, not a successful no-walk result.

### Capture evidence

Copy `tests/slope_runtime_capture.sqf` to your mission folder. Run locally in the debug console:

```sqf
[] execVM "slope_runtime_capture.sqf";
GAIT_runtimeCaptureLabel = "walk_75lb_hill1";
```

Change the label for each sprint, weight or strafe pass. Stop with:

```sqf
GAIT_runtimeCaptureEnabled = false;
```

The local RPT receives `[GAIT_CAPTURE]` rows at 10 Hz: resolved inputs, actual forward/lateral and surface speed, animation/action family, coefficient, grade, load, locks, reserve and FPS. Send the RPT plus map/location and exact failing input sequence if a check fails.

## Source and GitHub

`addons/gait` is the complete editable addon. The main checkout is `F:\GAIT`; `.hemtt/project.toml` configures a direct `hemtt build`. All runtime scripts retain their RC2 content and `gait` virtual prefix. `README_HEMTT.md` contains the deployment, folder migration and build commands.

`DEPLOY_GITHUB.ps1` migrates the existing checkout to `F:\GAIT`, preserving an older folder at that path as a dated backup if necessary. It moves the tracked source into HEMTT's addon layout and pushes `dev/gait-1.7.0-rc2`.

## Validation and limits

* HEMTT config/SQF compilation and PBO build, plus SQF-VM syntax checks.
* Executed input cancellation, overlapping A/D, diagonal normalization and time-step ramp tests.
* Executed continuous pace tests over 225,900 grade/load/reserve combinations, including angles 0–89 and loads 0–250 lb.
* Dedicated direction tests and reserve-dependent floor checks.

No Arma 3 session or multiplayer test was available here. The engine action routing, transition blending, physical speed advantage and ACE-version compatibility remain acceptance gates. This is a complete test build, not a verified release.

## Primary references

* [ACE movement action maps](https://github.com/acemod/ACE3/blob/master/addons/movement/CfgMoves.hpp)
* [ACE custom directional action family precedent](https://github.com/acemod/ACE3/blob/master/addons/dragging/CfgMovesBasic.hpp)
* [Bohemia animation list](https://community.bistudio.com/wiki/Arma_3:_Moves)
* [Bohemia input action names](https://community.bistudio.com/wiki/inputAction/actions)
* [ACE fatigue effects](https://github.com/acemod/ACE3/blob/master/addons/advanced_fatigue/functions/fnc_handleEffects.sqf)
* [ACE physiology main loop](https://github.com/acemod/ACE3/blob/master/addons/advanced_fatigue/functions/fnc_mainLoop.sqf)
