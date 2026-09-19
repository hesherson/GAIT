# GAIT 1.8.0-alpha9: movement transitions and downhill velocity

Requires Arma 3 2.18+, CBA_A3 and ACE3. Build/deploy commands are in README_HEMTT.md. Load only the new GAIT copy and start a fresh mission.

## Changes

- Stopping from GAIT sprint or ordinary standing movement controlled by GAIT uses a faster, blended stop target. The stop interpolation rate is doubled to target half the previous blend time. Movement input remains live so a new direction or sprint press can interrupt the stop. Releasing W during an unfinished jog transition now redirects into the stop immediately.
- Releasing Shift while holding W starts its short speed taper from the current release state. Repeated taps must continue from partially decayed speed rather than restoring a full-speed starting value. There is no stationary full-speed hold or extra exponential tail after the taper.
- Heavy gear gains a little more speed during a sustained downhill run. Light and medium loads through 55 displayed lb keep their previous downhill bonus. The original overall weight penalty, uphill pace and sprint/ordinary pace floor remain intact.
- Downhill trip risk follows current horizontal velocity, including during deceleration. At the default speed influence, risk starts at zero at the configured minimum speed, rises linearly above it and keeps rising past the reference speed. The original slope, sustained-travel, cooldown, immunity and medical restrictions remain.
- ACE heartbeat gain is now 20% of the original for all seven variants, down from 50% in alpha8. Original samples, pitch, selection, heart-rate timing and physiology are unchanged. Other audio is unchanged. The optional heartbeat PBO applies this setting while loaded, independently of GAIT's runtime enable switch.

The brief launch brace remains on every gear tier, with the previous modest heavy-gear acceleration improvement. GAIT still does not write weapon sway, native fatigue or recoil coefficients. The alpha8 PBO path fix and deployment repair remain included.

## Fatigue visuals retained

The subtle fatigue vignette appears only in short pulses. The center stays clear; edge darkening is capped at 14%. Each pulse fades in and out over 1.3 seconds, followed by 5-12 seconds with no GAIT screen effect.

While **Intermittent fatigue vignette** is enabled, GAIT replaces only ACE Advanced Fatigue's blackout effect with these pulses. ACE pain, injury and unconsciousness effects remain under ACE control. Turning the option off restores the previous ACE fatigue-effect enabled state.

Recovery, disabling the option/mod, death, unconsciousness, trips, player changes, spectator/remote control and reset clear the pulse. An independent frame watchdog expires stale requests within 0.75 seconds. Brief threshold crossings and quick restarts preserve the minimum clear interval.

## In-game checks

1. At light, medium and heavy loads, build a full sprint and release both W and Shift. Compare stop time and forward travel with alpha8. Repeat after jogging and on downhill terrain. Confirm the shorter stop remains blended, and A/D/S or a fresh W press takes effect promptly.
2. Hold W and release Shift at early acceleration, full sprint, exhausted sprint and halfway down an earlier release taper. Speed should start decreasing from its current value without a bump. Retap Shift repeatedly, including entirely between scheduled speed updates. Check uphill braking and downhill release too.
3. Verify the light-tier brace remains visible and a heavy backpack can still sprint immediately into its brace and acceleration. Repeat W+A > A > D > W+D at steep grades around 32 degrees. Check crouch/prone, reload and weapon switching while stopping.
4. On the same descent, compare full-momentum heavy gear speeds with alpha8. At 100 displayed lb the target increase is about 2% near the peak downhill angle, with a smaller benefit on extreme slopes. Light/medium speeds through 55 lb should match alpha8.
5. Observe the trip-risk capture at different actual speeds on the same steep descent. Releasing Shift should not erase risk while still moving fast; risk should fall with velocity. Check cooldown and post-trip recovery, and verify no trip rolls in vehicles, midair or during medical/carry restrictions.
6. Compare ACE heartbeat at similar heart rates and audio settings. The configured gain is 40% of alpha8's already reduced gain, or 20% of the ACE original. Rhythm and pitch should match.
7. Check ADS while rested and after sprinting. Exhaust the reserve and confirm vignette pulses have fully clear gaps. Disabling GAIT or becoming unconscious mid-pulse must clear GAIT's effect.

For diagnostics, copy tests/foundation_capture.sqf into a saved Eden mission and run locally:

```sqf
[90, "alpha9 release transitions and downhill velocity"] execVM "foundation_capture.sqf";
```

The read-only capture records movement coefficients, observed speed, input, animation, trip risk and fatigue visual ownership. Send the RPT after STOP with approximate event times for any remaining issue.

## Packaging and validation

The main PBO retains prefix `gait`; the heartbeat PBO uses `z\gait\addons\heartbeat`. The installer repairs the obsolete nested heartbeat link and validates both PBOs before committing/pushing. The ZIP includes a verified standalone mod under `ready_to_load/GAIT`.

Automated build and regression results are in tests/VALIDATION_FOUNDATION.txt. They validate source logic, timing, graph definitions, gain values and cleanup. Arma's actual blend duration, travel distance, physical speed, perceived loudness and visual feel still need the in-game checks above. No measured clip-speed profiles or velocity-forcing workaround are added.
