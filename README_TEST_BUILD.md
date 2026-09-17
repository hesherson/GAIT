# GAIT 1.7.0-rc3

This build fixes the RC2 runtime error and replaces its jogging-only movement family with real sprint animation states. Uphill movement still uses continuous slope/load pacing, with no angle that deliberately forces walking.

## What changed

* Fixed `Error Params: Type Number, expected Array` in `fn_slopeLocomotion.sqf`. Bare cleanup calls inherited the speed writer's `[unit, coefficient, carry]` arguments. Cleanup now passes explicit empty argument arrays.
* Forward, forward-left and forward-right now inherit native **Meva sprint animations** for raised/lowered rifle, pistol and unarmed poses. Sideways and backward movement use the native **Mrun** clips.
* Replaced immediate `switchMove` cuts with single `playMoveNow` entry/exit requests and explicit animation-graph connections.
* Acquiring speed-coefficient ownership no longer releases the body animation. This prevents unrelated coefficient resets from causing another animation switch.
* Expected standing entry blends retain movement eligibility. Matching uses the exact entry source/target; crouch, prone, medical, weapon actions and unrelated transitions remain excluded. Slow blends on steep terrain do not fail solely because a fixed timer expires.
* Entry/exit requests are tracked so polling cannot restart an exit repeatedly. Canceling sprint during entry retains enough ownership to cancel the pending switch safely.
* The equipped weapon and the active animation family's pose stabilize rifle-family selection. A sprint clip lowering the rifle does not itself trigger a family change.

The slope/load pace model, reserve-based target margin, brace and acceleration values are retained from RC2. GAIT still removes only the ACE Advanced Fatigue movement restriction source, keeping other ACE restriction owners. ACE physiology remains read-only to GAIT.

## Install and build

Follow `README_HEMTT.md` to apply the complete source package to `F:\GAIT`, push `dev/gait-1.7.0-rc3`, and run:

```powershell
Set-Location 'F:\GAIT'
hemtt build
```

Load `F:\GAIT\.hemttout\build` as a local mod, together with CBA_A3 and ACE3. Unload previous GAIT versions and start a fresh mission. Check the GAIT debug HUD shows **1.7.0-rc3**.

`hemtt build` produces unsigned local test output. A future server release requires your chosen signing workflow.

## Focused in-game checks

1. On flat ground, start sprinting from idle and from jogging. Forward/diagonal motion should use `AmovPercMeva..._GAIT`, with the real sprint pose and no instant screen jump.
2. Hold W+Turbo continuously while crossing the original problem slope. Keep alternating A/D, including W+A → W+A+D → W+D. The engine should select matching directions inside the same family.
3. Release Turbo while holding W, release W while holding A/D, and tap/release sprint very quickly from rest. There should be no delayed custom-state entry or repeated transition.
4. Test crouch/prone, reload, weapon changes, casualty handling, vehicles, Zeus and unconsciousness during sprint. GAIT should give those actions control and allow normal recovery afterward.
5. Compare settled walking and sprinting on the same unobstructed strip, with the same load, weapon and reserve. Repeat above the native walk threshold and with kit above 75 lb. Steeper slopes and extra load should reduce pace; sprint should remain faster than matching walking.

Test first and third person. These changes target the observed error, wrong clip selection and abrupt transitions. **Compilation and regression checks cannot establish camera smoothness, collision behavior or physical speed in Arma.** Those still require this in-game comparison.

Launcher/binocular poses, crouched sprint and casualty carry keep native animation maps. Terrain sampling skips elevated structures to avoid applying the ground slope beneath a bridge. Walls and nontraversable terrain remain engine-controlled.

## Capture a remaining problem

Copy `tests/slope_runtime_capture.sqf` into your mission folder. In the local debug console:

```sqf
[] execVM "slope_runtime_capture.sqf";
GAIT_runtimeCaptureLabel = "rc3_sprint_strafe_same_hill";
```

Stop with `GAIT_runtimeCaptureEnabled = false;`. The RPT receives `[GAIT_CAPTURE]` rows at 10 Hz containing resolved inputs, real forward/lateral and surface speeds, animation/action family, coefficient, grade, load, locks, reserve and FPS. Include the RPT and a short first-person clip if the one-frame jump remains.

## Verification

* HEMTT compiled the addon config and all nine SQF files into the test PBO.
* The former inherited-argument error was reproduced in a small SQF-VM case. The real cleanup functions now pass tests from five different caller argument contexts.
* Coefficient-only cleanup is checked not to release the animation family.
* Expected/unsafe transition cases cover ordinary entry, crouch, prone, medical actions, unexpected directions and extra state fragments.
* Direction tests preserve opposite-key cancellation, A/D reversal, diagonal normalization and side-only release.
* State selection tests require all 12 forward/diagonal sprint states and all 20 native lateral/backward running states.
* The unchanged pace model retains RC2's earlier validation across 225,900 grade/load/reserve combinations plus 5,400 default reserve-response samples.

Arma and multiplayer tests have not been run here. HEMTT style suggestions may remain; they are separate from the corrected runtime argument error.

## Primary references

* [Bohemia native movement states](https://community.bistudio.com/wiki/Arma_3:_Moves)
* [Bohemia animation graph configuration](https://community.bistudio.com/wiki/CfgMoves_Config_Reference)
* [ACE native movement configuration](https://github.com/acemod/ACE3/blob/master/addons/movement/CfgMoves.hpp)
* [ACE fatigue movement effects](https://github.com/acemod/ACE3/blob/master/addons/advanced_fatigue/functions/fnc_handleEffects.sqf)
