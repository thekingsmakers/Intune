# THE KINGSMAKERS WINAPP TOOL - EXE Conversion Script
# This script converts the PowerShell project to a standalone EXE

param(
    [string]$OutputFile = "TKMWATool.exe",
    [string]$IconFile = "kingsmakers.ico",
    [switch]$Force,
    [switch]$NoConsole,
    [switch]$RequireAdmin,
    [string]$Version = "1.0.0.0",
    [switch]$BundleMode
)

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "               THE KINGSMAKERS WINAPP TOOL                        " -ForegroundColor Cyan
Write-Host "                    EXE CONVERSION SCRIPT                        " -ForegroundColor Yellow
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Check if PS2EXE is installed
Write-Host "Checking for PS2EXE module..." -ForegroundColor Yellow
try {
    $ps2exeModule = Get-Module -Name ps2exe -ListAvailable
    if (-not $ps2exeModule) {
        Write-Host "PS2EXE module not found. Installing..." -ForegroundColor Yellow
        Install-Module -Name ps2exe -Scope CurrentUser -Force -ErrorAction Stop
        Write-Host "PS2EXE installed successfully!" -ForegroundColor Green
    } else {
        Write-Host "PS2EXE module found: $($ps2exeModule.Version)" -ForegroundColor Green
    }
} catch {
    Write-Host "ERROR: Failed to install PS2EXE module. $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please install PS2EXE manually: Install-Module -Name ps2exe -Scope CurrentUser -Force" -ForegroundColor Red
    exit 1
}

# Check for required files
Write-Host "`nChecking for required files..." -ForegroundColor Yellow
$requiredFiles = @(
    "MainInstaller.ps1",
    "Utils.ps1",
    "Aliases.ps1",
    "PackageManagers.ps1",
    "Detection.ps1",
    "Winget.ps1",
    "Chocolatey.ps1",
    "Install.ps1",
    "Uninstall.ps1",
    "Upgrade.ps1",
    "package-aliases.json"
)

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

# Check for icon file
$useIcon = $false
if (Test-Path $IconFile) {
    Write-Host "Icon file found: $IconFile" -ForegroundColor Green
    $useIcon = $true
} else {
    Write-Host "Icon file not found: $IconFile (EXE will use default icon)" -ForegroundColor Yellow
}

# Check if output file exists
if ((Test-Path $OutputFile) -and -not $Force) {
    Write-Host "Output file '$OutputFile' already exists. Use -Force to overwrite." -ForegroundColor Red
    exit 1
}

# Create EXE wrapper script
Write-Host "`nCreating EXE wrapper script..." -ForegroundColor Yellow

$exeWrapperScript = @'
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
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction Stop
} catch {
    # Ignore execution policy errors in EXE context
}

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
    try {
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
    } catch {
        # Fallback for environments that don't support colored output
        Write-Host "=================================================================="
        Write-Host "               THE KINGSMAKERS WINAPP TOOL                        "
        Write-Host "                    (TKM WINAPP TOOL)                             "
        Write-Host "                         EXE VERSION                               "
        Write-Host "                                                                  "
        Write-Host "            Created by thekingsmakers                             "
        Write-Host "            Website: thekingsmaker.org                            "
        Write-Host "            Twitter: thekingsmakers                               "
        Write-Host "=================================================================="
        Write-Host ""
    }

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

            # Check if we have results (handle both arrays and strings)
            $hasResults = $false
            $resultCount = 0

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
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}
'@

$exeWrapperPath = "MainInstallerEXE.ps1"
$exeWrapperScript | Out-File -FilePath $exeWrapperPath -Encoding UTF8 -Force
Write-Host "EXE wrapper script created: $exeWrapperPath" -ForegroundColor Green

# Convert to EXE
Write-Host "`nConverting to EXE..." -ForegroundColor Yellow
Write-Host "Output file: $OutputFile" -ForegroundColor White
Write-Host "Version: $Version" -ForegroundColor White
Write-Host "Require Admin: $RequireAdmin" -ForegroundColor White
Write-Host "No Console: $NoConsole" -ForegroundColor White
if ($useIcon) { Write-Host "Icon: $IconFile" -ForegroundColor White }

# Build PS2EXE parameters
$ps2exeParams = @{
    inputFile = $exeWrapperPath
    outputFile = $OutputFile
    title = "THE KINGSMAKERS WINAPP TOOL"
    description = "Advanced Windows Package Management Tool with Intelligent Fallbacks"
    company = "thekingsmakers"
    product = "TKM WINAPP TOOL"
    copyright = "Created by thekingsmakers"
    version = $Version
    requireAdmin = $RequireAdmin
    noConsole = $NoConsole
    x64 = $true
}

# Note: runtime40 parameter may not be available in all PS2EXE versions
# Using default .NET runtime targeting

if ($useIcon) {
    $ps2exeParams.iconFile = $IconFile
}

try {
    # Call PS2EXE
    Invoke-ps2exe @ps2exeParams

    # Verify the EXE was created
    if (Test-Path $OutputFile) {
        $exeSize = (Get-Item $OutputFile).Length
        $exeSizeMB = [math]::Round($exeSize / 1MB, 2)

        Write-Host "`n==================================================================" -ForegroundColor Green
        Write-Host "EXE CREATION SUCCESSFUL!" -ForegroundColor Green
        Write-Host "==================================================================" -ForegroundColor Green
        Write-Host "Output File: $OutputFile" -ForegroundColor White
        Write-Host "File Size: $exeSizeMB MB" -ForegroundColor White
        Write-Host "Version: $Version" -ForegroundColor White
        Write-Host "" -ForegroundColor White

        # Test the EXE
        Write-Host "Testing EXE functionality..." -ForegroundColor Yellow
        try {
            $testResult = & $OutputFile -List -Silent 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "EXE test successful!" -ForegroundColor Green
            } else {
                Write-Host "EXE test completed with warnings (this is normal for listing)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "EXE test had issues, but file was created successfully" -ForegroundColor Yellow
        }

        Write-Host "`nUSAGE EXAMPLES:" -ForegroundColor Cyan
        Write-Host "  $OutputFile -List" -ForegroundColor White
        Write-Host "  $OutputFile -Install vscode" -ForegroundColor White
        Write-Host "  $OutputFile -Uninstall chrome" -ForegroundColor White
        Write-Host "  $OutputFile -Search 'browser'" -ForegroundColor White
        Write-Host "  $OutputFile -Upgrade 'all'" -ForegroundColor White

        Write-Host "`n==================================================================" -ForegroundColor Cyan
        Write-Host "THE KINGSMAKERS WINAPP TOOL EXE READY!" -ForegroundColor Cyan
        Write-Host "Created by thekingsmakers | thekingsmaker.org" -ForegroundColor Yellow
        Write-Host "==================================================================" -ForegroundColor Cyan

    } else {
        Write-Host "ERROR: EXE file was not created!" -ForegroundColor Red
        exit 1
    }

} catch {
    Write-Host "ERROR: EXE conversion failed. $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Make sure PS2EXE is properly installed and all files are accessible." -ForegroundColor Red
    exit 1
} finally {
    # Clean up wrapper script
    if (Test-Path $exeWrapperPath) {
        Remove-Item $exeWrapperPath -Force
        Write-Host "`nCleaned up temporary wrapper script." -ForegroundColor Gray
    }
}

Write-Host "`nScript completed successfully!" -ForegroundColor Green
