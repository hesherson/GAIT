# GAIT 1.8.0-alpha23 terrain, load, and stamina

Requires Arma 3 2.18+, CBA_A3 and ACE3. Restart Arma with the new GAIT copy and start a fresh mission. Current build/deploy instructions are in README_HEMTT.md; local build output is `.hemttout\\build`.

## What changed

A fully rested sprint starts with a brief flat-ground burst. Its target peaks at 1.10× normal sprint pace unloaded and 1.06× with 110 lb. Ordinary jogging and walking hold stamina, and resting restores it. The last 20% still tapers toward 65–75% of normal sprint pace. Sprint release eases into the selected walk or jog.

The final sprint-to-jog handoff now has a measured destination pace when a matching reference is available. Normal steady jogging supplies a session-local reference using horizontal velocity divided by the applied animation coefficient. Measurements require settled motion, ground contact, an eligible healthy character, a clear path and no active brace/release/vegetation penalty. References match the clip/config, character, weapon, surface and a narrow grade band and expire after ten minutes. No guessed km/h values are bundled.

Hold W and release Shift to ease from the current speed toward jog pace. Carried mass sets the release window. Pressing A or D during release redirects movement immediately and carries the current speed coefficient into ordinary locomotion. Lateral input also redirects sprint entry before Arma reports the custom animation blend.

All alpha17 crouch and strafe ownership fixes remain. Alpha18 fixes the remaining secondary-weapon-only acceleration pause by making lowered pistol locomotion (`SlowWpst`) a first-class GAIT family instead of converting every handgun into raised-pistol `SrasWpst`. The current native handgun pose is read from animationState first, then weaponLowered only as fallback, and the selected pose family remains latched through sprint acceleration. `SlowWpst` now has its own jog, sprint, lateral sprint and stop states plus its own `PistolLowStandActions`-derived action maps. GAIT also rejects internal `SlowWpst <-> SrasWpst` locomotion handoffs so a mid-ramp gun-pose correction cannot be introduced by the movement controller. Upward sprint acceleration is slower globally: the existing speed-ramp value is passed through a fixed 0.70 sprint-acceleration rate, stretching the default ~95% convergence from about 2.9 seconds to about 4.1 seconds without changing release, braking or ordinary movement timing.

Alpha19 audit hardening closes non-animation gaps found in the full foundation review: reset now clears recent input/stance/brake transients as well as owned movement; Zeus reset uses a CBA target event instead of direct RemoteExec; duplicate suspended-context logic is removed; passive same-context sprint measurements can automatically calibrate a physical pace target; and the debug HUD reports the actual pose family plus passive/full calibration state separately.

## Settings pass

The menu has 109 controls. Presets use the active controls.

| Removed control | Reason / current behavior |
| --- | --- |
| Shift-release sustain duration | Already inactive; the release starts immediately. |
| Secondary downhill onset cap | Downhill boost starts sets the onset, now 0.5° by default. |
| Reset on respawn | Owned movement state must always be cleaned up when the player changes. |
| Suspend in spectator | Camera/delegated-control suspension is always active. |
| Suspend while unconscious | Medical suspension is always active. |
| Exhausted sprint coefficient | Exhausted sprint targets 65–75% of normal sprint pace, depending on load. |

Movement only and Disabled are the two modes. ACE supplies fatigue feedback. Its heartbeat volume slider defaults to 10%. Saved numeric modes 0 and 1 both enable movement.

README_SETTINGS.md lists every current setting, registration default, range and description. Presets and mission/server overrides can change effective values; Custom stops preset rewrites.

## Retained behavior

The foundation retains the shared brief brace, lowered-pistol sprint family, short stopping blend and velocity-based trip risk.

## In-game acceptance

1. Test the secondary weapon separately. Begin from both a naturally lowered handgun state (`SlowWpst`) and a raised handgun state (`SrasWpst`), then sprint from rest through full speed. A lowered pistol must remain in the `SlowWpst` GAIT family for the entire acceleration instead of briefly converting to raised pistol; there must be no pause before full speed. Repeat with A/D throughout the ramp. Then compare rifle and unarmed starts to confirm their behavior is unchanged.
2. On flat ground, start a sprint at 100% reserve with a light and a 110 lb kit. Check that the initial burst ramps in briefly, feels stronger with the light kit, and settles to normal pace. Release and re-press Shift before stamina refills. The second sprint should use normal pace.
3. Tap Shift again during both the release and the animation blend. Repeat release/retap sequences; check for no restart, rebrace or stale top-speed value.
4. While running and sprinting at low, mid and near-full speed, press Crouch/MoveUp with W still held. The character should bend into crouched running the same way vanilla Arma does: no abrupt stop, no standstill detour and no visible coefficient snap during the bend. Repeat during W+A/W+D, during the acceleration ramp, during sprint release, and with Prone. After the low-stance state has settled, GAIT may relinquish the carried coefficient normally.
5. Hold W on an uphill slope, then press Shift without releasing W. Verify that the jog clip changes to the sprint clip and that sprint moves faster than both jog and deliberate walk, including on steep grades with heavy gear and low reserve. Release Shift and confirm that jog returns after the release taper. Repeat with the walk toggle enabled and with an explicit movement lock.
6. Repeat immediately after mission start, before calibration, and after changing surface/weapon. The existing release must remain available when no valid reference exists.
7. Compare flat and downhill movement on gentle and steep grades, both jogging and sprinting. Check that speed builds gradually over several seconds and settles. With matching pace references, check the default targets of 18 km/h for jog and 30 km/h for sprint. Repeat with a heavy ruck and verify that the capped boost fades on leaving the slope.
8. Hold sprint to empty reserve with light and heavy kits on flat ground. After the initial burst, both should sustain normal sprint pace until the final 20% of the bar. The light kit should settle near 75% and the heavy kit near 65%. Repeat uphill and downhill to check the uphill minimum and the removal of downhill momentum from the exhausted target.
9. Hold W on hills for at least 15 seconds with a raised and a lowered rifle, then repeat with a pistol. Look for periodic speed dips or unwanted weapon lowering. Release Shift while holding W both with and without the walk toggle. Compare speed through the taper and the final gait change.
10. In ACE heartbeat conditions, compare slider values of 0%, 10%, and 100% with stock ACE and with ACM Extended. The next beat should use the new setting, and breathing should still play at its usual volume.
11. Spend some stamina, jog for 30 seconds, walk for 30 seconds, then stop. The bar should hold during the jog and walk and refill once stationary.

For a read-only capture, copy tests/foundation_capture.sqf into a saved Eden mission and run locally:

```sqf
[90, "alpha23 rested sprint and stamina"] execVM "foundation_capture.sqf";
```

Send the RPT after STOP with approximate issue times. Its releaseMotion fields include whether a measured release was selected, reference count and the current handoff state.

## Verification

Run `tools\verify_build.ps1 -BuildPath .\.hemttout\build -SourceRoot .` after `hemtt build`. It validates the `gait_gait.pbo` checksum, its `gait` prefix, and all 20 embedded runtime scripts against source.

`tests/VALIDATION_FOUNDATION.txt` and `tests/VALIDATION_RESULTS.json` record alpha11 results. `tests/AUDIT_ALPHA19.md` records the alpha19 source audit and reproduction commands. Use the in-game cases above to verify physical pace and animation feel.
