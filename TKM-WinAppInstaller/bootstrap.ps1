# THE KINGSMAKERS WINAPP TOOL - GitHub Bootstrap Script
# Downloads and loads all modules from GitHub automatically
# Single small script that users can download and run
# Supports: iwr <url> | iex -List (or -Install, -Uninstall, -Upgrade, etc.)

param(
    [Parameter(Position = 0)]
    [string]$Command,
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

# If no parameters passed via param(), check $args (for IEX piping)
if (-not $Command -and $args.Count -gt 0) {
    # Parse arguments for IEX style: iwr url | iex -List package
    # Handle both -Parameter and Parameter formats
    for ($i = 0; $i -lt $args.Count; $i++) {
        $arg = $args[$i]
        if ($arg -match '^-(\w+)$') {
            # -Parameter format
            $Command = $matches[1]
            $Arguments = $args[($i + 1)..($args.Count - 1)]
            break
        } elseif ($arg -notmatch '^-') {
            # Parameter format (assuming first non-dash arg is command)
            $Command = $arg
            $Arguments = $args[($i + 1)..($args.Count - 1)]
            break
        }
    }
}

# Convert command to proper parameter format
$Install = @()
$Uninstall = @()
$Upgrade = @()
$Search = $null
$List = $false
$Info = $null
$Manager = 'auto'
$Silent = $false
$SkipElevation = $false
$Force = $false
$DdryRun = $false
$Parallel = $false
$MaxConcurrency = 3
$LogFile = $null
$LogLevel = 'Info'
$CacheDirectory = $null
$AdditionalArgs = @()
$Checksum = $null

# Parse based on command
switch ($Command) {
    {$_ -in @('List', 'list', 'LIST')} {
        $List = $true
    }
    {$_ -in @('Search', 'search', 'SEARCH')} {
        if ($Arguments) { $Search = $Arguments[0] }
    }
    {$_ -in @('Info', 'info', 'INFO')} {
        if ($Arguments) { $Info = $Arguments[0] }
    }
    {$_ -in @('Install', 'install', 'INSTALL')} {
        if ($Arguments) { $Install = $Arguments }
    }
    {$_ -in @('Uninstall', 'uninstall', 'UNINSTALL')} {
        if ($Arguments) { $Uninstall = $Arguments }
    }
    {$_ -in @('Upgrade', 'upgrade', 'UPGRADE')} {
        if ($Arguments) { $Upgrade = $Arguments }
    }
    default {
        # Show help when no valid command or when run without parameters
        Write-Host "==================================================================" -ForegroundColor Cyan
        Write-Host "               THE KINGSMAKERS WINAPP TOOL                        " -ForegroundColor Cyan
        Write-Host "                    GITHUB BOOTSTRAP                              " -ForegroundColor Yellow
        Write-Host "                                                                  " -ForegroundColor Cyan
        Write-Host "            Created by thekingsmakers                             " -ForegroundColor Yellow
        Write-Host "            Website: thekingsmaker.org                            " -ForegroundColor Yellow
        Write-Host "            Twitter: thekingsmakers                               " -ForegroundColor Yellow
        Write-Host "==================================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "USAGE: iwr <bootstrap-url> | iex <command> [arguments]" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "COMMANDS:" -ForegroundColor Yellow
        Write-Host "  -List              List installed packages" -ForegroundColor White
        Write-Host "  -Search <query>    Search for available packages" -ForegroundColor White
        Write-Host "  -Install <pkg>     Install package(s) (comma-separated)" -ForegroundColor White
        Write-Host "  -Uninstall <pkg>   Uninstall package(s) (comma-separated)" -ForegroundColor White
        Write-Host "  -Upgrade <pkg>     Upgrade package(s) (comma-separated)" -ForegroundColor White
        Write-Host "  -Info <pkg>        Get package information" -ForegroundColor White
        Write-Host ""
        Write-Host "EXAMPLES:" -ForegroundColor Cyan
        Write-Host "  iwr https://raw.githubusercontent.com/thekingsmakers/Intune/refs/heads/main/TKM-WinAppInstaller/bootstrap.ps1 | iex -List" -ForegroundColor White
        Write-Host "  iwr https://raw.githubusercontent.com/thekingsmakers/Intune/refs/heads/main/TKM-WinAppInstaller/bootstrap.ps1 | iex -Install vscode" -ForegroundColor White
        Write-Host "  iwr https://raw.githubusercontent.com/thekingsmakers/Intune/refs/heads/main/TKM-WinAppInstaller/bootstrap.ps1 | iex -Upgrade git,nodejs" -ForegroundColor White
        Write-Host ""
        Write-Host "DOWNLOAD URL:" -ForegroundColor Gray
        Write-Host "  https://raw.githubusercontent.com/thekingsmakers/Intune/refs/heads/main/TKM-WinAppInstaller/bootstrap.ps1" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "The script automatically downloads required modules from GitHub." -ForegroundColor Gray
        Write-Host "No installation required - just run the commands above!" -ForegroundColor Green
        Write-Host ""
        Write-Host "==================================================================" -ForegroundColor Cyan
        Write-Host "            Created by thekingsmakers - 2025                      " -ForegroundColor Yellow
        Write-Host "==================================================================" -ForegroundColor Cyan
        exit 0
    }
}

# GitHub repository details (UPDATE THESE FOR YOUR REPO)
$GitHubUser = "thekingsmakers"  # Replace with your GitHub username
$Repository = "Intune"  # Replace with your repository name
$Branch = "main"  # Or "master" depending on your default branch

# Raw GitHub URLs for each module (update these with your actual GitHub URLs)
$moduleUrls = @{
    "Utils" = "https://raw.githubusercontent.com/thekingsmakers/Intune/refs/heads/main/TKM-WinAppInstaller/Utils.ps1"
    "Aliases" = "https://raw.githubusercontent.com/thekingsmakers/Intune/refs/heads/main/TKM-WinAppInstaller/Aliases.ps1"
    "PackageManagers" = "https://raw.githubusercontent.com/thekingsmakers/Intune/refs/heads/main/TKM-WinAppInstaller/PackageManagers.ps1"
    "Detection" = "https://raw.githubusercontent.com/thekingsmakers/Intune/refs/heads/main/TKM-WinAppInstaller/Detection.ps1"
    "Winget" = "https://raw.githubusercontent.com/thekingsmakers/Intune/refs/heads/main/TKM-WinAppInstaller/Winget.ps1"
    "Chocolatey" = "https://raw.githubusercontent.com/thekingsmakers/Intune/refs/heads/main/TKM-WinAppInstaller/Chocolatey.ps1"
    "Install" = "https://raw.githubusercontent.com/thekingsmakers/Intune/refs/heads/main/TKM-WinAppInstaller/Install.ps1"
    "Uninstall" = "https://raw.githubusercontent.com/thekingsmakers/Intune/refs/heads/main/TKM-WinAppInstaller/Uninstall.ps1"
    "Upgrade" = "https://raw.githubusercontent.com/thekingsmakers/Intune/refs/heads/main/TKM-WinAppInstaller/Upgrade.ps1"
    "AliasesJson" = "https://raw.githubusercontent.com/thekingsmakers/Intune/refs/heads/main/TKM-WinAppInstaller/package-aliases.json"
}

# Global cache for downloaded modules
$global:DownloadedModules = @{}

# Set execution policy for this script
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction Stop
} catch {
    # Ignore execution policy errors
}

# Display branding
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "               THE KINGSMAKERS WINAPP TOOL                        " -ForegroundColor Cyan
Write-Host "                    GITHUB BOOTSTRAP                              " -ForegroundColor Yellow
Write-Host "                                                                  " -ForegroundColor Cyan
Write-Host "            Created by thekingsmakers                             " -ForegroundColor Yellow
Write-Host "            Website: thekingsmaker.org                            " -ForegroundColor Yellow
Write-Host "            Twitter: thekingsmakers                               " -ForegroundColor Yellow
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Function to download and load a specific module
function Download-AndLoadModule {
    param([string]$ModuleName)

    # Check if already downloaded
    if ($global:DownloadedModules.ContainsKey($ModuleName)) {
        Write-Host "$ModuleName already loaded" -ForegroundColor Gray
        return $true
    }

    # Check if URL exists
    if (-not $moduleUrls.ContainsKey($ModuleName)) {
        Write-Host "ERROR: No URL defined for module: $ModuleName" -ForegroundColor Red
        return $false
    }

    $url = $moduleUrls[$ModuleName]
    $tempPath = Join-Path $tempDir "$ModuleName.ps1"

    try {
        Write-Host "Downloading $ModuleName from GitHub..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $url -OutFile $tempPath -UseBasicParsing -ErrorAction Stop
        Write-Host "Downloaded $ModuleName successfully" -ForegroundColor Green

        # Load the module
        . $tempPath
        Write-Host "Loaded $ModuleName successfully" -ForegroundColor Green

        # Cache it
        $global:DownloadedModules[$ModuleName] = $tempPath
        return $true

    } catch {
        Write-Host "Failed to download/load $ModuleName`: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to download aliases JSON
function Download-AliasesJson {
    if ($global:DownloadedModules.ContainsKey("AliasesJson")) {
        return $true
    }

    $url = $moduleUrls["AliasesJson"]
    $tempPath = Join-Path $tempDir "package-aliases.json"

    try {
        Write-Host "Downloading package aliases from GitHub..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $url -OutFile $tempPath -UseBasicParsing -ErrorAction Stop
        Write-Host "Downloaded aliases successfully" -ForegroundColor Green

        # Load aliases
        $aliasesContent = Get-Content $tempPath -Raw -Encoding UTF8
        $global:aliases = $aliasesContent | ConvertFrom-Json
        Write-Host "Loaded package aliases successfully" -ForegroundColor Green

        $global:DownloadedModules["AliasesJson"] = $tempPath
        return $true

    } catch {
        Write-Host "Failed to download/load aliases: $($_.Exception.Message)" -ForegroundColor Red
        $global:aliases = @{}
        return $false
    }
}

# Create temp directory for downloaded modules
$tempDir = Join-Path $env:TEMP "TKMWinAppTool_Bootstrap_$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    Write-Host "Initializing THE KINGSMAKERS WINAPP TOOL..." -ForegroundColor Cyan

    # Initialize core modules (always needed)
    Write-Host "Loading core modules..." -ForegroundColor Cyan

    # Download Utils (needed for logging)
    if (-not (Download-AndLoadModule "Utils")) {
        throw "Failed to load Utils module"
    }

    # Initialize logging after Utils is loaded
    if (-not $LogFile) {
        $LogFile = Join-Path $env:TEMP 'tkm-winapp-tool.log'
    }

    Initialize-Logging -LogFile $LogFile -LogLevel $LogLevel

    # Download aliases (needed for package resolution)
    Download-AliasesJson

    # Download modules based on operation
    if ($Install.Count -gt 0) {
        Write-Host "Loading modules for Install operation..." -ForegroundColor Cyan
        # Install needs: PackageManagers, Detection, Winget, Chocolatey, Install
        $requiredModules = @("PackageManagers", "Detection", "Winget", "Chocolatey", "Install")
        foreach ($module in $requiredModules) {
            if (-not (Download-AndLoadModule $module)) {
                Write-Host "Warning: Failed to load $module module, install may not work properly" -ForegroundColor Yellow
            }
        }
    } elseif ($Uninstall.Count -gt 0) {
        Write-Host "Loading modules for Uninstall operation..." -ForegroundColor Cyan
        # Uninstall needs: PackageManagers, Detection, Winget, Chocolatey, Uninstall
        $requiredModules = @("PackageManagers", "Detection", "Winget", "Chocolatey", "Uninstall")
        foreach ($module in $requiredModules) {
            if (-not (Download-AndLoadModule $module)) {
                Write-Host "Warning: Failed to load $module module, uninstall may not work properly" -ForegroundColor Yellow
            }
        }
    } elseif ($Upgrade.Count -gt 0) {
        Write-Host "Loading modules for Upgrade operation..." -ForegroundColor Cyan
        # Upgrade needs: PackageManagers, Detection, Winget, Chocolatey, Upgrade
        $requiredModules = @("PackageManagers", "Detection", "Winget", "Chocolatey", "Upgrade")
        foreach ($module in $requiredModules) {
            if (-not (Download-AndLoadModule $module)) {
                Write-Host "Warning: Failed to load $module module, upgrade may not work properly" -ForegroundColor Yellow
            }
        }
    } elseif ($Search -or $List -or $Info) {
        Write-Host "Loading modules for query operation..." -ForegroundColor Cyan
        # Search/List/Info needs: PackageManagers, Detection, Winget, Chocolatey
        $requiredModules = @("PackageManagers", "Detection", "Winget", "Chocolatey")
        foreach ($module in $requiredModules) {
            if (-not (Download-AndLoadModule $module)) {
                Write-Host "Warning: Failed to load $module module, query may not work properly" -ForegroundColor Yellow
            }
        }
    }

    if (-not $CacheDirectory) {
        $CacheDirectory = Get-DefaultCacheDirectory
    }

    # Check elevation
    $elevated = Test-Elevation
    $requiresElevation = (($Install.Count -gt 0) -or ($Uninstall.Count -gt 0)) -and -not $SkipElevation

    if ($requiresElevation -and -not $elevated -and -not $DryRun) {
        Write-Log -Level Warning "Operation may require elevation. Will attempt to elevate if needed."
    }

    # Main logic (same as monolithic script)
    if ($Install.Count -gt 0) {
        $packages = @()
        foreach ($pkg in $Install) {
            $resolved = Get-PackageFromAlias -Alias $pkg -Manager $Manager
            $packages += $resolved
        }

        foreach ($pkg in $packages) {
            try {
                Install-Package -Name $pkg -Manager $Manager -Force:$Force -DryRun:$DryRun -Silent:$Silent -AdditionalArgs $AdditionalArgs
                Write-Host "Successfully processed install for: $pkg" -ForegroundColor Green
            } catch {
                Write-Host "Failed to install $pkg`: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } elseif ($Uninstall.Count -gt 0) {
        $packages = @()
        foreach ($pkg in $Uninstall) {
            $resolved = Get-PackageFromAlias -Alias $pkg -Manager $Manager
            $packages += $resolved
        }

        foreach ($pkg in $packages) {
            try {
                Uninstall-Package -Name $pkg -Manager $Manager -Force:$Force -DryRun:$DryRun -Silent:$Silent -AdditionalArgs $AdditionalArgs
                Write-Host "Successfully processed uninstall for: $pkg" -ForegroundColor Green
            } catch {
                Write-Host "Failed to uninstall $pkg`: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } elseif ($Upgrade.Count -gt 0) {
        $packages = @()
        foreach ($pkg in $Upgrade) {
            $resolved = Get-PackageFromAlias -Alias $pkg -Manager $Manager
            $packages += $resolved
        }

        foreach ($pkg in $packages) {
            try {
                Update-Package -Name $pkg -Manager $Manager -Force:$Force -DryRun:$DryRun -Silent:$Silent -AdditionalArgs $AdditionalArgs
                Write-Host "Successfully processed upgrade for: $pkg" -ForegroundColor Green
            } catch {
                Write-Host "Failed to upgrade $pkg`: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } elseif ($Search) {
        $results = Search-Package -Query $Search -Manager $Manager
        if ($results -and $results.Count -gt 0) {
            Write-Host "Found $($results.Count) result(s):" -ForegroundColor Green
            $results | Format-Table -AutoSize
        } else {
            Write-Host "No packages found matching '$Search'" -ForegroundColor Yellow
        }
    } elseif ($List) {
        $installed = Get-InstalledPackages -Manager $Manager
        if ($installed -and $installed.Count -gt 0) {
            Write-Host "Found $($installed.Count) installed package(s):" -ForegroundColor Green
            $installed | Format-Table -AutoSize
        } else {
            Write-Host "No installed packages found" -ForegroundColor Yellow
        }
    } elseif ($Info) {
        $results = Search-Package -Query $Info -Manager $Manager
        if ($results -and $results.Count -gt 0) {
            Write-Host "Package information:" -ForegroundColor Green
            $results[0] | Format-List
        } else {
            Write-Host "Package not found: $Info" -ForegroundColor Yellow
        }
    } else {
        Write-Host 'THE KINGSMAKERS WINAPP TOOL - GitHub Bootstrap Version' -ForegroundColor Cyan
        Write-Host 'Automatically downloads and loads all modules from GitHub' -ForegroundColor White
        Write-Host ""
        Write-Host 'No operation specified. Use -Install, -Uninstall, -Upgrade, -Search, -List, or -Info.' -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Cyan
        Write-Host "  .\bootstrap.ps1 -List" -ForegroundColor White
        Write-Host "  .\bootstrap.ps1 -Install vscode" -ForegroundColor White
        Write-Host "  .\bootstrap.ps1 -Uninstall chrome" -ForegroundColor White
        Write-Host "  .\bootstrap.ps1 -Search 'browser'" -ForegroundColor White
        Write-Host "  .\bootstrap.ps1 -Upgrade 'git'" -ForegroundColor White
        Write-Host ""
        Write-Host "This script will automatically download all required modules from:" -ForegroundColor Gray
        Write-Host "https://github.com/$GitHubUser/$Repository" -ForegroundColor Gray
    }

    Write-Log -Level Info "Operation completed successfully"
} catch {
    Write-Log -Level Error "Operation failed: $($_.Exception.Message)"
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    # Clean up temp directory
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
