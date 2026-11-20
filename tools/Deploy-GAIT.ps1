[CmdletBinding()]
param(
    [string]$DeployPath
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$build = Join-Path $root '.hemttout/build'
$verify = Join-Path $PSScriptRoot 'verify_build.ps1'

function Test-SameOrChildPath([string]$Path, [string]$Parent) {
    $separator = [IO.Path]::DirectorySeparatorChar
    $parentPath = $Parent.TrimEnd($separator)
    return $Path.Equals($parentPath, [StringComparison]::OrdinalIgnoreCase) -or
        $Path.StartsWith($parentPath + $separator, [StringComparison]::OrdinalIgnoreCase)
}

function Assert-DeployTarget([string]$Path) {
    $existing = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $existing) { return }
    $addons = Join-Path $Path 'addons'
    $currentPbo = Test-Path -LiteralPath (Join-Path $addons 'gait.pbo') -PathType Leaf
    $legacyPbo = Test-Path -LiteralPath (Join-Path $addons 'gait_gait.pbo') -PathType Leaf
    if ($existing -isnot [IO.DirectoryInfo] -or
        ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        !($currentPbo -or $legacyPbo)) {
        throw "DeployPath must be a new directory or an existing GAIT mod directory. Checked $Path."
    }
}

$target = $null
if ($DeployPath) {
    $target = [IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DeployPath))
    if ($target -eq [IO.Path]::GetPathRoot($target)) {
        throw "DeployPath must name a GAIT mod directory within $target."
    }
    $target = $target.TrimEnd([IO.Path]::DirectorySeparatorChar)
    if ($target -ieq $build) {
        $target = $null
    } elseif ((Test-SameOrChildPath $target $root) -or (Test-SameOrChildPath $root $target)) {
        throw "DeployPath overlaps GAIT source or build files at $target."
    } else {
        $parent = Split-Path -Parent $target
        if (!(Test-Path -LiteralPath $parent -PathType Container)) {
            throw "DeployPath's parent directory does not exist: $parent."
        }
        Assert-DeployTarget $target
    }
}

$hemtt = Get-Command hemtt -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $hemtt) {
    $localName = if ($env:OS -eq 'Windows_NT') { 'hemtt.exe' } else { 'hemtt' }
    $localHemtt = Join-Path $root $localName
    if (!(Test-Path -LiteralPath $localHemtt -PathType Leaf)) {
        throw 'Install HEMTT or add its executable to PATH before building GAIT.'
    }
    $hemttPath = $localHemtt
} else {
    $hemttPath = $hemtt.Source
}

Push-Location $root
try {
    & $hemttPath build
    if ($LASTEXITCODE -ne 0) { throw "HEMTT build failed with exit code $LASTEXITCODE." }
    & $verify -BuildPath $build -SourceRoot $root
} finally {
    Pop-Location
}

if (!$target) { return }

$stage = Join-Path $parent ('.gait-stage-' + [guid]::NewGuid().ToString('N'))
$backup = $null
try {
    [void][IO.Directory]::CreateDirectory($stage)
    Get-ChildItem -LiteralPath $build -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $stage -Recurse -Force
    }
    & $verify -BuildPath $stage -SourceRoot $root 6>$null
    Assert-DeployTarget $target
    if (Test-Path -LiteralPath $target) {
        $backup = $target + '.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
        [IO.Directory]::Move($target, $backup)
    }
    try {
        [IO.Directory]::Move($stage, $target)
    } catch {
        if ($backup -and !(Test-Path -LiteralPath $target)) {
            [IO.Directory]::Move($backup, $target)
        } elseif ($backup) {
            Write-Warning "Previous GAIT deployment is available at $backup."
        }
        throw
    }
} finally {
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
}

Write-Host "Load this local mod folder: $target"
if ($backup) { Write-Host "Previous GAIT deployment preserved at $backup." }
