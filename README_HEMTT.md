# GAIT: HEMTT build

The main checkout is `F:\GAIT`. This package contains the complete RC3 source, arranged for direct HEMTT builds. RC3 fixes the release-argument error and restores real forward/diagonal sprint animations with blended transitions.

## Install and deploy

Save `GAIT_v1_7_0_RC3_HEMTT.zip` to `M:\downloads`, then paste this complete block into PowerShell:

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $Zip = 'M:\downloads\GAIT_v1_7_0_RC3_HEMTT.zip'
    $Extract = 'M:\downloads\GAIT_RC3'
    Expand-Archive -LiteralPath $Zip -DestinationPath $Extract -Force
    Set-Location 'M:\downloads'
    powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File "$Extract\GAIT\DEPLOY_GITHUB.ps1"
    if ($LASTEXITCODE -ne 0) { throw 'GAIT deployment failed.' }
}
```

The script uses an existing `F:\GAIT` checkout or renames `F:\GAIT-Git` to `F:\GAIT`. If an older non-Git `F:\GAIT` folder exists, it is renamed to a dated backup before the checkout moves. It validates the existing checkout and stops if there are uncommitted changes. If neither checkout exists, it clones the repository.

It migrates `source\gait` to `addons\gait`, applies the complete RC3 source and HEMTT configuration, commits, and pushes `dev/gait-1.7.0-rc3`. Main is unchanged. A rejected push stops with an error; no force push or reset is performed. Close terminals/editors using the old folder if Windows reports it is in use.

## Install HEMTT if needed

```powershell
winget install hemtt
```

Open a new PowerShell window after installation so PATH updates are available. If using a manually downloaded executable, place `hemtt.exe` in `F:\GAIT` and use `.\hemtt.exe build` instead. The executable is excluded from Git.

Official installation instructions: https://hemtt.dev/installation/index.html

## Build

```powershell
Set-Location 'F:\GAIT'
hemtt build
```

Successful output:

| Item | Path |
| --- | --- |
| Complete loadable mod folder | `F:\GAIT\.hemttout\build` |
| PBO | `F:\GAIT\.hemttout\build\addons\gait_gait.pbo` |
| Mod metadata | `F:\GAIT\.hemttout\build\mod.cpp` |

The PBO's internal prefix remains `gait`, preserving all existing `\gait\functions`, sound and texture paths. `addons\gait\addon.toml` declares that this legacy prefix is intentional.

The file layout is `.hemtt\project.toml`, `addons\gait\config.cpp`, `addons\gait\functions`, `tests`, and root `mod.cpp`. Edit only `addons\gait` for gameplay changes. Build output and release archives are ignored by Git.

In the Arma launcher, add `F:\GAIT\.hemttout\build` as a local mod. Enable CBA_A3 and ACE3, unload other GAIT versions, and start a fresh mission. Rebuild from `F:\GAIT` after editing source.

If Arma 3 Tools is absent, this addon has no raw model or texture assets requiring Binarize. HEMTT still compiles the config and SQF and packs the existing PAA/OGG assets. Read the build diagnostics; a successful package does not establish in-game movement behavior.

Official build reference: https://hemtt.dev/commands/build.html

## Later release packaging

After in-game testing, `hemtt release` creates `.hemttout\release` and release ZIPs. HEMTT's default release signing generates a public key to distribute to servers. It does not automatically use your previous GAIT signing key. No Workshop upload or main-branch merge happens automatically.

## Validation

This layout was built with HEMTT 1.21.0. The build compiled nine SQF files and the addon config, retained the `gait` virtual prefix, and produced a loadable mod folder with `mod.cpp`. PBO-embedded SQF was compared against the packaged source.

See `README_TEST_BUILD.md` for the RC3 movement changes, tests and remaining Arma acceptance checks. This packaging update does not add an in-game test result.
