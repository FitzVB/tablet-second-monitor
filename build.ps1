# build.ps1 - Comprehensive build script for Tablet Monitor project
# Handles both Rust host and Android client builds
# Usage: .\build.ps1 -Target host|android|all -Release [-Deploy]

param(
    [ValidateSet("host", "android", "all")]
    [string]$Target = "all",
    
    [switch]$Release = $false,
    [switch]$Deploy = $false,
    [switch]$Clean = $false,
    [switch]$Test = $false
)

$ErrorActionPreference = "Stop"
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$StartTime = Get-Date

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

# Verify tools
Write-Header "Pre-flight Checks"

$tools = @("rustc", "cargo", "adb", "java", "javac")
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
    Write-Error-Custom "Missing tools: $($missing -join ', ')"
    Write-Host "Run .\setup.ps1 -Install to fix" -ForegroundColor Yellow
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
switch ($Target) {
    "host" {
        $hostBinary = Build-Host -ReleaseMode $Release
        if ($hostBinary -and -not $Deploy) {
            Write-Header "Build Summary"
            Write-Success "Host binary: $hostBinary"
        }
    }
    
    "android" {
        $androidApk = Build-Android -ReleaseMode $Release
        if ($androidApk) {
            if ($Deploy) {
                Deploy-APK -ApkPath $androidApk
            } else {
                Write-Header "Build Summary"
                Write-Success "APK: $androidApk"
            }
        }
    }
    
    "all" {
        $hostBinary = Build-Host -ReleaseMode $Release
        $androidApk = Build-Android -ReleaseMode $Release
        
        if ($Deploy -and $androidApk) {
            Deploy-APK -ApkPath $androidApk
        }
        
        if ($hostBinary -or $androidApk) {
            Write-Header "Build Summary"
            if ($hostBinary) { Write-Success "Host: $hostBinary" }
            if ($androidApk) { Write-Success "APK: $androidApk" }
        }
    }
}

# Timing
$Duration = (Get-Date) - $StartTime
Write-Host "`nTotal time: $($Duration.ToString("mm\:ss"))" -ForegroundColor Gray
