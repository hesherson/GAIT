param(
    [string]$RepoPath = 'F:\GAIT',
    [string]$PreviousRepoPath = 'F:\GAIT-Git'
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
            throw "Commit or stash your changes in $Path first. No files have been replaced."
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
        $Branch = 'dev/gait-1.7.0-rc2'
        $LocalBranch = @(Run-Git branch --list $Branch)
        if ($LocalBranch.Count -gt 0) {
            Run-Git switch $Branch
        } else {
            $RemoteBranch = @(Run-Git branch --remotes --list "origin/$Branch")
            if ($RemoteBranch.Count -gt 0) {
                Run-Git switch --track "origin/$Branch"
            } else {
                Run-Git switch -c $Branch origin/dev/gait-1.7.0-rc1
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
        foreach ($Folder in @('addons', '.hemtt', 'tests')) {
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
        Run-Git add -- addons .hemtt tests mod.cpp .gitignore README_HEMTT.md README_TEST_BUILD.md DEPLOY_GITHUB.ps1
        Run-Git diff --cached --check
        $ChangedFiles = @(Run-Git diff --cached --name-only)
        if ($ChangedFiles.Count -gt 0) {
            Run-Git commit -m 'Prepare GAIT RC2 for direct HEMTT builds'
        }
        Run-Git push -u origin $Branch
        Write-Host "Deployed $Branch. Build with: cd $RepoPath; hemtt build"
    } finally { Pop-Location }
}
