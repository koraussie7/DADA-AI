@echo off
title Liberty Reach - Windows Installer
cd /d "%~dp0"

:: Check if running as admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ========================================
    echo   Liberty Reach Windows Installer
    echo ========================================
    echo.
    echo This installer needs Administrator privileges.
    echo Requesting admin access...
    echo.
    powershell -Command "Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0windows_install.ps1\"'"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows_install.ps1"
pause
