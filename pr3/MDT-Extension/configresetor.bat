@echo off
echo Resetting MDT Extension configuration to default...

set "configFilePath=MDT-Extension\Configuration\config.xml"
echo Config file path: %configFilePath%
echo Creating default config.xml...

powershell.exe -NoProfile -ExecutionPolicy Bypass -File reset-config.ps1

if %errorlevel% equ 0 (
    echo Configuration reset to default successfully.
) else (
    echo Error occurred while resetting configuration.
)

pause