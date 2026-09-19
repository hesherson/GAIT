# GAIT 1.8.0-alpha11: measured speed handoffs and settings cleanup

Requires Arma 3 2.18+, CBA_A3 and ACE3. Load only the new GAIT copy and start a fresh mission. Full build/deploy instructions are in README_HEMTT.md; the packaged mod is under ready_to_load/GAIT.

## What changed

The final sprint-to-jog handoff now has a measured destination pace when a matching reference is available. Normal steady jogging supplies a session-local reference using horizontal velocity divided by the applied animation coefficient. Measurements require settled motion, ground contact, an eligible healthy character, a clear path and no active brace/release/vegetation penalty. References match the clip/config, character, weapon, surface and a narrow grade band and expire after ten minutes. No guessed km/h values are bundled.

Hold W and release Shift: the controller captures current speed, calculates the jog endpoint in the running clip's units, and performs the existing short release. During the native animation blend, the same coefficient writer compensates for the two clips' measured pace and reported blend weight. Shift retaps resume from the remaining pace without a new brace. Stops, changed direction and unsafe movement contexts cancel the bridge. Its maximum lifetime is half a second.

Until normal jogging has supplied a valid reference (roughly two seconds of stable travel), the alpha10 release remains the fallback. Changing weapon, surface or grade may require a new reference. This does not retune steady sprint/jog targets or impose a physical top-speed cap. The compensation uses a two-clip root-motion model; automated tests cannot prove how Arma blends root motion in every transition.

## Settings pass

The menu has 122 controls, down from 127. Every retained setting has a runtime reader; preset entries refer only to active controls.

| Removed control | Reason / current behavior |
| --- | --- |
| Shift-release sustain duration | Already inactive; the release starts immediately. |
| Secondary downhill onset cap | Consolidated into Downhill boost starts. For custom settings, put the smaller of your former onset and cap into that remaining control. Defaults are unchanged. |
| Reset on respawn | Owned state and effects must always be cleaned up when the player changes. |
| Suspend in spectator | Camera/delegated-control suspension is always active. |
| Suspend while unconscious | Medical suspension is always active. |

The duplicate Full/Hybrid mode is now Movement and effects. Old saved numeric modes 0 and 1 remain compatible. Other choices remain Effects and hearing, Visuals and tinnitus, and Disabled. The release-curve slider now exposes the existing effective 1–3 range; HUD interval starts at the existing 0.05-second minimum. Descriptions now distinguish coefficients from physical speed, nominal timing from bounded release timing, ACE physiology from fallback reserve, and tinnitus from the fixed 20% heartbeat patch.

README_SETTINGS.md lists every current setting, registration default, range and description. Presets and mission/server overrides can change effective values; Custom stops preset rewrites.

## Retained behavior

The shared brief brace, original gear tuning, heavy sprint access, lowered-pistol entry fix, shorter stopping blend, heavy downhill improvement, velocity-based trip risk, 20% ACE heartbeat and intermittent vignette remain. GAIT has no weapon-sway writes. No new terrain-footing or recovery mechanic is added.

## In-game acceptance

1. With rifle, pistol and unarmed movement, jog steadily for about two seconds on level ground before sprinting. Test both raised and lowered pistol starts for the reported run/skip/run interruption.
2. Keep W held and release Shift during partial acceleration and at full sprint. Verify the release starts at the current pace and the final jog handoff has no speed step. Repeat with light, medium and heavy gear, and on a descent after collecting a matching jog reference.
3. Tap Shift again during both the release and the animation blend. Repeat release/retap sequences; check for no restart, rebrace or stale top-speed value.
4. Release W/all movement keys, then try A, D and S during the handoff. Input must take effect promptly. Repeat while reloading, changing weapon/stance, entering medical/carry actions and becoming unconscious.
5. Check heavy backpack sprint access, uphill braking, respawn, spectator, disabled mode and fully clear intervals between fatigue vignette pulses. Confirm the unchanged 20% heartbeat.
6. Repeat immediately after mission start, before calibration, and after changing surface/weapon. The existing release must remain available when no valid reference exists.

For a read-only capture, copy tests/foundation_capture.sqf into a saved Eden mission and run locally:

```sqf
[90, "alpha11 measured handoff"] execVM "foundation_capture.sqf";
```

Send the RPT after STOP with approximate issue times. Its releaseMotion fields include whether a measured release was selected, reference count and the current handoff state.

## Verification

Run VERIFY_READY.ps1 to validate the bundled PBO prefixes, checksums and all eighteen runtime scripts against source. Core prefix is gait; heartbeat prefix is z\gait\addons\heartbeat.

Automated evidence is in tests/VALIDATION_FOUNDATION.txt and tests/VALIDATION_RESULTS.json. SQF model/lifecycle tests, static settings/graph checks and a clean build do not replace Arma acceptance for physical velocity, interpolation, stopping distance or perceived sound/visuals.
