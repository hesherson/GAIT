# GAIT 1.8.0-alpha25 build and deployment

Requires Arma 3 2.18+, CBA_A3, ACE3 with Medical Feedback, Git, and HEMTT. Close Arma before building and deploying so the ACE and ACM startup hooks reload on launch.

## First checkout

Run once with a destination that does not exist yet:

```powershell
git clone --branch dev/gait-foundation-1.8.0 https://github.com/hesherson/GAIT.git F:\GAIT
```

If `F:\GAIT` is already your GAIT checkout, use it directly. Run `git fetch origin` and `git switch dev/gait-foundation-1.8.0` there if it is on another branch. If `F:\GAIT` contains an extracted ZIP, use a new empty destination and substitute that path below.

## Update and build

```powershell
Set-Location 'F:\GAIT'
git pull --ff-only
if ($LASTEXITCODE -ne 0) { throw 'GAIT pull failed.' }
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Deploy-GAIT.ps1
```

Add `F:\GAIT\.hemttout\build` as a local mod in Arma Launcher. Enable one GAIT copy.

To keep using an existing launcher mod path, pass its full folder path as `-DeployPath` to the same script. The script verifies the staged build before replacing an existing GAIT folder and saves the previous folder beside it.

## Verify source

```powershell
python .\tools\generate_foundation_actions.py --check
python .\tests\settings_audit.py
python .\tests\pace_calibration_integration.py
python .\tests\foundation_graph.py
python .\tests\pbo_prefix_layout.py
python .\tests\alpha19_invariants.py
python .\tests\heartbeat_audio.py
python .\tests\ace_sprint_reserve_hook.py

python .\tools\run_regressions.py --sqfvm 'C:\path\to\sqfvm.exe'
```

The deploy script verifies the single `gait_gait.pbo`, its `gait` prefix and checksum, and all 18 embedded runtime SQF files, and the optional ACM heartbeat config. The SQF-VM suites exercise the movement model and ownership logic. See [in-game checks](README_TEST_BUILD.md) for physical pace and animation validation.
