# GAIT alpha19 source audit

Date: 2026-09-21
Branch: `dev/gait-foundation-1.8.0`

This record documents the alpha19 foundation audit. Current GitHub CI enforces source/static contracts, a pinned HEMTT 1.22.0 build with source-matched PBO verification, and the pinned SQF-VM 2.0.0 behavioral suite. Arma runtime acceptance is still separate because CI cannot simulate engine root motion, animation appearance, physical collision, or dedicated-server rendering.

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
- Historical alpha11 validation files and the RC4/alpha11 byte-preservation harness are explicitly marked historical; current source invariants live in `tests/alpha19_invariants.py`.
- GitHub CI runs all 22 current SQF-VM behavioral suites and stores their regression report/logs as an artifact.
- GitHub CI builds both PBOs with HEMTT 1.22.0 and verifies virtual prefixes, checksums, the 18-script inventory, and embedded-script SHA256 equality against source.

## Current validation commands

Run from `F:\GAIT`:

```powershell
python .\tools\generate_foundation_actions.py --check
python .\tests\settings_audit.py
python .\tests\pace_calibration_integration.py
python .\tests\foundation_graph.py
python .\tests\heartbeat_audio.py
python .\tests\pbo_prefix_layout.py
python .\tests\alpha19_invariants.py

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
