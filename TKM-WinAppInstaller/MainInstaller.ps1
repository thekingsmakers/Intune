# MainInstaller.ps1
# THE KINGSMAKERS WINAPP TOOL (TKM WINAPP TOOL)
# Created by thekingsmakers
# Website: thekingsmaker.org
# Twitter: thekingsmakers
# An advanced Windows application management tool with comprehensive uninstall capabilities

<#
.SYNOPSIS
    THE KINGSMAKERS WINAPP TOOL (TKM WINAPP TOOL) - Advanced Windows Package Manager

.DESCRIPTION
    A comprehensive Windows package management solution featuring:
    - Multiple package manager support (winget, choco, PowerShell)
    - Advanced uninstallation with registry cleanup and file removal
    - Intelligent package detection and detailed information gathering
    - Professional branding and user experience

    Created by thekingsmakers
    Website: thekingsmaker.org
    Twitter: thekingsmakers
    Installation Methods (tried in order):
    1. Winget (Windows Package Manager)
    2. Chocolatey (if available)
    3. Direct download (for URLs)
    4. PowerShell-native methods (for local files)

    Features:
    - Multiple installation methods with automatic fallbacks
    - Package upgrade capabilities with version management
    - Direct download support with checksum verification for MSI/EXE/ZIP files
    - Parallel installation and upgrade for multiple packages
    - Intelligent elevation handling (tries non-elevated first)
    - Package alias mapping system
    - Robust logging and error handling

.PARAMETER Install
    Install one or more packages.

.PARAMETER Uninstall
    Uninstall one or more packages with advanced cleanup.

.PARAMETER Upgrade
    Upgrade one or more packages.

.PARAMETER Search
    Search for available packages.

.PARAMETER List
    List installed packages.

.PARAMETER Info
    Get detailed information about a package.

.PARAMETER Manager
    Package manager to use ('auto', 'winget', 'choco').

.PARAMETER Force
    Force operations.

.PARAMETER DryRun
    Show what would be done without making changes.

.PARAMETER Silent
    Silent operations.

.PARAMETER Parallel
    Use parallel processing for multiple packages.

.PARAMETER MaxConcurrency
    Maximum concurrent operations.

.PARAMETER AdditionalArgs
    Additional arguments to pass to package managers.

.PARAMETER LogLevel
    Logging level: Error, Warning, Info, Debug, Trace (default: Info).

.PARAMETER CacheDirectory
    Directory for downloaded files (default: user profile cache).

.PARAMETER Args
    Additional arguments to pass to installers.

.PARAMETER Checksum
    SHA256 checksum for direct downloads (verifies integrity).

.EXAMPLE
    .\MainInstaller.ps1 -Upgrade "vscode,git"

    Upgrades Visual Studio Code and Git to their latest versions.

.EXAMPLE
    .\MainInstaller.ps1 -Install "vscode,git" -Parallel

    Installs Visual Studio Code and Git concurrently using the best available package manager.

.EXAMPLE
    .\MainInstaller.ps1 -Search "chrome"

    Searches for Chrome-related packages.

    .\MainInstaller.ps1 -Install "https://example.com/app.exe" -Checksum "ABC123..." -Silent

    Downloads and installs an application from URL with checksum verification.

.EXAMPLE
    .\MainInstaller.ps1 -Install "firefox" -Manager winget

    Installs Firefox using winget.

.EXAMPLE
    .\MainInstaller.ps1 -Uninstall "chrome" -Manager auto

    Uninstalls Chrome using the best available package manager.

.EXAMPLE
    .\MainInstaller.ps1 -List

    Lists all installed packages.

.NOTES
    THE KINGSMAKERS WINAPP TOOL (TKM WINAPP TOOL)
    Created by thekingsmakers
    Website: thekingsmaker.org
    Twitter: thekingsmakers

.NOTES
    Requires PowerShell 7+ for full functionality.
    For winget: Windows Package Manager (winget)
    For choco: Chocolatey package manager
    Direct downloads support MSI and EXE files with checksum verification.
#>

[CmdletBinding(DefaultParameterSetName = 'None')]
param (
    [Parameter(ParameterSetName = 'Install')]
    [string[]]$Install,

    [Parameter(ParameterSetName = 'Uninstall')]
    [string[]]$Uninstall,

    [Parameter(ParameterSetName = 'Upgrade')]
    [string[]]$Upgrade,

    [Parameter(ParameterSetName = 'Search')]
    [string]$Search,

    [Parameter(ParameterSetName = 'List')]
    [switch]$List,

    [Parameter(ParameterSetName = 'Info')]
    [string]$Info,

    [ValidateSet('winget', 'choco', 'direct', 'powershell', 'auto')]
    [string]$Manager = 'auto',

    [Alias('Quiet')]
    [switch]$Silent,

    [Alias('NoElevate')]
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

# Import modules
. $PSScriptRoot\Utils.ps1
. $PSScriptRoot\Aliases.ps1
. $PSScriptRoot\PackageManagers.ps1
. $PSScriptRoot\Detection.ps1
. $PSScriptRoot\Winget.ps1
. $PSScriptRoot\Chocolatey.ps1
. $PSScriptRoot\Install.ps1
. $PSScriptRoot\Uninstall.ps1
. $PSScriptRoot\Upgrade.ps1

# Initialize
if (-not $LogFile) {
    $LogFile = Join-Path $PSScriptRoot 'installer.log'
}

# Display branding
try {
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "               THE KINGSMAKERS WINAPP TOOL                        " -ForegroundColor Cyan
    Write-Host "                    (TKM WINAPP TOOL)                             " -ForegroundColor Cyan
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
$requiresElevation = $PSCmdlet.ParameterSetName -in @('Install', 'Uninstall') -and -not $SkipElevation

if ($requiresElevation -and -not $elevated -and -not $DryRun) {
    Write-Log -Level Warning "Operation may require elevation. Will attempt to elevate if needed."
    # Don't elevate preemptively - let the operation fail first, then elevate
}

# Resolve aliases for packages
function Resolve-Packages {
    param ([string[]]$Packages)
    $resolved = @()
    foreach ($pkg in $Packages) {
        $aliasInfo = Get-PackageFromAlias -Name $pkg -Aliases $aliases
        if ($aliasInfo) {
            $resolvedPkg = if ($aliasInfo.winget) { $aliasInfo.winget } elseif ($aliasInfo.choco) { $aliasInfo.choco } elseif ($aliasInfo.url) { $aliasInfo.url } else { $pkg }
            $resolved += @{
                Name = $resolvedPkg
                Checksum = $aliasInfo.checksum
            }
        } else {
            $resolved += @{
                Name = $pkg
                Checksum = $null
            }
        }
    }
    return $resolved
}

# Main logic
try {
    switch ($PSCmdlet.ParameterSetName) {
        'Install' {
            $packages = Resolve-Packages -Packages $Install

            # For install, always use 'auto' to enable fallbacks unless a specific manager is requested
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
        'Upgrade' {
            $packages = Resolve-Packages -Packages $Upgrade

            # For upgrade, always use 'auto' to enable fallbacks unless a specific manager is requested
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
        'Uninstall' {
            $packages = Resolve-Packages -Packages $Uninstall

            # For uninstall, always use 'auto' to enable fallbacks unless a specific manager is requested
            if ($Manager -eq 'auto') {
                $selectedManager = 'auto'
            } else {
                $selectedManager = $Manager
            }

            foreach ($pkg in $packages) {
                Uninstall-Package -Name $pkg.Name -Manager $selectedManager -Force:$Force -DryRun:$DryRun -Silent:$Silent -AdditionalArgs $AdditionalArgs
            }
        }
        'Search' {
            # Auto-select manager if not specified
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
            # Auto-select manager if not specified
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
                    $resultCount = 1  # String result counts as 1
                } else {
                    # Single object
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
            # Auto-select manager if not specified
            if ($Manager -eq 'auto') {
                $availableManagers = Get-AvailablePackageManagers
                $selectedManager = if ($availableManagers) { $availableManagers[0] } else { throw "No package manager available for info" }
            } else {
                $selectedManager = $Manager
            }

            # Simplified - search and show first result
            $results = Search-Package -Query $Info -Manager $selectedManager
            if ($results) {
                $results[0] | Format-List
            } else {
                Write-Host "Package not found: $Info"
            }
        }
        default {
            Write-Host 'No operation specified. Use -Install, -Uninstall, -Search, -List, or -Info.'
            Write-Host "Run 'Get-Help .\MainInstaller.ps1 -Full' for detailed help."
            exit 2
        }
    }

    Write-Log -Level Info "Operation completed successfully"
    exit 0

} catch {
    Write-Log -Level Error "Operation failed: $($_.Exception.Message)"
    exit 1
}
