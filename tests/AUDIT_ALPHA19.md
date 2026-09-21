# GAIT alpha19 source audit

Date: 2026-09-21
Branch: `dev/gait-foundation-1.8.0`

This record documents source-level audit work performed while preparing alpha19. It is **not** a claim that HEMTT, SQF-VM, or Arma runtime acceptance passed in this environment.

## Source/static findings

- Animation graph independently checked at 85 custom locomotion states, 5 stop states and 15 action maps across `SrasWrfl`, `SlowWrfl`, `SrasWpst`, `SlowWpst` and `SnonWnon`.
- Each pose family has 1 idle, 3 forward sprint, 8 jog-owned run and 5 sprint-owned lateral/back run states.
- No custom `Mwlk` states are present.
- Every custom state has direct internal graph routes to the other custom states in its pose family.
- 122 CBA settings are uniquely registered and all have runtime readers; presets reference only live controls.
- Lowered pistol is a first-class family rather than a native `SlowWpst` to custom `SrasWpst` conversion.
- The duplicate `GAIT_fnc_isSuspendedContext` runtime definition was removed.
- Reset clears locomotion input/stance transients and mission movement envelopes; the scheduled loop consumes `GAIT_resetRequested` to clear its private state.
- Zeus reset uses `CBA_fnc_targetEvent` instead of direct RemoteExec.
- Fatigue tinnitus uses local listener audio and is stoppable on reset.
- Heartbeat source/config remains fixed at 10% of ACE original amplitude.
- Passive pace calibration is connected to the steep-downhill physical target; a manual pace profile is no longer the only route to calibrated 32–34 km/h targeting.
- Debug HUD reports the actual pose family, locomotion-active flag, automatic sprint-reference calibration and full-profile calibration separately.
- Historical alpha11 validation files are explicitly marked historical.

## Current validation commands

Run from `F:\GAIT`:

```powershell
python .\tools\generate_foundation_actions.py --check
python .\tests\settings_audit.py
python .\tests\pace_calibration_integration.py
python .\tests\foundation_graph.py
python .\tests\heartbeat_audio.py
python .\tests\pbo_prefix_layout.py
python .\tests\feature_preservation.py --self-test

hemtt build
powershell.exe -NoProfile -ExecutionPolicy Bypass `
    -File .\tools\verify_build.ps1 `
    -BuildPath .\.hemttout\build `
    -SourceRoot .

python .\tools\run_regressions.py `
    --sqfvm 'C:\path\to\sqfvm.exe' `
    --output '.\tests\validation-current'
```

Then perform the in-game acceptance list in `README_TEST_BUILD.md` on a fresh mission and on the dedicated-server setup used for release testing.

## Evidence boundary

Source inspection and static graph/settings checks can catch missing states, stale references, ownership gaps and documentation drift. They cannot prove Arma root motion, animation interpolation, collision response, dedicated-server visual synchronization, or the subjective smoothness of crouch/strafe transitions. Those remain runtime acceptance requirements.
