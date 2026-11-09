[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OldApk,

    [Parameter(Mandatory = $true)]
    [string]$NewApk,

    [string]$BuildTools
)

$ErrorActionPreference = 'Stop'

function Resolve-ApkPath {
    param(
        [string]$Path,
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label not found: $Path"
    }

    return (Resolve-Path -LiteralPath $Path).Path
}

function Get-AndroidBuildToolsPath {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        if (-not (Test-Path -LiteralPath $ExplicitPath -PathType Container)) {
            throw "Build-tools directory not found: $ExplicitPath"
        }

        $resolved = (Resolve-Path -LiteralPath $ExplicitPath).Path
        if (-not (Test-Path -LiteralPath (Join-Path $resolved 'apksigner.bat')) -and
            -not (Test-Path -LiteralPath (Join-Path $resolved 'apksigner.exe'))) {
            throw "apksigner not found in build-tools: $resolved"
        }
        if (-not (Test-Path -LiteralPath (Join-Path $resolved 'aapt2.exe')) -and
            -not (Test-Path -LiteralPath (Join-Path $resolved 'aapt.exe'))) {
            throw "aapt2/aapt not found in build-tools: $resolved"
        }
        return $resolved
    }

    $roots = @(
        $env:ANDROID_SDK_ROOT,
        $env:ANDROID_HOME,
        (Join-Path $env:LOCALAPPDATA 'Android\Sdk'),
        'C:\Android\Sdk'
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

    foreach ($root in $roots) {
        $buildToolsRoot = Join-Path $root 'build-tools'
        if (-not (Test-Path -LiteralPath $buildToolsRoot)) { continue }

        $candidates = Get-ChildItem -LiteralPath $buildToolsRoot -Directory |
            Sort-Object { try { [version]$_.Name } catch { [version]'0.0.0' } } -Descending

        foreach ($candidate in $candidates) {
            $hasSigner = (Test-Path -LiteralPath (Join-Path $candidate.FullName 'apksigner.bat')) -or
                (Test-Path -LiteralPath (Join-Path $candidate.FullName 'apksigner.exe'))
            $hasAapt = (Test-Path -LiteralPath (Join-Path $candidate.FullName 'aapt2.exe')) -or
                (Test-Path -LiteralPath (Join-Path $candidate.FullName 'aapt.exe'))
            if ($hasSigner -and $hasAapt) {
                return $candidate.FullName
            }
        }
    }

    throw 'Android SDK build-tools not found (need apksigner and aapt2/aapt).'
}

function Get-ApkInfo {
    param(
        [string]$Apk,
        [string]$BuildToolsPath
    )

    $aapt2 = Join-Path $BuildToolsPath 'aapt2.exe'
    $aapt = Join-Path $BuildToolsPath 'aapt.exe'
    if (Test-Path -LiteralPath $aapt2) {
        $tool = $aapt2
        $arguments = @('dump', 'badging', $Apk)
    } elseif (Test-Path -LiteralPath $aapt) {
        $tool = $aapt
        $arguments = @('dump', 'badging', $Apk)
    } else {
        throw 'aapt2/aapt not found.'
    }

    $output = & $tool @arguments 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "Failed to read APK metadata: $Apk`n$output"
    }

    if ($output -notmatch "package: name='([^']+)' versionCode='([^']+)' versionName='([^']*)'") {
        throw "Cannot parse package metadata from APK: $Apk`n$output"
    }

    return [pscustomobject]@{
        Package = $Matches[1]
        VersionCode = [long]$Matches[2]
        VersionName = $Matches[3]
    }
}

function Get-ApkSignerSha256 {
    param(
        [string]$Apk,
        [string]$BuildToolsPath
    )

    $apksigner = Join-Path $BuildToolsPath 'apksigner.bat'
    if (-not (Test-Path -LiteralPath $apksigner)) {
        $apksigner = Join-Path $BuildToolsPath 'apksigner.exe'
    }
    if (-not (Test-Path -LiteralPath $apksigner)) {
        throw 'apksigner not found.'
    }

    $output = & $apksigner verify --print-certs $Apk 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "APK signature verification failed: $Apk`n$output"
    }

    $signers = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($output -split "`r?`n")) {
        if ($line -match '(?i)signer.*certificate SHA-256 digest:\s*([0-9A-Fa-f]+)') {
            $signers.Add($Matches[1].ToLowerInvariant())
        }
    }

    if ($signers.Count -eq 0) {
        throw "No signer certificate found in APK: $Apk`n$output"
    }

    return @($signers | Sort-Object -Unique)
}

$oldPath = Resolve-ApkPath -Path $OldApk -Label 'Old APK'
$newPath = Resolve-ApkPath -Path $NewApk -Label 'New APK'
$buildToolsPath = Get-AndroidBuildToolsPath -ExplicitPath $BuildTools

$oldInfo = Get-ApkInfo -Apk $oldPath -BuildToolsPath $buildToolsPath
$newInfo = Get-ApkInfo -Apk $newPath -BuildToolsPath $buildToolsPath
$oldSigners = @(Get-ApkSignerSha256 -Apk $oldPath -BuildToolsPath $buildToolsPath)
$newSigners = @(Get-ApkSignerSha256 -Apk $newPath -BuildToolsPath $buildToolsPath)

$packageMatches = $oldInfo.Package -eq $newInfo.Package
$versionIncreases = $newInfo.VersionCode -gt $oldInfo.VersionCode
$oldSignerText = $oldSigners -join ','
$newSignerText = $newSigners -join ','
$signaturesMatch = $oldSignerText -eq $newSignerText
$compatible = $packageMatches -and $versionIncreases -and $signaturesMatch

Write-Output "old_apk=$oldPath"
Write-Output "new_apk=$newPath"
Write-Output "old_package=$($oldInfo.Package)"
Write-Output "new_package=$($newInfo.Package)"
Write-Output "old_version_code=$($oldInfo.VersionCode)"
Write-Output "new_version_code=$($newInfo.VersionCode)"
Write-Output "old_version_name=$($oldInfo.VersionName)"
Write-Output "new_version_name=$($newInfo.VersionName)"
Write-Output "old_signer_sha256=$oldSignerText"
Write-Output "new_signer_sha256=$newSignerText"
Write-Output "UPGRADE_COMPATIBLE=$($compatible.ToString().ToLowerInvariant())"

if (-not $packageMatches) {
    [Console]::Error.WriteLine('reason=package_name_mismatch')
}
if (-not $versionIncreases) {
    [Console]::Error.WriteLine('reason=version_code_not_increased')
}
if (-not $signaturesMatch) {
    [Console]::Error.WriteLine('reason=signer_mismatch_use_original_release_keystore')
}

if (-not $compatible) {
    exit 1
}

exit 0
