#Requires -Version 5.1
<#
.SYNOPSIS
    Build y empaqueta Tablet Monitor en un ZIP listo para distribucion.

.DESCRIPTION
    1. Compila host-windows.exe con cargo build --release
    2. Descarga FFmpeg estatico (BtbN) si no existe en cache
    3. Descarga ADB platform-tools si no existe en cache
    4. Copia todo en dist/TabletMonitor-vX.X.X-windows/
    5. Genera el ZIP

.PARAMETER Version
    Version del paquete. Por defecto lee Cargo.toml.
.PARAMETER SkipAndroid
    Omite la compilacion del APK Android (requiere Android SDK + Gradle).
.PARAMETER CacheDir
    Directorio para almacenar descargas (evita re-descargar). Default: .cache
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
        throw "Falta '$cmd'. Instalalo y agrega al PATH antes de empaquetar."
    }
}

# Download with progress
function Invoke-Download([string]$url, [string]$dest) {
    if (Test-Path $dest) {
        Write-Ok "Cache hit: $(Split-Path $dest -Leaf)"
        return
    }
    Write-Host "    Descargando: $url"
    $tmp = "$dest.tmp"
    try {
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
        Move-Item $tmp $dest
    } catch {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        throw "Fallo la descarga de: $url`n$_"
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
Write-Host "  Destino:  $distDir"
Write-Host "  ZIP:      $zipPath"

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
Write-Step "Verificando herramientas de construccion"
Assert-Command "cargo"
New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null

# ---------------------------------------------------------------------------
# 1. Build Rust host
# ---------------------------------------------------------------------------
Write-Step "Compilando host-windows (release)"
$hostSrc = Join-Path $PSScriptRoot "host-windows"
if (-not (Test-Path $hostSrc)) {
    throw "No se encontro el directorio host-windows/. Ejecuta este script desde la raiz del repo."
}
Push-Location $hostSrc
try {
    cargo build --release
    if ($LASTEXITCODE -ne 0) { throw "cargo build --release fallo (codigo $LASTEXITCODE)" }
    Write-Ok "host-windows.exe compilado"
} finally {
    Pop-Location
}

# ---------------------------------------------------------------------------
# 2. Download FFmpeg (BtbN static GPL build)
# ---------------------------------------------------------------------------
Write-Step "Obteniendo FFmpeg estatico"
$ffmpegZip   = Join-Path $CacheDir "ffmpeg-win64.zip"
$ffmpegUrl   = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
Invoke-Download -url $ffmpegUrl -dest $ffmpegZip

$ffmpegCache = Join-Path $CacheDir "ffmpeg"
if (-not (Test-Path (Join-Path $ffmpegCache "ffmpeg.exe"))) {
    Write-Host "    Extrayendo FFmpeg..."
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
Write-Ok "ffmpeg.exe listo"

# ---------------------------------------------------------------------------
# 3. Download ADB platform-tools
# ---------------------------------------------------------------------------
Write-Step "Obteniendo ADB platform-tools"
$adbZip   = Join-Path $CacheDir "platform-tools-windows.zip"
$adbUrl   = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
Invoke-Download -url $adbUrl -dest $adbZip

$adbCache = Join-Path $CacheDir "adb"
$adbNeeded = @("adb.exe","AdbWinApi.dll","AdbWinUsbApi.dll")
$allAdbPresent = $adbNeeded | ForEach-Object { Test-Path (Join-Path $adbCache $_) }
if ($allAdbPresent -contains $false) {
    Write-Host "    Extrayendo ADB..."
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
Write-Ok "adb.exe listo"

# ---------------------------------------------------------------------------
# 4. (Optional) Build Android APK
# ---------------------------------------------------------------------------
$apkSrc = $null
if (-not $SkipAndroid) {
    Write-Step "Compilando APK Android (debug)"
    $androidDir = Join-Path $PSScriptRoot "android-client"
    if (Test-Path $androidDir) {
        Push-Location $androidDir
        try {
            $gradlew = if ($IsWindows -or $PSVersionTable.Platform -ne "Unix") { ".\gradlew.bat" } else { "./gradlew" }
            & $gradlew assembleDebug
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    AVISO: gradle fallo. El APK no se incluira en el paquete." -ForegroundColor Yellow
            } else {
                $apkFile = Get-ChildItem -Path "app\build\outputs\apk\debug\*.apk" |
                           Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($apkFile) {
                    $apkSrc = $apkFile.FullName
                    Write-Ok "APK: $($apkFile.Name)"
                }
            }
        } catch {
            Write-Host "    AVISO: No se pudo compilar el APK: $_" -ForegroundColor Yellow
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "    Directorio android-client/ no encontrado, omitiendo APK." -ForegroundColor Yellow
    }
} else {
    Write-Host "    --SkipAndroid especificado, omitiendo compilacion Android."
}

# ---------------------------------------------------------------------------
# 5. Assemble distribution directory
# ---------------------------------------------------------------------------
Write-Step "Ensamblando paquete de distribucion"

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
  TABLET MONITOR - Guia rapida de uso
  version $Version
============================================================

REQUISITOS
  - PC con Windows 10/11
  - Tablet/telefono Android 5.0+
  - Cable USB de datos (no solo carga)
  - App TabletMonitor instalada en la tablet

PRIMERA VEZ - CONFIGURACION USB
  1. En la tablet: Ajustes -> Opciones de desarrollador ->
     activa "Depuracion USB"
  2. Conecta la tablet al PC con cable USB
  3. En la tablet: acepta la solicitud "Permitir depuracion USB"
     (activa "Confiar siempre" para no repetirlo)

USO DIARIO
  1. Conecta la tablet por USB
  2. Haz doble clic en  START.bat
  3. Abre la app en la tablet y pulsa "Connect" (o "Conectar")
  4. Para detener: cierra la ventana del host o ejecuta STOP.bat

USO POR WIFI (sin cable)
  1. El PC y la tablet deben estar en la misma red Wi-Fi
  2. Abre la app en la tablet
  3. Escribe la IP local del PC en el campo "PC IP"
     (la puedes ver con ipconfig en el PC, busca IPv4)
  4. Pulsa "Connect"

MULTIPLE MONITORES
  - En el campo "Disp" de la app, escribe 0, 1, 2...
    para elegir que monitor de tu PC se transmite.

PROBLEMAS COMUNES
  - "adb no encontrado": verifica que la tablet este conectada
    y que acceptaste la solicitud de depuracion USB
  - Sin imagen en la tablet: prueba reconectar el cable y
    reiniciar START.bat
  - Imagen entrecortada: baja la calidad en el codigo de URL
    o usa un cable USB de mejor calidad

============================================================
"@
$guideContent | Set-Content (Join-Path $distDir "GUIDE.txt") -Encoding UTF8

Write-Ok "Carpeta lista: $distDir"

# ---------------------------------------------------------------------------
# 6. Create ZIP
# ---------------------------------------------------------------------------
Write-Step "Creando ZIP"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
[System.IO.Compression.ZipFile]::CreateFromDirectory($distDir, $zipPath)
$sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
Write-Ok "ZIP creado: $zipPath  ($sizeMB MB)"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " PAQUETE LISTO" -ForegroundColor Green
Write-Host " $zipPath" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Para publicar en GitHub Releases:"
Write-Host "  gh release create v$Version dist\$distName.zip --title 'v$Version' --notes 'Ver CHANGELOG.md'"
