# Tablet Monitor - USB Mode Server with Auto-Forward

Write-Host ""
Write-Host "Tablet Monitor - USB Mode Startup" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

# Ensure adb is available (auto-add Android SDK platform-tools)
$platformTools = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools"
# Reset PATH to machine+user defaults so cargo/rustup are available.
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
if (Test-Path $platformTools) {
    $env:Path = $env:Path + ";" + $platformTools
}

$adbCmd = Get-Command adb -ErrorAction SilentlyContinue
if (-not $adbCmd) {
    Write-Host "[ERROR] ADB not in PATH" -ForegroundColor Red
    Write-Host "        Expected at: $platformTools" -ForegroundColor Yellow
    exit 1
}

# Get connected devices
Write-Host "[*] Checking USB devices..." -ForegroundColor Cyan
$adbOut = adb devices
$deviceCount = 0
foreach ($line in ($adbOut | Select-Object -Skip 1)) {
    if ($line -match "device" -and $line -notmatch "List") {
        $deviceCount++
    }
}

if ($deviceCount -gt 0) {
    Write-Host "[OK] Found $deviceCount device(s)" -ForegroundColor Green
    Write-Host "[*] Setting up USB tunnel (adb reverse)..." -ForegroundColor Cyan
    adb reverse --remove-all | Out-Null
    adb reverse tcp:9001 tcp:9001
    Write-Host "[OK] Reverse tcp:9001 ready" -ForegroundColor Green
    Write-Host "     Tablet will use 127.0.0.1:9001" -ForegroundColor Gray
} else {
    Write-Host "[!] No USB devices found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[*] Starting server..." -ForegroundColor Cyan

Stop-Process -Name "host-windows" -Force -ErrorAction SilentlyContinue

$portOwners = Get-NetTCPConnection -LocalPort 9001 -State Listen -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique
foreach ($ownerPid in $portOwners) {
    if ($ownerPid -and $ownerPid -ne $PID) {
        Stop-Process -Id $ownerPid -Force -ErrorAction SilentlyContinue
    }
}

$root = Split-Path -Parent $PSScriptRoot
cd "$root\host-windows"
$env:TABLET_MONITOR_LISTEN = '127.0.0.1'
$env:TABLET_MONITOR_FPS = '60'

# If a stale AMF preference was persisted, clear it for USB startup stability.
$settingsPath = Join-Path $root "host-windows\target\release\host-settings.json"
if (Test-Path $settingsPath) {
    try {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        if ($settings.preferred_encoder -eq 'h264_amf') {
            $settings.preferred_encoder = $null
            $settings.preferred_amf_device = $null
            $settings | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $settingsPath
            Write-Host "[INFO] Cleared persisted AMF preference for stable USB startup" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[WARN] Could not parse host-settings.json; continuing with runtime fallback" -ForegroundColor Yellow
    }
}

if (Test-Path ".\target\release\host-windows.exe") {
    .\target\release\host-windows.exe
} else {
    cargo run --release
}
