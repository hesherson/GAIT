# GAIT 1.8.0-alpha15: stance-safe transitions and no-walk slope jogging

Requires Arma 3 2.18+, CBA_A3 and ACE3. Load only the new GAIT copy and start a fresh mission. Full build/deploy instructions are in README_HEMTT.md; the packaged mod is under ready_to_load/GAIT.

## What changed

The final sprint-to-jog handoff now has a measured destination pace when a matching reference is available. Normal steady jogging supplies a session-local reference using horizontal velocity divided by the applied animation coefficient. Measurements require settled motion, ground contact, an eligible healthy character, a clear path and no active brace/release/vegetation penalty. References match the clip/config, character, weapon, surface and a narrow grade band and expire after ten minutes. No guessed km/h values are bundled.

Hold W and release Shift: the controller captures current speed and eases toward jog pace with the current weight-tier release window. Speed continuity does not own direction. Pressing A or D during the numerical release immediately retires the old directional identity while carrying the exact current coefficient into ordinary locomotion. Sprint-entry redirection now also works during the earliest native-source frames, before Arma reports the custom blend, so lateral input cannot be queued behind the initial forward sprint request.

Uphill sprint slowdown still builds progressively with time, and zero-momentum uphill starts retain the exponential positive-grade brace burden from alpha14. Downhill momentum still builds only from actual descending sprint travel, with calibrated steep descents targeting roughly 34 km/h light and about 32 km/h at 150 lb+. Alpha15 changes transition ownership: Crouch/MoveUp/Prone input creates a short stance-yield lease before stance or animationState visibly changes, clears GAIT's standing transition/coefficient ownership without issuing a stop animation, and leaves the inherited Arma stance graph to execute the input. Ordinary forward movement on any real slope now enters dedicated custom Mrun forward/diagonal states. Walk/Slow/Tact selectors stay in Mrun; only Fast/Turbo forward selectors use Meva. At engine forced-walk angles, W-only movement therefore remains visually jogging and its calibrated physical floor is 6% above the corresponding walk pace.

## Settings pass

The menu has 122 controls, down from 127. Every retained setting has a runtime reader; preset entries refer only to active controls.

| Removed control | Reason / current behavior |
| --- | --- |
| Shift-release sustain duration | Already inactive; the release starts immediately. |
| Secondary downhill onset cap | Consolidated into Downhill boost starts. For custom settings, put the smaller of your former onset and cap into that remaining control. Defaults are unchanged. |
| Reset on respawn | Owned state and effects must always be cleaned up when the player changes. |
| Suspend in spectator | Camera/delegated-control suspension is always active. |
| Suspend while unconscious | Medical suspension is always active. |

The duplicate Full/Hybrid mode is now Movement and effects. Old saved numeric modes 0 and 1 remain compatible. Other choices remain Effects and hearing, Visuals and tinnitus, and Disabled. The release-curve slider now exposes the existing effective 1–3 range; HUD interval starts at the existing 0.05-second minimum. Descriptions now distinguish coefficients from physical speed, nominal timing from bounded release timing, ACE physiology from fallback reserve, and tinnitus from the fixed 10% heartbeat patch.

README_SETTINGS.md lists every current setting, registration default, range and description. Presets and mission/server overrides can change effective values; Custom stops preset rewrites.

## Retained behavior

The shared brief brace, original gear tuning, heavy sprint access, lowered-pistol entry fix, shorter stopping blend, heavy downhill improvement, velocity-based trip risk, 10% ACE heartbeat and intermittent vignette remain. GAIT has no weapon-sway writes. No new terrain-footing or recovery mechanic is added.

## In-game acceptance

1. With rifle, pistol and unarmed movement, start sprinting from rest and immediately press W+A, W+D, pure A and pure D before the sprint blend visibly settles. The weapon/body must redirect immediately instead of pointing forward and queuing the strafe. Repeat raised and lowered pistol starts and repeat on steep uphill terrain.
2. Keep W held and release Shift during partial acceleration and at full sprint. Verify the release starts at the current pace and the final jog handoff has no speed step. Repeat with light, medium and heavy gear, and on a descent after collecting a matching jog reference.
3. Tap Shift again during both the release and the animation blend. Repeat release/retap sequences; check for no restart, rebrace or stale top-speed value.
4. During sprint startup, acceleration, release, sprint-to-jog handoff and steep-slope entry/exit, press Crouch/MoveUp while W remains held. Crouch must register on the first press without GAIT forcing an idle stop first; the body should hand directly to the native crouch transition. Repeat with Prone, with A/D held, and while changing slope. Then repeat the A/D transition tests from alpha14.
5. Hold only W on shallow slopes and at the engine's ~32 degree forced-walk threshold, uphill and downhill. The animation must remain Mrun/jog rather than Mwlk/walk. On a calibrated pace reference the ordinary slope jog target must remain only slightly above the matching walk pace (6% floor). Then repeat the alpha14 zero-momentum uphill brace and 100–150 lb steep-downhill 30+ km/h tests.
6. Repeat immediately after mission start, before calibration, and after changing surface/weapon. The existing release must remain available when no valid reference exists.

For a read-only capture, copy tests/foundation_capture.sqf into a saved Eden mission and run locally:

```sqf
[90, "alpha15 stance yield + no-walk slopes"] execVM "foundation_capture.sqf";
```

Send the RPT after STOP with approximate issue times. Its releaseMotion fields include whether a measured release was selected, reference count and the current handoff state.

## Verification

Run VERIFY_READY.ps1 to validate the bundled PBO prefixes, checksums and all eighteen runtime scripts against source. Core prefix is gait; heartbeat prefix is z\gait\addons\heartbeat.

Automated evidence is in tests/VALIDATION_FOUNDATION.txt and tests/VALIDATION_RESULTS.json. SQF model/lifecycle tests, static settings/graph checks and a clean build do not replace Arma acceptance for physical velocity, interpolation, stopping distance or perceived sound/visuals.
