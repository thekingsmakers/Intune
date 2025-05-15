@echo off
setlocal EnableDelayedExpansion

:: Define log file
set "LogFile=%TEMP%\StoreAppsDownloader_%date:~-4,4%%date:~-10,2%%date:~-7,2%.log"

:: Log start of script
echo [%date% %time%] Starting script execution >> "%LogFile%"

:: Ask user for the working folder
echo Enter the working folder path:
set /p workFolder=Enter path: 
echo [%date% %time%] User provided folder: %workFolder% >> "%LogFile%"

:: Validate input
if "%workFolder%"=="" (
    echo ERROR: No folder path provided.
    echo [%date% %time%] ERROR: No folder path provided >> "%LogFile%"
    pause
    exit /b 1
)

:: Remove trailing backslash and validate path
set "workFolder=%workFolder%\"
set "workFolder=%workFolder:\\=%"
set "workFolder=%workFolder:"=%"

:: Check if folder exists, if not, create it
if not exist "%workFolder%" (
    echo Folder does not exist. Creating...
    echo [%date% %time%] Creating folder: %workFolder% >> "%LogFile%"
    mkdir "%workFolder%" 2>nul
    if errorlevel 1 (
        echo ERROR: Failed to create folder %workFolder%.
        echo [%date% %time%] ERROR: Failed to create folder %workFolder% >> "%LogFile%"
        pause
        exit /b 1
    )
) else (
    echo Folder exists.
    echo [%date% %time%] Folder exists: %workFolder% >> "%LogFile%"
)

:: Change to the working directory
cd /d "%workFolder%" 2>nul
if errorlevel 1 (
    echo ERROR: Failed to change to directory %workFolder%.
    echo [%date% %time%] ERROR: Failed to change to directory %workFolder% >> "%LogFile%"
    pause
    exit /b 1
)
echo [%date% %time%] Changed to directory: %workFolder% >> "%LogFile%"

:: Define PowerShell script URL (corrected with %20 for spaces)
set "ScriptURL=https://raw.githubusercontent.com/thekingsmakers/Intune/refs/heads/main/Ms%%20Store/Windows%%20store%%20apps%%20downloader/store.ps1"

:: Execute the PowerShell script directly
echo Executing PowerShell script from %ScriptURL%...
echo [%date% %time%] Executing script from %ScriptURL% >> "%LogFile%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& {try { $script = Invoke-WebRequest -Uri '%ScriptURL%' -ErrorAction Stop; Invoke-Expression $script.Content } catch { Write-Error $_.Exception.Message; exit 1 }}" >> "%LogFile%" 2>&1
if errorlevel 1 (
    echo ERROR: PowerShell script execution failed. Check log for details.
    echo [%date% %time%] ERROR: PowerShell script execution failed >> "%LogFile%"
    pause
    exit /b 1
)
echo [%date% %time%] PowerShell script executed successfully >> "%LogFile%"

echo Script execution complete!
echo [%date% %time%] Script execution complete >> "%LogFile%"
pause
exit /b 0
