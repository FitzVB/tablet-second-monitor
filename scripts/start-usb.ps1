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
    adb reverse tcp:9001 tcp:9001
    Write-Host "[OK] Reverse tcp:9001 ready" -ForegroundColor Green
    Write-Host "     Tablet will use 127.0.0.1:9001" -ForegroundColor Gray
} else {
    Write-Host "[!] No USB devices found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[*] Starting server..." -ForegroundColor Cyan

cd "$PSScriptRoot\host-windows"
$env:TABLET_MONITOR_FPS = '60'
cargo run --release
