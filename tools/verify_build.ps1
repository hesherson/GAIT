# Compatible with Windows PowerShell 5.1. No Python or extra modules required.
param(
    [string]$BuildPath = (Join-Path (Split-Path -Parent $PSScriptRoot) '.hemttout\build'),
    [string]$SourceRoot = ''
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

function Read-PboString([byte[]]$Bytes, [ref]$Offset) {
    $Start = $Offset.Value
    while ($Offset.Value -lt $Bytes.Length -and $Bytes[$Offset.Value] -ne 0) {
        $Offset.Value++
    }
    if ($Offset.Value -ge $Bytes.Length) { throw 'Unterminated PBO header string.' }
    $Value = [Text.Encoding]::ASCII.GetString($Bytes, $Start, $Offset.Value - $Start)
    $Offset.Value++
    return $Value
}

function Read-VerifiedPbo([string]$Path, [string]$ExpectedPrefix) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing built PBO: $Path" }
    $Bytes = [IO.File]::ReadAllBytes($Path)
    $Offset = 0
    $Properties = @{}
    $Entries = New-Object 'System.Collections.Generic.List[object]'
    while ($true) {
        $Name = Read-PboString $Bytes ([ref]$Offset)
        if ($Offset + 20 -gt $Bytes.Length) { throw "Truncated PBO header: $Path" }
        $Method = [BitConverter]::ToUInt32($Bytes, $Offset)
        $Size = [BitConverter]::ToUInt32($Bytes, $Offset + 16)
        $Offset += 20
        if ($Name -eq '' -and $Method -eq 0x56657273) {
            while ($true) {
                $Key = Read-PboString $Bytes ([ref]$Offset)
                if ($Key -eq '') { break }
                if ($Properties.ContainsKey($Key)) { throw "Duplicate PBO property '$Key': $Path" }
                $Properties[$Key] = Read-PboString $Bytes ([ref]$Offset)
            }
            continue
        }
        if ($Name -eq '') {
            if ($Method -ne 0 -or $Size -ne 0) { throw "Invalid PBO header terminator: $Path" }
            break
        }
        if ($Method -ne 0) { throw "Unsupported compressed entry '$Name'. Rebuild this package with hemtt build." }
        $Entries.Add([pscustomobject]@{ Name = $Name.Replace('/', '\').ToLowerInvariant(); Size = $Size })
    }
    if ($Properties['prefix'] -cne $ExpectedPrefix) {
        throw "Wrong virtual prefix in ${Path}: expected '$ExpectedPrefix', found '$($Properties['prefix'])'."
    }
    $Files = @{}
    foreach ($Entry in $Entries) {
        if ($Files.ContainsKey($Entry.Name)) { throw "Duplicate PBO entry '$($Entry.Name)': $Path" }
        if ([long]$Offset + $Entry.Size -gt $Bytes.Length - 21) { throw "Truncated PBO payload '$($Entry.Name)': $Path" }
        $Files[$Entry.Name] = [pscustomobject]@{ Offset = $Offset; Size = [int]$Entry.Size }
        $Offset += [int]$Entry.Size
    }
    if ($Offset + 21 -ne $Bytes.Length -or $Bytes[$Offset] -ne 0) { throw "Invalid PBO checksum trailer: $Path" }
    $Hasher = [Security.Cryptography.SHA1]::Create()
    try { $ActualChecksum = $Hasher.ComputeHash($Bytes, 0, $Offset) } finally { $Hasher.Dispose() }
    for ($Index = 0; $Index -lt 20; $Index++) {
        if ($ActualChecksum[$Index] -ne $Bytes[$Offset + 1 + $Index]) { throw "PBO checksum mismatch: $Path" }
    }
    if (-not $Files.ContainsKey('config.bin') -or $Files['config.bin'].Size -le 0) {
        throw "Missing compiled config.bin: $Path"
    }
    return [pscustomobject]@{ Bytes = $Bytes; Files = $Files }
}

$BuildPath = [IO.Path]::GetFullPath($BuildPath)
$AddonPath = Join-Path $BuildPath 'addons'
if (-not (Test-Path -LiteralPath $AddonPath -PathType Container)) { throw "Missing built addons folder: $AddonPath" }
$ExpectedPbos = @('gait_gait.pbo', 'gait_heartbeat.pbo')
$ActualPbos = @(Get-ChildItem -LiteralPath $AddonPath -Filter '*.pbo' -File)
if ($ActualPbos.Count -ne 2 -or @($ActualPbos | Where-Object { $_.Name -notin $ExpectedPbos }).Count -ne 0) {
    throw "Expected only gait_gait.pbo and gait_heartbeat.pbo in $AddonPath. Rebuild into a clean output folder."
}
$Core = Read-VerifiedPbo (Join-Path $AddonPath 'gait_gait.pbo') 'gait'
$Heartbeat = Read-VerifiedPbo (Join-Path $AddonPath 'gait_heartbeat.pbo') 'z\gait\addons\heartbeat'
$RequiredScripts = @(
    'fn_aceFatigueVisualBridge.sqf', 'fn_applyPreset.sqf', 'fn_braceMomentum.sqf',
    'fn_downhillPace.sqf', 'fn_fatigueVisuals.sqf', 'fn_gearInertia.sqf',
    'fn_initSprintSystem.sqf', 'fn_locomotionPace.sqf', 'fn_moduleResetEffects.sqf',
    'fn_nativeController.sqf', 'fn_registerSettings.sqf', 'fn_resetEffects.sqf',
    'fn_slopeLocomotion.sqf', 'fn_slopePaceModel.sqf', 'fn_traversalHelpers.sqf',
    'fn_uphillBrake.sqf'
)
if ($SourceRoot -ne '') {
    $SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
    $SourceFunctions = Join-Path $SourceRoot 'addons\gait\functions'
    $SourceScripts = @(Get-ChildItem -LiteralPath $SourceFunctions -Filter '*.sqf' -File)
    if ($SourceScripts.Count -ne $RequiredScripts.Count -or @($SourceScripts | Where-Object { $_.Name -notin $RequiredScripts }).Count -ne 0) {
        throw 'Source function inventory differs from this package. Update the verifier with intentional source additions.'
    }
}
$Hasher = [Security.Cryptography.SHA256]::Create()
try {
    foreach ($Script in $RequiredScripts) {
        $VirtualPath = 'functions\' + $Script.ToLowerInvariant()
        if (-not $Core.Files.ContainsKey($VirtualPath) -or $Core.Files[$VirtualPath].Size -le 0) {
            throw "Missing or empty runtime script: \gait\$VirtualPath"
        }
        if ($SourceRoot -ne '') {
            $SourceBytes = [IO.File]::ReadAllBytes((Join-Path $SourceFunctions $Script))
            $Entry = $Core.Files[$VirtualPath]
            $SourceHash = [Convert]::ToBase64String($Hasher.ComputeHash($SourceBytes))
            $BuiltHash = [Convert]::ToBase64String($Hasher.ComputeHash($Core.Bytes, $Entry.Offset, $Entry.Size))
            if ($SourceHash -cne $BuiltHash) { throw "Built script does not match current source: $Script" }
        }
    }
} finally { $Hasher.Dispose() }
Write-Host 'GAIT build verified: two PBOs, correct virtual paths, valid checksums, and all 16 runtime scripts.'
if ($SourceRoot -ne '') { Write-Host 'All 16 embedded SQF files match the current source by SHA256.' }
Write-Host "Load this local mod folder: $BuildPath"
