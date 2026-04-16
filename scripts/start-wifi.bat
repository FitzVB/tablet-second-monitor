@echo off
setlocal
title Tablet Monitor - Wi-Fi Mode

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-wifi.ps1"
exit /b %errorlevel%
