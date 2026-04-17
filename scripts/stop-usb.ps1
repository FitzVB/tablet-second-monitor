$ErrorActionPreference = "SilentlyContinue"

$root = Split-Path -Parent $PSScriptRoot

function Resolve-AdbPath {
    param([string]$Root)
    $bundled = Join-Path $Root "adb.exe"
    if (Test-Path $bundled) { return $bundled }
    $sdkAdb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $sdkAdb) { return $sdkAdb }
    $inPath = Get-Command adb -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }
    return $null
}

$adb = Resolve-AdbPath -Root $root
if ($adb) {
    & $adb reverse --remove-all 2>$null | Out-Null
    Write-Host "ADB reverse removed (all rules)"
}

Stop-Process -Name "host-windows" -Force -ErrorAction SilentlyContinue
Write-Host "Host stopped."
