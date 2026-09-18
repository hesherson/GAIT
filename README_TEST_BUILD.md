# GAIT 1.8.0-alpha1: locomotion foundation rebuild

This is the complete GAIT source with a rebuilt animation controller and custom movement family. The tuned step-off, brace, momentum, reserve, slope, gear and effects logic is retained. It is an **in-game validation build**: HEMTT and regression tests pass, but Arma movement and camera behavior have not been executed here.

## What was preserved

The original CBA settings registration, preset file and slope pace model are byte-identical to RC4. An automated audit protects 25 executable feature blocks, including:

* Initial push-off, crouch-armed brace, zero-momentum detection and gear brace relief
* Brace duration, speed dip, acceleration curve, cooldown and walking-settle requirements
* Slope-stop memory, additional slope brace duration and dip
* Short sprint retaps, forward-release rearming, momentum ramp and Shift-release hold/taper
* ACE reserve reading, standalone reserve/recovery, exhaustion response and carry pace
* Weapon sway/recovery, tinnitus/hearing, hard landings, downhill trips and vegetation drag
* Existing visual-effect cleanup behavior; previously disabled post-processing is not reintroduced

These checks preserve the program and its settings. The different animation foundation can still change how that tuning feels, which is why the first acceptance run includes the step-off itself. See `tests/FEATURE_PRESERVATION.md` for the detailed contract.

## What was rebuilt

The feature loop computes the same tuned pace and brace output. It submits locomotion intent to a separate controller instead of issuing body animation commands from its scheduled loop.

The controller has explicit native, entering, active, exiting and blocked states. It reads current input from Draw3D and makes one direct entry into the custom family. Arma chooses movement directions after entry. It does not restart the clip whenever A/D changes, and it does not write position or velocity to drive ordinary movement.

The action graph has 36 states: four custom idles, 12 real forward/diagonal Meva sprint clips and 20 lateral/backward Mrun clips. Default, stop and turn selectors stay within the family. Turning uses the custom native-idle derivative as a fallback rather than assuming unverified turn clip names. Native action/transition inheritance is preserved for weapon, injury, stance and other actions; the graph does not remove every inherited native edge.

Pure A/D and a brief stop while Turbo remains held retain the family. **Forward sprint effort remains forward-only**, preserving the original brace/reserve decisions and normal sideways speed cap. Verified blends between two custom states in the same family now remain eligible; medical, stance and unrelated blends do not receive that exemption.

Releases cancel intent immediately and queue one Draw3D exit. Reload/throw/melee gestures, lost contact and weapon handoffs defer that exit while retaining cleanup ownership. A native or medical body transition clears the pending command. An exit and re-entry cannot be issued in the same frame. Unexpected graph escape is reported and latched until the input/context changes, rather than hidden with repeated forced animation.

ACE's fatigue movement policy now has a stable ownership check separate from the eligibility of a particular animation frame. It retains the RC4 public status-event bridge and removes only AF's restriction source. Medical and other owners remain effective. ACE's physiology and final functions are untouched. This remains a reactive bridge, not a pre-setter ACE integration hook.

## Physical speed interface

A new pace adapter supports measured per-clip references in metres per second and applies the sustained sprint/walk margin before brace and acceleration. It does not impose a speed floor on the brace itself.

No measured speed profiles are invented or bundled. With the default empty profile set, this adapter returns the **exact existing coefficient targets**. `GAIT_paceCalibrated=false` and metric targets `-1` mean no verified profile is installed. The optional developer collector in `tests/collect_pace_reference.sqf` reports candidates without changing gameplay or activating them. It is not required to play this build.

A physical target remains distinct from actual speed on collision-limited or nontraversable terrain. The current build does not claim to have demonstrated sprint faster than walking at every grade.

## Install and build

Use `README_HEMTT.md`. Keep the checkout named `F:\GAIT`. Load `F:\GAIT\.hemttout\build`, together with CBA_A3 and ACE3, and unload previous GAIT versions. Check the HUD/log identifies **1.8.0-alpha1**.

**Re-enable both GAIT and ACE Advanced Fatigue in mission Addon Options** if earlier isolation tests disabled them. Start a fresh single-player Eden preview. For this first comparison, load only CBA_A3, ACE3 and GAIT; add Animate Rewrite and other movement addons afterward.

## One normal gameplay acceptance run

This checks the rebuilt mod with its features active. The previous isolated native/custom clip tests are not required for this run.

1. Copy `tests/foundation_capture.sqf` into the saved mission's folder.
2. Run this in the debug console using **Local Exec**:

```sqf
[60, "foundation step-off and hill"] execVM "foundation_capture.sqf";
```

3. From a stop, sprint forward. Check the familiar push-off/dip and acceleration. Release and immediately retap Turbo, then stop long enough for the brace to rearm. Repeat once from crouch.
4. Cross the original steep hill with W+Turbo. Alternate W+A/W+D, then release W while holding Turbo+A or Turbo+D and return to forward movement. Briefly stop with Turbo still held, then move again. Test uphill and downhill.
5. Release Turbo while still moving. Check the familiar release hold/taper. Reload, change weapon and crouch/prone once to check control returns normally.
6. Wait for the capture STOP message, or stop early with `GAIT_foundationCaptureEnabled = false;`. Send the RPT and note whether the step-off still feels right, sprint persists past the problem grade, and the camera jumps at entry/exit.

The recorder is read-only and samples at 10 Hz. It includes the controller phase, inputs, animation, restrictions, actual speed, brace telemetry and configured pace targets. The controller also logs entry, exit and unexpected escape events directly.

## Remaining runtime questions

* A string `switchMove` starts a clip directly and can reset phase/aim. Draw3D timing addresses the previously investigated camera context, but does not prove smoothness.
* Custom idle/default routing and retained native edges need confirmation in the loaded game configuration.
* Inherited weapon transitions must take control during a weapon handoff; GAIT will not force a cross-weapon movement pose to hide a failure.
* Exact physical speed calibration, multiplayer observation, respawn and integration with other animation addons need Arma acceptance.

No DLL or modified ACE distribution is required. If a stable custom graph still encounters an independent engine terrain restriction, that result will justify the next, narrower engine investigation.

## Development checks

```powershell
python tests/feature_preservation.py --self-test
python tests/foundation_graph.py
python tools/generate_foundation_actions.py --check
hemtt build
```

Python is only needed for these developer checks, not for a normal HEMTT build. SQF regression cases and the validation record are in `tests`.
