param(
    [switch]$AutoLaunch = $false
)

$ErrorActionPreference = "Stop"
$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:RuntimeRoot = Join-Path $script:RepoRoot ".runtime"

function Write-Step {
    param([string]$Message)
    Write-Host "`n[STEP] $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Download-File {
    param(
        [string]$Url,
        [string]$OutFile
    )
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
}

function Expand-ZipTo {
    param(
        [string]$ZipPath,
        [string]$DestPath
    )
    Ensure-Dir $DestPath
    Expand-Archive -Path $ZipPath -DestinationPath $DestPath -Force
}

function Set-LocalRuntimeEnv {
    $runtimeEnv = Join-Path $PSScriptRoot "runtime-env.ps1"
    . $runtimeEnv -RootPath $script:RepoRoot
}

function Ensure-Winget {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw "winget.exe is not available. Install App Installer and run again."
    }
}

function Ensure-AdbLocal {
    $adbExe = Join-Path $script:RuntimeRoot "adb\platform-tools\adb.exe"
    if (Test-Path $adbExe) {
        Write-Ok "ADB local ready"
        return
    }

    Write-Step "Installing local ADB in .runtime"
    $tmp = Join-Path $env:TEMP "flexdisplay-platform-tools.zip"
    Download-File -Url "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $tmp
    Expand-ZipTo -ZipPath $tmp -DestPath (Join-Path $script:RuntimeRoot "adb")
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path $adbExe)) {
        throw "Could not install local ADB"
    }
    Write-Ok "ADB local installed"
}

function Ensure-JavaLocal {
    $javaExe = Join-Path $script:RuntimeRoot "java\current\bin\java.exe"
    if (Test-Path $javaExe) {
        Write-Ok "Java local ready"
        return
    }

    Write-Step "Installing local Java 17 in .runtime"
    $api = "https://api.adoptium.net/v3/assets/latest/17/hotspot?os=windows&architecture=x64&image_type=jdk&vendor=eclipse"
    $assets = Invoke-RestMethod -Uri $api
    $pkg = $assets | Select-Object -First 1
    if (-not $pkg -or -not $pkg.binary.package.link) {
        throw "Could not resolve Java package URL"
    }

    $zipPath = Join-Path $env:TEMP "flexdisplay-jdk17.zip"
    Download-File -Url $pkg.binary.package.link -OutFile $zipPath

    $extractBase = Join-Path $script:RuntimeRoot "java"
    Ensure-Dir $extractBase
    Expand-ZipTo -ZipPath $zipPath -DestPath $extractBase
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

    $jdkDir = Get-ChildItem $extractBase -Directory | Where-Object { $_.Name -like "jdk-*" } | Select-Object -First 1
    if (-not $jdkDir) {
        throw "Could not find extracted JDK directory"
    }

    $current = Join-Path $extractBase "current"
    if (Test-Path $current) {
        Remove-Item $current -Recurse -Force
    }
    New-Item -ItemType Junction -Path $current -Target $jdkDir.FullName | Out-Null

    if (-not (Test-Path $javaExe)) {
        throw "Could not install local Java"
    }
    Write-Ok "Java local installed"
}

function Ensure-RustLocal {
    $cargoExe = Join-Path $script:RuntimeRoot "rust\cargo\bin\cargo.exe"
    $rustcExe = Join-Path $script:RuntimeRoot "rust\cargo\bin\rustc.exe"
    if ((Test-Path $cargoExe) -and (Test-Path $rustcExe)) {
        Write-Ok "Rust local ready"
        return
    }

    Write-Step "Installing local Rust toolchain in .runtime"
    $rustDir = Join-Path $script:RuntimeRoot "rust"
    Ensure-Dir $rustDir

    $installer = Join-Path $env:TEMP "rustup-init.exe"
    Download-File -Url "https://win.rustup.rs/x86_64" -OutFile $installer

    $env:CARGO_HOME = Join-Path $rustDir "cargo"
    $env:RUSTUP_HOME = Join-Path $rustDir "rustup"

    & $installer -y --default-toolchain stable --profile minimal --no-modify-path
    if ($LASTEXITCODE -ne 0) {
        throw "Rust local install failed"
    }

    Remove-Item $installer -Force -ErrorAction SilentlyContinue

    if ((-not (Test-Path $cargoExe)) -or (-not (Test-Path $rustcExe))) {
        throw "Rust binaries not found after installation"
    }
    Write-Ok "Rust local installed"
}

function Ensure-FfmpegLocal {
    $ffmpegExe = Join-Path $script:RuntimeRoot "ffmpeg\bin\ffmpeg.exe"
    if (Test-Path $ffmpegExe) {
        Write-Ok "FFmpeg local ready"
        return
    }

    Write-Step "Installing local FFmpeg in .runtime"
    $zipPath = Join-Path $env:TEMP "flexdisplay-ffmpeg.zip"
    Download-File -Url "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip" -OutFile $zipPath

    $tmpExtract = Join-Path $script:RuntimeRoot "ffmpeg_tmp"
    Expand-ZipTo -ZipPath $zipPath -DestPath $tmpExtract
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

    $inner = Get-ChildItem $tmpExtract -Directory | Select-Object -First 1
    if (-not $inner) {
        throw "Could not extract FFmpeg"
    }

    $final = Join-Path $script:RuntimeRoot "ffmpeg"
    if (Test-Path $final) {
        Remove-Item $final -Recurse -Force
    }
    Move-Item -Path $inner.FullName -Destination $final
    Remove-Item $tmpExtract -Recurse -Force -ErrorAction SilentlyContinue

    if (-not (Test-Path $ffmpegExe)) {
        throw "Could not install local FFmpeg"
    }
    Write-Ok "FFmpeg local installed"
}

function Ensure-VirtualDisplayDriver {
    Write-Step "Checking virtual display driver"
    Ensure-Winget
    $check = winget list --id VirtualDrivers.Virtual-Display-Driver -e 2>$null | Out-String
    if ($check -match "VirtualDrivers.Virtual-Display-Driver") {
        Write-Ok "Virtual display driver already installed"
        return
    }

    Write-Warn "Virtual display driver not found. Installing (system driver)..."
    $installScript = Join-Path $script:RepoRoot "scripts\install-virtual-display.ps1"
    & $installScript
    if ($LASTEXITCODE -ne 0) {
        throw "Virtual display driver installation failed"
    }
    Write-Ok "Virtual display driver installed"
}

function Ensure-InitialBuilds {
    Set-LocalRuntimeEnv

    Write-Step "Building host (release) if needed"
    $hostExe = Join-Path $script:RepoRoot "host-windows\target\release\host-windows.exe"
    if (-not (Test-Path $hostExe)) {
        Push-Location (Join-Path $script:RepoRoot "host-windows")
        try {
            cargo build --release
            if ($LASTEXITCODE -ne 0) { throw "Host build failed" }
        } finally {
            Pop-Location
        }
        Write-Ok "Host build completed"
    } else {
        Write-Ok "Host release binary already exists"
    }

    Write-Step "Building Android APK (debug) if needed"
    $apk = Join-Path $script:RepoRoot "android-client\app\build\outputs\apk\debug\app-debug.apk"
    if (-not (Test-Path $apk)) {
        Push-Location (Join-Path $script:RepoRoot "android-client")
        try {
            .\gradlew.bat assembleDebug
            if ($LASTEXITCODE -ne 0) { throw "Android debug build failed" }
        } finally {
            Pop-Location
        }
        Write-Ok "Android debug APK generated"
    } else {
        Write-Ok "Android debug APK already exists"
    }
}

Write-Host ""
Write-Host "FlexDisplay - First Run Setup" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

Ensure-Dir $script:RuntimeRoot
Ensure-Dir (Join-Path $script:RuntimeRoot "bin")

Ensure-AdbLocal
Ensure-JavaLocal
Ensure-RustLocal
Ensure-FfmpegLocal
Set-LocalRuntimeEnv
Ensure-VirtualDisplayDriver
Ensure-InitialBuilds

Write-Host ""
Write-Host "[DONE] First run setup complete (local runtime in .runtime)." -ForegroundColor Green
Write-Host "       If virtual display was just installed, one reboot may be required." -ForegroundColor Yellow

if ($AutoLaunch) {
    Write-Step "Launching START.bat"
    $startBat = Join-Path $script:RepoRoot "START.bat"
    & $startBat
}
