[CmdletBinding()]
param(
    [string]$Distro = $env:MIAOMIAO_WSL_DISTRO,
    [string]$OutputDir,
    [string]$ApktoolJar,
    [string]$Keystore,
    [string]$KeyAlias = $env:MIAOMIAO_KEY_ALIAS,
    [string]$StorePass = $env:MIAOMIAO_STORE_PASS,
    [string]$KeyPass = $env:MIAOMIAO_KEY_PASS,
    [string]$LegacyApk,
    [string]$BuildTools
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..')).Path
$buildScript = (Resolve-Path (Join-Path $scriptDir 'build.sh')).Path
if (-not $OutputDir) {
    $OutputDir = Join-Path $repoRoot 'dist'
}
$OutputDir = [System.IO.Path]::GetFullPath($OutputDir)
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$wslBase = if ($Distro) { @('-d', $Distro) } else { @() }

function Invoke-Wsl {
    param([string[]]$Arguments)
    $stderrFile = [System.IO.Path]::GetTempFileName()
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & wsl.exe @wslBase -- @Arguments 2>$stderrFile
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previous
    $stderr = Get-Content -LiteralPath $stderrFile -Raw -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stderrFile -Force -ErrorAction SilentlyContinue
    if ($exitCode -ne 0) {
        if ($stderr) { Write-Host $stderr.Trim() }
        throw "WSL command failed: $($Arguments -join ' ')"
    }
}

function Get-WslPath {
    param([string]$Path)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $normalized = $Path -replace '\\', '/'
    $result = & wsl.exe @wslBase -- wslpath -a $normalized 2>$null
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previous
    if ($exitCode -ne 0 -or -not $result) {
        throw "Cannot convert path to WSL: $Path"
    }
    return ($result | Select-Object -First 1).Trim()
}

function Get-AndroidBuildTools {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        if (-not (Test-Path -LiteralPath $ExplicitPath -PathType Container)) {
            throw "Build-tools directory not found: $ExplicitPath"
        }
        $resolved = (Resolve-Path -LiteralPath $ExplicitPath).Path
        if (-not (Test-Path -LiteralPath (Join-Path $resolved 'zipalign.exe')) -or
            -not (Test-Path -LiteralPath (Join-Path $resolved 'apksigner.bat'))) {
            throw "build-tools must contain zipalign.exe and apksigner.bat: $resolved"
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
            if ((Test-Path -LiteralPath (Join-Path $candidate.FullName 'zipalign.exe')) -and
                (Test-Path -LiteralPath (Join-Path $candidate.FullName 'apksigner.bat'))) {
                return $candidate.FullName
            }
        }
    }

    throw 'Android SDK build-tools not found (need zipalign.exe and apksigner.bat).'
}

function Get-Keytool {
    $command = Get-Command keytool.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    if ($env:JAVA_HOME) {
        $candidate = Join-Path $env:JAVA_HOME 'bin\keytool.exe'
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    throw 'keytool not found.'
}

function Get-ApktoolJar {
    param([string]$ExplicitPath)

    $version = '2.10.0'
    $expectedSha256 = 'C0350ABBAB5314248DFE2EE0C907DEF4EDD14F6FAEF1F5D372D3D4ABD28F0431'
    if ($ExplicitPath) {
        if (-not (Test-Path -LiteralPath $ExplicitPath)) {
            throw "apktool jar not found: $ExplicitPath"
        }
        $jarPath = (Resolve-Path -LiteralPath $ExplicitPath).Path
    } else {
        $cacheDir = Join-Path $env:USERPROFILE '.cache\miaomiao-assistant\apktool'
        $jarPath = Join-Path $cacheDir "apktool_$version.jar"
        if (-not (Test-Path -LiteralPath $jarPath)) {
            New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
            $tmp = "$jarPath.part"
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            Write-Host "Downloading apktool $version ..."
            Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/iBotPeaches/Apktool/releases/download/v$version/apktool_$version.jar" -OutFile $tmp
            $downloadedHash = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash
            if ($downloadedHash -ne $expectedSha256) {
                Remove-Item -LiteralPath $tmp -Force
                throw "apktool SHA256 mismatch: $downloadedHash"
            }
            Move-Item -LiteralPath $tmp -Destination $jarPath -Force
        }
    }

    $actualHash = (Get-FileHash -LiteralPath $jarPath -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedSha256) {
        throw "apktool SHA256 mismatch: $actualHash"
    }
    return $jarPath
}

$wslRepo = Get-WslPath $repoRoot
$wslOutput = Get-WslPath $OutputDir
$wslBuildScript = Get-WslPath $buildScript
$apktoolJar = Get-ApktoolJar $ApktoolJar
$wslApktoolJar = Get-WslPath $apktoolJar

Write-Host "Repo: $repoRoot"
Write-Host "Output: $OutputDir"
Invoke-Wsl -Arguments @('env', "APKTOOL_JAR=$wslApktoolJar", 'bash', $wslBuildScript, $wslRepo, $wslOutput)

$unsigned = Get-ChildItem -LiteralPath $OutputDir -Filter 'miaomiao-assistant-*-unsigned.apk' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if (-not $unsigned) {
    throw "Build finished but no unsigned APK was found: $OutputDir"
}

$version = if ($unsigned.BaseName -match '^miaomiao-assistant-(.+)-unsigned$') {
    $Matches[1]
} else {
    'unknown'
}

$buildTools = Get-AndroidBuildTools -ExplicitPath $BuildTools
$zipalign = Join-Path $buildTools 'zipalign.exe'
$apksigner = Join-Path $buildTools 'apksigner.bat'

$customKeystore = [bool]$Keystore
if (-not $customKeystore) {
    $Keystore = Join-Path $env:USERPROFILE '.android\debug.keystore'
    if (-not (Test-Path -LiteralPath $Keystore)) {
        $keytool = Get-Keytool
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Keystore) | Out-Null
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        & $keytool -genkeypair -v -keystore $Keystore -storepass android -keypass android `
            -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 `
            -dname 'CN=Android Debug,O=Android,C=US'
        $keytoolExit = $LASTEXITCODE
        $ErrorActionPreference = $previous
        if ($keytoolExit -ne 0) { throw 'Failed to generate Android debug keystore.' }
    }
} elseif (-not (Test-Path -LiteralPath $Keystore)) {
    throw "Keystore not found: $Keystore"
}

if ($customKeystore) {
    if (-not $KeyAlias) {
        throw 'KeyAlias is required for a custom keystore. Pass -KeyAlias or set MIAOMIAO_KEY_ALIAS.'
    }
    if (-not $StorePass) {
        throw 'Store password is required for a custom keystore. Pass -StorePass or set MIAOMIAO_STORE_PASS.'
    }
    if (-not $KeyPass) {
        $KeyPass = $StorePass
    }
} else {
    if (-not $KeyAlias) { $KeyAlias = 'androiddebugkey' }
    if (-not $StorePass) { $StorePass = 'android' }
    if (-not $KeyPass) { $KeyPass = 'android' }
}

$suffix = if ($customKeystore) { 'release' } else { 'debug' }
$aligned = Join-Path $OutputDir "miaomiao-assistant-$version-aligned.apk"
$signed = Join-Path $OutputDir "miaomiao-assistant-$version-$suffix.apk"
Remove-Item -LiteralPath $aligned -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $signed -Force -ErrorAction SilentlyContinue

$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& $zipalign -p -f 4 $unsigned.FullName $aligned
$zipalignExit = $LASTEXITCODE
$ErrorActionPreference = $previous
if ($zipalignExit -ne 0) { throw 'zipalign failed.' }

$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& $apksigner sign --ks $Keystore --ks-key-alias $KeyAlias `
    --ks-pass "pass:$StorePass" --key-pass "pass:$KeyPass" `
    --out $signed $aligned
$signExit = $LASTEXITCODE
$ErrorActionPreference = $previous
if ($signExit -ne 0) { throw 'apksigner signing failed.' }

$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& $apksigner verify --verbose $signed
$verifyExit = $LASTEXITCODE
$ErrorActionPreference = $previous
if ($verifyExit -ne 0) { throw 'APK signature verification failed.' }

$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& $zipalign -c -v 4 $signed | Select-Object -Last 1
$alignExit = $LASTEXITCODE
$ErrorActionPreference = $previous
if ($alignExit -ne 0) { throw 'APK alignment verification failed.' }

if ($LegacyApk) {
    if (-not (Test-Path -LiteralPath $LegacyApk -PathType Leaf)) {
        throw "Legacy APK not found: $LegacyApk"
    }
    $legacyPath = (Resolve-Path -LiteralPath $LegacyApk).Path
    $checkScript = Join-Path $scriptDir 'check-upgrade.ps1'
    Write-Host "Checking in-place upgrade against $legacyPath ..."
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checkScript `
        -OldApk $legacyPath -NewApk $signed -BuildTools $buildTools
    $checkExit = $LASTEXITCODE
    $ErrorActionPreference = $previous
    if ($checkExit -ne 0) {
        throw 'Upgrade compatibility check failed. This APK cannot replace the installed legacy app; use the original release keystore and a higher versionCode.'
    }
    Write-Host 'Upgrade compatibility check passed.'
    $upgradeStatus = 'true'
} else {
    Write-Host 'WARNING: no -LegacyApk supplied; in-place upgrade compatibility was not verified.'
    $upgradeStatus = 'unverified'
}

Remove-Item -LiteralPath $aligned -Force
$hash = (Get-FileHash -LiteralPath $signed -Algorithm SHA256).Hash
Write-Host "signed_apk=$signed"
Write-Host "sha256=$hash"
Write-Host "upgrade_compatible=$upgradeStatus"
