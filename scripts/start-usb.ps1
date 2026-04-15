$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot

# ---------------------------------------------------------------------------
# Resolve ADB: bundled copy first, then SDK, then PATH.
# The bundled distribution ships adb.exe in the same folder as host-windows.exe
# so that the user does not need Android SDK installed.
# ---------------------------------------------------------------------------
function Resolve-AdbPath {
    param([string]$Root)

    # 1. Bundled next to the host executable (dist package)
    $bundled = Join-Path $Root "adb.exe"
    if (Test-Path $bundled) { return $bundled }

    # 2. Android SDK installed on the machine
    $sdkAdb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $sdkAdb) { return $sdkAdb }

    # 3. Somewhere on PATH
    $inPath = Get-Command adb -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }

    throw "adb.exe no encontrado. Descarga el paquete de distribucion completo desde GitHub Releases."
}

# ---------------------------------------------------------------------------
# Locate the host executable: pre-built release binary or fall back to cargo run
# ---------------------------------------------------------------------------
function Start-Host {
    param([string]$Root)

    $releaseBin = Join-Path $Root "host-windows.exe"
    if (Test-Path $releaseBin) {
        Write-Host "Iniciando host (release): $releaseBin"
        $env:TABLET_MONITOR_LISTEN = "127.0.0.1"
        & $releaseBin
    } else {
        Write-Host "Binario precompilado no encontrado, usando cargo run..."
        $hostDir = Join-Path $Root "host-windows"
        if (-not (Test-Path $hostDir)) {
            throw "No se encontro ni host-windows.exe ni el directorio host-windows/. Instala desde GitHub Releases."
        }
        Set-Location $hostDir
        $env:TABLET_MONITOR_LISTEN = "127.0.0.1"
        cargo run --release
    }
}

$adb = Resolve-AdbPath -Root $root
Write-Host "Usando adb: $adb"
& $adb start-server 2>$null | Out-Null

# Check for connected authorized device
$devices = & $adb devices
$authorizedDevices = $devices | Select-String "\tdevice$"
if (-not $authorizedDevices) {
    Write-Host ""
    Write-Host "AVISO: No hay dispositivo Android autorizado por USB."
    Write-Host "  1. Conecta la tablet con cable USB de datos."
    Write-Host "  2. Activa 'Depuracion USB' en Ajustes -> Opciones de desarrollador."
    Write-Host "  3. Acepta la huella RSA que aparece en la tablet."
    Write-Host "Reintentando en 5 segundos..."
    Start-Sleep -Seconds 5
    $devices = & $adb devices
    $authorizedDevices = $devices | Select-String "\tdevice$"
    if (-not $authorizedDevices) {
        Write-Host "Aun sin dispositivo. Continuando de todas formas (modo Wi-Fi)."
    }
}

& $adb reverse tcp:9001 tcp:9001 2>$null | Out-Null
Write-Host "ADB reverse activo: tablet:9001 -> host:9001"

# Install APK if present in the distribution package
$apk = Join-Path $root "TabletMonitor.apk"
if (Test-Path $apk) {
    $installed = & $adb shell pm list packages 2>$null | Select-String "com.example.tabletmonitor"
    if (-not $installed) {
        Write-Host "Instalando TabletMonitor.apk en la tablet..."
        & $adb install -r $apk
    }
}

Write-Host ""
Write-Host "============================================================"
Write-Host " Tablet Monitor - Servidor iniciado"
Write-Host " Abre la app en la tablet y pulsa 'Connect'"
Write-Host " Presiona Ctrl+C para detener"
Write-Host "============================================================"
Write-Host ""

Start-Host -Root $root
