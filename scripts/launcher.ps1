# Tablet Monitor - Simple Launcher
# No ADB automation or APK install

Write-Host ""
Write-Host "Tablet Monitor - Launcher" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""

$root = Split-Path -Parent $PSScriptRoot
$usbScript = Join-Path $PSScriptRoot "start-usb.ps1"
$wifiScript = Join-Path $PSScriptRoot "start-wifi.ps1"

# Ask for connection mode
Write-Host "Select connection mode:" -ForegroundColor Gray
Write-Host "  1) USB (recommended)" -ForegroundColor Gray
Write-Host "  2) Wi-Fi" -ForegroundColor Gray
$pick = Read-Host "Mode [1/2]"

$mode = if ($pick -eq "2") { "wifi" } else { "usb" }

if ($mode -eq "usb") {
    Write-Host ""
    Write-Host "[INFO] USB mode selected" -ForegroundColor Cyan
    if (-not (Test-Path $usbScript)) {
        Write-Host "[ERROR] scripts\start-usb.ps1 not found" -ForegroundColor Red
        exit 1
    }
    & $usbScript
} else {
    Write-Host ""
    Write-Host "[INFO] Wi-Fi mode selected" -ForegroundColor Cyan
    if (-not (Test-Path $wifiScript)) {
        Write-Host "[ERROR] scripts\start-wifi.ps1 not found" -ForegroundColor Red
        exit 1
    }
    & $wifiScript
}
