@echo off
SETLOCAL

:: Check if running as administrator
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo This script requires administrator privileges.
    echo Please run as administrator.
    pause
    exit /b 1
)

:: Set execution policy if needed
powershell -Command "Set-ExecutionPolicy RemoteSigned -Scope Process -Force"

:: Run the deployment script
echo Starting deployment process...
powershell -ExecutionPolicy Bypass -File "%~dp0Automation\Deploy-Image.ps1"

if %ERRORLEVEL% equ 0 (
    echo Deployment completed successfully.
) else (
    echo Deployment failed with error %ERRORLEVEL%
    echo Check Deployment.log for details
)

pause