# GAIT response correction: feature preservation contract

Alpha5 follows the corrected user requirements: gear may slow acceleration and deepen the existing launch brace, but gear alone must never force walking. Sprint-release momentum is allowed only while resolved forward input remains held. Stopping and turning must remain prompt; holding a stale forward animation is not a momentum feature. The original relief tiers and base brace duration are restored. The alpha3 uphill release brake remains intact. A successful source check does not establish animation smoothness or physical speed in Arma.

The reference is GAIT 1.7.0-rc4 from this investigation. The fixed historical hashes are retained. Unless another file is named, baseline line references below identify `addons/gait/functions/fn_initSprintSystem.sqf` in RC4.

## Authorized changes through alpha5

The guard retains all 25 original RC4 block hashes and all three file reference hashes. Nineteen executable blocks remain intact; six require fourteen exact reversals. Changes are allowed only as exact reviewed fragments that are reversed in memory before comparison with RC4. A missing fragment, additional edit, reordered relief tier or retuned preserved value fails. Reference hashes must never be regenerated from current code to silence failures.

| Area | Authorized change | What stays protected |
| --- | --- | --- |
| Initialization and reset | Release-time coast snapshots and new momentum/brake/controller ownership state. | Original setting reads, values, resets and preset selection. |
| Gear and launch brace | Restore the exact original tier selection and base launch duration after alpha4's excessive changes. | All four relief values, tier boundaries, effective-brace formula, base duration, slope additions and minimum coefficient. |
| Downhill speed | Retain the alpha2 sustained, load-aware bonus. | Directional grade sampling, smoothing, uphill targets, trips and hill-walk policy. |
| Brace readiness | Recognize actual stopped movement, veto a repeated launch brace during established momentum, and avoid a second brace when resuming the uphill release brake. | Original reserve gate, slope memory, dip formula and sprint-end bookkeeping. |
| Forward sprint release | Replace the long hold and trailing coefficient lag with a short, bounded taper that requires forward input. | Direction, eligibility, external restriction, sprint-resume and uphill-brake precedence. |
| Speed ramp | Mild load-dependent sprint acceleration; original ordinary response elsewhere; a direct finite forward-release taper. | Frame-time response, launch-brace snap, uphill braking and ACE carrying. |

Alpha5 deliberately removes the alpha4 exceptions for interpolated brace relief and multiplied launch duration. The relief block is intact again, and original launch duration is protected without an exception. Exact integration exceptions for the short release taper and acceleration helper are recorded in `feature_preservation.py`; separate behavioral suites check their bounds and input policy.

`fn_applyPreset.sqf` and `fn_slopePaceModel.sqf` remain byte-identical to RC4. Settings registration allows the two alpha2 description edits, one associated display-label edit and two new sliders, plus one alpha3 uphill-release checkbox. Alpha5 also updates four release-setting descriptions and marks the saved sustain setting inactive. Reversing those edits must reproduce the fixed RC4 registration token digest. Every original range, default, category, callback and CBA priority rule remains protected.

The active forward release has no hold and lasts 0.20–0.65 seconds, approximately 0.38–0.49 seconds at the stored 0.85-second default. The sprint acceleration scale remains between 0.90 and 1.00; ordinary deceleration and launch duration use their original scale of 1.00. These are animation-coefficient timings, not measured physical stopping distances.

The two added sliders retain their 0.12 unloaded sustained downhill bonus and 2.5-second momentum build defaults. The added uphill-release checkbox remains enabled by default and uses the original slope-brace angles, duration, dip and ramp tuning.

Animation ownership may remain in a compatible family during a brief forward sprint release and re-tap. Live input is authoritative when stopping, strafing or reversing. Issued entries retain only bounded cancellation ownership; cancellation must use current input and yield to unrelated full-body actions. The coast ends on its finite deadline, without a residual six-second family lease. These controller additions sit outside historical feature blocks and require separate behavioral and in-game checks.

## Protected behavior

| Feature | Baseline code | Contract |
| --- | --- | --- |
| Player configuration and presets | Existing registrations in `fn_registerSettings.sqf`; complete `fn_applyPreset.sqf` | Preserve original ranges, defaults, preset overrides and CBA priority. Only the reviewed alpha2/alpha5 labels and descriptions, two added sliders and uphill-release checkbox above may differ. Custom stops preset rewrites; forced mission/server values retain precedence. |
| Live tuning and resets | 527–760, 772–942 | Preserve live setting refresh, preset application, reserve-ratio preservation when capacity changes, and existing state initialization and reset. Reset also clears movement-history, uphill-brake and coast ownership state. |
| Sprint intent | 977–998 | Sprint pace requires held Turbo and positive resolved forward input, eligible movement, non-prone stance and no external sprint/walk lock. Actual crouch remains distinct from a crouch-key press. Animation ownership must use a separate condition. |
| Input resolution | `fn_traversalHelpers.sqf`:8–26 | Preserve opposed-key cancellation, 0.05 deadzone, normalized diagonal input and held-Turbo semantics. TurnLeft/TurnRight are the strafe actions. Do not replace them with rotation actions. |
| Stopped-start step-off | 1229–1333 | Without retained sprint momentum, a qualifying settled state arms the brief brace dip. Alpha5 restores the original base duration; dip, minimum speed and added slope duration/dip remain intact. Compatible walking states carry the visible push-off. |
| Actual crouch start | 1235–1245, 1313–1315 | Actual crouch or an armed crouch start permits the brace when retained sprint momentum is absent. Merely pressing crouch is insufficient. Preserve the existing crouch path through sprint intent. |
| Settling and quick Shift taps | 1281–1297 | Normal rearming uses the settled-movement timer, recent-sprint cooldown and reserve gate. The zero-momentum path catches walk-to-sprint starts without waiting for those timers. Established actual sprint travel now vetoes every brace cause, including crouch and remembered slope stops, until a real stop or settled recovery. Retapping Shift during retained movement must not manufacture another brace. |
| ACE brace compatibility | 1262–1279 | With ACE Advanced Fatigue active, standing/zero-momentum brace readiness does not require nearly full metabolic reserve. Without ACE, retain the configured reserve threshold for those paths. Actual crouch retains its separate brace path. This exception is essential to standing step-off. |
| Forward-release rearming | 1048–1049 | Track actual forward input and the configured time since it ended. Sideways animation ownership must not rewrite that timer or pretend forward input continues. |
| Gear-dependent brace relief | 1060–1077 | Keep the exact original four relief tiers, configured boundaries and effective-brace formula. Heavy gear retains the original deeper dip; no extra duration multiplier is added. |
| Slope stop/restart brace | 1299–1329, 1356–1357 | Keep slope-stop memory, slope severity, additional dip and duration, and the minimum brace coefficient. Both ascent and descent can affect a restart after momentum has ended. A recent slope stop cannot override established retained momentum for a new launch brace. The new release brake is a separate event and intentionally slows a moving uphill body. |
| Sprint-end bookkeeping | 1335–1368 | Preserve last-sprint time/grade, clear the active brace, and do not reintroduce a forced post-run weapon/posture correction. |
| Shift-release carry and taper | 1339–1353, 1578–1609 | Only with forward input held, use a short release-time taper with no full-speed hold. Heavy gear can taper slightly longer than light gear within the same short bound. Uphill severity shortens the window and caps stored speed at the post-brake coefficient. Forward release, pure sideways/backwards input, renewed sprint, ineligibility or external restrictions cancel forward-only carry. Forward diagonals remain valid. There is no trailing exponential slowdown after the finite taper. |
| Acceleration/deceleration | 1614–1621; `fn_traversalHelpers.sqf`:28–32 | Keep the original base ramp setting, frame-time adjustment and sideways/external-lock speed caps. Alpha5 limits extra load scaling to mild sprint acceleration while preserving ordinary response, launch-brace snap, uphill braking and ACE-carry ramp behavior. Short forward-release tapering takes precedence over the ordinary exponential response. Do not reset momentum merely because a custom directional state changes. |
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
| Stored Shift-release hold / taper / exponent settings | 1.00 s / 0.85 s / 1.45; alpha5 bounds the active release window |
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

The script carries fixed RC4 reference digests and needs no earlier checkout or third-party Python package. It checks original presets and slope pace bytes, normalized original settings registrations and all 25 executable-token blocks after exact authorized reversals. Comments and whitespace may change; a block preserved only in comments fails.

The mutation self-test changes brace dip/duration, original relief selection, reserve gating, release-taper input and completion behavior, lateral sprint eligibility, ramp timing, momentum veto, uphill resume/brake behavior, downhill integration and a settings default. Each mutation must be rejected. Intact extraction to a helper must remain accepted.

Run all fourteen behavioral suites against actual helper source with an installed SQF-VM:

```powershell
python .\tools\run_regressions.py --sqfvm 'C:\tools\sqfvm.exe' --output "$env:TEMP\GAIT-regressions"
```

The runner creates fresh combined scripts from this checkout and records source hashes, commands and full logs. It requires the suite's PASS and completion messages and rejects warnings/errors. It does not execute the live animation commands or model engine physics.

This is a preservation guard, not proof of runtime reachability or engine behavior. It complements SQF parsing, build verification and the movement/controller regression tests. New code must still call the preserved computations in the correct order.

## In-game acceptance cases

1. Start sprinting from standing, ordinary forward movement and actual crouch. Confirm the brief push-off noticeably slows walking before acceleration. Repeat light, medium and heavy kits: heavy starts should retain the original lower brace relief and slightly slower acceleration, with the original base dip duration. Heavy kits must still enter genuine sprint while sprint and forward are held. Check raised-rifle starts for abrupt pose changes.
2. Release/repress Shift quickly while W stays held, after a brief W release, on a hill and after crouching while still moving. Confirm an established sprint re-tap does not create a second launch brace. Releasing W must cancel scalar coasting; after an actual stop or settled recovery, confirm the brace returns.
3. Release Shift while continuing straight forward on flat/downhill travel. Confirm the brief taper remains smooth and slightly longer for heavy gear than light gear, with no full-speed hold or long tail. Re-tap midway through the coast and check for an abrupt animation reset. Release all movement keys, then repeat with A, D and S: stop/direction input must take effect promptly through a short blend, without continuing the forward speed boost or blocking lateral input. On uphill travel, release Shift and then W: braking should strengthen smoothly with grade. Re-tap during that brake and confirm no extra launch brace or stale carry speed returns.
4. Move W+A > A > D > W+D while holding Turbo on either side of the old steep-grade boundary. Confirm continuous directional control, normal sideways pace and no repeated animation entry or camera snap.
5. Stop/restart uphill and downhill within the slope memory interval. Confirm extra brace duration/dip remain kit-sensitive and match the chosen preset.
6. Repeat with ACE active at reduced reserves: standing step-off still works, ACE fatigue consequences continue, and medical movement restrictions win. Test standalone reserve drain/recovery separately with ACE Advanced Fatigue disabled.
7. Verify carry/pickup, crouch/prone, reload, medical actions, unconsciousness, respawn, remote control and spectator transitions. The new movement controller must release appropriately without resetting unrelated physiology.
8. Compare sustained physical sprint and walk speeds at matched kit and grade, including both sides of ±32°. Repeat downhill with light, medium and heavy kits; gain should build over travel time and vary smoothly with grade, with less bonus under heavier loads. A working graph and preserved tuning do not by themselves prove the speed requirement.
