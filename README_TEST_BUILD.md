# GAIT 1.8.0-alpha13: immediate sprint-start strafing and progressive uphill slowdown

Requires Arma 3 2.18+, CBA_A3 and ACE3. Load only the new GAIT copy and start a fresh mission. Full build/deploy instructions are in README_HEMTT.md; the packaged mod is under ready_to_load/GAIT.

## What changed

The final sprint-to-jog handoff now has a measured destination pace when a matching reference is available. Normal steady jogging supplies a session-local reference using horizontal velocity divided by the applied animation coefficient. Measurements require settled motion, ground contact, an eligible healthy character, a clear path and no active brace/release/vegetation penalty. References match the clip/config, character, weapon, surface and a narrow grade band and expire after ten minutes. No guessed km/h values are bundled.

Hold W and release Shift: the controller captures current speed and eases toward jog pace with the current weight-tier release window. Speed continuity does not own direction. Pressing A or D during the numerical release immediately retires the old directional identity while carrying the exact current coefficient into ordinary locomotion. Sprint-entry redirection now also works during the earliest native-source frames, before Arma reports the custom blend, so lateral input cannot be queued behind the initial forward sprint request.

Uphill sprint slowdown now has a separate time component. The existing slope start angle, reference angle and maximum penalty still define the final target, but the penalty builds as uphill running continues. Shallow slopes approach that target slowly, while steep slopes converge much faster. Returning toward flat terrain recovers smoothly. Until normal jogging has supplied a valid reference (roughly two seconds of stable travel), the alpha10 release remains the fallback. Changing weapon, surface or grade may require a new reference.

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
4. During the release itself, during the sprint-to-jog body blend, and while entering/exiting the custom family on a steep slope, press W+A, W+D, pure A and pure D. Lateral input must take over immediately without waiting for the old phase or direction. Then release W/all movement keys and repeat with S. Repeat while reloading, changing weapon/stance, entering medical/carry actions and becoming unconscious.
5. Sprint continuously up shallow, moderate and steep hills. Speed should bleed down progressively rather than jump to the full slope penalty: shallow hills should take longer, steep hills should converge faster, and flattening terrain should recover smoothly. Then check heavy backpack sprint access, uphill braking, respawn, spectator, disabled mode and the current 10% heartbeat.
6. Repeat immediately after mission start, before calibration, and after changing surface/weapon. The existing release must remain available when no valid reference exists.

For a read-only capture, copy tests/foundation_capture.sqf into a saved Eden mission and run locally:

```sqf
[90, "alpha13 startup strafe + uphill buildup"] execVM "foundation_capture.sqf";
```

Send the RPT after STOP with approximate issue times. Its releaseMotion fields include whether a measured release was selected, reference count and the current handoff state.

## Verification

Run VERIFY_READY.ps1 to validate the bundled PBO prefixes, checksums and all eighteen runtime scripts against source. Core prefix is gait; heartbeat prefix is z\gait\addons\heartbeat.

Automated evidence is in tests/VALIDATION_FOUNDATION.txt and tests/VALIDATION_RESULTS.json. SQF model/lifecycle tests, static settings/graph checks and a clean build do not replace Arma acceptance for physical velocity, interpolation, stopping distance or perceived sound/visuals.
