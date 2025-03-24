

@echo off

echo -------------------------------------
echo Created by Omar Osman
echo Credits : x.com/thekingsmakers
echo -------------------------------------



:: Ensure the script runs as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo This script requires administrative privileges. Please run as administrator.
    pause
    exit /b
)

:: List available disks
echo Listing available disks...
diskpart /s "%~dp0list_disks.txt"

:: Display disk information
type "%~dp0disk_info.txt"
echo.

:: Prompt the user for the disk number
set /p diskNumber=Enter the disk number to select (as shown above): 

:: Create a temporary diskpart script
(
    echo select disk %diskNumber%
    echo clean
    echo create partition primary
    echo format fs=ntfs quick
    echo assign letter=K
    echo exit
) > "%~dp0diskpart_script.txt"

:: Run diskpart with the generated script
diskpart /s "%~dp0diskpart_script.txt"

:: Clean up temporary files
del "%~dp0diskpart_script.txt" "%~dp0disk_info.txt" 2>nul

echo Disk has been partitioned, formatted, and assigned to drive letter K.

start https://thekingsmakers.github.io/Intune/
pause
exit /b

:: Below is the content for "list_disks.txt"
:: Save this content as a separate file named "list_disks.txt" in the same directory as the script.

