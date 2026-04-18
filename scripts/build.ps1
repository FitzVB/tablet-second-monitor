# build.ps1 - Comprehensive build script for FlexDisplay project
# Handles Rust host, Android client, and InnoSetup installer
# Usage: .\build.ps1 -Target host|android|installer|all -Release [-Deploy] [-SkipAndroid] [-SkipSetup]

param(
    [ValidateSet("host", "android", "installer", "all")]
    [string]$Target = "all",

    [switch]$Release = $false,
    [switch]$Deploy = $false,
    [switch]$Clean = $false,
    [switch]$Test = $false,
    [switch]$SkipAndroid = $false,
    [switch]$SkipSetup = $false
)

$ErrorActionPreference = "Stop"
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$StartTime = Get-Date
$ProgressPreference = "SilentlyContinue"

function Write-Header {
    param([string]$Message)
    Write-Host "`n================================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "================================================`n" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Blue
}

# Verify tools
Write-Header "Pre-flight Checks"

$tools = @("cargo")
$missing = @()

foreach ($tool in $tools) {
    try {
        $version = & $tool --version 2>&1 | Select-Object -First 1
        Write-Success "$tool installed: $version"
    } catch {
        $missing += $tool
        Write-Error-Custom "$tool NOT found"
    }
}

if ($missing.Count -gt 0) {
    Write-Error-Custom "Missing critical tools: $($missing -join ', ')"
    exit 1
}

# Download dependencies functions
function Download-FFmpeg {
    Write-Header "Preparing FFmpeg"

    $ffmpegExe = Join-Path $ScriptPath "ffmpeg.exe"

    if (Test-Path $ffmpegExe) {
        Write-Success "ffmpeg.exe already present"
        return
    }

    $cacheDir = Join-Path $ScriptPath ".build-cache"
    New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
    $ffmpegZip = Join-Path $cacheDir "ffmpeg.zip"

    if (-not (Test-Path $ffmpegZip)) {
        Write-Info "Downloading FFmpeg (BtbN static GPL build)..."
        $url = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
        try {
            Invoke-WebRequest -Uri $url -OutFile $ffmpegZip -UseBasicParsing -ErrorAction Stop
            Write-Success "FFmpeg downloaded"
        } catch {
            Write-Error-Custom "Failed to download FFmpeg: $_"
            return
        }
    }

    Write-Host "Extracting FFmpeg..."
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ffmpegZip)
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -match "/bin/ffmpeg\.exe$") {
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $ffmpegExe, $true)
            break
        }
    }
    $zip.Dispose()
    Write-Success "ffmpeg.exe ready"
}

function Download-ADB {
    Write-Header "Preparing ADB"

    $adbNeeded = @("adb.exe", "AdbWinApi.dll", "AdbWinUsbApi.dll")
    $allPresent = $true

    foreach ($f in $adbNeeded) {
        if (-not (Test-Path (Join-Path $ScriptPath $f))) {
            $allPresent = $false
            break
        }
    }

    if ($allPresent) {
        Write-Success "ADB files already present"
        return
    }

    $cacheDir = Join-Path $ScriptPath ".build-cache"
    New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
    $adbZip = Join-Path $cacheDir "adb.zip"

    if (-not (Test-Path $adbZip)) {
        Write-Info "Downloading platform-tools..."
        $url = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
        try {
            Invoke-WebRequest -Uri $url -OutFile $adbZip -UseBasicParsing -ErrorAction Stop
            Write-Success "platform-tools downloaded"
        } catch {
            Write-Error-Custom "Failed to download ADB: $_"
            return
        }
    }

    Write-Host "Extracting ADB..."
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($adbZip)
    foreach ($entry in $zip.Entries) {
        $leaf = [System.IO.Path]::GetFileName($entry.FullName)
        if ($adbNeeded -contains $leaf) {
            $dest = Join-Path $ScriptPath $leaf
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dest, $true)
        }
    }
    $zip.Dispose()
    Write-Success "ADB files ready"
}

# Verify tools
Write-Header "Pre-flight Checks"

$tools = @("rustc", "cargo")
$missing = @()

foreach ($tool in $tools) {
    try {
        $version = & $tool --version 2>&1 | Select-Object -First 1
        Write-Success "$tool installed: $version"
    } catch {
        $missing += $tool
        Write-Error-Custom "$tool NOT found"
    }
}

# Optional tools (Android, Java)
if (-not $SkipAndroid) {
    foreach ($tool in @("java", "javac")) {
        try {
            $version = & $tool -version 2>&1 | Select-Object -First 1
            Write-Success "$tool installed: $version"
        } catch {
            Write-Error-Custom "$tool NOT found (Android build will fail)"
        }
    }
}

if ($missing.Count -gt 0) {
    Write-Error-Custom "Missing critical tools: $($missing -join ', ')"
    exit 1
}


# Build functions
function Build-Host {
    param([bool]$ReleaseMode)

    Write-Header "Building Host (Rust)"
    $buildType = if ($ReleaseMode) { "Release" } else { "Debug" }

    try {
        Push-Location "$ScriptPath\host-windows"

        if ($Clean) {
            Write-Host "Cleaning previous build..."
            cargo clean
        }

        if ($Test) {
            Write-Host "Running tests..."
            cargo test
            Write-Success "Tests passed"
        }

        if ($ReleaseMode) {
            cargo build --release
            $binary = ".\target\release\host-windows.exe"
        } else {
            cargo build
            $binary = ".\target\debug\host-windows.exe"
        }

        if (Test-Path $binary) {
            Write-Success "Host build complete: $binary"
            return $binary
        } else {
            Write-Error-Custom "Build failed: Binary not found"
            return $null
        }
    } catch {
        Write-Error-Custom "Build error: $_"
        return $null
    } finally {
        Pop-Location
    }
}

function Build-Android {
    param([bool]$ReleaseMode)

    Write-Header "Building Android Client"

    try {
        Push-Location "$ScriptPath\android-client"

        if ($Clean) {
            Write-Host "Cleaning previous build..."
            .\gradlew clean
        }

        if ($Test) {
            Write-Host "Running tests..."
            .\gradlew test
            Write-Success "Tests passed"
        }

        if ($ReleaseMode) {
            .\gradlew assembleRelease
            $apk = ".\app\build\outputs\apk\release\app-release.apk"
        } else {
            .\gradlew assembleDebug
            $apk = ".\app\build\outputs\apk\debug\app-debug.apk"
        }

        if (Test-Path $apk) {
            Write-Success "Android build complete: $apk"
            return $apk
        } else {
            Write-Error-Custom "Build failed: APK not found"
            return $null
        }
    } catch {
        Write-Error-Custom "Build error: $_"
        return $null
    } finally {
        Pop-Location
    }
}

function Build-Installer {
    Write-Header "Building InnoSetup Installer"

    # Find InnoSetup installation
    $innoDir = @(
        "C:\Program Files (x86)\Inno Setup 6",
        "C:\Program Files\Inno Setup 6",
        "C:\Program Files (x86)\Inno Setup 5",
        "C:\Program Files\Inno Setup 5"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $innoDir) {
        Write-Error-Custom "Inno Setup not found"
        Write-Info "Download from: https://jrsoftware.org/isdl.php"
        return $null
    }

    $iscc = Join-Path $innoDir "ISCC.exe"
    $setupScript = Join-Path $ScriptPath "setup.iss"

    if (-not (Test-Path $setupScript)) {
        Write-Error-Custom "setup.iss not found"
        return $null
    }

    Write-Info "Using Inno Setup: $innoDir"
    Write-Host "Compiling: $setupScript"

    try {
        & $iscc $setupScript

        if ($LASTEXITCODE -ne 0) {
            throw "ISCC compilation failed"
        }

        $installer = Join-Path $ScriptPath "dist\FlexDisplay-Setup.exe"
        if (Test-Path $installer) {
            Write-Success "Installer created: $installer"
            return $installer
        } else {
            Write-Error-Custom "Installer file not created"
            return $null
        }
    } catch {
        Write-Error-Custom "Installer build error: $_"
        return $null
    }
}

function Deploy-APK {
    param([string]$ApkPath)

    Write-Header "Deploying APK"

    try {
        # Verify device
        $devices = adb devices | Select-Object -Skip 1 | Where-Object { $_ -match " device" }

        if ($null -eq $devices) {
            Write-Error-Custom "No Android devices found"
            return $false
        }

        Write-Host "Connected devices:"
        adb devices

        Write-Host "Installing $ApkPath..."
        adb install -r $ApkPath

        if ($LASTEXITCODE -eq 0) {
            Write-Success "APK installed successfully"
            Write-Host "Launching app..."
            adb shell am start -n com.example.tabletmonitor/.MainActivity
            return $true
        } else {
            Write-Error-Custom "Installation failed"
            return $false
        }
    } catch {
        Write-Error-Custom "Deployment error: $_"
        return $false
    }
}

# Main execution
Write-Info "Target: $Target | Release: $Release | Deploy: $Deploy"

$results = @{}

switch ($Target) {
    "host" {
        Download-FFmpeg
        Download-ADB
        $results.host = Build-Host -ReleaseMode $Release
    }

    "android" {
        if (-not $SkipAndroid) {
            $results.android = Build-Android -ReleaseMode $Release
            if ($Deploy -and $results.android) {
                Deploy-APK -ApkPath $results.android
            }
        }
    }

    "installer" {
        Download-FFmpeg
        Download-ADB
        if (-not $SkipAndroid) {
            $results.android = Build-Android -ReleaseMode $Release
        }
        $results.host = Build-Host -ReleaseMode $Release
        if (-not $SkipSetup) {
            $results.installer = Build-Installer
        }
    }

    "all" {
        Download-FFmpeg
        Download-ADB

        if (-not $SkipAndroid) {
            $results.android = Build-Android -ReleaseMode $Release
            if ($Deploy) {
                Deploy-APK -ApkPath $results.android
            }
        }

        $results.host = Build-Host -ReleaseMode $Release

        if (-not $SkipSetup) {
            $results.installer = Build-Installer
        }
    }
}

# Summary
Write-Header "Build Summary"
if ($results.host) { Write-Success "Host: $($results.host)" }
if ($results.android) { Write-Success "APK: $($results.android)" }
if ($results.installer) { Write-Success "Installer: $($results.installer)" }

# Timing
$Duration = (Get-Date) - $StartTime
Write-Host "`nTotal time: $($Duration.ToString("mm\:ss"))" -ForegroundColor Gray
