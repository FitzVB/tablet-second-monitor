param(
    [string]$InfPath,
    [ValidateSet("inf", "winget")]
    [string]$Provider = "winget"
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot

function Resolve-InfPath {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        $resolved = Resolve-Path -Path $ExplicitPath -ErrorAction Stop
        return $resolved.Path
    }

    $defaultDir = Join-Path $repoRoot "drivers\virtual-display"
    $candidate = Get-ChildItem -Path $defaultDir -Filter *.inf -File -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($candidate) {
        return $candidate.FullName
    }

    throw "No .inf was found. Place the driver under drivers\\virtual-display or pass -InfPath."
}

if ($Provider -eq "winget") {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw "winget.exe is not available. Use -Provider inf or install App Installer."
    }

    Write-Host "Installing Virtual Display Driver from winget..." -ForegroundColor Cyan
    winget install --id VirtualDrivers.Virtual-Display-Driver -e --accept-package-agreements --accept-source-agreements

    # winget exits 0 on fresh install, but exits 1 with "No update available" when the
    # package is already installed at the latest version. Both outcomes mean VDD is present.
    # Treat exit code 1 as a soft-success and let the caller re-check via Get-PnpDevice.
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1) {
        throw "winget devolvio codigo $LASTEXITCODE"
    }

    Write-Host "Virtual driver installed from winget." -ForegroundColor Green
    return
}

if (-not (Get-Command pnputil.exe -ErrorAction SilentlyContinue)) {
    throw "pnputil.exe is not available on this system."
}

$resolvedInf = Resolve-InfPath -ExplicitPath $InfPath
Write-Host "Installing virtual driver from: $resolvedInf" -ForegroundColor Cyan

pnputil.exe /add-driver "$resolvedInf" /install

if ($LASTEXITCODE -ne 0) {
    throw "pnputil returned exit code $LASTEXITCODE"
}

Write-Host "Driver installed. If Windows does not show the new monitor, reconnect the device or reboot." -ForegroundColor Green
Write-Host "Then use extended mode and leave display on Auto, or set TABLET_MONITOR_EXTENDED_DISPLAY." -ForegroundColor Green
