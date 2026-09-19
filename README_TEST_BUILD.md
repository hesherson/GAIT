# GAIT 1.8.0-alpha7: fatigue feedback and weapon handling

Complete source based on alpha6. Requires Arma 3 2.18+, CBA_A3 and ACE3. Build/deploy commands are in README_HEMTT.md. Load only the new GAIT copy and start a fresh mission.

## Changes

- ACE heartbeat gain is halved for all seven variants. Original samples, pitch, selection, heart-rate timing and physiology remain unchanged. These sounds belong to ACE Medical Feedback and can play for exertion or medical reasons. Other audio is unchanged. The optional heartbeat PBO applies this setting while loaded, independently of GAIT's runtime enable switch.
- Heavy-gear acceleration after the brief brace is 2% faster. The adjustment blends smoothly into the existing lighter-load rates. Brace duration, depth, release response, maximum speeds, slope behavior and animation graph remain as in alpha6.
- GAIT's weapon-sway controller is removed, including its startup, disabled-state and reset writes. Old sway options cannot reactivate it. Native fatigue writes are also removed because they can affect aim; GAIT still uses its reserve for movement and feedback. ACE/native weapon handling and ACE physiology remain active.
- A subtle vignette appears only in short fatigue pulses. The center stays clear; edge darkening is capped at 14%. Each pulse fades in, briefly holds and fades out over 1.3 seconds, followed by 5-12 seconds with no GAIT screen effect.

## Fatigue visual ownership

While the new **Intermittent fatigue vignette** option is enabled, GAIT replaces only ACE Advanced Fatigue's blackout effect with these pulses. That prevents the two fatigue effects from stacking or the ACE fatigue blackout becoming continuous at high exhaustion. ACE pain, injury and unconsciousness effects remain under ACE control.

The effect handle is destroyed after each pulse. Recovery, disabling the option/mod, death, unconsciousness, trips, player changes, spectator/remote control and reset clear it. An independent frame watchdog expires the request within 0.75 seconds if the scheduled update loop stops. The minimum clear interval survives brief threshold crossings and quick restarts.

Turning this option off restores ACE's previous fatigue-effect enabled state. It does not disable unrelated medical screen effects. No permanent blur, chromatic aberration or resting vignette is added.

The new option defaults on, so the old disabled visual-effect setting does not silently suppress it. Existing exhaustion threshold and maximum visual-strength options control the new pulses, with the hard opacity and duration caps always enforced.

## In-game checks

1. Compare the ACE heartbeat with alpha6 at similar heart rates and audio settings. Check both fast and slow variants when available; all should be quieter without changing their rhythm.
2. Aim down sights while rested, moving and recovering from sprint. GAIT should no longer alternate sway coefficients. Confirm ACE's own sway and breath-hold behavior remain available.
3. Sprint until fatigued. Observe brief, subtle edge darkening with fully clear gaps, including at high exhaustion. Rest and confirm the vignette clears.
4. During a pulse, disable the new vignette option, disable GAIT, use Reset GAIT Effects, switch player or enter spectator. Confirm GAIT's overlay disappears. Other ACE medical effects may still appear when medically appropriate.
5. With a heavy backpack, compare acceleration out of the brace. The change should be small. Confirm light gear still braces, sprint taps still blend, W release cancels forward coast and steep slopes retain their movement behavior.

For diagnostics, copy tests/foundation_capture.sqf into a saved Eden mission and run locally:

```sqf
[90, "alpha7 fatigue feedback"] execVM "foundation_capture.sqf";
```

The read-only capture includes fatigue intensity, vignette opacity/handle, pulse timing and ACE fatigue visual ownership alongside existing movement diagnostics. Send the RPT after STOP with the approximate event time.

## Validation limits

Build and regression results are in tests/VALIDATION_FOUNDATION.txt. Automated tests check gain values, source ownership, timing and cleanup, but cannot render Arma's post processing, measure perceived loudness, or confirm ADS and movement feel. Those require the game checks above.
