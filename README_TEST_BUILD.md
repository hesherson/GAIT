# GAIT 1.8.0-alpha2: smooth sprint entry and retained momentum

Complete HEMTT source update for the 1.8 foundation. Requires **Arma 3 2.18 or later**, CBA_A3 and ACE3. This build addresses abrupt sprint entry, repeated braces during moving recovery, and sustained downhill pace. The existing sprint and strafe action families are retained; the short brace has its own walk-derived family.

## Brace and momentum

* Walking or standing starts keep the original brace duration, dip, snap, kit relief and slope enhancement. Balanced starts at 0.15 seconds; the existing steep-slope addition still applies.
* A genuine brace now uses actual native walking clips before one blended handoff into the real sprint clips. The dip no longer starts by immediately applying a walking-scale coefficient to sprint root motion.
* Established moving sprint momentum vetoes **all** brace triggers, including crouch and remembered slope-stop triggers. Releasing and re-pressing sprint while still recovering does not create another brace.
* Releasing W alone does not erase internal momentum. A physical stop lasting 0.15 seconds clears it; a single zero-velocity frame does not.
* While moving, the existing grace period must pass, then the character must settle at walking coefficient and at or below 2 m/s for the existing walking-settle duration. Faster actual movement stays protected even if its coefficient is low on a hill.
* The first sprint press and holding sprint against a wall do not count as established momentum. New braces can also start after a real stop while Turbo remains held.
* Momentum protection skips only the brace. Fatigue, gear, uphill penalties, injury restrictions and deliberate movement changes still affect pace.

The original presets and slope pace model are byte-identical. Original brace settings and all previous setting defaults remain unchanged. The preservation audit checks 22 unchanged blocks and exact reviewed changes in three others. It does not claim the changed brace/terrain behavior is identical to alpha1. See `tests/FEATURE_PRESERVATION.md`.

## Smooth animation handoff

Entry, brace promotion and exit use the documented Arma 3 2.18 array form of `switchMove`, beginning at the current pose weight and retaining aim/head offsets. Animation phase is reused only when source and destination use the identical RTM file. Different clips use their own start phase.

The graph contains 72 states: the original 36 sprint/run/idle states and 36 walk/idle brace states. Normal directional selection stays inside the selected family. One genuine brace activates its walking family once, then promotes once when its tuned window ends. There is no directional animation watchdog or ordinary position/velocity forcing.

Queued cleanup, one body command per frame, medical/weapon/stance handoffs, and failure logging remain. ACE physiology, source-specific fatigue restriction handling, carry movement, sway, hearing, trips, landing effects and vegetation drag are retained.

Sources: [switchMove](https://community.bistudio.com/wiki/switchMove), [getUnitMovesInfo](https://community.bistudio.com/wiki/getUnitMovesInfo), [Arma 3 2.18 release](https://dev.arma3.com/post/spotrep-00115). The blend parameter is a pose weight, not a duration in seconds.

## Downhill pace

Actual sustained sprint travel builds downhill momentum over time. With the default build time, it reaches about 95% after 2.5 seconds; a brief moving recovery retains it and a real stop clears it. Existing angle smoothing and the time-based speed ramp still smooth the final output.

The Balanced preset retains its 6% base bonus. A new **Sustained downhill bonus** adds up to 12% before load attenuation. At mature momentum and an 18–35 degree decline, the combined extra target is approximately:

| Carried load in GAIT units | Extra downhill target |
| --- | --- |
| 0 lb | 18% |
| 35 lb | 12.3% |
| 75 lb | 9% |
| 150 lb | 6% |

The existing overall kit penalty applies as well, so heavier kits remain slower. Bonus rises smoothly from the configured onset angle, reaches the configured peak angle, and tapers between 35 and 75 degrees to retain one quarter of the extra bonus on extreme descents. Total extra gain is bounded at 35% even with high custom settings. Existing trip risk remains active.

These are target ratios, not a claim of measured real-world or in-game top speeds. GAIT's displayed pounds use its existing configurable load conversion. No fabricated physical clip-speed profiles are shipped.

New Addon Options in the slope category:

* **Sustained downhill bonus:** default 0.12. Set to zero to remove the added bonus.
* **Downhill momentum build time:** default 2.5 seconds.

Existing downhill enable, onset, peak, base bonus, kit and fatigue settings still apply. The existing preset selections retain their prior values; the new options are independent settings.

## Build and load

Follow `README_HEMTT.md`. Keep the checkout at `F:\GAIT` and load `F:\GAIT\.hemttout\build`. Unload older GAIT copies and start a fresh mission. Keep **GAIT and ACE Advanced Fatigue enabled**. For the first check, load CBA_A3, ACE3 and GAIT only.

## Focused gameplay check

1. Walk with the rifle raised, then press sprint. Check for the brief walking brace, smooth weapon/head transition and gradual acceleration. Repeat with a lowered rifle and unarmed.
2. Sprint for several seconds, release sprint while moving, then re-press it. Repeat on the working downhill slope. There should be no new brace dip.
3. Hold Turbo, stop by releasing W for half a second, then press W again. A real stop should rearm the brief brace even though the movement family stayed active.
4. Descend the same slope with a light and heavy kit. Build speed before entering the slope; compare smooth acceleration and the lower speed with the heavy kit. Cross a crest and alternate forward diagonals and pure strafing.
5. Reload, change weapon, crouch and go prone to check that normal actions retain control.

If a problem remains, copy `tests/foundation_capture.sqf` into a saved Eden mission folder, then use **Local Exec**:

```sqf
[90, "alpha2 brace and downhill"] execVM "foundation_capture.sqf";
```

Reproduce the problem and wait for the STOP message. Send that RPT and identify the input sequence. The recorder only observes; it includes actual horizontal speed, brace protection, downhill momentum and animation stage. The older isolated native/custom trials are unnecessary for this check.

## Validation limits

HEMTT and SQF-VM check compilation, pure policies, safety gates and regression cases. SQF-VM does not simulate Arma animation blending, root motion, collision or multiplayer. Camera continuity and the visible dip must be verified in game. The optional measured-pace interface is retained; its default empty profiles preserve the coefficient model. Terrain speed is not guaranteed on nontraversable geometry.
