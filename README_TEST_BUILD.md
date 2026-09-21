# GAIT 1.8.0-alpha17: native running crouch and strafe-safe acceleration

Requires Arma 3 2.18+, CBA_A3 and ACE3. Load only the new GAIT copy and start a fresh mission. Full build/deploy instructions are in README_HEMTT.md; the packaged mod is under ready_to_load/GAIT.

## What changed

The final sprint-to-jog handoff now has a measured destination pace when a matching reference is available. Normal steady jogging supplies a session-local reference using horizontal velocity divided by the applied animation coefficient. Measurements require settled motion, ground contact, an eligible healthy character, a clear path and no active brace/release/vegetation penalty. References match the clip/config, character, weapon, surface and a narrow grade band and expire after ten minutes. No guessed km/h values are bundled.

Hold W and release Shift: the controller captures current speed and eases toward jog pace with the current weight-tier release window. Speed continuity does not own direction. Pressing A or D during the numerical release immediately retires the old directional identity while carrying the exact current coefficient into ordinary locomotion. Sprint-entry redirection now also works during the earliest native-source frames, before Arma reports the custom blend, so lateral input cannot be queued behind the initial forward sprint request.

Uphill/downhill tuning, no-walk slope jogging and the alpha16 pace-locked acceleration remain. Alpha17 fixes two remaining transition ownership issues. Running crouch/prone now keeps the coefficient already on the character while Arma's inherited stance graph performs the bend, so GAIT no longer restores the pre-GAIT coefficient halfway through the transition. The stance lease ends only after a native Pknl/Ppne locomotion state has actually settled or the bounded timeout expires. Sprint strafing now has distinct sprint-owned lateral Mrun states (`_GAITSprint`) instead of reusing the jog-owned lateral states. A/D while Shift is held therefore cannot silently fall into the jog action map. In addition, a raw direction edge during either the entering or active acceleration phase gets one immediate graph retarget on that Draw3D frame; held A/D cannot spam the request.

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

1. With rifle, lowered rifle, pistol and unarmed movement, sprint from rest to full speed. During the entire ramp, repeatedly add/remove A and D, including W+A, W+D, pure A/D and fast A-to-D reversals. Strafe must begin on the input edge without a forward-only delay, gun-up wait or queued movement. Sprint-owned lateral states should remain `_GAITSprint`, and returning forward while Shift is still held must go directly back to Meva.
2. Keep W held and release Shift during partial acceleration and at full sprint. Verify the release starts at the current pace and the final jog handoff has no speed step. Repeat with light, medium and heavy gear, and on a descent after collecting a matching jog reference.
3. Tap Shift again during both the release and the animation blend. Repeat release/retap sequences; check for no restart, rebrace or stale top-speed value.
4. While running and sprinting at low, mid and near-full speed, press Crouch/MoveUp with W still held. The character should bend into crouched running the same way vanilla Arma does: no abrupt stop, no standstill detour and no visible coefficient snap during the bend. Repeat during W+A/W+D, during the acceleration ramp, during sprint release, and with Prone. After the low-stance state has settled, GAIT may relinquish the carried coefficient normally.
5. Hold only W on shallow slopes and at the engine's ~32 degree forced-walk threshold, uphill and downhill. The animation must remain Mrun/jog rather than Mwlk/walk. On a calibrated pace reference the ordinary slope jog target must remain only slightly above the matching walk pace (6% floor). Then repeat the alpha14 zero-momentum uphill brace and 100–150 lb steep-downhill 30+ km/h tests.
6. Repeat immediately after mission start, before calibration, and after changing surface/weapon. The existing release must remain available when no valid reference exists.

For a read-only capture, copy tests/foundation_capture.sqf into a saved Eden mission and run locally:

```sqf
[90, "alpha17 crouch + strafe ownership"] execVM "foundation_capture.sqf";
```

Send the RPT after STOP with approximate issue times. Its releaseMotion fields include whether a measured release was selected, reference count and the current handoff state.

## Verification

Run VERIFY_READY.ps1 to validate the bundled PBO prefixes, checksums and all eighteen runtime scripts against source. Core prefix is gait; heartbeat prefix is z\gait\addons\heartbeat.

Automated evidence is in tests/VALIDATION_FOUNDATION.txt and tests/VALIDATION_RESULTS.json. SQF model/lifecycle tests, static settings/graph checks and a clean build do not replace Arma acceptance for physical velocity, interpolation, stopping distance or perceived sound/visuals.
