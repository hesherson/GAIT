# GAIT 1.8.0-alpha4: gear inertia and responsive movement

Complete HEMTT source, based on alpha3. Requires Arma 3 2.18+, CBA_A3 and ACE3. Keep GAIT and ACE Advanced Fatigue enabled. Deployment commands are in README_HEMTT.md.

## Gear behavior

Heavy equipment takes longer to accelerate and longer to settle from sprinting into ordinary forward movement. Light equipment accelerates and sheds pace sooner. Directional input is immediate: a speed coast cannot hold W for you, delay A/D, or override a deliberate stop.

The existing 35/55/75 lb tier thresholds are used as continuous interpolation landmarks. This retains the four displayed tiers (Light, Medium, Moderate, Heavy) while avoiding a sudden response change at a boundary. The model uses GAIT's existing configurable load conversion, not a physical mass measurement.

Balanced response factors:

| Load | Acceleration rate | Slowdown rate | Forward coast duration | Launch brace duration |
| --- | --- | --- | --- | --- |
| 0 lb | 1.20x | 1.40x | 0.60x | 0.90x |
| 35 lb | 1.10x | 1.20x | 0.80x | 0.95x |
| 55 lb | 1.00x | 1.00x | 1.00x | 1.00x |
| 75 lb | 0.86x | 0.84x | 1.15x | 1.08x |
| 100 lb | 0.73x | 0.70x | 1.30x | 1.18x |
| 125+ lb | 0.62x | 0.60x | 1.45x | 1.28x |

A lower response rate means more time to change pace. Rates scale the existing time-based exponential ramp; they do not multiply top speed. Coast hold/taper are bounded by the existing 3/4-second caps. Load is sampled at release for that coast, so changing inventory cannot restart the hold phase.

The original brace base speed, snap rate, slope addition and CBA settings remain. Brace relief now decreases continuously with load, reaching the original full heavy dip at the moderate/heavy boundary (75 lb by default). The base launch duration also scales with weight. A genuine walking/rest start has a short, noticeable dip. An established moving sprint re-tap continues from the remaining pace without another launch brace.

The original full-speed/load/fatigue targets and presets remain unchanged. Heavy equipment retains its lower sustained speed; slower braking does not give it a higher maximum speed. See README_SPEED_REFERENCE.md for coefficient limits. No unmeasured km/h claims or clip calibration profiles are bundled.

## Stopping, strafing and sprint re-taps

* A forward sprint-release coast can retain the current custom sprint family through its remaining speed decay, with a bounded six-second tail after the configured taper. Re-pressing sprint during that coast resumes without a forced native exit and custom re-entry.
* Current input is read in Draw3D. Releasing all movement keys exits to idle even if sprint remains held. Pure sideways input takes priority over forward coast metadata. Holding sprint while strafing still uses GAIT's existing lateral family.
* A stop or direction exit is serviced in the same render callback when ordinary movement is safe. Medical actions, weapon changes, reloads and stance changes retain their safety gates.
* A sprint entry that has been issued but has not appeared yet retains cleanup ownership if the keys are released. This prevents a late custom sprint from becoming unowned after cancellation.
* No velocity, position or synthetic input is applied. Internal momentum history decays without movement input and clears after the existing real-stop threshold.

## Uphill brake and downhill behavior

The alpha3 uphill release brake remains. It starts gently above 15 degrees and reaches full strength at 35 degrees with Balanced defaults. Its duration is about 0.310 seconds at 32 degrees and 0.330 seconds at full strength. It overrides ordinary gear coasting, shortens the remaining coast with slope, and never restores the pre-brake speed afterward.

A sprint re-tap during the uphill step cancels its remaining duration without another launch brace. Releasing W or choosing pure strafe takes priority over the forward brace animation; the numerical brake can still shed stored pace without forcing forward motion.

The working downhill angle/load curve is retained. Sustained downhill momentum builds more slowly with heavier gear, using the acceleration factor above. The existing downhill bonus ceiling, extreme-descent taper, trip behavior and gear speed penalties remain.

ACE reserve integration, carrying/dragging restrictions, sway, hearing, audio, vegetation and landing effects remain. The 72-state sprint/brace graph and its 8 action maps are retained.

## Focused in-game check

1. On the same level ground, compare a light kit, about 55 lb, and about 100 lb. Walk into sprint: heavier kits should show a deeper launch dip and take longer to build speed.
2. At full sprint, release sprint while holding W. Heavy gear should take longer to lose speed. Re-press sprint midway through the slowdown several times; there should be no second brace or forced animation exit/re-entry.
3. At full sprint and midway through coast, release all movement keys. Repeat while holding sprint. Then release W and press A or D. Stop/sideways input should take control promptly without forced forward travel.
4. Repeat the releases/re-taps on the working downhill slope and above the uphill 32-degree boundary. Uphill release should still dig in promptly despite heavy gear.
5. Stop for half a second, then sprint again: the initial brace should rearm. Check rifle raised/lowered, pistol, unarmed, reload, weapon change, crouch and prone.

If a problem remains, copy tests/foundation_capture.sqf into a saved Eden mission, then use Local Exec:

```sqf
[90, "alpha4 gear and input"] execVM "foundation_capture.sqf";
```

Reproduce the issue, wait for STOP, and send the RPT with the exact input sequence and approximate kit weight. The recorder observes movement only.

## Validation limits

HEMTT and SQF-VM verify compilation and behavioral policies, including cleanup ownership, time-based response, load ordering and uphill brake precedence. They do not simulate Arma root motion, camera blending, collisions or multiplayer. In-game smoothness and actual stopping distance remain acceptance checks. The local Windows installer is included; it is not executable in this Linux validation environment.
