@echo off
setlocal enabledelayedexpansion

:: Define the software name
set "SoftwareName=WPS"

echo Searching for installed locations of %SoftwareName% ...
echo.

:: -------------------------------
:: 1. Search common folders
:: -------------------------------
echo --- Folder Search Results ---
for %%D in ("C:\Program Files" "C:\Program Files (x86)" "%LOCALAPPDATA%" "%APPDATA%") do (
    if exist %%D (
        echo Scanning %%D ...
        dir /b /s "%%D\*%SoftwareName%*" 2>nul
    )
)

:: -------------------------------
:: 2. Aggressive Registry Search
:: -------------------------------
echo.
echo --- Registry Search Results ---

set "RegRoots=HKLM\SOFTWARE HKLM\SOFTWARE\WOW6432Node HKCU\SOFTWARE HKU HKCR"

for %%R in (%RegRoots%) do (
    echo Scanning %%R ...
    reg query "%%R" /f %SoftwareName% /s 2>nul
)

echo.
echo Search complete.
pause
