# THE KINGSMAKERS WINAPP TOOL - EXE Conversion Guidelines

## Automated Conversion Script

### Quick Start (Recommended)
Use the provided `ConvertToEXE.ps1` script for one-click conversion:

```powershell
# Basic conversion
.\ConvertToEXE.ps1

# Advanced conversion with options
.\ConvertToEXE.ps1 -OutputFile "MyTool.exe" -IconFile "custom.ico" -Version "2.0.0.0" -RequireAdmin -NoConsole -Force
```

### Script Parameters
- `-OutputFile`: Name of the output EXE file (default: "TKMWATool.exe")
- `-IconFile`: Path to custom icon file (default: "kingsmakers.ico")
- `-Force`: Overwrite existing EXE file
- `-NoConsole`: Hide console window (for GUI-only applications)
- `-RequireAdmin`: Require administrator privileges
- `-Version`: Version number for the EXE metadata (default: "1.0.0.0")
- `-BundleMode`: Create bundle with supporting files

### What the Script Does
1. ✅ Checks for and installs PS2EXE if needed
2. ✅ Validates all required source files exist
3. ✅ Creates EXE wrapper script with proper parameter handling
4. ✅ Converts to EXE with professional metadata (compatible parameters)
5. ✅ Tests the created EXE
6. ✅ Provides usage examples and file information
7. ✅ Cleans up temporary files

### Compatibility Notes
- **PS2EXE Version**: Script automatically detects and adapts to different PS2EXE versions
- **Parameter Compatibility**: Removes unsupported parameters like `runtime40` for older versions
- **Cross-Version Support**: Works with PS2EXE 1.0.10+ (tested with 1.0.17)

---

## Manual Conversion (Alternative)
Yes, we can absolutely create a standalone executable (.exe) from this PowerShell project! This will allow users to run THE KINGSMAKERS WINAPP TOOL without requiring PowerShell to be installed or visible.

## Recommended Approach: PS2EXE

### Why PS2EXE?
- **Free & Open Source**: No licensing costs
- **PowerShell Native**: Specifically designed for PowerShell scripts
- **Complex Script Support**: Handles multiple file imports and modules
- **Parameter Support**: Preserves all command-line arguments
- **Embedding Support**: Can bundle additional files (JSON configs, etc.)
- **Execution Control**: Can run with or without console window
- **Icon Support**: Add custom application icons

---

## Prerequisites

### Required Software
```powershell
# Install PS2EXE module
Install-Module -Name ps2exe -Scope CurrentUser -Force

# Alternative: Download from GitHub
# https://github.com/MScholtes/PS2EXE
```

### System Requirements
- Windows PowerShell 5.1+ or PowerShell Core 6+
- .NET Framework 4.5+ (included in Windows 10+)
- Administrator privileges for installation

---

## Conversion Process

### Step 1: Prepare the Main Script
Create a wrapper script that handles the EXE environment:

```powershell
# Create: MainInstallerEXE.ps1
param(
    [string[]]$Install,
    [string[]]$Uninstall,
    [string[]]$Upgrade,
    [string]$Search,
    [switch]$List,
    [string]$Info,
    [ValidateSet('winget', 'choco', 'direct', 'powershell', 'auto')]
    [string]$Manager = 'auto',
    [switch]$Silent,
    [switch]$SkipElevation,
    [switch]$Force,
    [switch]$DryRun,
    [switch]$Parallel,
    [int]$MaxConcurrency = 3,
    [string]$LogFile,
    [ValidateSet('Error', 'Warning', 'Info', 'Debug', 'Trace')]
    [string]$LogLevel = 'Info',
    [string]$CacheDirectory,
    [string[]]$AdditionalArgs = @(),
    [string]$Checksum
)

# Set execution policy for EXE context
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Get the directory where the EXE is running from
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Change to the script directory
Push-Location $ScriptDir

try {
    # Import all required modules
    . "$ScriptDir\Utils.ps1"
    . "$ScriptDir\Aliases.ps1"
    . "$ScriptDir\PackageManagers.ps1"
    . "$ScriptDir\Detection.ps1"
    . "$ScriptDir\Winget.ps1"
    . "$ScriptDir\Chocolatey.ps1"
    . "$ScriptDir\Install.ps1"
    . "$ScriptDir\Uninstall.ps1"
    . "$ScriptDir\Upgrade.ps1"

    # Initialize logging with EXE-appropriate path
    if (-not $LogFile) {
        $LogFile = Join-Path $ScriptDir 'installer.log'
    }

    # Display branding (EXE version)
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "               THE KINGSMAKERS WINAPP TOOL                        " -ForegroundColor Cyan
    Write-Host "                    (TKM WINAPP TOOL)                             " -ForegroundColor Cyan
    Write-Host "                         EXE VERSION                               " -ForegroundColor Yellow
    Write-Host "                                                                  " -ForegroundColor Cyan
    Write-Host "            Created by thekingsmakers                             " -ForegroundColor Yellow
    Write-Host "            Website: thekingsmaker.org                            " -ForegroundColor Yellow
    Write-Host "            Twitter: thekingsmakers                               " -ForegroundColor Yellow
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host ""

    Initialize-Logging -LogFile $LogFile -LogLevel $LogLevel

    if (-not $CacheDirectory) {
        $CacheDirectory = Get-DefaultCacheDirectory
    }

    $aliases = Load-PackageAliases

    # Check elevation
    $elevated = Test-Elevation
    $requiresElevation = ($PSBoundParameters.ContainsKey('Install') -or $PSBoundParameters.ContainsKey('Uninstall')) -and -not $SkipElevation

    if ($requiresElevation -and -not $elevated -and -not $DryRun) {
        Write-Log -Level Warning "Operation may require elevation. Will attempt to elevate if needed."
    }

    # Main logic (same as original MainInstaller.ps1)
    switch ($PSBoundParameters.Keys) {
        'Install' {
            $packages = Resolve-Packages -Packages $Install

            if ($Manager -eq 'auto') {
                $selectedManager = 'auto'
            } else {
                $selectedManager = $Manager
            }

            if ($Parallel -and $packages.Count -gt 1) {
                $packageNames = $packages | ForEach-Object { $_.Name }
                Install-PackagesParallel -Packages $packageNames -Manager $selectedManager -MaxConcurrency $MaxConcurrency -Force:$Force -DryRun:$DryRun -Silent:$Silent -AdditionalArgs $AdditionalArgs
            } else {
                foreach ($pkg in $packages) {
                    Install-Package -Name $pkg.Name -Manager $selectedManager -Force:$Force -DryRun:$DryRun -Silent:$Silent -AdditionalArgs $AdditionalArgs
                }
            }
        }
        'Uninstall' {
            $packages = Resolve-Packages -Packages $Uninstall

            if ($Manager -eq 'auto') {
                $selectedManager = 'auto'
            } else {
                $selectedManager = $Manager
            }

            foreach ($pkg in $packages) {
                Uninstall-Package -Name $pkg.Name -Manager $selectedManager -Force:$Force -DryRun:$DryRun -Silent:$Silent -AdditionalArgs $AdditionalArgs
            }
        }
        'Upgrade' {
            $packages = Resolve-Packages -Packages $Upgrade

            if ($Manager -eq 'auto') {
                $selectedManager = 'auto'
            } else {
                $selectedManager = $Manager
            }

            if ($Parallel -and $packages.Count -gt 1) {
                $packageNames = $packages | ForEach-Object { $_.Name }
                Update-PackagesParallel -Packages $packageNames -Manager $selectedManager -MaxConcurrency $MaxConcurrency -Force:$Force -DryRun:$DryRun -Silent:$Silent -AdditionalArgs $AdditionalArgs
            } else {
                foreach ($pkg in $packages) {
                    Update-Package -Name $pkg.Name -Manager $selectedManager -Force:$Force -DryRun:$DryRun -Silent:$Silent -AdditionalArgs $AdditionalArgs
                }
            }
        }
        'Search' {
            if ($Manager -eq 'auto') {
                $availableManagers = Get-AvailablePackageManagers
                $selectedManager = if ($availableManagers) { $availableManagers[0] } else { throw "No package manager available for search" }
            } else {
                $selectedManager = $Manager
            }

            Write-Log -Level Info "Searching for '$Search' using $selectedManager"
            $results = Search-Package -Query $Search -Manager $selectedManager
            if ($results -and $results.Count -gt 0) {
                Write-Log -Level Info "Found $($results.Count) results"
                $results | Format-Table -AutoSize
            } else {
                Write-Host "No packages found matching '$Search'"
            }
        }
        'List' {
            if ($Manager -eq 'auto') {
                $availableManagers = Get-AvailablePackageManagers
                $selectedManager = if ($availableManagers) { $availableManagers[0] } else { throw "No package manager available for listing" }
            } else {
                $selectedManager = $Manager
            }

            Write-Log -Level Info "Listing installed packages using $selectedManager"
            $installed = Get-InstalledPackages -Manager $selectedManager

            if ($installed) {
                if ($installed -is [array]) {
                    $hasResults = $installed.Count -gt 0
                    $resultCount = $installed.Count
                } elseif ($installed -is [string]) {
                    $hasResults = $true
                    $resultCount = 1
                } else {
                    $hasResults = $true
                    $resultCount = 1
                }
            }

            if ($hasResults) {
                Write-Log -Level Info "Found $resultCount result(s)"
                if ($installed -is [string]) {
                    Write-Host $installed
                } else {
                    $installed | Format-Table -AutoSize
                }
            } else {
                Write-Host "No installed packages found"
            }
        }
        'Info' {
            if ($Manager -eq 'auto') {
                $availableManagers = Get-AvailablePackageManagers
                $selectedManager = if ($availableManagers) { $availableManagers[0] } else { throw "No package manager available for info" }
            } else {
                $selectedManager = $Manager
            }

            $results = Search-Package -Query $Info -Manager $selectedManager
            if ($results) {
                $results[0] | Format-List
            } else {
                Write-Host "Package not found: $Info"
            }
        }
        default {
            Write-Host 'No operation specified. Use -Install, -Uninstall, -Search, -List, or -Info.'
            Write-Host "Run 'TKMWATool.exe -Help' for detailed help."
            exit 2
        }
    }

    Write-Log -Level Info "Operation completed successfully"
    exit 0

} catch {
    Write-Log -Level Error "Operation failed: $($_.Exception.Message)"
    exit 1
} finally {
    Pop-Location
}
```

### Step 2: Create the EXE

#### Basic Conversion
```powershell
# Convert to EXE (console application)
ps2exe -inputFile "MainInstallerEXE.ps1" -outputFile "TKMWATool.exe" -iconFile "kingsmakers.ico"
```

#### Advanced Conversion with Options
```powershell
# Full-featured conversion
ps2exe `
    -inputFile "MainInstallerEXE.ps1" `
    -outputFile "TKMWATool.exe" `
    -iconFile "kingsmakers.ico" `
    -title "THE KINGSMAKERS WINAPP TOOL" `
    -description "Advanced Windows Package Management Tool" `
    -company "thekingsmakers" `
    -product "TKM WINAPP TOOL" `
    -copyright "Created by thekingsmakers" `
    -version "1.0.0.0" `
    -requireAdmin $false `
    -noConsole $false `
    -x64 `
    -runtime40
```

### Step 3: Bundle Additional Files

#### Create a Bundle Script
```powershell
# Create: CreateBundle.ps1
param(
    [string]$OutputDir = ".\TKMWA-Bundle",
    [string]$IconPath = ".\kingsmakers.ico"
)

# Create output directory
New-Item -ItemType Directory -Path $OutputDir -Force

# Copy all required files
Copy-Item "*.ps1" $OutputDir -Force
Copy-Item "package-aliases.json" $OutputDir -Force
Copy-Item "installer.log" $OutputDir -Force -ErrorAction SilentlyContinue

# Copy icon if it exists
if (Test-Path $IconPath) {
    Copy-Item $IconPath $OutputDir -Force
}

# Create the EXE wrapper
$exeWrapper = @"
param(
    [string[]]`$Install,
    [string[]]`$Uninstall,
    [string[]]`$Upgrade,
    [string]$Search,
    [switch]$List,
    [string]$Info,
    [ValidateSet('winget', 'choco', 'direct', 'powershell', 'auto')]
    [string]$Manager = 'auto',
    [switch]$Silent,
    [switch]$SkipElevation,
    [switch]$Force,
    [switch]$DryRun,
    [switch]$Parallel,
    [int]$MaxConcurrency = 3,
    [string]$LogFile,
    [ValidateSet('Error', 'Warning', 'Info', 'Debug', 'Trace')]
    [string]$LogLevel = 'Info',
    [string]$CacheDirectory,
    [string[]]$AdditionalArgs = @(),
    [string]$Checksum
)

# Get the directory where the EXE is running from
`$ScriptDir = Split-Path -Parent `$MyInvocation.MyCommand.Path

# Execute the main script with all parameters
& "`$ScriptDir\MainInstaller.ps1" @PSBoundParameters
"@

$exeWrapper | Out-File "$OutputDir\MainInstallerEXE.ps1" -Encoding UTF8

Write-Host "Bundle created in: $OutputDir"
Write-Host "Run: ps2exe -inputFile '$OutputDir\MainInstallerEXE.ps1' -outputFile 'TKMWATool.exe'"
```

#### Run Bundle Creation
```powershell
# Create the bundle
.\CreateBundle.ps1

# Convert to EXE
ps2exe -inputFile ".\TKMWA-Bundle\MainInstallerEXE.ps1" -outputFile "TKMWATool.exe" -iconFile "kingsmakers.ico"
```

---

## Distribution Options

### Option 1: Single EXE (Recommended)
- **Pros**: Clean, single file distribution
- **Cons**: Larger file size, no customization
- **Use Case**: Standalone tool distribution

### Option 2: EXE + Bundle Directory
- **Pros**: Smaller EXE, customizable files
- **Cons**: Requires keeping files together
- **Use Case**: Enterprise deployment with custom configurations

### Option 3: MSI Installer Package
```powershell
# Create MSI using WiX Toolset or Advanced Installer
# Bundle the EXE with documentation and create desktop shortcuts
```

---

## Usage Examples (EXE Version)

### Basic Installation
```cmd
TKMWATool.exe -Install vscode
```

### Advanced Uninstallation
```cmd
TKMWATool.exe -Uninstall chrome -Force
```

### Silent Automation
```cmd
TKMWATool.exe -Install git,nodejs -Silent -Force
```

### List Installed Packages
```cmd
TKMWATool.exe -List
```

---

## Technical Considerations

### Execution Requirements
- **Windows 7 SP1+** or **Windows Server 2008 R2+**
- **.NET Framework 4.0+** (included in Windows 8+)
- **No PowerShell requirement** (embedded in EXE)

### File Size Expectations
- **Basic EXE**: ~2-3 MB
- **With embedded resources**: ~5-10 MB
- **Bundle approach**: EXE ~1MB + files ~500KB

### Performance Impact
- **Startup time**: 2-5 seconds (PowerShell initialization)
- **Memory usage**: 50-100 MB during operation
- **Disk I/O**: Log files and temp files created

### Security Considerations
- **Code Signing**: Sign the EXE with certificate
- **UAC Prompt**: Configure requireAdmin based on needs
- **Execution Policy**: EXE bypasses PowerShell execution policy

---

## Testing the EXE

### Functional Testing
```powershell
# Test all major functions
.\TKMWATool.exe -List
.\TKMWATool.exe -Search "chrome"
.\TKMWATool.exe -Install "notepad++" -DryRun
.\TKMWATool.exe -Uninstall "testapp" -DryRun
```

### Error Handling Testing
```powershell
# Test error scenarios
.\TKMWATool.exe -Install "nonexistentpackage"
.\TKMWATool.exe -Uninstall "notinstalled"
```

### Performance Testing
```powershell
# Measure execution time
Measure-Command { .\TKMWATool.exe -List }
```

---

## Deployment Strategies

### Individual User Deployment
```powershell
# Copy EXE to user's desktop or program files
Copy-Item TKMWATool.exe "$env:USERPROFILE\Desktop\"
```

### Enterprise Deployment
```powershell
# Use Group Policy or SCCM for network deployment
# Create MSI package for software distribution systems
```

### Portable Usage
```powershell
# EXE can be run from any directory
# Logs and cache created in execution directory
```

---

## Maintenance & Updates

### Version Management
- Include version information in EXE metadata
- Update version number in conversion script
- Maintain changelog for EXE releases

### Update Process
1. Update source PowerShell files
2. Test thoroughly
3. Reconvert to EXE
4. Test EXE functionality
5. Distribute updated version

### Troubleshooting EXE Issues
- Check Windows Event Viewer for .NET errors
- Test with `-LogLevel Debug` for detailed logging
- Verify .NET Framework version
- Check antivirus exclusions

---

## Alternative Tools

### Win-PS2EXE
```powershell
# GUI-based conversion tool
# Download from: https://winps2exe.codeplex.com/
```

### PowerShell Pro Tools
```powershell
# Commercial solution with advanced features
# Includes GUI designer and packaging tools
```

### Manual .NET Compilation
```powershell
# Advanced: Compile directly with C# and PowerShell engine
# Maximum control but complex implementation
```

---

## Summary

**Yes, creating an EXE from THE KINGSMAKERS WINAPP TOOL is absolutely feasible and recommended for:**

- ✅ **End-user deployment** (no PowerShell knowledge required)
- ✅ **Enterprise distribution** (MSI packaging possible)
- ✅ **Portable usage** (run from any location)
- ✅ **Professional appearance** (custom icon, metadata)
- ✅ **Simplified execution** (double-click or command-line)

**Recommended Approach:**
1. Use PS2EXE for conversion
2. Create bundle script for file management
3. Test thoroughly in target environments
4. Sign the EXE for security
5. Package with documentation

**The resulting EXE will provide the same functionality as the PowerShell scripts but with a professional, standalone application experience!** 🚀

**Created by thekingsmakers | Website: thekingsmaker.org | Twitter: thekingsmakers** ✨
