#Requires -Version 5.1
<#
.SYNOPSIS
    Remediation script for Windows Store app updates - Intune Remediation
.DESCRIPTION
    Downloads and installs/updates Windows Store apps directly using PowerShell
.NOTES
    Run as: System
    Exit 0: Remediation successful
    Exit 1: Remediation failed
.AUTHOR
	Created by:  Omar Osman Mahat
	Aka : THEKINGSMAKERS	
#>

# ============================================================================
# APP CONFIGURATION - Add your apps here
# ============================================================================
$StoreApps = @{
    Viewer3D = @{
    ProductId = "9NBLGGH42THS"
    PackageName = "Microsoft.Microsoft3DViewer"
    MinimumVersion = "7.2003.11022.0"
}
}

# ============================================================================
# CONFIGURATION
# ============================================================================
$TempFolder = "$env:TEMP\StoreAppUpdates"
$Ring = "Retail"  # Options: Retail, RP (Preview), WIS (Slow), WIF (Fast)
$Arch = "x64"     # Options: x64, x86, arm64, arm

# Get system architecture if not specified
if ([Environment]::Is64BitOperatingSystem) {
    $Arch = "x64"
} else {
    $Arch = "x86"
}

# ============================================================================
# REMEDIATION LOGIC - Do not modify below unless needed
# ============================================================================

$remediationSuccess = $true
$logEntries = @()

# Dependency list for Store apps
$DependencyList = @(
    'Microsoft.VCLibs',
    'Microsoft.UI.Xaml',
    'Microsoft.NET.Native.Framework',
    'Microsoft.NET.Native.Runtime'
)

# Function to compare versions
function Compare-AppVersion {
    param (
        [string]$InstalledVersion,
        [string]$RequiredVersion
    )
    
    try {
        $installed = [version]$InstalledVersion
        $required = [version]$RequiredVersion
        return ($installed -lt $required)
    } catch {
        return $true
    }
}

# Function to get download links using store.rg-adguard.net
function Get-StoreDownloadLinks {
    param (
        [string]$ProductId,
        [string]$Ring,
        [string]$Arch
    )
    
    try {
        $logEntries += "  Fetching download links for ProductId: $ProductId"
        
        $url = "https://store.rg-adguard.net/api/GetFiles"
        $body = "type=ProductId&url=$ProductId&ring=$Ring&lang=en-US"
        
        $response = Invoke-WebRequest -Uri $url -Method Post -ContentType "application/x-www-form-urlencoded" -Body $body -UseBasicParsing -ErrorAction Stop
        
        # Parse links using the same method as reference script
        $rawLinks = $response.Links.outerHTML | Where-Object {
            $_ -notmatch 'BlockMap' -and 
            $_ -notmatch '\.eappx' -and 
            $_ -notmatch '\.emsix' -and 
            ($_ -match $Arch -or $_ -match '_neutral_')
        }
        
        $logEntries += "  Found $($rawLinks.Count) matching links"
        return $rawLinks
        
    } catch {
        $logEntries += "  ERROR fetching links: $($_.Exception.Message)"
        return @()
    }
}

# Function to download file
function Download-File {
    param (
        [string]$Url,
        [string]$OutputPath
    )
    
    try {
        $fileName = Split-Path $OutputPath -Leaf
        $logEntries += "  Downloading: $fileName"
        
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing -ErrorAction Stop
        
        if (Test-Path $OutputPath) {
            $fileSize = (Get-Item $OutputPath).Length / 1MB
            $logEntries += "  Downloaded: $([math]::Round($fileSize, 2)) MB"
            return $true
        }
        
        return $false
    } catch {
        $logEntries += "  Download failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to install AppX package
function Install-AppxPackageWithDeps {
    param (
        [string]$PackagePath,
        [array]$DependencyPaths
    )
    
    try {
        $logEntries += "  Installing: $(Split-Path $PackagePath -Leaf)"
        
        # Install dependencies first
        if ($DependencyPaths.Count -gt 0) {
            $logEntries += "  Installing $($DependencyPaths.Count) dependencies..."
            foreach ($depPath in $DependencyPaths) {
                try {
                    Add-AppxProvisionedPackage -Online -PackagePath $depPath -SkipLicense -ErrorAction SilentlyContinue | Out-Null
                } catch {
                    # Some dependencies may already exist, continue
                }
            }
        }
        
        # Install main package
        Add-AppxProvisionedPackage -Online -PackagePath $PackagePath -SkipLicense -ErrorAction Stop
        $logEntries += "  Installation successful"
        
        return $true
    } catch {
        $logEntries += "  Provisioned install failed: $($_.Exception.Message)"
        
        # Try alternative method
        try {
            $logEntries += "  Trying alternative installation..."
            Add-AppxPackage -Path $PackagePath -ErrorAction Stop
            $logEntries += "  Installation successful (alternative method)"
            return $true
        } catch {
            $logEntries += "  Alternative install failed: $($_.Exception.Message)"
            return $false
        }
    }
}

try {
    # Check if running as System or Admin
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Output "ERROR: Script must run with administrative privileges"
        exit 1
    }

    $logEntries += "=========================================="
    $logEntries += "Store App Update Remediation"
    $logEntries += "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $logEntries += "=========================================="
    $logEntries += "Architecture: $Arch"
    $logEntries += "Ring: $Ring"
    $logEntries += "Temp Folder: $TempFolder"
    
    # Create temp folder
    if (-not (Test-Path $TempFolder)) {
        New-Item -Path $TempFolder -ItemType Directory -Force | Out-Null
        $logEntries += "Created temp folder"
    }
    
    # Set security protocol
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # Process each app
    foreach ($appKey in $StoreApps.Keys) {
        $appInfo = $StoreApps[$appKey]
        $logEntries += ""
        $logEntries += "=========================================="
        $logEntries += "Processing: $appKey"
        $logEntries += "=========================================="
        $logEntries += "Product ID: $($appInfo.ProductId)"
        $logEntries += "Package: $($appInfo.PackageName)"
        
        try {
            # Check current version
            $installedApp = Get-AppxPackage -Name $appInfo.PackageName -AllUsers -ErrorAction SilentlyContinue
            $needsUpdate = $false
            
            if ($installedApp) {
                $installedVersion = $installedApp.Version
                $logEntries += "Installed Version: $installedVersion"
                
                # Get latest version from download links to compare
                $logEntries += "Checking for latest available version..."
            } else {
                $logEntries += "Status: Not installed - will install latest version"
                $needsUpdate = $true
            }
            
            # Get download links
            $logEntries += "Getting download links..."
            $rawLinks = Get-StoreDownloadLinks -ProductId $appInfo.ProductId -Ring $Ring -Arch $Arch
            
            if ($rawLinks.Count -eq 0) {
                $logEntries += "ERROR: No download links found"
                $remediationSuccess = $false
                continue
            }
            
            # Build file list with versions (same as reference script)
            $fileList = New-Object System.Collections.ArrayList
            
            foreach ($link in $rawLinks) {
                $packageName = $link.Split('>')[1].Split('<')[0]
                $family = $packageName.Split('_')[0]
                $version = $packageName.Split('_')[1]
                
                $null = $fileList.Add([PSCustomObject]@{
                    'Package' = $packageName
                    'Family' = $family
                    'Version' = [Version]$version
                    'Link' = $link
                })
            }
            
            # Separate dependencies and main packages
            $appsOnlyList = New-Object System.Collections.ArrayList
            $collectedDependencies = @{}
            
            foreach ($file in ($fileList | Sort-Object -Property Family, Version)) {
                $isDependency = $false
                
                # Check if this is a dependency
                foreach ($dep in $DependencyList) {
                    if ($file.Family -match $dep) {
                        $collectedDependencies[$dep] = $file
                        $isDependency = $true
                        break
                    }
                }
                
                # If not a dependency, add to apps list
                if (-not $isDependency) {
                    $null = $appsOnlyList.Add($file)
                }
            }
            
            # Get the latest version of the main app (group by major version, get latest)
            $latestPackage = $appsOnlyList | 
                Group-Object -Property { $_.Version.Major } | 
                ForEach-Object { $_.Group | Sort-Object Version -Descending | Select-Object -First 1 } |
                Sort-Object Version -Descending | 
                Select-Object -First 1
            
            if (-not $latestPackage) {
                $logEntries += "ERROR: Could not identify main package from available files"
                $remediationSuccess = $false
                continue
            }
            
            $latestVersion = $latestPackage.Version
            $logEntries += "Latest Available: $latestVersion"
            
            # Check if update is needed
            if ($installedApp) {
                $needsUpdate = Compare-AppVersion -InstalledVersion $installedVersion -RequiredVersion $latestVersion.ToString()
                
                if (-not $needsUpdate) {
                    $logEntries += "Status: Already at latest version (skipping)"
                    continue
                }
                
                $logEntries += "Status: Update available"
            }
            
            # Create app-specific folder
            $appFolder = Join-Path $TempFolder $appKey
            if (-not (Test-Path $appFolder)) {
                New-Item -Path $appFolder -ItemType Directory -Force | Out-Null
            }
            
            # Extract main package URL
            $mainPackageFilename = $latestPackage.Package
            $mainPackageUrl = ($latestPackage.Link).Split('"')[1]
            
            $logEntries += "Main Package: $mainPackageFilename"
            
            # Download main package
            $mainPackagePath = Join-Path $appFolder $mainPackageFilename
            $downloadSuccess = Download-File -Url $mainPackageUrl -OutputPath $mainPackagePath
            
            if (-not $downloadSuccess) {
                $logEntries += "ERROR: Failed to download main package"
                $remediationSuccess = $false
                continue
            }
            
            # Download dependencies
            $dependencyPaths = @()
            $logEntries += "Processing $($collectedDependencies.Count) dependency types..."
            
            foreach ($depKey in $collectedDependencies.Keys) {
                $depFile = $collectedDependencies[$depKey]
                $depFilename = $depFile.Package
                $depUrl = ($depFile.Link).Split('"')[1]
                $depPath = Join-Path $appFolder $depFilename
                
                if (Download-File -Url $depUrl -OutputPath $depPath) {
                    $dependencyPaths += $depPath
                }
            }
            
            $logEntries += "Downloaded $($dependencyPaths.Count) dependencies"
            
            # Install package
            $installSuccess = Install-AppxPackageWithDeps -PackagePath $mainPackagePath -DependencyPaths $dependencyPaths
            
            if ($installSuccess) {
                $logEntries += "SUCCESS: $appKey installed/updated"
            } else {
                $logEntries += "ERROR: Failed to install $appKey"
                $remediationSuccess = $false
            }
            
        } catch {
            $logEntries += "ERROR processing $appKey : $($_.Exception.Message)"
            $logEntries += $_.ScriptStackTrace
            $remediationSuccess = $false
        }
    }
    
    # Cleanup
    try {
        if (Test-Path $TempFolder) {
            Remove-Item $TempFolder -Recurse -Force -ErrorAction SilentlyContinue
            $logEntries += ""
            $logEntries += "Cleaned up temp files"
        }
    } catch {
        # Ignore cleanup errors
    }

    # Output log
    $logEntries | ForEach-Object { Write-Output $_ }
    
    # Final result
    Write-Output ""
    Write-Output "=========================================="
    if ($remediationSuccess) {
        Write-Output "RESULT: Remediation completed successfully"
        Write-Output "=========================================="
        exit 0
    } else {
        Write-Output "RESULT: Remediation completed with errors"
        Write-Output "=========================================="
        exit 1
    }
    
} catch {
    Write-Output "FATAL ERROR: $($_.Exception.Message)"
    Write-Output $_.ScriptStackTrace
    exit 1
}