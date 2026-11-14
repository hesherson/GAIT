# GAIT 1.8.0-alpha26 terrain, load, and stamina

Requires Arma 3 2.18+, CBA_A3 and ACE3. Restart Arma with the new GAIT copy and start a fresh mission. Current build/deploy instructions are in README_HEMTT.md; local build output is `.hemttout\\build`.

## What changed

A fully rested sprint starts with a brief flat-ground burst. Its target peaks at 1.14× normal sprint pace unloaded and about 1.08× with 110 lb. It settles into normal sprint pace within 4.1 seconds. Sprint pace gradually tapers below half reserve and reaches 65–75% at empty, depending on load. Only sprinting spends reserve. Rest restores it and walking or jogging holds it steady.

Stamina drain changes gently through 70 lb and increases more sharply after 120 lb. Grade affects drain with ACE or the fallback reserve. On descents, speed builds gradually toward a grade-dependent target, with more buildup on sustained moderate slopes.

Ordinary forward jog targets a small margin above native walking and combat jog. Deliberate walk uses native pace for formations. During sprint release, the first new direction input can redirect a forward blend that is still queued. Arma then handles all movement inputs while the common speed coefficient tapers.

Passive clip measurements calibrate terrain pace when a matching reference is available. Normal steady movement supplies a session-local reference using horizontal velocity divided by the applied animation coefficient. References match the clip, character, weapon, surface and grade and expire after ten minutes.

## Settings pass

The menu has 107 controls. Presets use the active controls.

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
5. Hold W on an uphill slope, then press Shift without releasing W. Verify that the jog clip changes to the sprint clip and that sprint moves faster than both jog and deliberate walk, including on steep grades with heavy gear and low reserve. Release Shift and confirm that the jog animation starts before the pace taper is finished. Repeat with the walk toggle enabled and with an explicit movement lock.
6. Repeat immediately after mission start, before calibration, and after changing surface or weapon. Hold W across Shift release and tap A or D immediately, while the forward blend is still pending. Repeat during the blend. Then release W into pure A and D and reverse direction. Each input should take effect during the slowdown.
7. Compare flat and downhill movement on gentle and steep grades, both jogging and sprinting. Check that speed builds gradually over several seconds and settles. With matching pace references, check the default targets of 18 km/h for jog and 30 km/h for sprint. Repeat with a heavy ruck and verify that the capped boost fades on leaving the slope.
8. Hold sprint to empty reserve with light and heavy kits on flat ground. After the initial burst, both should sustain normal sprint pace until 50% reserve, then taper gradually. The light kit should settle near 75% and the heavy kit near 65%. Repeat uphill and downhill to check the uphill minimum and the removal of downhill momentum from the exhausted target.
9. Hold W on hills for at least 15 seconds with a raised and a lowered rifle, then repeat with a pistol. Look for periodic speed dips or unwanted weapon lowering. Release Shift while holding W both with and without the walk toggle. Confirm that walk uses native pace, and that stop, A/D reversals and stance changes respond during the slowdown. Repeat with slope handling disabled.
10. In ACE heartbeat conditions, compare slider values of 0%, 10%, and 100% with stock ACE and with ACM Extended. The next beat should use the new setting, and breathing should still play at its usual volume.
11. Spend some stamina, jog for 30 seconds, walk for 30 seconds, then stop. The bar should hold during the jog and walk and refill once stationary.
12. Compare two players in the same weapon pose on the same route, one light and one carrying 110 lb. Use native walk across flat terrain and a moderate incline, then repeat with the temporary Walk/Run binding. Check formation spacing and compare with GAIT unloaded.
13. Hold sprint on a steep climb for at least 15 seconds, with the rifle both raised and lowered. Watch the weapon pose at ACE's fatigue tick and over bumps. While holding sprint, change weapon pose deliberately and confirm that the new pose responds once.
14. Compare reserve drain at 0, 70, 110, 120 and 150 lb in the same weapon pose and on the same route. Repeat on a climb and a moderate descent. Change ACE Performance Factor and Load Factor separately and verify the sprint reserve responds.
15. Compare deliberate walk, raised-weapon combat jog and ordinary W-only jog on flat ground and a mild slope. Give each pace time to settle. Ordinary jog should come out slightly faster and deliberate walk should match the native pace.

For a read-only capture, copy tests/foundation_capture.sqf into a saved Eden mission and run locally:

```sqf
[90, "alpha26 sprint, reserve, and release"] execVM "foundation_capture.sqf";
```

Send the RPT after STOP with approximate issue times. Compare the recorded animation, directional input, coefficient and horizontal speed at each input change.

## Verification

Run `tools\verify_build.ps1 -BuildPath .\.hemttout\build -SourceRoot .` after `hemtt build`. It validates the `gait_gait.pbo` checksum, its `gait` prefix, and all 18 embedded runtime scripts against source.

`tests/VALIDATION_FOUNDATION.txt` and `tests/VALIDATION_RESULTS.json` record alpha11 results. `tests/AUDIT_ALPHA19.md` records the alpha19 source audit and reproduction commands. Use the in-game cases above to verify physical pace and animation feel.
