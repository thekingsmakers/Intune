# THE KINGSMAKERS WINAPP TOOL - REALISTIC DISTRIBUTION SOLUTION
# Creates a proper ZIP distribution package that actually works

param(
    [string]$OutputName = "THEKINGSMAKERS-WINAPP-TOOL",
    [string]$Version = "1.0.0"
)

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "               THE KINGSMAKERS WINAPP TOOL                        " -ForegroundColor Cyan
Write-Host "                   DISTRIBUTION PACKAGE                           " -ForegroundColor Yellow
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Check if 7-Zip or built-in compression is available
$use7Zip = $false
$sevenZip = Get-Command "7z.exe" -ErrorAction SilentlyContinue
if ($sevenZip) {
    $use7Zip = $true
    Write-Host "7-Zip found: $($sevenZip.Source)" -ForegroundColor Green
} else {
    Write-Host "7-Zip not found, using built-in compression" -ForegroundColor Yellow
}

# Required files for distribution
$requiredFiles = @(
    "THEKINGSMAKERS-WINAPP-TOOL.exe",
    "Utils.ps1",
    "Aliases.ps1",
    "PackageManagers.ps1",
    "Detection.ps1",
    "Winget.ps1",
    "Chocolatey.ps1",
    "Install.ps1",
    "Uninstall.ps1",
    "Upgrade.ps1",
    "package-aliases.json",
    "installer.log"
)

# Documentation files
$docFiles = @(
    "Features.md",
    "UsageExamples.md",
    "Issues.Md",
    "EXE_Conversion_Guidelines.md",
    "thefunctionality.md"
)

# Check for required files
Write-Host "`nChecking for required files..." -ForegroundColor Yellow
$missingFiles = @()
foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "ERROR: Missing required files:" -ForegroundColor Red
    $missingFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
Write-Host "All required files found!" -ForegroundColor Green

# Create distribution directory
$distDir = "$OutputName-v$Version"
$zipFile = "$distDir.zip"

if (Test-Path $distDir) {
    Remove-Item $distDir -Recurse -Force
}

New-Item -ItemType Directory -Path $distDir -Force | Out-Null
Write-Host "`nCreated distribution directory: $distDir" -ForegroundColor Green

# Copy files to distribution directory
Write-Host "`nCopying files to distribution package..." -ForegroundColor Yellow

foreach ($file in $requiredFiles) {
    Copy-Item $file $distDir -Force
    Write-Host "  Copied: $file" -ForegroundColor Gray
}

foreach ($file in $docFiles) {
    if (Test-Path $file) {
        Copy-Item $file $distDir -Force
        Write-Host "  Copied: $file" -ForegroundColor Gray
    }
}

# Create a simple batch launcher for convenience
$batchLauncher = @"
@echo off
REM THE KINGSMAKERS WINAPP TOOL - Batch Launcher
echo ==================================================================
echo                THE KINGSMAKERS WINAPP TOOL
echo                     (TKM WINAPP TOOL)
echo ==================================================================
echo.

REM Check if PowerShell is available
powershell -Command "Write-Host 'PowerShell found - launching tool...'" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: PowerShell is required to run this tool.
    echo Please install Windows PowerShell or PowerShell Core.
    pause
    exit /b 1
)

REM Launch the PowerShell tool with all passed arguments
powershell -ExecutionPolicy Bypass -File "%~dp0THEKINGSMAKERS-WINAPP-TOOL.exe" %*

REM Keep window open if there was an error
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Press any key to exit...
    pause >nul
)
"@

$batchLauncher | Out-File -FilePath "$distDir\Run-Tool.bat" -Encoding ASCII -Force
Write-Host "  Created: Run-Tool.bat (convenience launcher)" -ForegroundColor Green

# Create a README for the distribution
$readme = @"
# THE KINGSMAKERS WINAPP TOOL - Distribution Package

## Overview
THE KINGSMAKERS WINAPP TOOL (TKM WINAPP TOOL) is a comprehensive Windows package management solution featuring advanced installation, uninstallation, upgrading, searching, and listing capabilities using multiple package managers with intelligent fallbacks.

Created by thekingsmakers | Website: thekingsmaker.org | Twitter: thekingsmakers

## Installation
1. Extract all files to a folder
2. Run THEKINGSMAKERS-WINAPP-TOOL.exe or use Run-Tool.bat
3. All files must remain in the same directory

## Usage Examples
THEKINGSMAKERS-WINAPP-TOOL.exe -List
THEKINGSMAKERS-WINAPP-TOOL.exe -Install vscode
THEKINGSMAKERS-WINAPP-TOOL.exe -Uninstall chrome
THEKINGSMAKERS-WINAPP-TOOL.exe -Search "browser"
THEKINGSMAKERS-WINAPP-TOOL.exe -Upgrade "git,nodejs"

## Requirements
- Windows 7 SP1 or later
- PowerShell 3.0 or later (included in Windows 7+)
- Internet connection for package downloads

## Features
- Intelligent package detection and management
- Multi-manager fallback system (winget → choco → PowerShell)
- Advanced uninstallation with registry cleanup
- Parallel processing for multiple packages
- Professional branding and logging

## Documentation
- Features.md - Complete feature list
- UsageExamples.md - Detailed usage examples
- Issues.Md - Known issues and resolutions
- EXE_Conversion_Guidelines.md - Technical documentation

## Support
Created by thekingsmakers
Website: thekingsmaker.org
Twitter: thekingsmakers
"@

$readme | Out-File -FilePath "$distDir\README.md" -Encoding UTF8 -Force
Write-Host "  Created: README.md (distribution documentation)" -ForegroundColor Green

# Create ZIP archive
Write-Host "`nCreating ZIP distribution package..." -ForegroundColor Yellow

if ($use7Zip) {
    # Use 7-Zip for better compression
    & $sevenZip.Source a -tzip $zipFile $distDir | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "ZIP created with 7-Zip: $zipFile" -ForegroundColor Green
    } else {
        Write-Host "7-Zip compression failed, falling back to built-in method" -ForegroundColor Yellow
        $use7Zip = $false
    }
}

if (-not $use7Zip) {
    # Use built-in compression
    try {
        Compress-Archive -Path $distDir -DestinationPath $zipFile -Force
        Write-Host "ZIP created with built-in compression: $zipFile" -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to create ZIP archive. $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Get file sizes
$zipSize = (Get-Item $zipFile).Length
$zipSizeMB = [math]::Round($zipSize / 1MB, 2)
$distSize = (Get-ChildItem $distDir -Recurse | Measure-Object -Property Length -Sum).Sum
$distSizeMB = [math]::Round($distSize / 1MB, 2)

Write-Host "`n==================================================================" -ForegroundColor Green
Write-Host "DISTRIBUTION PACKAGE CREATED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "Distribution Directory: $distDir" -ForegroundColor White
Write-Host "ZIP Archive: $zipFile" -ForegroundColor White
Write-Host "Package Size: $distSizeMB MB (uncompressed)" -ForegroundColor White
Write-Host "ZIP Size: $zipSizeMB MB (compressed)" -ForegroundColor White
Write-Host "Files Included: $(Get-ChildItem $distDir -Recurse | Measure-Object | Select-Object -ExpandProperty Count)" -ForegroundColor White
Write-Host "" -ForegroundColor White

Write-Host "PACKAGE CONTENTS:" -ForegroundColor Cyan
Get-ChildItem $distDir | Select-Object Name | ForEach-Object {
    Write-Host "  $($_.Name)" -ForegroundColor White
}

Write-Host "`nUSAGE INSTRUCTIONS:" -ForegroundColor Cyan
Write-Host "1. Extract $zipFile to any folder" -ForegroundColor White
Write-Host "2. Keep all files together in the same directory" -ForegroundColor White
Write-Host "3. Run THEKINGSMAKERS-WINAPP-TOOL.exe or Run-Tool.bat" -ForegroundColor White
Write-Host "" -ForegroundColor White

Write-Host "EXAMPLE COMMANDS:" -ForegroundColor Cyan
Write-Host "  THEKINGSMAKERS-WINAPP-TOOL.exe -List" -ForegroundColor White
Write-Host "  THEKINGSMAKERS-WINAPP-TOOL.exe -Install vscode" -ForegroundColor White
Write-Host "  THEKINGSMAKERS-WINAPP-TOOL.exe -Uninstall chrome" -ForegroundColor White
Write-Host "" -ForegroundColor White

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "THE KINGSMAKERS WINAPP TOOL DISTRIBUTION READY!" -ForegroundColor Cyan
Write-Host "Created by thekingsmakers | thekingsmaker.org" -ForegroundColor Yellow
Write-Host "==================================================================" -ForegroundColor Cyan

Write-Host "`nPackage creation completed successfully!" -ForegroundColor Green
Write-Host "Ready for distribution: $zipFile" -ForegroundColor Green
