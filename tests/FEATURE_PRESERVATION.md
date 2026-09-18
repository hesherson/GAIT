# GAIT gear inertia update: feature preservation contract

The movement foundation may change how animation states are entered, selected and released. Alpha2 introduced a shared retained-momentum veto for launch-brace triggers and a sustained downhill bonus. Alpha3 added separate slope-dependent uphill release braking. Alpha4 explicitly authorizes heavier gear to accelerate more slowly, preserve sprint-to-walk momentum longer and require a stronger initial step-off, with continuous interpolation through the existing gear ranges. Raw stopping and direction input must remain responsive; retained speed is not permission to keep moving forward after W is released. Reserve, pace targets, ACE carrying, sway, fatigue and the uphill brake remain protected. A successful static check establishes source preservation within the stated exceptions, not smooth movement or correct physical speed in Arma.

The reference is the GAIT 1.7.0-rc4 source from this investigation. Line references below identify that baseline, so they remain useful if the new source gains lines or extracts helpers. Unless another file is named, references are to `addons/gait/functions/fn_initSprintSystem.sqf`.

## Authorized changes through alpha4

The original 25 RC4 block hashes and all three file hashes remain in the test. They have not been replaced with hashes of the rewritten code. **18 blocks remain intact; seven blocks contain fourteen exact authorized edits:**

| Modified block | Authorized edit | What stays protected |
| --- | --- | --- |
| Initial tuning and momentum state | Alpha4 adds release-time coast duration snapshots. | All original initial values and tuning reads. |
| Preset and reset state | Alpha2 clears new brace-history and downhill-momentum state. Alpha3 clears uphill-brake state, owner and timing. Alpha4 clears coast ownership. | Every original reset statement and preset selection. |
| Gear weight and brace relief | Alpha4 interpolates the existing relief anchors through a continuous inertia helper. | Weight conversion, continuous top-speed calculation and effective-brace formula. |
| Directional grade, trips and walk pace | Replace the immediate downhill bonus with the sustained, load-aware helper. | Grade sampling/smoothing, uphill targets, trip logic and hill-walk policy. |
| Step-off, brace and sprint end | Alpha2 readiness recognizes a real stop and rejects retained sprint momentum. Alpha3 also vetoes launch bracing when sprint resumes during the release brake. Alpha4 scales the base launch duration by load and snapshots the load-scaled coast window on release. | Base launch setting, dip formula, reserve gate, slope memory, minimum brace speed and sprint-end bookkeeping. |
| Shift-release hold and taper | Alpha4 consumes the fixed release-time coast snapshot. | Existing hold/taper formula, eligibility and cancellation rules. |
| Brace or momentum speed ramp | Alpha3 selects the uphill-release target and braking rate. Alpha4 scales ordinary acceleration/deceleration by load, excluding ACE carry and active launch/release braces. | Original ramp settings, brace snap rate and frame-time-adjusted coefficient step. |

For these edits, the guard requires each exact reviewed new fragment, reverses only that fragment in memory, and checks the original RC4 hash of the entire block. Extra edits still fail. New helper behavior is covered separately by the brace, downhill, uphill, gear-inertia and locomotion-coast suites. The seven alpha4 deltas reverse before the seven prior deltas; no historical reference digest changes.

`fn_applyPreset.sqf` and `fn_slopePaceModel.sqf` remain byte-identical to RC4. Settings registration allows the two alpha2 description edits, one associated display-label edit and two new sliders, plus one alpha3 uphill-release checkbox. After reversing those changes, every original registration token must match the fixed RC4 reference. All original ranges, defaults, categories, callbacks and CBA priority rules remain protected. Comments and whitespace in the registration file may change.

The two new sliders are a 0.12 unloaded sustained downhill bonus and a 2.5-second momentum build time. They supplement the existing base bonus; original preset values are unchanged. Actual downhill target gain also depends on carried load, grade and established movement. Targets still require in-game speed calibration. The new uphill-release checkbox defaults to enabled and uses the existing slope-brace angles, duration, dip and ramp tuning; none of those defaults changed.

Additional controller work keeps forward sprint-to-walk coasting within the active movement family so a re-tap does not require another entry. Render-time input overrides an older scheduled coast request when stopping, strafing or reversing. An observed custom animation or recognized blend receives one safe exit. An entry that has been issued but still reports its native source retains bounded cancellation ownership; its cancellation uses current input, and full-body or unrelated native actions take priority. These additions sit outside the historical feature blocks and require behavioral and game checks. Downhill build/recovery time now uses the same gear-dependent response rates. The uphill brake still shortens the release-time coast snapshot continuously with severity, removes it at full severity and caps stored speed at the post-brake coefficient. Its parameter/edge-detection helper is unchanged from alpha3.

## Protected behavior

| Feature | Baseline code | Contract |
| --- | --- | --- |
| Player configuration and presets | Existing registrations in `fn_registerSettings.sqf`; complete `fn_applyPreset.sqf` | Preserve original ranges, defaults, preset overrides and CBA priority. Only the two descriptions, one associated display label, two added sliders and uphill-release checkbox above may differ. Custom stops preset rewrites; forced mission/server values retain precedence. |
| Live tuning and resets | 527–760, 772–942 | Preserve live setting refresh, preset application, reserve-ratio preservation when capacity changes, and existing state initialization and reset. Reset also clears movement-history, uphill-brake and coast ownership state. |
| Sprint intent | 977–998 | Sprint pace requires held Turbo and positive resolved forward input, eligible movement, non-prone stance and no external sprint/walk lock. Actual crouch remains distinct from a crouch-key press. Animation ownership must use a separate condition. |
| Input resolution | `fn_traversalHelpers.sqf`:8–26 | Preserve opposed-key cancellation, 0.05 deadzone, normalized diagonal input and held-Turbo semantics. TurnLeft/TurnRight are the strafe actions. Do not replace them with rotation actions. |
| Stopped-start step-off | 1229–1333 | Without retained sprint momentum, a qualifying settled state arms the brief brace dip. Alpha4 scales base duration by gear; the configured base, dip formula, minimum speed and added slope duration/dip remain intact. Compatible walking states carry the visible push-off. |
| Actual crouch start | 1235–1245, 1313–1315 | Actual crouch or an armed crouch start permits the brace when retained sprint momentum is absent. Merely pressing crouch is insufficient. Preserve the existing crouch path through sprint intent. |
| Settling and quick Shift taps | 1281–1297 | Normal rearming uses the settled-movement timer, recent-sprint cooldown and reserve gate. The zero-momentum path catches walk-to-sprint starts without waiting for those timers. Established actual sprint travel now vetoes every brace cause, including crouch and remembered slope stops, until a real stop or settled recovery. Retapping Shift during retained movement must not manufacture another brace. |
| ACE brace compatibility | 1262–1279 | With ACE Advanced Fatigue active, standing/zero-momentum brace readiness does not require nearly full metabolic reserve. Without ACE, retain the configured reserve threshold for those paths. Actual crouch retains its separate brace path. This exception is essential to standing step-off. |
| Forward-release rearming | 1048–1049 | Track actual forward input and the configured time since it ended. Sideways animation ownership must not rewrite that timer or pretend forward input continues. |
| Gear-dependent brace relief | 1060–1077 | Keep all four configurable relief anchors and the effective-brace formula. Alpha4 replaces abrupt relief tier selection with continuous interpolation across the configured weight boundaries; heavier gear receives less relief at default settings. |
| Slope stop/restart brace | 1299–1329, 1356–1357 | Keep slope-stop memory, slope severity, additional dip and duration, and the minimum brace coefficient. Both ascent and descent can affect a restart after momentum has ended. A recent slope stop cannot override established retained momentum for a new launch brace. The new release brake is a separate event and intentionally slows a moving uphill body. |
| Sprint-end bookkeeping | 1335–1368 | Preserve last-sprint time/grade, clear the active brace, and do not reintroduce a forced post-run weapon/posture correction. |
| Shift-release carry and taper | 1339–1353, 1578–1609 | With W held, retain the existing hold/taper shape using a release-time load-scaled window. Heavy gear keeps momentum longer; light gear sheds it sooner. Uphill severity shortens that window continuously and caps stored speed at the post-brake coefficient. Sideways/backwards input, renewed sprint, ineligibility or external restrictions cancel forward-only carry. |
| Acceleration/deceleration | 1614–1621; `fn_traversalHelpers.sqf`:28–32 | Keep the original base ramp setting, frame-time adjustment and sideways/external-lock speed caps. Alpha4 scales ordinary acceleration/deceleration by load while preserving launch-brace snap, uphill braking and ACE-carry ramp behavior. Do not reset momentum merely because a custom directional state changes. |
| Standalone reserve | 1373–1455 | Keep sprint drain, uphill drain severity, recovery time, exhaustion clamps and temporary fallback before ACE publishes its first reserve. Sideways ownership alone must not count as sprint drain. |
| ACE reserve bridge | 1390–1417 | Read the minimum anaerobic/aerobic reserve with the existing acidosis and muscle-damage penalties. Do not write ACE physiological values. |
| Continuous grade and weight pace | 1085–1223, 1553–1566; complete `fn_slopePaceModel.sqf` | Preserve directional sampling, slope smoothing, uphill decay, hill-walk penalties, continuous load scaling, fresh/exhausted targets and the sprint/walk coefficient floor. The downhill bonus is intentionally replaced with sustained, angle-dependent, load-scaled gain that tapers on extreme descents. No new slope cutoff may replace the continuous model. |
| ACE carrying | 971–975, 1568–1573 | Keep independent carry walk/fresh-sprint/exhausted-sprint targets. Ordinary custom sprint animation ownership must not take over ACE carry or pickup animations. |
| Unarmed normalization | 1553–1556 | Keep the existing unarmed multiplier; holstering must not silently grant a different movement profile. |
| Vegetation drag | `fn_nativeController.sqf`:89–104, 114 | Preserve bush-distance weighting, maximum drag, 0.4 s query interval and multiplication into the single speed-coefficient write. |
| Downhill trip risk | 1024–1046, 1125–1198 | Keep the slope/speed/weight factors, sustained-movement gates, cooldown/immunity and chance-per-second calculation. Directional graph membership does not itself imply a valid sprint. |
| Trip recovery | 205–260 | Keep the trip impulse, minimum ragdoll interval, actual horizontal-speed recovery check and maximum duration. Preserve ACE unconsciousness when releasing GAIT's trip. |
| Landing feedback | 1000–1009 | Preserve the ground-contact transition, vertical-speed threshold and severity-scaled camera shake. |
| Weapon sway | 377–506 | Keep the separate sprint sway and linear recovery loop, resting/walking baselines, settings and context gates. Locomotion ownership must not become another aim-coefficient writer. |
| Tinnitus and hearing | 139–164, 575–607, 1457–1548 | Keep exhaustion thresholds, fades, volume scaling and restoration. ACE Advanced Fatigue continues owning heartbeat audio. |
| Visual-effect policy | 318–373, 1480–1512 | RC4 deliberately cleans up legacy post-processing rather than recreating it. Preserve that current policy even though the older feature description advertises tunnel vision. Do not silently restore blur or aberration during this rebuild. |

## Important tuned values

These are the main-loop fallbacks/shared Balanced values, not a replacement for effective CBA mission/server values. Other presets intentionally override some of them.

| Setting | Preserved value |
| --- | --- |
| Ordinary / fresh sprint / exhausted sprint coefficient | 0.86 / 1.28 / 0.89 |
| Standalone reserve / recovery | 25 s / 10 s |
| Ordinary ramp / nominal loop interval | 0.05 / 0.05 s |
| Brace duration / coefficient / ramp | 0.15 s / 0.42 / 0.575 |
| Settled movement before normal brace / recent sprint cooldown | 2 s / 3 s |
| Non-ACE brace reserve gate / zero-momentum margin | 0.98 / 0.04 |
| Brace-ready movement threshold / forward-release rearm delay | 4 km/h / 0.50 s |
| Gear boundaries | 35 / 55 / 75 displayed lb |
| Light / medium / moderate / heavy brace relief | 0.55 / 0.35 / 0.18 / 0 |
| Slope-brace range / remembered-stop interval | 15–35° / 2.5 s |
| Maximum added slope-brace duration / dip | 0.18 s / 0.28 |
| Shift-release hold / taper / exponent | 1.00 s / 0.85 s / 1.45 |
| Grade magnitude rise / fall smoothing | 22 / 30 degrees per second |
| Minimum sprint/walk coefficient ratio / fresh margin | 1.20 / 0.20 |
| Unarmed sprint normalization | 0.725 |
| ACE acidosis / muscle-damage penalty factors | 0.45 / 0.25 |
| Resting / walking / sprint aim coefficient; recovery | 0.02 / 0.01 / 2.0; 6 s |

The physical sprint speed must still be measured against walking at the same grade and kit. A coefficient ratio alone does not establish metres per second, especially when the selected animation changes. Any optional measured-pace adapter must default to the unchanged legacy calculation until a valid profile is explicitly supplied. It must not replace brace or momentum tuning.

## The ownership boundary

Retaining the custom graph through W+A > A > D > W+D must not turn pure sideways movement into sprint pace. `_isSprinting` continues driving brace transitions, reserve consumption and ordinary targets with its original forward-input requirement. A separate animation-ownership condition may keep compatible directional states available while the ordinary pace calculation handles pure sideways input.

The source-preservation check intentionally permits new animation graph code, new entry/exit ownership, narrow recognition of valid custom movement blends, additional diagnostics, the motion-history helpers and an optional pace adapter between the preserved target calculation and Shift-release taper. It does not protect the failed RC3 animation entry mechanism. The alpha2 adapter is suspended during a brace so physical sprint targets cannot force a sprint pose during the walking push-off.

## Automated preservation check

From the project root:

```powershell
python .\tests\feature_preservation.py --self-test
```

The script carries fixed RC4 reference digests and needs no previous checkout or third-party Python package. It checks exact bytes for presets and the pace model, normalized original settings registrations, 18 intact executable-token blocks and seven blocks after fourteen exact reversals. Alpha4 reversals run before alpha3 and alpha2 reversals. Whitespace/comments may change, and an intact block may move to another function file. Removing a block, changing its retained tuning or preserving it only inside a comment fails.

The mutation self-test deliberately changes brace dip/duration, relief anchor order, reserve gating, Shift taper/window, lateral sprint eligibility, ramp timing/load direction, momentum veto, release-resume veto, brake-target direction, downhill integration and a settings default, and confirms each is rejected. It also confirms that intact extraction is accepted. Reference digests must not be regenerated from the rewritten implementation merely to make the check pass.

Run all fourteen behavioral suites against actual helper source with an installed SQF-VM:

```powershell
python .\tools\run_regressions.py --sqfvm 'C:\tools\sqfvm.exe' --output "$env:TEMP\GAIT-regressions"
```

The runner creates fresh combined scripts from this checkout and records source hashes, commands and full logs. It requires the suite's PASS and completion messages and rejects warnings/errors. It does not execute the live animation commands or model engine physics.

This is a preservation guard, not proof of runtime reachability or engine behavior. It complements SQF parsing, build verification and the movement/controller regression tests. New code must still call the preserved computations in the correct order.

## In-game acceptance cases

1. Start sprinting from standing, ordinary forward movement and actual crouch. Confirm the brief push-off noticeably slows walking before acceleration. Repeat light, medium and heavy kits: heavy starts should have less brace relief, a longer base dip and slower acceleration. Check raised-rifle starts for abrupt pose changes.
2. Release/repress Shift quickly while W stays held, after a brief W release, on a hill and after crouching while still moving. Confirm retained sprint momentum prevents every new brace. After an actual stop or settled recovery, confirm the brace returns.
3. Release Shift while continuing straight forward on flat/downhill travel. Confirm the hold/taper remain smooth and heavy gear retains speed longer than light gear. Re-tap midway through the coast and check for an abrupt animation reset. Release all movement keys, then repeat with A, D and S: direction/stop input must take effect promptly, without forced forward travel. On uphill travel, release Shift and then W: braking should strengthen smoothly with grade. Re-tap during that brake and confirm no extra launch brace or stale carry speed returns.
4. Move W+A > A > D > W+D while holding Turbo on either side of the old steep-grade boundary. Confirm continuous directional control, normal sideways pace and no repeated animation entry or camera snap.
5. Stop/restart uphill and downhill within the slope memory interval. Confirm extra brace duration/dip remain kit-sensitive and match the chosen preset.
6. Repeat with ACE active at reduced reserves: standing step-off still works, ACE fatigue consequences continue, and medical movement restrictions win. Test standalone reserve drain/recovery separately with ACE Advanced Fatigue disabled.
7. Verify carry/pickup, crouch/prone, reload, medical actions, unconsciousness, respawn, remote control and spectator transitions. The new movement controller must release appropriately without resetting unrelated physiology.
8. Compare sustained physical sprint and walk speeds at matched kit and grade, including both sides of ±32°. Repeat downhill with light, medium and heavy kits; gain should build over travel time and vary smoothly with grade, with less bonus under heavier loads. A working graph and preserved tuning do not by themselves prove the speed requirement.
