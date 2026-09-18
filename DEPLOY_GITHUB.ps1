param(
    [string]$RepoPath = 'F:\GAIT',
    [string]$PreviousRepoPath = 'F:\GAIT-Git',
    [switch]$StashChanges,
    [switch]$NoPush
)
& {
    $ErrorActionPreference = 'Stop'
    function Run-Git {
        & git @args
        if ($LASTEXITCODE -ne 0) { throw "Git command failed: git $($args -join ' ')" }
    }
    function Assert-Checkout([string]$Path) {
        $RemoteUrl = (Run-Git -C $Path remote get-url origin).Trim()
        if ($RemoteUrl -notin @('https://github.com/hesherson/GAIT.git', 'https://github.com/hesherson/GAIT', 'git@github.com:hesherson/GAIT.git')) {
            throw "Unexpected origin in ${Path}: $RemoteUrl"
        }
        $DirtyFiles = @(Run-Git -C $Path status --porcelain)
        if ($DirtyFiles.Count -gt 0) {
            if (-not $StashChanges) {
                throw "Commit or stash changes in $Path, or rerun with -StashChanges to preserve them automatically. No files have been replaced."
            }
            $StashLabel = 'Before GAIT foundation ' + (Get-Date -Format 'yyyyMMdd_HHmmss')
            Run-Git -C $Path stash push --include-untracked -m $StashLabel
            Write-Host "Local edits preserved in stash: $StashLabel. They will not be reapplied automatically."
            if (@(Run-Git -C $Path status --porcelain).Count -gt 0) {
                throw 'Checkout is still dirty after stashing; deployment stopped.'
            }
        }
    }
    function Preserve-ExistingFolder([string]$Path) {
        if (Test-Path -LiteralPath $Path) {
            $BackupPath = $Path + '_before_HEMTT_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
            if (Test-Path -LiteralPath $BackupPath) { throw "Backup already exists: $BackupPath" }
            Move-Item -LiteralPath $Path -Destination $BackupPath
            Write-Host "Previous folder preserved at $BackupPath"
        }
    }

    $PackagePath = $PSScriptRoot
    if (-not (Test-Path -LiteralPath (Join-Path $PackagePath '.hemtt\project.toml'))) {
        throw 'Extract the complete GAIT HEMTT ZIP before running this script.'
    }
    if ([IO.Path]::GetFullPath($PackagePath).TrimEnd('\') -eq [IO.Path]::GetFullPath($RepoPath).TrimEnd('\')) {
        throw 'Run this installer from the extracted download folder, outside your Git checkout.'
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git is not installed or is not on PATH.' }

    if (Test-Path -LiteralPath (Join-Path $RepoPath '.git')) {
        Assert-Checkout $RepoPath
    } elseif (Test-Path -LiteralPath (Join-Path $PreviousRepoPath '.git')) {
        Assert-Checkout $PreviousRepoPath
        Preserve-ExistingFolder $RepoPath
        Move-Item -LiteralPath $PreviousRepoPath -Destination $RepoPath
        Write-Host "Renamed the checkout to $RepoPath"
    } else {
        Preserve-ExistingFolder $RepoPath
        Run-Git clone https://github.com/hesherson/GAIT.git $RepoPath
    }

    Push-Location $RepoPath
    try {
        Run-Git fetch origin
        $Branch = 'dev/gait-foundation-1.8.0'
        $LocalBranch = @(Run-Git branch --list $Branch)
        if ($LocalBranch.Count -gt 0) {
            Run-Git switch $Branch
        } else {
            $RemoteBranch = @(Run-Git branch --remotes --list "origin/$Branch")
            if ($RemoteBranch.Count -gt 0) {
                Run-Git switch --track "origin/$Branch"
            } else {
                $BaseBranch = $null
                foreach ($Candidate in @('origin/dev/gait-1.7.0-rc4', 'origin/dev/gait-1.7.0-rc3', 'origin/main')) {
                    & git rev-parse --verify --quiet $Candidate *> $null
                    if ($LASTEXITCODE -eq 0) { $BaseBranch = $Candidate; break }
                }
                if (-not $BaseBranch) { throw 'No expected remote base branch was found.' }
                Run-Git switch -c $Branch $BaseBranch
            }
        }

        # Move the tracked addon instead of keeping two editable source copies.
        if (Test-Path -LiteralPath 'source\gait') {
            if (Test-Path -LiteralPath 'addons\gait') {
                throw 'Both source\gait and addons\gait exist. Resolve the duplicate source folders before applying this package.'
            }
            New-Item -ItemType Directory -Path 'addons' -Force | Out-Null
            Run-Git mv -- source/gait addons/gait
        }
        foreach ($Folder in @('addons', '.hemtt', 'tests', 'tools')) {
            Copy-Item -LiteralPath (Join-Path $PackagePath $Folder) -Destination $RepoPath -Recurse -Force
        }
        foreach ($File in @('mod.cpp', 'README_HEMTT.md', 'README_TEST_BUILD.md', 'DEPLOY_GITHUB.ps1')) {
            Copy-Item -LiteralPath (Join-Path $PackagePath $File) -Destination $RepoPath -Force
        }
        # Preserve the repository's existing ignore rules.
        $IgnorePath = Join-Path $RepoPath '.gitignore'
        $IgnoreRules = if (Test-Path -LiteralPath $IgnorePath) { @(Get-Content -LiteralPath $IgnorePath) } else { @() }
        $NewRules = @(Get-Content -LiteralPath (Join-Path $PackagePath '.gitignore') | Where-Object { $_ -notin $IgnoreRules })
        if ($NewRules.Count -gt 0) {
            $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [IO.File]::AppendAllText($IgnorePath, [Environment]::NewLine + ($NewRules -join [Environment]::NewLine) + [Environment]::NewLine, $Utf8NoBom)
        }
        if (-not (Get-Command hemtt -ErrorAction SilentlyContinue)) { throw 'HEMTT must be on PATH before deployment. Source was copied; no new commit or push was made.' }
        & hemtt build
        if ($LASTEXITCODE -ne 0) { throw 'HEMTT build failed. Source remains available for inspection; no new commit or push was made.' }
        Run-Git add -- addons .hemtt tests tools mod.cpp .gitignore README_HEMTT.md README_TEST_BUILD.md DEPLOY_GITHUB.ps1
        Run-Git diff --cached --check
        $ChangedFiles = @(Run-Git diff --cached --name-only)
        if ($ChangedFiles.Count -gt 0) {
            Run-Git commit -m 'Rebuild GAIT locomotion foundation while preserving tuned movement features'
        }
        if (-not $NoPush) { Run-Git push -u origin $Branch }
        Write-Host "Built $Branch. Load local mod: $RepoPath\.hemttout\build"
        if ($NoPush) { Write-Host 'Local commit created. GitHub push skipped by -NoPush.' }
    } finally { Pop-Location }
}
