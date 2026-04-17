#Requires -Version 5.1
<#
.SYNOPSIS
    Build and package Tablet Monitor into a distribution-ready ZIP.

.DESCRIPTION
    1. Compila host-windows.exe con cargo build --release
    2. Descarga FFmpeg estatico (BtbN) si no existe en cache
    3. Descarga ADB platform-tools si no existe en cache
    4. Copia todo en dist/TabletMonitor-vX.X.X-windows/
    5. Genera el ZIP

.PARAMETER Version
    Package version. Defaults to Cargo.toml.
.PARAMETER SkipAndroid
    Skip Android APK build (requires Android SDK + Gradle).
.PARAMETER CacheDir
    Directory used for cached downloads (avoids re-downloading). Default: .cache
#>
param(
    [string]$Version         = "",
    [switch]$SkipAndroid,
    [string]$CacheDir        = (Join-Path $PSScriptRoot ".cache")
)

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"   # Makes Invoke-WebRequest much faster

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Step([string]$msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Write-Ok([string]$msg) {
    Write-Host "    [OK] $msg" -ForegroundColor Green
}

function Assert-Command([string]$cmd) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw "Missing '$cmd'. Install it and add it to PATH before packaging."
    }
}

# Download with progress
function Invoke-Download([string]$url, [string]$dest) {
    if (Test-Path $dest) {
        Write-Ok "Cache hit: $(Split-Path $dest -Leaf)"
        return
    }
    Write-Host "    Downloading: $url"
    $tmp = "$dest.tmp"
    try {
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
        Move-Item $tmp $dest
    } catch {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        throw "Download failed: $url`n$_"
    }
}

# ---------------------------------------------------------------------------
# Resolve version from Cargo.toml
# ---------------------------------------------------------------------------
if (-not $Version) {
    $cargoToml = Join-Path $PSScriptRoot "host-windows\Cargo.toml"
    if (Test-Path $cargoToml) {
        $versionLine = Select-String 'version\s*=\s*"([^"]+)"' $cargoToml | Select-Object -First 1
        if ($versionLine) {
            $Version = $versionLine.Matches[0].Groups[1].Value
        }
    }
    if (-not $Version) { $Version = "0.0.0" }
}

$distName   = "TabletMonitor-v$Version-windows"
$distDir    = Join-Path $PSScriptRoot "dist\$distName"
$zipPath    = Join-Path $PSScriptRoot "dist\$distName.zip"

Write-Step "Tablet Monitor packager  —  version $Version"
Write-Host "  Destination:  $distDir"
Write-Host "  ZIP:      $zipPath"

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
Write-Step "Checking build tools"
Assert-Command "cargo"
New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null

# ---------------------------------------------------------------------------
# 1. Build Rust host
# ---------------------------------------------------------------------------
Write-Step "Compilando host-windows (release)"
$hostSrc = Join-Path $PSScriptRoot "host-windows"
if (-not (Test-Path $hostSrc)) {
    throw "host-windows/ directory not found. Run this script from the repository root."
}
Push-Location $hostSrc
try {
    cargo build --release
    if ($LASTEXITCODE -ne 0) { throw "cargo build --release failed (exit code $LASTEXITCODE)" }
    Write-Ok "host-windows.exe built"
} finally {
    Pop-Location
}

# ---------------------------------------------------------------------------
# 2. Download FFmpeg (BtbN static GPL build)
# ---------------------------------------------------------------------------
Write-Step "Fetching static FFmpeg"
$ffmpegZip   = Join-Path $CacheDir "ffmpeg-win64.zip"
$ffmpegUrl   = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
Invoke-Download -url $ffmpegUrl -dest $ffmpegZip

$ffmpegCache = Join-Path $CacheDir "ffmpeg"
if (-not (Test-Path (Join-Path $ffmpegCache "ffmpeg.exe"))) {
    Write-Host "    Extracting FFmpeg..."
    Remove-Item $ffmpegCache -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $ffmpegCache | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ffmpegZip)
    foreach ($entry in $zip.Entries) {
        # Only extract bin/ subdirectory contents
        if ($entry.FullName -match "/bin/ffmpeg\.exe$") {
            $destFile = Join-Path $ffmpegCache "ffmpeg.exe"
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destFile, $true)
        }
    }
    $zip.Dispose()
}
Write-Ok "ffmpeg.exe ready"

# ---------------------------------------------------------------------------
# 3. Download ADB platform-tools
# ---------------------------------------------------------------------------
Write-Step "Fetching ADB platform-tools"
$adbZip   = Join-Path $CacheDir "platform-tools-windows.zip"
$adbUrl   = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
Invoke-Download -url $adbUrl -dest $adbZip

$adbCache = Join-Path $CacheDir "adb"
$adbNeeded = @("adb.exe","AdbWinApi.dll","AdbWinUsbApi.dll")
$allAdbPresent = $adbNeeded | ForEach-Object { Test-Path (Join-Path $adbCache $_) }
if ($allAdbPresent -contains $false) {
    Write-Host "    Extracting ADB..."
    Remove-Item $adbCache -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $adbCache | Out-Null
    $zip = [System.IO.Compression.ZipFile]::OpenRead($adbZip)
    foreach ($entry in $zip.Entries) {
        $leaf = [System.IO.Path]::GetFileName($entry.FullName)
        if ($adbNeeded -contains $leaf) {
            $destFile = Join-Path $adbCache $leaf
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destFile, $true)
        }
    }
    $zip.Dispose()
}
Write-Ok "adb.exe ready"

# ---------------------------------------------------------------------------
# 4. (Optional) Build Android APK
# ---------------------------------------------------------------------------
$apkSrc = $null
if (-not $SkipAndroid) {
    Write-Step "Building Android APK (debug)"
    $androidDir = Join-Path $PSScriptRoot "android-client"
    if (Test-Path $androidDir) {
        Push-Location $androidDir
        try {
            $gradlew = if ($IsWindows -or $PSVersionTable.Platform -ne "Unix") { ".\gradlew.bat" } else { "./gradlew" }
            & $gradlew assembleDebug
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    WARN: gradle failed. APK will not be included in the package." -ForegroundColor Yellow
            } else {
                $apkFile = Get-ChildItem -Path "app\build\outputs\apk\debug\*.apk" |
                           Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($apkFile) {
                    $apkSrc = $apkFile.FullName
                    Write-Ok "APK: $($apkFile.Name)"
                }
            }
        } catch {
            Write-Host "    WARN: Could not build APK: $_" -ForegroundColor Yellow
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "    android-client/ directory not found, skipping APK." -ForegroundColor Yellow
    }
} else {
    Write-Host "    --SkipAndroid specified, skipping Android build."
}

# ---------------------------------------------------------------------------
# 5. Assemble distribution directory
# ---------------------------------------------------------------------------
Write-Step "Assembling distribution package"

if (Test-Path $distDir) { Remove-Item $distDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $distDir | Out-Null

# Host binary
Copy-Item (Join-Path $hostSrc "target\release\host-windows.exe") (Join-Path $distDir "host-windows.exe")

# FFmpeg
Copy-Item (Join-Path $ffmpegCache "ffmpeg.exe") (Join-Path $distDir "ffmpeg.exe")

# ADB + DLLs
foreach ($f in $adbNeeded) {
    $src = Join-Path $adbCache $f
    if (Test-Path $src) { Copy-Item $src (Join-Path $distDir $f) }
}

# APK
if ($apkSrc -and (Test-Path $apkSrc)) {
    Copy-Item $apkSrc (Join-Path $distDir "TabletMonitor.apk")
}

# Launcher scripts
Copy-Item (Join-Path $PSScriptRoot "START.bat") (Join-Path $distDir "START.bat")
Copy-Item (Join-Path $PSScriptRoot "STOP.bat")  (Join-Path $distDir "STOP.bat")

# Guide
$guideContent = @"
============================================================
    TABLET MONITOR - Quick usage guide
  version $Version
============================================================

REQUIREMENTS
    - Windows 10/11 PC
    - Android tablet/phone 5.0+
    - USB data cable (not charge-only)
    - TabletMonitor app installed on tablet

FIRST RUN - USB SETUP
    1. On tablet: Settings -> Developer options ->
         enable "USB debugging"
    2. Connect the tablet to the PC with USB cable
    3. On tablet: accept the "Allow USB debugging" prompt
         (enable "Always trust" to avoid repeated prompts)

DAILY USE
    1. Connect the tablet over USB
    2. Double-click START.bat
    3. Open the app on tablet and tap "Connect"
    4. To stop: close the host window or run STOP.bat

WIFI MODE (NO CABLE)
    1. PC and tablet must be on the same Wi-Fi network
    2. Open the app on tablet
    3. Enter the PC local IP in "PC IP"
         (check via ipconfig on the PC, look for IPv4)
    4. Tap "Connect"

MULTI-MONITOR
    - In the app "Disp" field, enter 0, 1, 2...
        to choose which monitor is streamed.

COMMON ISSUES
    - "adb not found": verify the tablet is connected
        and USB debugging authorization was accepted
    - No image on tablet: reconnect cable and restart START.bat
    - Choppy image: lower URL quality settings
        or use a higher quality USB cable

============================================================
"@
$guideContent | Set-Content (Join-Path $distDir "GUIDE.txt") -Encoding UTF8

Write-Ok "Folder ready: $distDir"

# ---------------------------------------------------------------------------
# 6. Create ZIP
# ---------------------------------------------------------------------------
Write-Step "Creating ZIP"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
[System.IO.Compression.ZipFile]::CreateFromDirectory($distDir, $zipPath)
$sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
Write-Ok "ZIP created: $zipPath  ($sizeMB MB)"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " PACKAGE READY" -ForegroundColor Green
Write-Host " $zipPath" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Para publicar en GitHub Releases:"
Write-Host "  gh release create v$Version dist\$distName.zip --title 'v$Version' --notes 'Ver CHANGELOG.md'"
