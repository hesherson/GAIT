# GAIT 1.8.0-alpha19: build and validation

GAIT is developed from the Git checkout at `F:\GAIT` on branch `dev/gait-foundation-1.8.0`. Arma 3 2.18+, CBA_A3 and ACE3 are required. Close Arma before rebuilding the local mod.

## Update and build

```powershell
Set-Location 'F:\GAIT'

git fetch origin
git pull --ff-only origin dev/gait-foundation-1.8.0
git log -1 --oneline

hemtt build

powershell.exe -NoProfile -ExecutionPolicy Bypass `
    -File .\tools\verify_build.ps1 `
    -BuildPath .\.hemttout\build `
    -SourceRoot .
```

Load only `F:\GAIT\.hemttout\build` as the local GAIT mod. Disable older GAIT copies before starting a fresh mission.

The verifier requires exactly two PBOs:

| PBO | Virtual prefix |
| --- | --- |
| `gait_gait.pbo` | `gait` |
| `gait_heartbeat.pbo` | `z\gait\addons\heartbeat` |

It validates PBO checksums, prefixes, `config.bin`, the complete 18-file runtime SQF inventory, and source-vs-built SHA256 equality when `-SourceRoot .` is supplied.

The optional heartbeat PBO keeps ACE Medical Feedback heartbeat samples at **10% of ACE's original amplitude**. Unloading that PBO restores ACE's normal heartbeat configuration.

## Source/static checks

Python is not required to play or build GAIT, but it is recommended before committing graph/settings changes:

```powershell
Set-Location 'F:\GAIT'

python .\tools\generate_foundation_actions.py --check
python .\tests\settings_audit.py
python .\tests\pace_calibration_integration.py
python .\tests\foundation_graph.py
python .\tests\heartbeat_audio.py
python .\tests\pbo_prefix_layout.py
python .\tests\feature_preservation.py --self-test
```

Do not regenerate preservation baselines merely to make a failure disappear. If the preservation test rejects an intentional new change, review that exact delta before authorizing it.

## SQF-VM regression suite

SQF-VM is supplied separately. The current runner contains 22 actual-helper suites:

```powershell
python .\tools\run_regressions.py `
    --sqfvm 'C:\path\to\sqfvm.exe' `
    --output '.\tests\validation-current'
```

This tests pure/state-machine SQF logic. It does not simulate Arma animation interpolation, root motion, physical collision, dedicated-server rendering, or perceived audiovisual behavior.

## In-game validation

Use `README_TEST_BUILD.md` for current acceptance cases. The debug HUD identifies the actual weapon/pose family, locomotion phase, automatic sprint-reference calibration and full manual pace-profile state.

For a read-only capture, copy `tests/foundation_capture.sqf` into the test mission and run:

```sqf
[90, "alpha19 audit hardening"] execVM "foundation_capture.sqf";
```

The current source repository does not contain a prebuilt `ready_to_load/GAIT` package or a root `VERIFY_READY.ps1`. Build output is `.hemttout\build`; the supported verifier is `tools\verify_build.ps1`.

## Deployment helper

`DEPLOY_GITHUB.ps1` remains available for applying a complete extracted source package into the checkout. It stashes or rejects dirty work before replacement, builds with HEMTT, runs `tools\verify_build.ps1`, commits and optionally pushes `dev/gait-foundation-1.8.0`. For ordinary development on the existing checkout, use the direct update/build commands above.
