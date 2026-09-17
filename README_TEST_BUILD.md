# GAIT 1.7.0-rc1

Native movement test build, based on your GAIT 1.6.1 source.

This build removes competing animation and velocity control from hill movement. It keeps GAIT's sprint acceleration, brace step, weight-dependent pace, ACE reserve-based speed, sway recovery and fatigue audio. Arma handles movement direction, foot placement, animation transitions and collisions.

It has compiled successfully, but has not been run inside Arma 3. Treat it as a candidate for testing, not a verified Workshop release.

## Install the local test

1. Extract `@GAIT_TEST` to your local Arma mod folder and add it through the Arma launcher.
2. Load CBA_A3, ACE3 and this test mod. Unload the previous GAIT PBO so both versions are not running together.
3. Start a new editor mission. Do not resume a save containing the previous GAIT scripts.
4. Open Options > Addon Options > GAIT. Balanced is a starting point. Select Custom before individual tuning if you want to keep those choices across mission starts.
5. Enable the GAIT debug HUD for the movement checks below.

The supplied PBO is **unsigned**, intended for local testing. Dedicated servers that require signatures need a build signed with your normal release key. This package contains no replacement public key or release signature.

Rollback: unload `@GAIT_TEST` and load your previous GAIT release, then start a fresh mission.

## What was causing the bad response

| Finding in 1.6.1 | Change in this build |
| --- | --- |
| AnimChanged rescues, a strafe watchdog, key-release handoffs and slope animation forcing could all request different animations | Removed scripted locomotion animation requests |
| Releasing A while D remained held could queue a forward animation | Movement uses a single current input sample; opposite inputs cancel |
| Side-only movement could be assigned a forward-diagonal animation | Native Arma direction selection stays in control |
| Rotation and strafe actions were combined | Only actual strafe actions contribute to the lateral axis |
| Slope sampling followed character facing | Grade is sampled along intended travel direction, including diagonals and backward movement |
| Multiple velocity assistance/cap layers could act during movement transitions | Removed the hill velocity assistance and speed-cap stack |
| A separate 0.01-second loop raced ACE's movement restrictions | Integration now runs immediately after ACE's own effects update, plus the normal GAIT update |
| Direct `forceWalk false` could undo another system's restriction | Uses only ACE's source-specific status API; remaining sprint/walk restrictions are respected |
| Uphill code directly edited ACE reserve percentages and acidosis | ACE physiology is read-only to GAIT |
| Speed timing depended on the movement loop interval | Acceleration and deceleration use elapsed time |
| Disable/respawn could leave animation exclusions behind | One movement owner tracks and restores the affected unit, removing only GAIT's exclusions |

## Expected movement

* Straight and diagonal uphill movement should use native transitions, with GAIT gradually adjusting pace
* A/D reversals should change direction immediately through Arma's movement system, with no queued forward handoff
* A/D alone should remain lateral, including while Turbo is held
* Moving across a hillside uses the grade along that route, rather than automatically receiving the full uphill penalty
* Uphill pace still decreases with slope, kit and available ACE reserve
* Releasing Turbo retains the coefficient taper; releasing movement stops through the engine's normal behavior
* Medical actions, reload gestures, stance transitions, vehicles, airborne states, spectator and Zeus contexts release GAIT's movement control

The new **Maximum ACE slope override** defaults to 38 degrees with a two-degree re-entry band. Above that limit, GAIT stops removing ACE's terrain restrictions. It is an ACE integration limit, not a collision limit or a guarantee of sprinting on every slope. It requires the ACE bridge and walk-lock override to be active.

The documented `terrainSpeedCoef` remains 1. The old unverified `terrainGradientDisableSprint = 100` and `terrainGradientForceWalk = 100` entries were removed. Arma may still enforce native walk states on some geometry. If that happens, this build deliberately avoids another animation/velocity rescue loop.

Terrain sampling skips elevated surfaces more than 0.6 m above terrain. Bridges, rooftops and stairs are left to native movement rather than receiving the slope of the land below. This is a conservative heuristic, not a complete geometry solver.

## Test sequence

Use the same soldier, kit and route when comparing this build with 1.6.1. Compare in separate fresh missions.

| Check | What to look for |
| --- | --- |
| Flat ground, then roughly 15, 20, 25, 30 and 35-degree climbs | Gradual pace change; no repeated stop/sprint animation cycling |
| Hold forward + Turbo and alternate A/D rapidly, including overlapping keys | No delayed direction change, forward kick or sideways lock |
| Hold A or D without forward; press both, then release one | No unintended forward movement; cancellation and recovery follow input |
| Release Turbo while holding forward, then add A/D | Taper without a forward push from a separate velocity system |
| Turn the character without strafe input | Turning does not masquerade as lateral movement |
| Traverse across the same hillside and go backward | HUD travel grade follows the route |
| Rifle, pistol, launcher, unarmed; weapon raised/lowered | No GAIT-forced weapon change or locomotion animation |
| Crouch, prone, reload, treatment, casualty carry/drag | No forced stand-up or movement injection; injury restrictions remain |
| Respawn, enter/exit vehicle, Zeus/spectator, disable/re-enable GAIT | No stale speed coefficient or stuck movement |
| Light/heavy kits; rested/exhausted ACE state | Pace changes while ACE reserves and effects continue normally |
| Multiplayer, watched by another player | Check remote animation smoothness as well as local responsiveness |

If the engine still forces walking or movement remains irregular, capture the debug HUD, map/location, slope, exact input sequence, weapon and mod list. Save the RPT. The useful distinction is whether the HUD reports sprint/walk blocked, or whether a native walking animation persists while those restrictions are clear.

## Source and rebuilding

`source/gait` is the complete editable addon. Pack that folder using Arma 3 Addon Builder with PBO prefix **gait**. Include the two new files, `fn_traversalHelpers.sqf` and `fn_nativeController.sqf`; the main script loads both. Retain the existing sounds and PAA assets. Sign the resulting `gait.pbo` through your usual release process when preparing a server release.

Obsolete velocity/animation workaround settings were removed from Addon Options and preset tables. Saved values for those retired options no longer reactivate the old code. Presets now use CBA's client settings route, so forced mission/server values keep precedence.

The supplied 1.6.1 source already disabled GAIT tunnel vision, blur and chromatic aberration. This revision does not restore those effects; ACE's visual fatigue behavior remains responsible for them.

## Validation completed

* HEMTT 1.21.0 compiled all seven SQF files, rapified config.cpp and built the PBO
* SQF-VM parsed all SQF/config files without errors
* Executed input cancellation, A/D reversal, diagonal normalization, analog input and deadzone tests against the actual resolver
* Executed acceleration tests at five update intervals, plus deceleration and scheduler-stall checks
* Confirmed UTF-8 without BOM, packaged helper files and PBO prefix `gait`
* No undefined-local-variable diagnostics remained in the final HEMTT check

HEMTT used bundled command definitions because its wiki update was unavailable. Arma 3 Tools was unavailable; existing PAA/OGG assets were retained. Remaining diagnostics were style suggestions, existing unused config declarations and the temporary build project's expected-prefix warning. The actual PBO prefix was inspected separately.

These checks do not validate Arma's locomotion, multiplayer replication or compatibility with every ACE version. The integration wraps ACE's internal `handleEffects` function, whose dynamic call was verified against current official source. Future ACE changes or another addon replacing that function may require adjustment.

## Technical references

* [Bohemia action names](https://community.bistudio.com/wiki/inputAction/actions): `TurnLeft`/`TurnRight` are strafe actions; `MoveLeft`/`MoveRight` rotate
* [Bohemia playMoveNow](https://community.bistudio.com/wiki/playMoveNow): animation queue behavior
* [Bohemia 1.54 changelog](https://dev.arma3.com/post/spotrep-00049): terrain speed coefficient
* [ACE effects](https://github.com/acemod/ACE3/blob/master/addons/advanced_fatigue/functions/fnc_handleEffects.sqf): fatigue and terrain movement restrictions
* [ACE main loop](https://github.com/acemod/ACE3/blob/master/addons/advanced_fatigue/functions/fnc_mainLoop.sqf): physiology calculations and dynamic effects call
* [ACE status effects](https://github.com/acemod/ACE3/blob/master/addons/common/functions/fnc_statusEffect_set.sqf): source-specific restrictions
* [CBA settings setter](https://github.com/CBATeam/CBA_A3/blob/master/addons/settings/fnc_set.sqf): client setting priority
