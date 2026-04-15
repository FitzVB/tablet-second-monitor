$ErrorActionPreference = "Stop"

function Resolve-AdbPath {
    $adbFromPath = Get-Command adb -ErrorAction SilentlyContinue
    if ($adbFromPath) {
        return $adbFromPath.Source
    }

    $sdkAdb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $sdkAdb) {
        return $sdkAdb
    }

    throw "No se encontro adb. Instala Android SDK Platform-Tools o agrega adb al PATH."
}

$root = Split-Path -Parent $PSScriptRoot
$hostDir = Join-Path $root "host-windows"
$adb = Resolve-AdbPath

Write-Host "Usando adb: $adb"
& $adb start-server | Out-Null

$devices = & $adb devices
$authorizedDevices = $devices | Select-String "\tdevice$"
if (-not $authorizedDevices) {
    throw "No hay dispositivo Android autorizado por USB. Activa depuracion USB y acepta la clave RSA."
}

& $adb reverse tcp:9001 tcp:9001 | Out-Null
Write-Host "ADB reverse activo: tcp:9001 -> host tcp:9001"

Set-Location $hostDir
$env:TABLET_MONITOR_LISTEN = "127.0.0.1"

Write-Host "Iniciando host USB en 127.0.0.1:9001..."
Write-Host "Para cerrar: Ctrl+C y luego ejecuta scripts\\stop-usb.ps1"
cargo run
