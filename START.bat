@echo off
setlocal EnableDelayedExpansion
title Tablet Monitor

echo.
echo  ============================================================
echo   TABLET MONITOR - Iniciando...
echo  ============================================================
echo.

:: ---------------------------------------------------------------------------
:: Resolve ADB: same folder first, then SDK, then PATH
:: ---------------------------------------------------------------------------
set "ADB=%~dp0adb.exe"
if not exist "%ADB%" (
    set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
)
if not exist "%ADB%" (
    where adb >nul 2>&1
    if !errorlevel! == 0 (
        for /f "delims=" %%i in ('where adb') do set "ADB=%%i"
    )
)
if not exist "%ADB%" (
    echo  ERROR: No se encontro adb.exe
    echo  Descarga el paquete completo desde GitHub Releases.
    pause
    exit /b 1
)

echo  ADB: %ADB%

:: ---------------------------------------------------------------------------
:: Start ADB server (silent)
:: ---------------------------------------------------------------------------
"%ADB%" start-server >nul 2>&1

:: ---------------------------------------------------------------------------
:: Set up ADB reverse tunnel (USB mode)
:: ---------------------------------------------------------------------------
"%ADB%" reverse tcp:9001 tcp:9001 >nul 2>&1
if %errorlevel% == 0 (
    echo  Tunel USB activo: tablet:9001 -^> host:9001
) else (
    echo  Sin dispositivo USB ^(modo Wi-Fi^). La tablet debe conectarse por red.
)

:: ---------------------------------------------------------------------------
:: Install APK if present and not already installed
:: ---------------------------------------------------------------------------
if exist "%~dp0TabletMonitor.apk" (
    "%ADB%" shell pm list packages 2>nul | findstr "com.example.tabletmonitor" >nul 2>&1
    if !errorlevel! neq 0 (
        echo  Instalando TabletMonitor.apk en la tablet...
        "%ADB%" install -r "%~dp0TabletMonitor.apk"
    )
)

:: ---------------------------------------------------------------------------
:: Launch host server
:: ---------------------------------------------------------------------------
set "HOST=%~dp0host-windows.exe"
if not exist "%HOST%" (
    echo  ERROR: No se encontro host-windows.exe junto a este archivo.
    pause
    exit /b 1
)

echo.
echo  ============================================================
echo   Servidor listo. Abre la app en la tablet y pulsa Connect.
echo   Cierra esta ventana o presiona Ctrl+C para detener.
echo  ============================================================
echo.

:: Run in this window so Ctrl+C works naturally
"%HOST%"

:: After host exits, clean up the reverse tunnel
"%ADB%" reverse --remove tcp:9001 >nul 2>&1

echo.
echo  Servidor detenido. Puedes cerrar esta ventana.
pause
