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
    }
    catch {
        return $false
    }
}

function Add-DefenderExclusion {
    param([string]$FolderPath)
    # Check if already excluded
    try {
        $prefs = Get-MpPreference -ErrorAction Stop
        $existing = $prefs.ExclusionPath
        if ($existing -contains $FolderPath) {
            Write-Host '[OK] Antivirus exclusion already configured' -ForegroundColor Green
            return
        }
    }
    catch {
        # Windows Defender not available / managed by policy — skip silently
        return
    }

    Write-Host ''
    Write-Host '[!] Windows Defender may flag host-windows.exe as suspicious.' -ForegroundColor Yellow
    Write-Host '    This is a false positive. The binary is open-source:' -ForegroundColor Yellow
    Write-Host "    https://github.com/FitzVB/tablet-second-monitor" -ForegroundColor DarkYellow
    Write-Host ''
    Write-Host '    To fix this, FlexDisplay needs to add its folder to the' -ForegroundColor Yellow
    Write-Host '    Defender exclusion list (requires administrator privileges).' -ForegroundColor Yellow
    Write-Host ''

    if (Test-IsAdmin) {
        try {
            Add-MpPreference -ExclusionPath $FolderPath -ErrorAction Stop
            Write-Host '[OK] Antivirus exclusion added successfully' -ForegroundColor Green
        }
        catch {
            Write-Host "[WARN] Could not add exclusion: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host '    Running elevated process to add exclusion...' -ForegroundColor Cyan
        try {
            $escaped = $FolderPath -replace "'", "''"
            $elevatedCmd = "Add-MpPreference -ExclusionPath '$escaped'"
            $result = Start-Process powershell.exe `
                -ArgumentList "-NoProfile -NonInteractive -Command `"$elevatedCmd`"" `
                -Verb RunAs `
                -Wait `
                -PassThru `
                -ErrorAction Stop
            if ($result.ExitCode -eq 0) {
                Write-Host '[OK] Antivirus exclusion added successfully' -ForegroundColor Green
            }
            else {
                Write-Host '[WARN] Exclusion was not added (admin prompt rejected or failed).' -ForegroundColor Yellow
                Write-Host '       You can add it manually: Windows Security -> Virus & threat protection' -ForegroundColor DarkYellow
                Write-Host "       -> Manage settings -> Exclusions -> Add -> Folder -> $FolderPath" -ForegroundColor DarkYellow
            }
        }
        catch {
            Write-Host '[WARN] Could not request elevation. Add the exclusion manually:' -ForegroundColor Yellow
            Write-Host '       Windows Security -> Virus & threat protection -> Manage settings' -ForegroundColor DarkYellow
            Write-Host "       -> Exclusions -> Add an exclusion -> Folder -> $FolderPath" -ForegroundColor DarkYellow
        }
    }
    Write-Host ''
}

function Test-VirtualDisplayDriverInstalled {
    # Match any indirect display adapter installed as ROOT\DISPLAY (all VDD variants)
    # or by known friendly name patterns used across different VDD package versions.
    $driverPresent = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue |
    Where-Object {
        $_.InstanceId -like 'ROOT\DISPLAY\*' -or
        $_.FriendlyName -like '*Virtual*Display*' -or
        $_.FriendlyName -like '*Virtual*Monitor*' -or
        $_.FriendlyName -like '*VDD*'
    }
    if ($driverPresent) { return $true }

    $monitorPresent = Get-PnpDevice -Class Monitor -ErrorAction SilentlyContinue |
    Where-Object { $_.FriendlyName -like '*VDD*' -or $_.FriendlyName -like '*Virtual*' }
    return ($null -ne $monitorPresent)
}

# Defender exclusion — prevent false positive quarantine
Add-DefenderExclusion -FolderPath $root

# VDD check — informational only, no auto-install
Write-Host '[*] Checking virtual display driver...' -ForegroundColor Cyan
if (Test-VirtualDisplayDriverInstalled) {
    $errDevice = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue |
    Where-Object {
        ($_.InstanceId -like 'ROOT\DISPLAY\*' -or
        $_.FriendlyName -like '*Virtual*Display*' -or
        $_.FriendlyName -like '*Virtual*Monitor*' -or
        $_.FriendlyName -like '*VDD*') -and
        $_.Status -eq 'Error'
    }
    if ($errDevice) {
        Write-Host '[WARN] Virtual display device is in error state.' -ForegroundColor Yellow
        Write-Host '       Go to Device Manager -> Display adapters -> right-click -> Enable.' -ForegroundColor DarkYellow
    }
    else {
        Write-Host '[OK] Virtual display driver detected' -ForegroundColor Green
    }
}
else {
    Write-Host '[WARN] Virtual display driver not found.' -ForegroundColor Yellow
    Write-Host '       Extended mode will not be available.' -ForegroundColor Yellow
    Write-Host '       To install manually run:  .\scripts\install-virtual-display.ps1' -ForegroundColor DarkYellow
}

if (Test-Path $ensureRuntimeScript) {
    Write-Host "[*] Checking local runtime (ADB/FFmpeg)..." -ForegroundColor Cyan
    try {
        & $ensureRuntimeScript -RootPath $root -EnsureAdb -EnsureFfmpeg
    }
    catch {
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
}
else {
    Write-Host ""
    Write-Host "[INFO] Wi-Fi mode selected" -ForegroundColor Cyan
    if (-not (Test-Path $wifiScript)) {
        Write-Host "[ERROR] scripts\start-wifi.ps1 not found" -ForegroundColor Red
        exit 1
    }
    & $wifiScript
}
