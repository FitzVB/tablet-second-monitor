param(
    [string]$PublishedName,
    [string]$Match = "virtual"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command pnputil.exe -ErrorAction SilentlyContinue)) {
    throw "pnputil.exe no esta disponible en este sistema."
}

function Get-DriverMatches {
    param([string]$NameMatch)

    $text = pnputil.exe /enum-drivers | Out-String
    $blocks = $text -split "(\r?\n){2,}"

    foreach ($block in $blocks) {
        if ($block -notmatch "Published Name:\s*(\S+)") {
            continue
        }

        $published = $Matches[1]
        $original = if ($block -match "Original Name:\s*(.+)") { $Matches[1].Trim() } else { "" }
        $provider = if ($block -match "Provider Name:\s*(.+)") { $Matches[1].Trim() } else { "" }
        $className = if ($block -match "Class Name:\s*(.+)") { $Matches[1].Trim() } else { "" }

        $haystack = "$published $original $provider $className".ToLowerInvariant()
        if ($haystack.Contains($NameMatch.ToLowerInvariant())) {
            [pscustomobject]@{
                PublishedName = $published
                OriginalName = $original
                ProviderName = $provider
                ClassName = $className
            }
        }
    }
}

$targets = if ($PublishedName) {
    @([pscustomobject]@{ PublishedName = $PublishedName })
} else {
    @(Get-DriverMatches -NameMatch $Match)
}

if ($targets.Count -eq 0) {
    throw "No se encontraron drivers que coincidan con '$Match'."
}

foreach ($target in $targets) {
    Write-Host "Eliminando driver: $($target.PublishedName)" -ForegroundColor Cyan
    pnputil.exe /delete-driver $target.PublishedName /uninstall /force

    if ($LASTEXITCODE -ne 0) {
        throw "pnputil devolvio codigo $LASTEXITCODE al eliminar $($target.PublishedName)"
    }
}

Write-Host "Driver(s) eliminados." -ForegroundColor Green