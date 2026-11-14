# GAIT 1.8.0-alpha21 terrain, load, and stamina

Requires Arma 3 2.18+, CBA_A3 and ACE3. Load only the new GAIT copy and start a fresh mission. Current build/deploy instructions are in README_HEMTT.md; local build output is `.hemttout\\build`.

## What changed

Carried inventory mass continuously changes pace and first-step bracing. Light loads climb faster. Descending gives an early speed gain that builds with continued downhill travel, and heavier loads build a greater gain. Near-empty stamina tapers sprint to 85% of the kit’s normal run pace. An uphill minimum keeps sprint above the corresponding walk and jog. Downhill buildup is gradual and capped, and the first step is slightly quicker.

The final sprint-to-jog handoff now has a measured destination pace when a matching reference is available. Normal steady jogging supplies a session-local reference using horizontal velocity divided by the applied animation coefficient. Measurements require settled motion, ground contact, an eligible healthy character, a clear path and no active brace/release/vegetation penalty. References match the clip/config, character, weapon, surface and a narrow grade band and expire after ten minutes. No guessed km/h values are bundled.

Hold W and release Shift to ease from the current speed toward jog pace. Carried mass sets the release window. Pressing A or D during release redirects movement immediately and carries the current speed coefficient into ordinary locomotion. Lateral input also redirects sprint entry before Arma reports the custom animation blend.

All alpha17 crouch and strafe ownership fixes remain. Alpha18 fixes the remaining secondary-weapon-only acceleration pause by making lowered pistol locomotion (`SlowWpst`) a first-class GAIT family instead of converting every handgun into raised-pistol `SrasWpst`. The current native handgun pose is read from animationState first, then weaponLowered only as fallback, and the selected pose family remains latched through sprint acceleration. `SlowWpst` now has its own jog, sprint, lateral sprint and stop states plus its own `PistolLowStandActions`-derived action maps. GAIT also rejects internal `SlowWpst <-> SrasWpst` locomotion handoffs so a mid-ramp gun-pose correction cannot be introduced by the movement controller. Upward sprint acceleration is slower globally: the existing speed-ramp value is passed through a fixed 0.70 sprint-acceleration rate, stretching the default ~95% convergence from about 2.9 seconds to about 4.1 seconds without changing release, braking or ordinary movement timing.

Alpha19 audit hardening closes non-animation gaps found in the full foundation review: reset now clears recent input/stance/brake transients as well as owned movement; Zeus reset uses a CBA target event instead of direct RemoteExec; duplicate suspended-context logic is removed; passive same-context sprint measurements can automatically calibrate a physical pace target; and the debug HUD reports the actual pose family plus passive/full calibration state separately.

## Settings pass

The menu has 107 controls. Presets use the active controls.

| Removed control | Reason / current behavior |
| --- | --- |
| Shift-release sustain duration | Already inactive; the release starts immediately. |
| Secondary downhill onset cap | Downhill boost starts sets the onset, now 0.5° by default. |
| Reset on respawn | Owned movement state must always be cleaned up when the player changes. |
| Suspend in spectator | Camera/delegated-control suspension is always active. |
| Suspend while unconscious | Medical suspension is always active. |
| Exhausted sprint coefficient | Exhausted sprint targets 85% of normal run pace for the same load. |

Movement only and Disabled are the two modes. ACE supplies fatigue feedback. Saved numeric modes 0 and 1 both enable movement.

README_SETTINGS.md lists every current setting, registration default, range and description. Presets and mission/server overrides can change effective values; Custom stops preset rewrites.

## Retained behavior

The foundation retains the shared brief brace, lowered-pistol sprint family, short stopping blend and velocity-based trip risk.

## In-game acceptance

1. Test the secondary weapon separately. Begin from both a naturally lowered handgun state (`SlowWpst`) and a raised handgun state (`SrasWpst`), then sprint from rest through full speed. A lowered pistol must remain in the `SlowWpst` GAIT family for the entire acceleration instead of briefly converting to raised pistol; there must be no pause before full speed. Repeat with A/D throughout the ramp. Then compare rifle and unarmed starts to confirm their behavior is unchanged.
2. On flat ground with default speed-ramp settings, sprint acceleration should build continuously toward maximum speed, reaching roughly 95% of the target in about 4.1 seconds before the carried-load adjustment. Add or remove individual items around 35, 55, and 75 lb and confirm each change affects pace gradually. Then release Shift during partial acceleration and at full sprint to check the handoff.
3. Tap Shift again during both the release and the animation blend. Repeat release/retap sequences; check for no restart, rebrace or stale top-speed value.
4. While running and sprinting at low, mid and near-full speed, press Crouch/MoveUp with W still held. The character should bend into crouched running the same way vanilla Arma does: no abrupt stop, no standstill detour and no visible coefficient snap during the bend. Repeat during W+A/W+D, during the acceleration ramp, during sprint release, and with Prone. After the low-stance state has settled, GAIT may relinquish the carried coefficient normally.
5. Hold W on an uphill slope, then press Shift without releasing W. Verify that the jog clip changes to the sprint clip and that sprint moves faster than both jog and deliberate walk, including on steep grades with heavy gear and low reserve. Release Shift and confirm that jog returns after the release taper. Repeat with the walk toggle enabled and with an explicit movement lock.
6. Repeat immediately after mission start, before calibration, and after changing surface/weapon. The existing release must remain available when no valid reference exists.
7. Compare flat and downhill movement on gentle and steep grades, both jogging and sprinting. Check that speed builds gradually over several seconds and settles. With matching pace references, check the default targets of 18 km/h for jog and 30 km/h for sprint. Repeat with a heavy ruck and verify that the capped boost fades on leaving the slope.
8. Hold sprint to empty reserve with light and heavy kits on flat ground. Each should settle near 85% of its own normal run pace. Repeat uphill and downhill to check the uphill minimum and the removal of downhill momentum from the exhausted target.

For a read-only capture, copy tests/foundation_capture.sqf into a saved Eden mission and run locally:

```sqf
[90, "alpha21 pace and uphill gait"] execVM "foundation_capture.sqf";
```

Send the RPT after STOP with approximate issue times. Its releaseMotion fields include whether a measured release was selected, reference count and the current handoff state.

## Verification

Run `tools\verify_build.ps1 -BuildPath .\.hemttout\build -SourceRoot .` after `hemtt build`. It validates the `gait_gait.pbo` checksum, its `gait` prefix, and all 16 embedded runtime scripts against source.

`tests/VALIDATION_FOUNDATION.txt` and `tests/VALIDATION_RESULTS.json` record alpha11 results. `tests/AUDIT_ALPHA19.md` records the alpha19 source audit and reproduction commands. Use the in-game cases above to verify physical pace and animation feel.
