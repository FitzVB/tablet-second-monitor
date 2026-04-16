# Tablet Monitor - Lanzador Simple
# Sin automatización de ADB ni instalación de APK

Write-Host ""
Write-Host "Tablet Monitor - Launcher" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""

$root = Split-Path -Parent $PSScriptRoot

# Preguntar modo de conexión
Write-Host "Selecciona modo de conexión:" -ForegroundColor Gray
Write-Host "  1) USB (recomendado)" -ForegroundColor Gray
Write-Host "  2) Wi-Fi" -ForegroundColor Gray
$pick = Read-Host "Modo [1/2]"

$mode = if ($pick -eq "2") { "wifi" } else { "usb" }

if ($mode -eq "usb") {
    Write-Host ""
    Write-Host "[INFO] Modo USB seleccionado" -ForegroundColor Cyan
    Write-Host "[INFO] Asegúrate que la tablet está conectada por USB" -ForegroundColor Gray
    Write-Host "[INFO] Si necesitas, ejecuta manualmente:" -ForegroundColor Gray
    Write-Host "      adb reverse tcp:9001 tcp:9001" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "[INFO] Modo Wi-Fi seleccionado" -ForegroundColor Cyan
    
    # Detectar IP LAN
    $lanIp = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notlike '127.*' -and
            $_.IPAddress -notlike '169.254*' -and
            $_.InterfaceAlias -notmatch 'Loopback|vEthernet|Virtual|Hyper-V|VPN|Tailscale'
        } |
        Sort-Object InterfaceMetric |
        Select-Object -First 1 -ExpandProperty IPAddress

    if ($lanIp) {
        Write-Host "[OK] IP LAN detectada: $lanIp" -ForegroundColor Green
        Write-Host "[INFO] Ingresa esta IP en la app de Android para conectarte" -ForegroundColor Gray
    } else {
        Write-Host "[WARN] No se pudo detectar la IP LAN automáticamente" -ForegroundColor Yellow
        Write-Host "[INFO] Ejecuta 'ipconfig' y usa tu dirección IPv4" -ForegroundColor Gray
    }
    Write-Host ""
}

# Lanzar servidor
Write-Host "[*] Iniciando servidor..." -ForegroundColor Cyan
Set-Location "$root\host-windows"

# Resetear PATH para cargo/rustup
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')

if ($mode -eq "usb") {
    $env:TABLET_MONITOR_LISTEN = '127.0.0.1'
} else {
    Remove-Item Env:TABLET_MONITOR_LISTEN -ErrorAction SilentlyContinue
}

$env:TABLET_MONITOR_FPS = '60'

if (Test-Path ".\target\release\host-windows.exe") {
    .\target\release\host-windows.exe
} else {
    cargo run --release
}
