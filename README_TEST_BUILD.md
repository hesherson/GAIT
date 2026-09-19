# GAIT 1.8.0-alpha6: sprint entry and animation correction

Complete HEMTT source based on alpha5. Requires Arma 3 2.18+, CBA_A3 and ACE3. Deployment commands are in README_HEMTT.md. Load the new GAIT copy and start a fresh mission.

## What changed

The brace now applies its brief speed dip inside the running animation, as the original implementation did. The additional walking stage and its promotion timer are removed. Holding sprint and forward requests the sprint family directly, regardless of gear tier.

The native stamina override removed during the rebuild is restored with explicit ownership. GAIT saves the original enabled flag and restores it when movement ownership ends. This addresses the native load/stamina gate while retaining GAIT's existing continuous weight and fatigue pace calculations. ACE injury restrictions remain respected. This corrects a source regression; heavy-backpack behavior still needs an in-game check.

All tiers keep the original 0.15-second base brace, 0.42 base coefficient and 0.575 brace response. Existing tier relief now contributes at 20% strength, making the brace more similar across tiers and giving light gear a clearer step. This deliberately strengthens light bracing compared with the original relief formula. Heavy gear retains the original acceleration rate; lighter gear gets a small continuous boost, up to 6%. Original steady speed/load targets and presets are unchanged.

Light gear also had a rearming bug: ordinary jogging could remain above the old fixed 2 m/s cutoff indefinitely. Returning to settled ordinary pace now rearms using the existing cooldown and settling periods. A quick moving sprint re-tap still avoids a second brace.

## Sprint release and animation blending

Entry and release now request the movement graph's interpolation with one `playMoveNow` call. The previous `switchMove` pose-weight argument did not provide a timed animation transition. The graph contains 36 locomotion states, with direct ordinary entry/exit connections and no separate walking-brace family.

Releasing sprint begins the native movement transition promptly. A fresh sprint press can replace an ordinary exit in progress once, through the graph. Holding the same key does not repeatedly restart the animation. Stance changes, medical actions, weapon changes and other incompatible actions retain priority.

Releasing sprint while W remains held also starts a short, finite coefficient ramp:

| Displayed load | Default forward release ramp |
| --- | --- |
| 0 lb | 0.268 s |
| 35 lb | 0.283 s |
| 55 lb | 0.298 s |
| 75 lb | 0.312 s |
| 100 lb | 0.327 s |
| 125+ lb | 0.342 s |

These are coefficient timings, not measured stopping distances or animation-blend durations. The stored taper setting scales this ramp within 0.15-0.45 seconds. There is no full-speed hold or extra decay tail.

W+A/D keeps forward response and direction control. Releasing W, choosing pure strafe/back movement, or stopping cancels stored forward coast. A render-time input serial catches a W release even between scheduled updates. No input, velocity or position is synthesized to keep the player moving forward.

The existing uphill brake still applies its numerical speed dip when sprint is released with W held. Its angle, strength and timing tuning remain. It does not insert a walking clip. Sprint re-taps resume from the remaining coefficient without another launch brace.

## Focused in-game check

1. With a heavy backpack, hold W and sprint from rest, then from a jog. Check that the running animation starts with the brief brace and builds into full sprint. Repeat with medium and light gear.
2. Sprint, release sprint while holding W, then tap it repeatedly during the slowdown. Check interpolation in both directions, especially with light gear. There should be no walking-stage pause or new brace on quick moving re-taps.
3. Return to ordinary W-only jogging for several seconds, then sprint again. Confirm the brace returns in every tier.
4. Release every movement key. Repeat by switching to pure A/D or S. Check prompt stop/direction response. W+A/D should remain responsive during the short forward ramp.
5. Repeat on the working downhill slope and steep uphill terrain. Check the uphill release brake, reload, weapon changes, crouch/prone and ACE medical restrictions.

For a remaining problem, copy tests/foundation_capture.sqf into the saved Eden mission and use Local Exec:

```sqf
[90, "alpha6 heavy sprint and sprint taps"] execVM "foundation_capture.sqf";
```

The read-only recorder now includes native stamina ownership, engine sprint/walk permission, ACE restriction masks, backpack and load. Send the RPT after STOP with the key sequence and gear weight.

## Validation limits

HEMTT and the actual-helper SQF-VM suites check compilation, ownership lifecycle, brace rearming, finite ramps and controller requests. They cannot simulate Arma animation blending, root motion, camera, collision or multiplayer. Smoothness and heavy-backpack behavior require the focused game checks above.
