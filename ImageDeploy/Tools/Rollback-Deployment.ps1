<#
.SYNOPSIS
    Rolls back changes made during deployment
.DESCRIPTION
    Reverts system changes, removes installed software, and restores previous configuration
.PARAMETER LogPath
    Path to the deployment log file to analyze for rollback
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "..\Deployment\Logs\Deployment.log",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$rollbackLog = "..\Deployment\Logs\Rollback-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$global:originalConfig = $null

function Write-RollbackLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $rollbackLog -Value $logMessage
    
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "INFO"  { "White" }
        "SUCCESS" { "Green" }
    }
    Write-Host $logMessage -ForegroundColor $color
}

function Backup-Configuration {
    Write-RollbackLog "Creating configuration backup..."
    try {
        $configPath = "..\Deployment\Config\deploy-config.xml"
        if (Test-Path $configPath) {
            $global:originalConfig = [xml](Get-Content $configPath)
            Write-RollbackLog "Configuration backup created" -Level "SUCCESS"
        }
    }
    catch {
        Write-RollbackLog "Failed to backup configuration: $_" -Level "ERROR"
    }
}

function Restore-Hostname {
    Write-RollbackLog "Checking hostname changes..."
    try {
        if ($global:originalConfig -and $global:originalConfig.Deployment.Hostname) {
            $originalHostname = $global:originalConfig.Deployment.OriginalHostname
            if ($originalHostname) {
                Write-RollbackLog "Restoring original hostname: $originalHostname"
                Rename-Computer -NewName $originalHostname -Force -ErrorAction Stop
                Write-RollbackLog "Hostname restored successfully" -Level "SUCCESS"
            }
        }
    }
    catch {
        Write-RollbackLog "Failed to restore hostname: $_" -Level "ERROR"
    }
}

function Remove-InstalledSoftware {
    Write-RollbackLog "Checking installed software..."
    try {
        if ($global:originalConfig -and $global:originalConfig.Deployment.Software.Package) {
            foreach ($package in $global:originalConfig.Deployment.Software.Package) {
                $packageName = $package.Name
                Write-RollbackLog "Attempting to uninstall: $packageName"
                
                # Get installation info from registry
                $uninstallKeys = @(
                    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
                    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
                )
                
                $installedApp = Get-ItemProperty $uninstallKeys | 
                    Where-Object { $_.DisplayName -like "*$packageName*" } |
                    Select-Object -First 1
                
                if ($installedApp) {
                    if ($installedApp.UninstallString) {
                        $uninstallCmd = $installedApp.UninstallString
                        if ($uninstallCmd -match "msiexec") {
                            $productCode = [regex]::Match($uninstallCmd, "{[0-9A-F-]+}").Value
                            Start-Process "msiexec.exe" -ArgumentList "/x $productCode /qn" -Wait -NoNewWindow
                        }
                        else {
                            # Try to add silent flags to non-MSI uninstallers
                            $silentFlags = " /S /silent /quiet"
                            Start-Process $uninstallCmd -ArgumentList $silentFlags -Wait -NoNewWindow
                        }
                        Write-RollbackLog "Successfully uninstalled $packageName" -Level "SUCCESS"
                    }
                }
                else {
                    Write-RollbackLog "Could not find uninstall information for $packageName" -Level "WARN"
                }
            }
        }
    }
    catch {
        Write-RollbackLog "Failed to remove software: $_" -Level "ERROR"
    }
}

function Remove-WindowsFeatures {
    Write-RollbackLog "Checking Windows features..."
    try {
        if ($global:originalConfig -and $global:originalConfig.Deployment.Features.Feature) {
            foreach ($feature in $global:originalConfig.Deployment.Features.Feature) {
                Write-RollbackLog "Attempting to remove feature: $feature"
                Disable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart
                Write-RollbackLog "Successfully removed feature: $feature" -Level "SUCCESS"
            }
        }
    }
    catch {
        Write-RollbackLog "Failed to remove Windows features: $_" -Level "ERROR"
    }
}

function Remove-DomainJoin {
    Write-RollbackLog "Checking domain membership..."
    try {
        $computerSystem = Get-WmiObject Win32_ComputerSystem
        if ($computerSystem.PartOfDomain) {
            Write-RollbackLog "Removing from domain..."
            $credential = Get-Credential -Message "Enter domain admin credentials to remove computer from domain"
            Remove-Computer -UnjoinDomainCredential $credential -Force -PassThru
            Write-RollbackLog "Successfully removed from domain" -Level "SUCCESS"
        }
    }
    catch {
        Write-RollbackLog "Failed to remove from domain: $_" -Level "ERROR"
    }
}

function Remove-WifiProfile {
    Write-RollbackLog "Checking WiFi profiles..."
    try {
        if ($global:originalConfig -and $global:originalConfig.Deployment.Network.SSID) {
            $ssid = $global:originalConfig.Deployment.Network.SSID
            Write-RollbackLog "Removing WiFi profile: $ssid"
            netsh wlan delete profile name="$ssid"
            Write-RollbackLog "Successfully removed WiFi profile" -Level "SUCCESS"
        }
    }
    catch {
        Write-RollbackLog "Failed to remove WiFi profile: $_" -Level "ERROR"
    }
}

# Main execution
try {
    Write-Host "Windows Deployment Rollback Tool" -ForegroundColor Red
    Write-Host "=============================" -ForegroundColor Red
    
    if (-not $Force) {
        Write-Host "`nWARNING: This will attempt to undo all deployment changes." -ForegroundColor Yellow
        Write-Host "This includes:" -ForegroundColor Yellow
        Write-Host " - Removing installed software" -ForegroundColor Yellow
        Write-Host " - Restoring original hostname" -ForegroundColor Yellow
        Write-Host " - Removing Windows features" -ForegroundColor Yellow
        Write-Host " - Removing from domain" -ForegroundColor Yellow
        Write-Host " - Removing WiFi profiles" -ForegroundColor Yellow
        
        $confirm = Read-Host "`nDo you want to continue? (y/N)"
        if ($confirm -ne "y") {
            Write-Host "Operation cancelled by user" -ForegroundColor Yellow
            exit
        }
    }
    
    Start-Transcript -Path $rollbackLog -Append
    
    # Start rollback process
    Backup-Configuration
    Restore-Hostname
    Remove-InstalledSoftware
    Remove-WindowsFeatures
    Remove-DomainJoin
    Remove-WifiProfile
    
    Write-RollbackLog "`nRollback completed. A system restart may be required." -Level "SUCCESS"
    Write-RollbackLog "Rollback log saved to: $rollbackLog" -Level "INFO"
    
    $restart = Read-Host "Do you want to restart the computer now? (y/N)"
    if ($restart -eq "y") {
        Restart-Computer -Force
    }
}
catch {
    Write-RollbackLog "Rollback failed: $_" -Level "ERROR"
    Write-RollbackLog "Manual intervention may be required" -Level "ERROR"
    exit 1
}
finally {
    Stop-Transcript
}