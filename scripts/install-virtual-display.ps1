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

    throw "No se encontro ningun .inf. Coloca el driver en drivers\\virtual-display o pasa -InfPath."
}

if ($Provider -eq "winget") {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw "winget.exe no esta disponible. Usa -Provider inf o instala App Installer."
    }

    Write-Host "Instalando Virtual Display Driver desde winget..." -ForegroundColor Cyan
    winget install --id VirtualDrivers.Virtual-Display-Driver -e --accept-package-agreements --accept-source-agreements

    if ($LASTEXITCODE -ne 0) {
        throw "winget devolvio codigo $LASTEXITCODE"
    }

    Write-Host "Driver virtual instalado desde winget." -ForegroundColor Green
    return
}

if (-not (Get-Command pnputil.exe -ErrorAction SilentlyContinue)) {
    throw "pnputil.exe no esta disponible en este sistema."
}

$resolvedInf = Resolve-InfPath -ExplicitPath $InfPath
Write-Host "Instalando driver virtual desde: $resolvedInf" -ForegroundColor Cyan

pnputil.exe /add-driver "$resolvedInf" /install

if ($LASTEXITCODE -ne 0) {
    throw "pnputil devolvio codigo $LASTEXITCODE"
}

Write-Host "Driver instalado. Si Windows no muestra el nuevo monitor, reconecta el dispositivo o reinicia." -ForegroundColor Green
Write-Host "Luego usa el modo extended y deja el display en Auto, o fija TABLET_MONITOR_EXTENDED_DISPLAY." -ForegroundColor Green