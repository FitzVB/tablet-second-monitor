@echo off
setlocal EnableDelayedExpansion
title Tablet Monitor - Detener

:: ---------------------------------------------------------------------------
:: Resolve ADB
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

:: Stop host process
taskkill /IM host-windows.exe /F >nul 2>&1

:: Remove ADB reverse tunnel
if exist "%ADB%" (
    "%ADB%" reverse --remove tcp:9001 >nul 2>&1
    echo Tunel USB removido.
)

echo Tablet Monitor detenido.
timeout /t 2 /nobreak >nul
