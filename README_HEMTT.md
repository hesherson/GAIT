# GAIT 1.8.0-alpha11: build and deployment

Save `GAIT_v1_8_0_ALPHA11_HEMTT.zip` to `M:\downloads`. Close Arma before rebuilding. HEMTT and Git must be on PATH. This test build requires Arma 3 2.18 or later.

Paste this complete block into PowerShell. The installer repairs the old nested heartbeat link and verifies the built PBO contents before committing or pushing:

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $Extract = 'M:\downloads\GAIT_Foundation_1_8_0_ALPHA11'
    Expand-Archive -LiteralPath 'M:\downloads\GAIT_v1_8_0_ALPHA11_HEMTT.zip' `
        -DestinationPath $Extract -Force
    Set-Location 'M:\downloads'
    powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File "$Extract\GAIT\DEPLOY_GITHUB.ps1" -StashChanges
    if ($LASTEXITCODE -ne 0) { throw 'Deployment stopped; read the preceding error.' }
    Set-Location 'F:\GAIT'
}
```

The installer validates the existing checkout and saves uncommitted tracked/untracked files in a dated stash when `-StashChanges` is supplied. It never automatically reapplies that stash over the rebuild. Review saved edits with `git stash list` and `git stash show --stat 'stash@{0}'` before restoring selected work.

The checkout remains `F:\GAIT`. An existing `F:\GAIT-Git` checkout can be renamed automatically; a non-Git destination is preserved as a dated backup. The script applies the complete source on **dev/gait-foundation-1.8.0**, builds with HEMTT, commits and pushes that branch. It does not merge main or force-push. A new branch starts from remote RC4 if available, otherwise RC3, otherwise main.

To build and commit locally without pushing, add `-NoPush` to the installer command. If HEMTT fails, the copied source remains available for repair and no new commit/push is made. A push failure leaves the local commit intact. Reapplying a package after a failure requires reviewing or preserving the resulting local changes first.

## Build after later edits

```powershell
Set-Location 'F:\GAIT'
hemtt build
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\verify_build.ps1 -BuildPath .\.hemttout\build -SourceRoot .
```

| Item | Path |
| --- | --- |
| Load this local mod folder | `F:\GAIT\.hemttout\build` |
| Built PBO | `F:\GAIT\.hemttout\build\addons\gait_gait.pbo` |
| Edit gameplay source | `F:\GAIT\addons\gait` |
| Graph generator | `F:\GAIT\tools\generate_foundation_actions.py` |

The core PBO's virtual prefix remains `gait`, preserving asset and function paths. The heartbeat PBO uses `z\gait\addons\heartbeat`; it must never be nested beneath the core `gait` prefix. The source ZIP contains existing PAA/OGG assets, tests and HEMTT configuration; the verified standalone build is included under `ready_to_load/GAIT`. Other temporary build output is excluded. HEMTT compiles eighteen addon SQF files and builds two PBOs. The optional gait_heartbeat.pbo sets ACE Medical Feedback heartbeat gain to 20% of its original level and skips loading if that ACE component is absent. Python is unnecessary for a normal build because the generated graph is already included.

Load CBA_A3, ACE3 and the new local mod. Unload older GAIT copies and start a fresh mission with GAIT and ACE AF enabled. The runtime/HUD version is **1.8.0-alpha11**. Follow `README_TEST_BUILD.md` for heartbeat, ADS sway, fatigue vignette and movement checks.

If HEMTT is missing, install it using the [official instructions](https://hemtt.dev/installation/index.html), then open a new PowerShell window. This package was built with HEMTT 1.21.0. The existing PAA/OGG assets require no raw model/texture binarization.

`hemtt build` is unsigned test output. After in-game acceptance, use your chosen release/signing workflow. `hemtt release` does not automatically reuse the old GAIT private signing key. No Workshop publishing is performed by this package.

See `README_SPEED_REFERENCE.md` for all gear tiers and the distinction between animation multipliers and observed km/h.

## Load without rebuilding

The ZIP contains `GAIT/ready_to_load/GAIT`, a complete standalone mod with both PBOs. Add that exact inner folder through Arma Launcher's Local mod option and disable older GAIT entries. It does not require file patching or a source-directory link. The included VERIFY_READY.ps1 checks its PBOs against the bundled source.

The HEMTT source remains the outer `GAIT` directory. Load either the newly built `F:\GAIT\.hemttout\build` or the included standalone folder, with only one GAIT copy enabled.
