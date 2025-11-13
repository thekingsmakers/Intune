#Requires -Version 5.1
<#
.SYNOPSIS
    Remediation script for Windows Store app updates - Intune Remediation (Optimized)
.DESCRIPTION
    Downloads and installs/updates Windows Store apps directly using PowerShell
    Optimized for Intune Remediation constraints
.NOTES
    Run as: System
    Exit 0: Remediation successful
    Exit 1: Remediation failed
.AUTHOR
    Created by: Omar Osman Mahat
    Aka: THEKINGSMAKERS
    Modified: Optimized for Intune
#>

# ============================================================================
# APP CONFIGURATION - Add your apps here
# ============================================================================
$StoreApps = @{
    Viewer3D = @{
        ProductId = "9NBLGGH42THS"
        PackageName = "Microsoft.Microsoft3DViewer"
    }
}

# ============================================================================
# CONFIGURATION
# ============================================================================
$TempFolder = "$env:TEMP\StoreAppUpdates"
$Ring = "Retail"
$Arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
$MaxOutputLines = 30  # Limit output to stay under Intune's 2048 char limit

# Dependency list for Store apps
$DependencyList = @(
    'Microsoft.VCLibs',
    'Microsoft.UI.Xaml',
    'Microsoft.NET.Native.Framework',
    'Microsoft.NET.Native.Runtime'
)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Output function that respects line limits
$script:outputCount = 0
function Write-Log {
    param([string]$Message)
    
    if ($script:outputCount -lt $MaxOutputLines) {
        Write-Output $Message
        $script:outputCount++
    }
}

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

# Function to get download links with retry logic
function Get-StoreDownloadLinks {
    param (
        [string]$ProductId,
        [string]$Ring,
        [string]$Arch,
        [int]$MaxRetries = 3
    )
    
    $retryCount = 0
    $success = $false
    
    while ($retryCount -lt $MaxRetries -and -not $success) {
        try {
            if ($retryCount -gt 0) {
                Write-Log "Retry $retryCount of $MaxRetries..."
                Start-Sleep -Seconds 2
            }
            
            $url = "https://store.rg-adguard.net/api/GetFiles"
            $body = "type=ProductId&url=$ProductId&ring=$Ring&lang=en-US"
            
            # Increase timeout for web requests
            $response = Invoke-WebRequest -Uri $url -Method Post `
                -ContentType "application/x-www-form-urlencoded" `
                -Body $body `
                -UseBasicParsing `
                -TimeoutSec 60 `
                -ErrorAction Stop
            
            $rawLinks = $response.Links.outerHTML | Where-Object {
                $_ -notmatch 'BlockMap' -and 
                $_ -notmatch '\.eappx' -and 
                $_ -notmatch '\.emsix' -and 
                ($_ -match $Arch -or $_ -match '_neutral_')
            }
            
            if ($rawLinks.Count -gt 0) {
                $success = $true
                return $rawLinks
            }
            
        } catch {
            Write-Log "API call failed: $($_.Exception.Message)"
        }
        
        $retryCount++
    }
    
    return @()
}

# Function to download file with retry
function Download-File {
    param (
        [string]$Url,
        [string]$OutputPath,
        [int]$MaxRetries = 3
    )
    
    $retryCount = 0
    
    while ($retryCount -lt $MaxRetries) {
        try {
            if ($retryCount -gt 0) {
                Start-Sleep -Seconds 2
            }
            
            # Use BITS transfer for better reliability
            Start-BitsTransfer -Source $Url -Destination $OutputPath -ErrorAction Stop
            
            if (Test-Path $OutputPath) {
                return $true
            }
            
        } catch {
            # Fallback to Invoke-WebRequest
            try {
                Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing -TimeoutSec 300 -ErrorAction Stop
                
                if (Test-Path $OutputPath) {
                    return $true
                }
            } catch {
                Write-Log "Download attempt $($retryCount + 1) failed"
            }
        }
        
        $retryCount++
    }
    
    return $false
}

# Function to install AppX package
function Install-AppxPackageWithDeps {
    param (
        [string]$PackagePath,
        [array]$DependencyPaths
    )
    
    try {
        # Install dependencies first
        if ($DependencyPaths.Count -gt 0) {
            foreach ($depPath in $DependencyPaths) {
                try {
                    Add-AppxProvisionedPackage -Online -PackagePath $depPath -SkipLicense -ErrorAction SilentlyContinue | Out-Null
                } catch {
                    # Dependencies may already exist
                }
            }
        }
        
        # Install main package
        Add-AppxProvisionedPackage -Online -PackagePath $PackagePath -SkipLicense -ErrorAction Stop | Out-Null
        return $true
        
    } catch {
        # Try alternative method
        try {
            Add-AppxPackage -Path $PackagePath -ErrorAction Stop
            return $true
        } catch {
            return $false
        }
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try {
    # Check admin privileges
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Output "ERROR: Requires admin privileges"
        exit 1
    }

    Write-Log "=== Store App Remediation Started ==="
    Write-Log "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Log "Arch: $Arch | Ring: $Ring"
    
    # Create temp folder
    if (-not (Test-Path $TempFolder)) {
        New-Item -Path $TempFolder -ItemType Directory -Force | Out-Null
    }
    
    # Set security protocol and ignore certificate errors (for SYSTEM context)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # Ignore certificate validation errors (common in SYSTEM context)
    if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
        Add-Type @"
using System;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public class ServerCertificateValidationCallback {
    public static void Ignore() {
        ServicePointManager.ServerCertificateValidationCallback = 
            delegate (
                Object obj, 
                X509Certificate certificate, 
                X509Chain chain, 
                SslPolicyErrors errors
            ) {
                return true;
            };
    }
}
"@
    }
    [ServerCertificateValidationCallback]::Ignore()
    
    $remediationSuccess = $true
    $processedApps = 0
    
    # Process each app
    foreach ($appKey in $StoreApps.Keys) {
        $appInfo = $StoreApps[$appKey]
        Write-Log ""
        Write-Log "--- Processing: $appKey ---"
        
        try {
            # Check current version (for logging only)
            $installedApp = Get-AppxPackage -Name $appInfo.PackageName -AllUsers -ErrorAction SilentlyContinue
            
            if ($installedApp) {
                Write-Log "Current version: v$($installedApp.Version)"
            } else {
                Write-Log "Status: Not installed"
            }
            
            # Get download links (always fetch latest)
            Write-Log "Fetching latest version..."
            $rawLinks = Get-StoreDownloadLinks -ProductId $appInfo.ProductId -Ring $Ring -Arch $Arch
            
            if ($rawLinks.Count -eq 0) {
                Write-Log "ERROR: No download links found"
                $remediationSuccess = $false
                continue
            }
            
            Write-Log "Found $($rawLinks.Count) packages"
            
            # Build file list
            $fileList = New-Object System.Collections.ArrayList
            
            foreach ($link in $rawLinks) {
                try {
                    $packageName = $link.Split('>')[1].Split('<')[0]
                    $parts = $packageName.Split('_')
                    
                    if ($parts.Count -lt 2) { continue }
                    
                    $family = $parts[0]
                    $version = $parts[1]
                    
                    # Validate version format
                    $versionObj = [Version]::new($version)
                    
                    $null = $fileList.Add([PSCustomObject]@{
                        'Package' = $packageName
                        'Family' = $family
                        'Version' = $versionObj
                        'Link' = $link
                    })
                } catch {
                    # Skip invalid packages
                    continue
                }
            }
            
            # Separate dependencies and main packages
            $appsOnlyList = New-Object System.Collections.ArrayList
            $collectedDependencies = @{}
            
            if ($fileList.Count -eq 0) {
                Write-Log "ERROR: No valid packages found"
                $remediationSuccess = $false
                continue
            }
            
            foreach ($file in ($fileList | Sort-Object -Property Family, Version)) {
                $isDependency = $false
                
                foreach ($dep in $DependencyList) {
                    if ($file.Family -match $dep) {
                        if (-not $collectedDependencies.ContainsKey($dep)) {
                            $collectedDependencies[$dep] = $file
                        }
                        $isDependency = $true
                        break
                    }
                }
                
                if (-not $isDependency) {
                    $null = $appsOnlyList.Add($file)
                }
            }
            
            # Get latest version
            if ($appsOnlyList.Count -eq 0) {
                Write-Log "ERROR: No main packages found (only dependencies)"
                $remediationSuccess = $false
                continue
            }
            
            $latestPackage = $appsOnlyList | 
                Group-Object -Property { $_.Version.Major } | 
                ForEach-Object { $_.Group | Sort-Object Version -Descending | Select-Object -First 1 } |
                Sort-Object Version -Descending | 
                Select-Object -First 1
            
            if (-not $latestPackage) {
                Write-Log "ERROR: Could not identify main package"
                $remediationSuccess = $false
                continue
            }
            
            $latestVersion = $latestPackage.Version
            Write-Log "Latest available: v$latestVersion"
            
            # Always proceed with installation (detection script handles the check)
            Write-Log "Proceeding with installation..."
            
            # Create app folder
            $appFolder = Join-Path $TempFolder $appKey
            if (-not (Test-Path $appFolder)) {
                New-Item -Path $appFolder -ItemType Directory -Force | Out-Null
            }
            
            # Download main package
            $mainPackageFilename = $latestPackage.Package
            $mainPackageUrl = ($latestPackage.Link).Split('"')[1]
            $mainPackagePath = Join-Path $appFolder $mainPackageFilename
            
            Write-Log "Downloading main package..."
            $downloadSuccess = Download-File -Url $mainPackageUrl -OutputPath $mainPackagePath
            
            if (-not $downloadSuccess) {
                Write-Log "ERROR: Download failed"
                $remediationSuccess = $false
                continue
            }
            
            # Download dependencies
            $dependencyPaths = @()
            
            if ($collectedDependencies.Count -gt 0) {
                Write-Log "Downloading $($collectedDependencies.Count) dependencies..."
                
                foreach ($depKey in $collectedDependencies.Keys) {
                    $depFile = $collectedDependencies[$depKey]
                    $depUrl = ($depFile.Link).Split('"')[1]
                    $depPath = Join-Path $appFolder $depFile.Package
                    
                    if (Download-File -Url $depUrl -OutputPath $depPath) {
                        $dependencyPaths += $depPath
                    }
                }
            }
            
            # Install package
            Write-Log "Installing..."
            $installSuccess = Install-AppxPackageWithDeps -PackagePath $mainPackagePath -DependencyPaths $dependencyPaths
            
            if ($installSuccess) {
                Write-Log "SUCCESS: $appKey updated"
                $processedApps++
            } else {
                Write-Log "ERROR: Installation failed"
                $remediationSuccess = $false
            }
            
        } catch {
            Write-Log "ERROR: $($_.Exception.Message)"
            $remediationSuccess = $false
        }
    }
    
    # Cleanup
    if (Test-Path $TempFolder) {
        Remove-Item $TempFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Final result
    Write-Log ""
    Write-Log "=== Remediation Complete ==="
    Write-Log "Apps processed: $processedApps"
    
    if ($remediationSuccess) {
        Write-Log "Result: SUCCESS"
        exit 0
    } else {
        Write-Log "Result: COMPLETED WITH ERRORS"
        exit 1
    }
    
} catch {
    Write-Output "FATAL: $($_.Exception.Message)"
    exit 1
}