@echo off
SETLOCAL

:: Check if running after Windows installation
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v InstallDate >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo This script should run after Windows installation.
    pause
    exit /b 1
)

:: Set execution policy
powershell -Command "Set-ExecutionPolicy RemoteSigned -Scope Process -Force"

:: Run deployment script
echo Starting post-install deployment...
powershell -ExecutionPolicy Bypass -File "%~dp0Scripts\Deploy-Windows.ps1"

if %ERRORLEVEL% equ 0 (
    echo Deployment completed successfully.
) else (
    echo Deployment failed with error %ERRORLEVEL%
    echo Check %~dp0Logs\Deployment.log for details
)

:: Cleanup and eject USB if desired
choice /c yn /m "Remove USB drive? [y,n]"
if %ERRORLEVEL% equ 1 (
    powershell -Command "& { $drive = (Get-WmiObject Win32_Volume | Where-Object { $_.Label -eq 'Windows Deployment Tool' }).DriveLetter; $driveEject = New-Object -comObject Shell.Application; $driveEject.Namespace(17).ParseName($drive).InvokeVerb('Eject') }"
)

pause