# GAIT foundation rebuild: feature preservation contract

The movement foundation may change how animation states are entered, selected and released. It must preserve the reviewed RC4 movement tuning and the existing step-off/brace, momentum, reserve, gear, carry, sway and fatigue behavior. A successful static check establishes source preservation, not smooth movement or correct physical speed in Arma.

The reference is the GAIT 1.7.0-rc4 source from this investigation. Line references below identify that baseline, so they remain useful if the new source gains lines or extracts helpers. Unless another file is named, references are to `addons/gait/functions/fn_initSprintSystem.sqf`.

## Protected behavior

| Feature | Baseline code | Contract |
| --- | --- | --- |
| Player configuration and presets | Complete `fn_registerSettings.sqf` and `fn_applyPreset.sqf` | Preserve every registration, range, default, label, preset override and CBA priority. Custom stops preset rewrites; forced mission/server values retain precedence. |
| Live tuning and resets | 527–760, 772–942 | Preserve live setting refresh, preset application, reserve-ratio preservation when capacity changes, and brace/coast/momentum state initialization and reset. |
| Sprint intent | 977–998 | Sprint pace requires held Turbo and positive resolved forward input, eligible movement, non-prone stance and no external sprint/walk lock. Actual crouch remains distinct from a crouch-key press. Animation ownership must use a separate condition. |
| Input resolution | `fn_traversalHelpers.sqf`:8–26 | Preserve opposed-key cancellation, 0.05 deadzone, normalized diagonal input and held-Turbo semantics. TurnLeft/TurnRight are the strafe actions. Do not replace them with rotation actions. |
| Stopped-start step-off | 1229–1333 | When sprint starts, a qualifying settled state or absent sprint momentum arms the brief brace dip before acceleration. No animation-family change may erase this calculation. |
| Actual crouch start | 1235–1245, 1313–1315 | Actual crouch or an armed crouch start permits the brace. Merely pressing crouch is insufficient. Preserve the existing crouch path through sprint intent. |
| Settling and quick Shift taps | 1281–1297 | Normal rearming uses the settled-movement timer, recent-sprint cooldown and reserve gate. The zero-momentum path catches walk-to-sprint starts without waiting for those timers. Retapping Shift while meaningful sprint momentum remains must not manufacture another brace. |
| ACE brace compatibility | 1262–1279 | With ACE Advanced Fatigue active, standing/zero-momentum brace readiness does not require nearly full metabolic reserve. Without ACE, retain the configured reserve threshold for those paths. Actual crouch retains its separate brace path. This exception is essential to standing step-off. |
| Forward-release rearming | 1048–1049 | Track actual forward input and the configured time since it ended. Sideways animation ownership must not rewrite that timer or pretend forward input continues. |
| Gear-dependent brace relief | 1060–1077 | Keep all four relief tiers and the effective-brace formula. Weight scaling is continuous for movement pace; the brace relief keeps its established tiers. |
| Slope stop/restart brace | 1299–1329, 1356–1357 | Keep slope-stop memory, slope severity, additional dip and duration, and the minimum brace coefficient. Both ascent and descent can affect the restart brace through absolute grade. |
| Sprint-end bookkeeping | 1335–1368 | Preserve last-sprint time/grade, clear the active brace, and do not reintroduce a forced post-run weapon/posture correction. |
| Shift-release carry and taper | 1339–1353, 1578–1609 | Releasing Shift while W remains held preserves the current coefficient for the hold window, then eases it toward normal pace with the existing curve. Sideways/backwards input, renewed sprint, ineligibility or external restrictions cancel this forward-only carry. |
| Acceleration/deceleration | 1614–1621; `fn_traversalHelpers.sqf`:28–32 | Keep distinct brace and ordinary ramp strengths, the frame-time adjustment and the ordinary-speed cap for sideways motion and external locks. Do not reset momentum merely because a custom directional state changes. |
| Standalone reserve | 1373–1455 | Keep sprint drain, uphill drain severity, recovery time, exhaustion clamps and temporary fallback before ACE publishes its first reserve. Sideways ownership alone must not count as sprint drain. |
| ACE reserve bridge | 1390–1417 | Read the minimum anaerobic/aerobic reserve with the existing acidosis and muscle-damage penalties. Do not write ACE physiological values. |
| Continuous grade and weight pace | 1085–1223, 1553–1566; complete `fn_slopePaceModel.sqf` | Preserve directional sampling, slope smoothing, uphill decay, downhill bonus, hill-walk penalties, continuous load scaling, fresh/exhausted targets and the sprint/walk coefficient floor. No new slope cutoff may replace the continuous model. |
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

Retaining the custom graph through W+A → A → D → W+D must not turn pure sideways movement into sprint pace. `_isSprinting` continues driving brace transitions, reserve consumption and ordinary targets with its original forward-input requirement. A separate animation-ownership condition may keep compatible directional states available while the ordinary pace calculation handles pure sideways input.

The source-preservation check intentionally permits new animation graph code, new entry/exit ownership, narrow recognition of valid custom movement blends, additional diagnostics and an optional pace adapter between the preserved target calculation and Shift-release taper. It does not protect the failed RC3 animation entry mechanism.

## Automated preservation check

From the project root:

```powershell
python .\tests\feature_preservation.py --self-test
```

The script carries fixed RC4 reference digests and needs no previous checkout or third-party Python package. It checks exact bytes for settings registration, presets and the pace model. It then verifies fixed executable-token fingerprints of protected calculations and state updates across the addon function files. Whitespace/comments may change, and an intact block may move to another function file. Removing a block, changing its tuning or preserving it only inside a comment fails.

The mutation self-test deliberately changes brace dip, brace reserve gating, Shift taper, lateral sprint eligibility, ramp timing and settings content, and confirms each is rejected. It also confirms that intact extraction is accepted. Reference digests must not be regenerated from the rewritten implementation merely to make the check pass.

This is a preservation guard, not proof of runtime reachability or engine behavior. It complements SQF parsing, build verification and the movement/controller regression tests. New code must still call the preserved computations in the correct order.

## In-game acceptance cases

1. Start sprinting from standing, ordinary forward movement and actual crouch. Confirm the established push-off dip and acceleration are retained with light and heavy kits.
2. Release/repress Shift quickly while W stays held. Confirm preserved momentum prevents an unnecessary new brace. After settling, confirm the brace returns.
3. Release Shift while continuing straight forward. Confirm the existing hold and taper remain smooth. Turn sideways/backwards and confirm the forward-only carry ends.
4. Move W+A → A → D → W+D while holding Turbo on either side of the old steep-grade boundary. Confirm continuous directional control, normal sideways pace and no repeated animation entry or camera snap.
5. Stop/restart uphill and downhill within the slope memory interval. Confirm extra brace duration/dip remain kit-sensitive and match the chosen preset.
6. Repeat with ACE active at reduced reserves: standing step-off still works, ACE fatigue consequences continue, and medical movement restrictions win. Test standalone reserve drain/recovery separately with ACE Advanced Fatigue disabled.
7. Verify carry/pickup, crouch/prone, reload, medical actions, unconsciousness, respawn, remote control and spectator transitions. The new movement controller must release appropriately without resetting unrelated physiology.
8. Compare sustained physical sprint and walk speeds at matched kit and grade, including both sides of ±32°. A working graph and preserved tuning do not by themselves prove the speed requirement.
