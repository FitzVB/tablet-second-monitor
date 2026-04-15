$ErrorActionPreference = "Stop"

function Resolve-AdbPath {
    $adbFromPath = Get-Command adb -ErrorAction SilentlyContinue
    if ($adbFromPath) {
        return $adbFromPath.Source
    }

    $sdkAdb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $sdkAdb) {
        return $sdkAdb
    }

    throw "No se encontro adb."
}

$adb = Resolve-AdbPath
& $adb reverse --remove tcp:9001 | Out-Null
Write-Host "ADB reverse removido en tcp:9001"
