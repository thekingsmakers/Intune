@echo off
Title Windows Provisioning - Please wait...
REM Run Main-Orchestrator.ps1 which orchestrates all provisioning scripts
PowerShell.exe -ExecutionPolicy Bypass -File C:\Setup\Scripts\Main-Orchestrator.ps1
if errorlevel 1 (
    REM Fallback to legacy Provisioning.ps1 if Main-Orchestrator fails
    PowerShell.exe -ExecutionPolicy Bypass -File C:\Setup\Scripts\Provisioning.ps1
)
exit /b 0
