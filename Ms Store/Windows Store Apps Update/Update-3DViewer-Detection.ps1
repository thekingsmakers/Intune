#Requires -Version 5.1
<#
.SYNOPSIS
    Enhanced detection script for Windows Store app updates - Intune Remediation
.DESCRIPTION
    Checks if specified Windows Store apps need updates by comparing installed and latest versions.
    Only compares the LAST three version segments (e.g., 2506.10022.0), ignoring any leading prefix.
.NOTES
    Run as: System
    Exit 0: No updates needed (compliant)
    Exit 1: Updates available (non-compliant, triggers remediation)
	
.AUTHOR
	Created by Omar Osman Mahat
	Aka _ THEKINGSMAKERS
#>

# ============================================================================ 
# APP CONFIGURATION
# ============================================================================
$StoreApps = @{
    Viewer3D = @{
    ProductId = "9NBLGGH42THS"
    PackageName = "Microsoft.Microsoft3DViewer"
    MinimumVersion = "7.2003.11022.0"
}
}

# Configuration
$Ring = "Retail"  # Options: Retail, RP, WIS, WIF
$Arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }

# ============================================================================ 
# DETECTION LOGIC
# ============================================================================
$updatesNeeded = $false
$logEntries = @()

# Restore original working fetching logic
function Get-LatestStoreVersion {
    param (
        [string]$ProductId,
        [string]$Ring,
        [string]$Arch,
        [string]$PackageName
    )
    
    try {
        $url = "https://store.rg-adguard.net/api/GetFiles"
        $body = "type=ProductId&url=$ProductId&ring=$Ring&lang=en-US"
        
        $response = Invoke-WebRequest -Uri $url -Method Post -ContentType "application/x-www-form-urlencoded" -Body $body -UseBasicParsing -ErrorAction Stop
        
        # Parse links and extract versions (original working logic)
        $links = $response.Links | Where-Object {
            $_.outerHTML -notmatch 'BlockMap' -and 
            $_.outerHTML -notmatch '\.eappx' -and 
            $_.outerHTML -notmatch '\.emsix' -and 
            ($_.outerHTML -match $Arch -or $_.outerHTML -match '_neutral_')
        }
        
        $versions = @()
        foreach ($link in $links) {
            $fileName = $link.outerHTML
            if ($fileName -match '_(\d+\.\d+\.\d+\.\d+)_') {
                $versions += [version]$matches[1]
            }
        }
        
        if ($versions.Count -gt 0) {
            $latestVersion = ($versions | Sort-Object -Descending | Select-Object -First 1).ToString()
            return $latestVersion
        }
        
        return $null
        
    } catch {
        return $null
    }
}

# Normalize version to last three parts (ignores prefix)
function Normalize-Version {
    param([string]$VersionString)
    try {
        $parts = $VersionString -split '\.'
        if ($parts.Count -gt 3) {
            # Keep only the last 3 segments, e.g. 2506.10022.0
            ($parts[-3..-1] -join '.')
        } else {
            $VersionString
        }
    } catch {
        $VersionString
    }
}

# Compare versions using normalized last-3-part logic
function Compare-AppVersion {
    param (
        [string]$InstalledVersion,
        [string]$RequiredVersion
    )
    
    try {
        $installedNorm = Normalize-Version $InstalledVersion
        $requiredNorm  = Normalize-Version $RequiredVersion
        
        Write-Verbose "Comparing Installed: $installedNorm vs Latest: $requiredNorm"
        
        $installed = [version]$installedNorm
        $required  = [version]$requiredNorm
        
        return ($installed -lt $required)
    } catch {
        return $true
    }
}

try {
    $logEntries += "=========================================="
    $logEntries += "Store App Update Detection (Enhanced)"
    $logEntries += "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $logEntries += "=========================================="
    $logEntries += "Architecture: $Arch"
    $logEntries += "Ring: $Ring"
    $logEntries += "Checking $($StoreApps.Count) applications"
    
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    foreach ($appKey in $StoreApps.Keys) {
        $appInfo = $StoreApps[$appKey]
        $logEntries += ""
        $logEntries += "--- $appKey ---"
        $logEntries += "Product ID: $($appInfo.ProductId)"
        $logEntries += "Package: $($appInfo.PackageName)"
        
        $logEntries += "Fetching latest version from Store..."
        $latestVersion = Get-LatestStoreVersion -ProductId $appInfo.ProductId -Ring $Ring -Arch $Arch -PackageName $appInfo.PackageName
        
        if (-not $latestVersion) {
            $logEntries += "WARNING: Could not retrieve latest version"
            $logEntries += "Status: UPDATE REQUIRED (will check during remediation)"
            $updatesNeeded = $true
            continue
        }
        
        $installedApp = Get-AppxPackage -Name $appInfo.PackageName -AllUsers -ErrorAction SilentlyContinue
        if ($installedApp) {
            $installedVersion = $installedApp.Version
            $logEntries += "Latest Available: $latestVersion"
            $logEntries += "Installed: $installedVersion"
            
            $needsUpdate = Compare-AppVersion -InstalledVersion $installedVersion -RequiredVersion $latestVersion
            if ($needsUpdate) {
                $logEntries += "Status: UPDATE REQUIRED"
                $updatesNeeded = $true
            } else {
                $logEntries += "Status: COMPLIANT (Up to date)"
            }
        } else {
            $logEntries += "Status: NOT INSTALLED"
            $updatesNeeded = $true
        }
    }

    $logEntries | ForEach-Object { Write-Output $_ }
    Write-Output ""
    Write-Output "=========================================="
    if ($updatesNeeded) {
        Write-Output "RESULT: Non-Compliant - Triggering remediation"
        Write-Output "=========================================="
        exit 1
    } else {
        Write-Output "RESULT: Compliant - All apps up to date"
        Write-Output "=========================================="
        exit 0
    }

} catch {
    Write-Output "FATAL ERROR: $($_.Exception.Message)"
    Write-Output $_.ScriptStackTrace
    exit 1
}
