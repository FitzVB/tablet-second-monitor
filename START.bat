@echo off
setlocal EnableDelayedExpansion
title Tablet Monitor

:: Unified launcher - delegates to PowerShell script for better modularity
:: This wrapper ensures cross-platform compatibility and consistent behavior

set "LAUNCHER=%~dp0scripts\launcher.ps1"

if not exist "%LAUNCHER%" (
    echo  ERROR: No se encontro scripts\launcher.ps1
    echo  Nota: Asegurate de ejecutar desde la raiz del proyecto.
    pause
    exit /b 1
)

:: Launch PowerShell with the unified launcher (bypass execution policy for this script only)
powershell -ExecutionPolicy Bypass -NoProfile -File "%LAUNCHER%"

:: Preserve exit code
exit /b %ERRORLEVEL%
