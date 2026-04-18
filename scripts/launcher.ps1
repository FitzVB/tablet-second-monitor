# FlexDisplay - Simple Launcher
# No ADB automation or APK install

Write-Host ""
Write-Host "FlexDisplay - Launcher" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""

$root = Split-Path -Parent $PSScriptRoot
$usbScript = Join-Path $PSScriptRoot "start-usb.ps1"
$wifiScript = Join-Path $PSScriptRoot "start-wifi.ps1"
$installVddScript = Join-Path $PSScriptRoot "install-virtual-display.ps1"
$ensureRuntimeScript = Join-Path $PSScriptRoot "ensure-runtime.ps1"

function Test-IsAdmin {
    try {
        $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Test-VirtualDisplayDriverInstalled {
    $driverPresent = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -eq "Virtual Display Driver" }
    if ($driverPresent) {
        return $true
    }

    $monitorPresent = Get-PnpDevice -Class Monitor -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -like "*VDD by MTT*" }
    return $null -ne $monitorPresent
}

function Ensure-VirtualDisplayDriver {
    Write-Host "[*] Checking virtual display driver..." -ForegroundColor Cyan

    if (Test-VirtualDisplayDriverInstalled) {
        Write-Host "[OK] Virtual display driver detected" -ForegroundColor Green
        return
    }

    Write-Host "[WARN] Virtual display support is not installed yet." -ForegroundColor Yellow
    Write-Host "       Extended mode needs this component." -ForegroundColor Yellow

    if (-not (Test-Path $installVddScript)) {
        Write-Host "[ERROR] scripts\install-virtual-display.ps1 not found" -ForegroundColor Red
        Write-Host "        Install VDD manually before using Extended mode." -ForegroundColor Red
        return
    }

    Write-Host "[*] Installing virtual display support..." -ForegroundColor Cyan
    try {
        & $installVddScript
    } catch {
        Write-Host "[WARN] First install attempt failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    if (Test-VirtualDisplayDriverInstalled) {
        Write-Host "[OK] Virtual display driver installed" -ForegroundColor Green
        return
    }

    if (-not (Test-IsAdmin)) {
        Write-Host "[*] Retrying with Administrator permissions (UAC prompt)..." -ForegroundColor Cyan
        try {
            $proc = Start-Process -FilePath "powershell.exe" -Verb RunAs -Wait -PassThru -ArgumentList @(
                "-ExecutionPolicy", "Bypass",
                "-NoProfile",
                "-File", ('"' + $installVddScript + '"')
            )
            if ($proc.ExitCode -ne 0) {
                Write-Host "[WARN] Admin install exited with code $($proc.ExitCode)." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "[WARN] Could not run elevated install automatically." -ForegroundColor Yellow
        }
    }

    if (Test-VirtualDisplayDriverInstalled) {
        Write-Host "[OK] Virtual display driver installed" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Virtual display support is still not detected." -ForegroundColor Yellow
        Write-Host "       You can continue in Mirror mode, or install manually:" -ForegroundColor Yellow
        Write-Host "       .\scripts\install-virtual-display.ps1" -ForegroundColor DarkYellow
        Write-Host "       If Windows still does not show displays, reboot once." -ForegroundColor DarkYellow
    }
}

Ensure-VirtualDisplayDriver

if (Test-Path $ensureRuntimeScript) {
    Write-Host "[*] Checking local runtime (ADB/FFmpeg)..." -ForegroundColor Cyan
    try {
        & $ensureRuntimeScript -RootPath $root -EnsureAdb -EnsureFfmpeg
    } catch {
        Write-Host "[WARN] Runtime bootstrap failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "       START can continue, but USB/Wi-Fi may fail without dependencies." -ForegroundColor Yellow
    }
}

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
