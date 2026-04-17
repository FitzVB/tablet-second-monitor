# Tablet Monitor - Wi-Fi Mode Startup

Write-Host ""
Write-Host "Tablet Monitor - Wi-Fi Mode Startup" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Reset PATH to machine+user defaults (cargo/rustup expected there)
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')

# IMPORTANT: do not force localhost in Wi-Fi mode
Remove-Item Env:TABLET_MONITOR_LISTEN -ErrorAction SilentlyContinue

# Best effort: detect LAN IPv4 for user guidance
$lanIp = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.IPAddress -notlike '127.*' -and
        $_.IPAddress -notlike '169.254*' -and
        $_.InterfaceAlias -notmatch 'Loopback|vEthernet|Virtual|Hyper-V|VPN|Tailscale'
    } |
    Sort-Object InterfaceMetric |
    Select-Object -First 1 -ExpandProperty IPAddress

if (-not $lanIp) {
    $line = ipconfig | Select-String 'IPv4' | Select-Object -First 1
    if ($line) { $lanIp = $line.ToString().Split(':')[-1].Trim() }
}

if ($lanIp) {
    Write-Host "[OK] Wi-Fi host IP detected: $lanIp" -ForegroundColor Green
    Write-Host "[INFO] Enter this IP in the Android app to connect via Wi-Fi." -ForegroundColor Gray
} else {
    Write-Host "[WARN] Could not detect LAN IP automatically." -ForegroundColor Yellow
    Write-Host "       Run 'ipconfig' and use your IPv4 address in the Android app." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[*] Starting host on 0.0.0.0:9001 ..." -ForegroundColor Cyan

Stop-Process -Name "host-windows" -Force -ErrorAction SilentlyContinue

$portOwners = Get-NetTCPConnection -LocalPort 9001 -State Listen -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique
foreach ($ownerPid in $portOwners) {
    if ($ownerPid -and $ownerPid -ne $PID) {
        Stop-Process -Id $ownerPid -Force -ErrorAction SilentlyContinue
    }
}

$root = Split-Path -Parent $PSScriptRoot
Set-Location "$root\host-windows"
$env:TABLET_MONITOR_FPS = '60'

if (Test-Path ".\target\release\host-windows.exe") {
    .\target\release\host-windows.exe
} else {
    cargo run --release
}
