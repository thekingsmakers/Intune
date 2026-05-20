@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do set "DRIVE=%%~di"

if not exist "%DRIVE%\scripts\home.xml" (
    echo ERROR: WiFi profile 'home.xml' not found.
    pause
    exit /b 1
)

echo Importing profile...
netsh wlan add profile filename="%DRIVE%\scripts\home.xml" user=current
if errorlevel 1 (
    echo ERROR: Import failed. Try re-exporting profile as current user.
    pause
    exit /b 1
)

for /f "tokens=2 delims=<>" %%i in ('find "<name>" "%DRIVE%\scripts\home.xml"') do (
    set "SSID=%%i"
    goto connect_wifi
)

:connect_wifi
if not defined SSID (
    echo ERROR: SSID not found.
    pause
    exit /b 1
)

echo Connecting to WiFi: !SSID!
netsh wlan connect name="!SSID!"
timeout /t 5 >nul
netsh wlan show interfaces | findstr /C:"State" /C:"SSID"

