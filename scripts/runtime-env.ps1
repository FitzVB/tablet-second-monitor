param(
    [string]$RootPath
)

if (-not $RootPath) {
    $RootPath = Split-Path -Parent $PSScriptRoot
}

$runtimeRoot = Join-Path $RootPath ".runtime"
$localBin = Join-Path $runtimeRoot "bin"
$adbDir = Join-Path $runtimeRoot "adb\platform-tools"
$ffmpegBin = Join-Path $runtimeRoot "ffmpeg\bin"
$cargoHome = Join-Path $runtimeRoot "rust\cargo"
$rustupHome = Join-Path $runtimeRoot "rust\rustup"
$cargoBin = Join-Path $cargoHome "bin"
$javaCurrent = Join-Path $runtimeRoot "java\current"
$javaBin = Join-Path $javaCurrent "bin"

foreach ($dir in @($runtimeRoot, $localBin)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

$env:CARGO_HOME = $cargoHome
$env:RUSTUP_HOME = $rustupHome

if (Test-Path $javaCurrent) {
    $env:JAVA_HOME = $javaCurrent
}

$prepend = @($localBin, $adbDir, $ffmpegBin, $cargoBin, $javaBin) | Where-Object { Test-Path $_ }
$existing = $env:Path -split ';'

foreach ($p in ($prepend | Select-Object -Unique)) {
    if ($existing -notcontains $p) {
        $env:Path = "$p;$($env:Path)"
        $existing = $env:Path -split ';'
    }
}
