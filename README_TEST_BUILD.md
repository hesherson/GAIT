# GAIT 1.8.0-alpha18: lowered-pistol continuity and slower sprint acceleration

Requires Arma 3 2.18+, CBA_A3 and ACE3. Load only the new GAIT copy and start a fresh mission. Full build/deploy instructions are in README_HEMTT.md; the packaged mod is under ready_to_load/GAIT.

## What changed

The final sprint-to-jog handoff now has a measured destination pace when a matching reference is available. Normal steady jogging supplies a session-local reference using horizontal velocity divided by the applied animation coefficient. Measurements require settled motion, ground contact, an eligible healthy character, a clear path and no active brace/release/vegetation penalty. References match the clip/config, character, weapon, surface and a narrow grade band and expire after ten minutes. No guessed km/h values are bundled.

Hold W and release Shift: the controller captures current speed and eases toward jog pace with the current weight-tier release window. Speed continuity does not own direction. Pressing A or D during the numerical release immediately retires the old directional identity while carrying the exact current coefficient into ordinary locomotion. Sprint-entry redirection now also works during the earliest native-source frames, before Arma reports the custom blend, so lateral input cannot be queued behind the initial forward sprint request.

All alpha17 crouch and strafe ownership fixes remain. Alpha18 fixes the remaining secondary-weapon-only acceleration pause by making lowered pistol locomotion (`SlowWpst`) a first-class GAIT family instead of converting every handgun into raised-pistol `SrasWpst`. The current native handgun pose is read from animationState first, then weaponLowered only as fallback, and the selected pose family remains latched through sprint acceleration. `SlowWpst` now has its own jog, sprint, lateral sprint and stop states plus its own `PistolLowStandActions`-derived action maps. GAIT also rejects internal `SlowWpst <-> SrasWpst` locomotion handoffs so a mid-ramp gun-pose correction cannot be introduced by the movement controller. Upward sprint acceleration is slower globally: the existing speed-ramp value is passed through a fixed 0.70 sprint-acceleration rate, stretching the default ~95% convergence from about 2.9 seconds to about 4.1 seconds without changing release, braking or ordinary movement timing.

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

1. Test the secondary weapon separately. Begin from both a naturally lowered handgun state (`SlowWpst`) and a raised handgun state (`SrasWpst`), then sprint from rest through full speed. A lowered pistol must remain in the `SlowWpst` GAIT family for the entire acceleration instead of briefly converting to raised pistol; there must be no pause before full speed. Repeat with A/D throughout the ramp. Then compare rifle and unarmed starts to confirm their behavior is unchanged.
2. On flat ground with default speed-ramp settings, sprint acceleration should now build noticeably slower and continuously toward maximum speed, reaching roughly 95% of the target in about 4.1 seconds before load-tier variation. Verify there is no plateau, pause or late snap to top speed. Then release Shift during partial acceleration and at full sprint; release timing should remain unchanged.
3. Tap Shift again during both the release and the animation blend. Repeat release/retap sequences; check for no restart, rebrace or stale top-speed value.
4. While running and sprinting at low, mid and near-full speed, press Crouch/MoveUp with W still held. The character should bend into crouched running the same way vanilla Arma does: no abrupt stop, no standstill detour and no visible coefficient snap during the bend. Repeat during W+A/W+D, during the acceleration ramp, during sprint release, and with Prone. After the low-stance state has settled, GAIT may relinquish the carried coefficient normally.
5. Hold only W on shallow slopes and at the engine's ~32 degree forced-walk threshold, uphill and downhill. The animation must remain Mrun/jog rather than Mwlk/walk. On a calibrated pace reference the ordinary slope jog target must remain only slightly above the matching walk pace (6% floor). Then repeat the alpha14 zero-momentum uphill brace and 100–150 lb steep-downhill 30+ km/h tests.
6. Repeat immediately after mission start, before calibration, and after changing surface/weapon. The existing release must remain available when no valid reference exists.

For a read-only capture, copy tests/foundation_capture.sqf into a saved Eden mission and run locally:

```sqf
[90, "alpha18 lowered pistol + slower ramp"] execVM "foundation_capture.sqf";
```

Send the RPT after STOP with approximate issue times. Its releaseMotion fields include whether a measured release was selected, reference count and the current handoff state.

## Verification

Run VERIFY_READY.ps1 to validate the bundled PBO prefixes, checksums and all eighteen runtime scripts against source. Core prefix is gait; heartbeat prefix is z\gait\addons\heartbeat.

Automated evidence is in tests/VALIDATION_FOUNDATION.txt and tests/VALIDATION_RESULTS.json. SQF model/lifecycle tests, static settings/graph checks and a clean build do not replace Arma acceptance for physical velocity, interpolation, stopping distance or perceived sound/visuals.
