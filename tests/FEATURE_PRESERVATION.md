# GAIT alpha7 fatigue feedback: feature preservation contract

Alpha7 removes all GAIT aim-coefficient and native-fatigue writes, adds intermittent peripheral fatigue cues, halves the seven ACE heartbeat samples' gain, and increases heavy-kit acceleration by 2%. The alpha6 brief brace inside the running animation, original brace duration/dip, short forward-only release taper, slope targets and animation graph remain. The alpha3 uphill release brake remains intact. These source and helper checks cannot establish aim feel, rendered appearance, perceived loudness or physical speed in Arma.

The reference is GAIT 1.7.0-rc4 from this investigation. The fixed historical hashes are retained. Unless another file is named, baseline line references below identify `addons/gait/functions/fn_initSprintSystem.sqf` in RC4.

## Authorized changes through alpha7

The guard retains all 25 original RC4 block hashes and all three file reference hashes. Fourteen executable blocks remain intact; eleven require twenty-six exact reversals. Changes are allowed only as exact reviewed fragments that are reversed in memory before comparison with RC4. A missing fragment, additional edit, reordered relief tier or retuned preserved value fails. Reference hashes must never be regenerated from current code to silence failures.

| Area | Authorized change | What stays protected |
| --- | --- | --- |
| Initialization and reset | Release-time coast snapshots and new momentum/brake/controller ownership state; remove retired sway/native-fatigue state and add visual cleanup. | Every shared movement/trip initializer, retained setting read, reserve reset and preset selection. |
| Gear and launch brace | Preserve original tier selection; multiply bounded relief by 0.20 for a similar visible brace across tiers. The brace is numerical within the running clip. | All four configured relief values, tier boundaries, base dip/duration/ramp, slope additions and minimum coefficient. |
| Native stamina ownership | Restore the original mod's native stamina suspension while GAIT owns eligible movement. Release that ownership before trips and during reset or player replacement. | External sprint/walk restrictions, ACE source masks and physiological values. The previously enabled stamina flag is restored when ownership ends. |
| Downhill speed | Retain the alpha2 sustained, load-aware bonus. | Directional grade sampling, smoothing, uphill targets, trips and hill-walk policy. |
| Brace readiness | Recognize actual stopped movement, veto a repeated launch brace during established momentum, and avoid a second brace when resuming the uphill release brake. | Original reserve gate, slope memory, dip formula and sprint-end bookkeeping. |
| Forward sprint release | Replace the long hold and trailing coefficient lag with a short, bounded taper that requires forward input. | Direction, eligibility, external restriction, sprint-resume and uphill-brake precedence. |
| Speed ramp | Heavy acceleration is now 2% above the original rate; light remains up to 6% faster. Ordinary response and the finite forward-release taper remain unchanged. | Frame-time response, launch-brace snap, uphill braking and ACE carrying. |
| Weapon handling | Remove the entire GAIT sway loop, all startup/disabled/reset aim writes, six sway controls, seven sway preset entries, and native-fatigue writes plus their dead arithmetic/settings/preset entry. | Native/ACE weapon handling, ACE physiology, GAIT local reserve and all shared movement/trip state. |
| Fatigue visuals | Replace the retired visual toggle with a brief vignette, refreshed each tick and supervised independently. Suspend only ACE Advanced Fatigue's published blackout handle during valid visual ownership. | Existing legacy-handle cleanup, owned handle restoration, medical effects and clear intervals between pulses. |
| Heartbeat audio | Optional config addon halves gain for all seven ACE Medical Feedback heartbeat variants. | Sample paths, pitch, ACE playback logic, unrelated sounds and standalone operation without ACE. |

The original launch duration is protected without a tier multiplier. Alpha6 deliberately compresses the relief contribution, while preserving configured relief values and their tier selection. The exact formula and trip-cleanup deltas are recorded in `feature_preservation.py`, alongside the retained release taper and acceleration integration. Separate behavioral suites check their bounds and input policy.

`fn_slopePaceModel.sqf` remains byte-identical to RC4. The complete original preset-file digest is retained: six exact byte reversals restore the eight removed sway/native-fatigue entries before comparison. Every other preset byte remains protected. Settings registration keeps the exact earlier alpha2-alpha6 revisions and permits only the reviewed alpha7 removals, replacement visual toggle, category changes and descriptions. Reversing those edits must reproduce the fixed RC4 registration token digest. Remaining ranges, defaults, callbacks and CBA priority rules remain protected.

The active forward release has no hold and lasts 0.15-0.45 seconds, approximately 0.27-0.34 seconds at the stored 0.85-second default. The sprint acceleration scale varies continuously from 1.06 at zero load, through 1.04 at 35 lb and 1.02 at 55 lb, remaining at 1.02 for heavier loads. Ordinary response and launch duration retain their original scales. These are animation-coefficient timings, not measured physical stopping distances.

The two added sliders retain their 0.12 unloaded sustained downhill bonus and 2.5-second momentum build defaults. The added uphill-release checkbox remains enabled by default and uses the original slope-brace angles, duration, dip and ramp tuning.

The custom graph has 36 directional sprint/idle states and no walking-brace family. Entry and exit issue one `playMoveNow` request through explicit interpolation edges. Sprint release starts an ordinary animation transition immediately, independently of the short coefficient taper. A new sprint press can replace an issued exit during its exact recognized blend. It cannot repeatedly reassert an animation while sprint stays held. Live stop/strafe/reverse input and unrelated full-body actions remain authoritative. These controller additions sit outside historical feature blocks and require separate behavioral and in-game checks.

## Protected behavior

| Feature | Baseline code | Contract |
| --- | --- | --- |
| Player configuration and presets | Existing registrations in `fn_registerSettings.sqf`; complete `fn_applyPreset.sqf` | Preserve retained ranges, defaults, preset overrides and CBA priority after the exact authorized revisions through alpha7 listed above. Custom stops preset rewrites; forced mission/server values retain precedence. |
| Live tuning and resets | 527–760, 772–942 | Preserve live setting refresh, preset application, reserve-ratio preservation when capacity changes, and existing state initialization and reset. Reset also clears movement-history, uphill-brake and coast ownership state. |
| Sprint intent | 977–998 | Sprint pace requires held Turbo and positive resolved forward input, eligible movement, non-prone stance and no external sprint/walk lock. Actual crouch remains distinct from a crouch-key press. Animation ownership must use a separate condition. |
| Input resolution | `fn_traversalHelpers.sqf`:8–26 | Preserve opposed-key cancellation, 0.05 deadzone, normalized diagonal input and held-Turbo semantics. TurnLeft/TurnRight are the strafe actions. Do not replace them with rotation actions. |
| Stopped-start step-off | 1229–1333 | Without retained sprint momentum, a qualifying settled state arms the brief brace dip. The original base duration, dip, minimum speed and added slope duration/dip remain intact. The running animation begins at entry and carries the numerical brace; there is no separate walking stage. |
| Actual crouch start | 1235–1245, 1313–1315 | Actual crouch or an armed crouch start permits the brace when retained sprint momentum is absent. Merely pressing crouch is insufficient. Preserve the existing crouch path through sprint intent. |
| Settling and quick Shift taps | 1281–1297 | Normal rearming uses the settled-movement timer, recent-sprint cooldown and reserve gate. The zero-momentum path catches walk-to-sprint starts without waiting for those timers. Established actual sprint travel vetoes every brace cause until a real stop or settled recovery. Recovery is measured against the intended ordinary coefficient after the original grace/settle windows; a native W-only jog above 2 m/s cannot permanently suppress light-kit bracing. A short moving sprint retap must not create another brace. |
| ACE brace compatibility | 1262–1279 | With ACE Advanced Fatigue active, standing/zero-momentum brace readiness does not require nearly full metabolic reserve. Without ACE, retain the configured reserve threshold for those paths. Actual crouch retains its separate brace path. This exception is essential to standing step-off. |
| Forward-release rearming | 1048–1049 | Track actual forward input and the configured time since it ended. Sideways animation ownership must not rewrite that timer or pretend forward input continues. |
| Gear-dependent brace relief | 1060–1077 | Keep the original four relief settings and configured boundaries. Clamp the selected relief to 0-1 and apply it at 20% strength within the original formula. Heavy gear retains the original full dip; all tiers brace for the same base duration. |
| Slope stop/restart brace | 1299–1329, 1356–1357 | Keep slope-stop memory, slope severity, additional dip and duration, and the minimum brace coefficient. Both ascent and descent can affect a restart after momentum has ended. A recent slope stop cannot override established retained momentum for a new launch brace. The new release brake is a separate event and intentionally slows a moving uphill body. |
| Sprint-end bookkeeping | 1335–1368 | Preserve last-sprint time/grade, clear the active brace, and do not reintroduce a forced post-run weapon/posture correction. |
| Shift-release carry and taper | 1339–1353, 1578–1609 | Only with forward input held, use a short release-time taper with no full-speed hold. Heavy gear can taper slightly longer than light gear within the same short bound. Uphill severity shortens the window and caps stored speed at the post-brake coefficient. Forward release, pure sideways/backwards input, renewed sprint, ineligibility or external restrictions cancel forward-only carry. Forward diagonals remain valid. There is no trailing exponential slowdown after the finite taper. |
| Acceleration/deceleration | 1614–1621; `fn_traversalHelpers.sqf`:28–32 | Keep the original base ramp setting, frame-time adjustment and sideways/external-lock speed caps. Extra scaling applies only to sprint acceleration, from a 2% heavy-kit boost to a 6% unloaded boost. Ordinary response, launch-brace snap, uphill braking and ACE-carry behavior remain intact. Short forward-release tapering takes precedence over the ordinary exponential response. Do not reset momentum merely because a custom directional state changes. |
| Standalone reserve | 1373–1455 | Keep sprint drain, uphill drain severity, recovery time, exhaustion clamps and temporary fallback before ACE publishes its first reserve. Sideways ownership alone must not count as sprint drain. |
| ACE reserve bridge | 1390–1417 | Read the minimum anaerobic/aerobic reserve with the existing acidosis and muscle-damage penalties. Do not write ACE physiological values. |
| Continuous grade and weight pace | 1085–1223, 1553–1566; complete `fn_slopePaceModel.sqf` | Preserve directional sampling, slope smoothing, uphill decay, hill-walk penalties, continuous load scaling, fresh/exhausted targets and the sprint/walk coefficient floor. The downhill bonus is intentionally replaced with sustained, angle-dependent, load-scaled gain that tapers on extreme descents. No new slope cutoff may replace the continuous model. |
| ACE carrying | 971–975, 1568–1573 | Keep independent carry walk/fresh-sprint/exhausted-sprint targets. Ordinary custom sprint animation ownership must not take over ACE carry or pickup animations. |
| Unarmed normalization | 1553–1556 | Keep the existing unarmed multiplier; holstering must not silently grant a different movement profile. |
| Vegetation drag | `fn_nativeController.sqf`:89–104, 114 | Preserve bush-distance weighting, maximum drag, 0.4 s query interval and multiplication into the single speed-coefficient write. |
| Downhill trip risk | 1024–1046, 1125–1198 | Keep the slope/speed/weight factors, sustained-movement gates, cooldown/immunity and chance-per-second calculation. Directional graph membership does not itself imply a valid sprint. |
| Trip recovery | 205–260 | Keep the trip impulse, minimum ragdoll interval, actual horizontal-speed recovery check and maximum duration. Release native stamina ownership before tripping; preserve ACE unconsciousness when releasing GAIT's trip. |
| Landing feedback | 1000–1009 | Preserve the ground-contact transition, vertical-speed threshold and severity-scaled camera shake. |
| Weapon sway | 377–506 | Remove all GAIT sway control as requested. Preserve shared movement/trip initialization from this block. The guard rejects executable aim-coefficient, native-fatigue or recoil writers in every GAIT function, including cleanup paths. |
| Tinnitus and hearing | 139–164, 575–607, 1457–1548 | Keep exhaustion thresholds, fades, volume scaling and restoration. ACE Medical Feedback continues owning heartbeat playback; the optional config patch scales only its seven heartbeat gains by 0.5. |
| Visual-effect policy | 318–373, 1480–1512 | Keep the legacy cleanup and add only the requested intermittent vignette. Pulses have a fixed 1.30-second envelope, peak edge opacity capped at 14%, and at least 5 seconds fully clear between pulses. Recovery and context/ownership loss destroy the vignette; stale caller updates expire after 0.75 seconds. No blur or chromatic aberration is recreated. |

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
| Light / medium / moderate / heavy configured brace relief | 0.55 / 0.35 / 0.18 / 0; applied at 20% strength since alpha6 |
| Slope-brace range / remembered-stop interval | 15–35° / 2.5 s |
| Maximum added slope-brace duration / dip | 0.18 s / 0.28 |
| Stored Shift-release hold / taper / exponent settings | 1.00 s / 0.85 s / 1.45; sustain is inactive and the active release window remains bounded |
| Grade magnitude rise / fall smoothing | 22 / 30 degrees per second |
| Minimum sprint/walk coefficient ratio / fresh margin | 1.20 / 0.20 |
| Unarmed sprint normalization | 0.725 |
| ACE acidosis / muscle-damage penalty factors | 0.45 / 0.25 |

The physical sprint speed must still be measured against walking at the same grade and kit. A coefficient ratio alone does not establish metres per second, especially when the selected animation changes. Any optional measured-pace adapter must default to the unchanged legacy calculation until a valid profile is explicitly supplied. It must not replace brace or momentum tuning.

## The ownership boundary

Retaining the custom graph through W+A > A > D > W+D must not turn pure sideways movement into sprint pace. `_isSprinting` continues driving brace transitions, reserve consumption and ordinary targets with its original forward-input requirement. A separate animation-ownership condition may keep compatible directional states available while the ordinary pace calculation handles pure sideways input.

The source-preservation check intentionally permits new animation graph code, new entry/exit ownership, narrow recognition of valid custom movement blends, additional diagnostics, the motion-history helpers and an optional pace adapter between the preserved target calculation and Shift-release taper. It does not protect the failed RC3 animation entry mechanism. The optional measured-pace adapter stays suspended during bracing so it cannot override the requested dip.

Native stamina ownership uses eligible movement context, independently of an animation frame or current sprint permission. It runs before the active-context and engine-permission gates, avoiding a circular prerequisite for heavy-kit entry. Temporary animation handoffs do not restore native stamina. Mode/context exit, reset, trips and player replacement release the saved ownership. Cleanup does not enable stamina that was already disabled on acquisition and does not reset fatigue or erase medical restrictions. The helper suite mocks only the engine boundary; four executable-fragment assertions separately protect acquisition ordering and cleanup call sites.

The fatigue vignette watchdog reads a fresh main-loop request on each rendered frame. A missing request, a 0.75-second stale lease or invalid body/camera context releases both visual owners. The vignette handle is destroyed at pulse end and during every clear interval; recovery/reentry keeps the cooldown so rapid toggles cannot create a permanent series of pulses. The separate ACE bridge changes only the published Advanced Fatigue blackout handle, remembers its prior enabled state and restores it when ownership ends. Replaced/deleted numeric handles are not queried or restored. Medical/pain effects remain outside GAIT ownership.

## Automated preservation check

From the project root:

```powershell
python .\tests\feature_preservation.py --self-test
```

The script carries fixed RC4 reference digests and needs no earlier checkout or third-party Python package. It checks original slope pace bytes, restored original preset bytes, normalized original settings registrations and all 25 executable-token blocks after exact authorized reversals. It also checks four stamina and nine visual lifecycle integration fragments and rejects executable GAIT aim/fatigue/recoil writers. Comments and whitespace may change; a block preserved only in comments fails.

The mutation self-test changes brace dip/duration, original relief selection and the new relief scale, reserve gating, release-taper input and completion behavior, lateral sprint eligibility, ramp timing, momentum veto, uphill resume/brake behavior, downhill integration and a settings default. It also removes stamina acquisition/reset cleanup, visual watchdog startup, unconditional lease refresh, reset cleanup, ACE feedback restoration and the native/ACE incapacitation and trip context guard; separate probes reintroduce forbidden aim/fatigue/recoil writers. Each mutation must be rejected. Intact extraction to a helper must remain accepted.

Run all seventeen behavioral suites against actual helper source with an installed SQF-VM:

```powershell
python .\tools\run_regressions.py --sqfvm 'C:\tools\sqfvm.exe' --output "$env:TEMP\GAIT-regressions"
```

The runner creates fresh combined scripts from this checkout and records source hashes, commands and full logs. It requires the suite's PASS and completion messages and rejects warnings/errors. It does not execute the live animation commands or model engine physics.

This is a preservation guard, not proof of runtime reachability or engine behavior. It complements SQF parsing, build verification and the movement/controller regression tests. New code must still call the preserved computations in the correct order.

## In-game acceptance cases

1. Start sprinting from standing, ordinary forward movement and actual crouch. The run animation should begin immediately with the brief numerical brace, then accelerate. Repeat light, medium and heavy kits: each tier must brace for the original base duration, with only small tier differences. Heavy backpacks must still enter genuine sprint while sprint and forward are held. Check raised-rifle starts for abrupt pose changes.
2. Release/repress Shift quickly while W stays held, after a brief W release, on a hill and after crouching while still moving. An established sprint retap must not create a second launch brace. Continue W-only jogging past the original grace and settle periods; the next sprint must brace again, including light gear. Releasing W cancels scalar coasting, and an actual stop restores brace readiness.
3. Release Shift while continuing straight forward on flat/downhill travel. Check immediate animation interpolation into ordinary movement and a smooth, short speed taper, slightly longer for heavy gear than light gear. Retap midway through the exit blend and look for an abrupt pose reset or delayed response. Release all movement keys, then repeat with A, D and S: stop/direction input must take effect promptly through a short blend, without continuing the forward speed boost or blocking lateral input. On uphill travel, release Shift and then W: braking should strengthen smoothly with grade. Retap during that brake and confirm no extra launch brace or stale carry speed returns.
4. Move W+A > A > D > W+D while holding Turbo on either side of the old steep-grade boundary. Confirm continuous directional control, normal sideways pace and no repeated animation entry or camera snap.
5. Stop/restart uphill and downhill within the slope memory interval. Confirm extra brace duration/dip remain kit-sensitive and match the chosen preset.
6. Repeat with ACE active at reduced reserves: standing step-off still works, ACE fatigue consequences continue, and medical movement restrictions win. Test standalone reserve drain/recovery separately with ACE Advanced Fatigue disabled.
7. Verify carry/pickup, crouch/prone, reload, medical actions, unconsciousness, respawn, remote control and spectator transitions. The controller must release appropriately without resetting unrelated physiology. Toggle GAIT off and change player while native stamina ownership is active; verify restoration of the prior enabled flag. Record engine sprint/walk flags, stamina ownership and ACE lock masks if heavy sprint still fails.
8. Compare sustained physical sprint and walk speeds at matched kit and grade, including both sides of ±32°. Repeat downhill with light, medium and heavy kits; gain should build over travel time and vary smoothly with grade, with less bonus under heavier loads. A working graph and preserved tuning do not by themselves prove the speed requirement.

9. Aim down sights while stationary, jogging and recovering from a sprint with ACE on and off. GAIT must issue no aim/fatigue/recoil writes and must not add the previous repeated sway/stop pattern. Test respawn, disabled mode and preset changes as well; these must not reset aim coefficients.
10. Exhaust the reserve and observe a brief subtle peripheral darkening followed by a fully clear interval. Sustained fatigue must not leave GAIT post-processing continuously visible. Recover, toggle the vignette/master setting, change player, enter spectator or become unconscious mid-pulse: owned effects must release promptly. Brief recovery/reentry must preserve the clear interval. A deliberately stalled main updater must clear its vignette within the 0.75-second lease.
11. Repeat with ACE Advanced Fatigue, including its exhaustion blackout condition. While GAIT owns the vignette, only the Advanced Fatigue blackout is suspended; breathing, heartbeat timing, medical effects and physiology continue. Disable GAIT and confirm the prior ACE handle state is restored. Check all seven heartbeat variants if available: sample timing/pitch remain unchanged and configured gain is half the original value. Perceived loudness still requires an in-game listening check.
