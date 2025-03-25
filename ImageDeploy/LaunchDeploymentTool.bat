@echo off
setlocal enabledelayedexpansion

:: Check for administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo This tool requires administrator privileges.
    echo Right-click and select "Run as administrator".
    echo.
    pause
    exit /b 1
)

:: Set window title and colors
title Windows Deployment Tool
color 0B

:: Set working directory to script location
cd /d "%~dp0"

:: Check if PowerShell is available
where powershell >nul 2>&1
if %errorLevel% neq 0 (
    echo PowerShell is required but not found.
    echo Please install PowerShell and try again.
    echo.
    pause
    exit /b 1
)

:: Check for required files
if not exist "Deploy.ps1" (
    echo ERROR: Deploy.ps1 not found.
    echo Please ensure all deployment files are present.
    echo.
    pause
    exit /b 1
)

:: Check PowerShell execution policy
powershell -Command "Get-ExecutionPolicy" | findstr /I "Restricted" >nul
if %errorLevel% equ 0 (
    echo Configuring PowerShell execution policy...
    powershell -Command "Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force"
)

:: Create Logs directory if it doesn't exist
if not exist "Logs" mkdir Logs

:: Launch deployment tool
echo Launching Windows Deployment Tool...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "Deploy.ps1" -Action Menu

:: Check for errors
if %errorLevel% neq 0 (
    echo.
    echo An error occurred during execution.
    echo Check the logs for details.
    echo.
    pause
    exit /b 1
)

exit /b 0