<#
.SYNOPSIS
    Windows Post-Install Deployment Script
.DESCRIPTION
    Automates configuration after Windows installation including:
    - Software installation
    - Hostname configuration
    - WiFi setup
    - Windows activation
    - Feature installation
    - Domain joining
.NOTES
    Version: 1.0
    Author: IT Deployment Team
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ConfigPath = "$PSScriptRoot\..\Config\deploy-config.xml",
    
    [Parameter()]
    [switch]$SkipPreReqCheck,
    
    [Parameter()]
    [switch]$Force
)

#region Initialization
function Write-ProgressBar {
    param(
        [int]$PercentComplete,
        [string]$Status,
        [string]$Activity = "Deployment Progress"
    )
    
    $width = $Host.UI.RawUI.WindowSize.Width - 20
    $complete = [math]::Round(($width * $PercentComplete) / 100)
    $remaining = $width - $complete
    
    $progressBar = "[" + ("=" * $complete) + (" " * $remaining) + "]"
    $percent = "{0,3:D}%" -f $PercentComplete
    $message = "`r${Activity}: ${progressBar} ${percent} ${Status}"
    
    Write-Host $message -NoNewline
    if ($PercentComplete -eq 100) {
        Write-Host ""
    }
}

function Write-StepProgress {
    param(
        [int]$CurrentStep,
        [int]$TotalSteps,
        [string]$StepName,
        [string]$Activity = "Deployment Progress"
    )
    
    $percent = [math]::Round(($CurrentStep / $TotalSteps) * 100)
    $stepInfo = "Step ${CurrentStep}/${TotalSteps}: ${StepName}"
    Write-ProgressBar -PercentComplete $percent -Status $stepInfo -Activity $Activity
}

# Define deployment steps
$Script:DeploymentSteps = @(
    "Initialize Environment",
    "Install Software",
    "Configure Network",
    "Set System Properties",
    "Install Windows Features",
    "Activate Windows",
    "Join Domain",
    "Verify Configuration"
)
$Script:TotalSteps = $DeploymentSteps.Count
$Script:CurrentStep = 0

function Update-DeploymentProgress {
    param([string]$StepName)
    $Script:CurrentStep++
    Write-StepProgress -CurrentStep $CurrentStep -TotalSteps $TotalSteps -StepName $StepName
}

function Test-Prerequisites {
    $prerequisites = @(
        @{
            Name = ".NET Runtime"
            Test = { Get-Command dotnet -ErrorAction SilentlyContinue }
            Message = "Install .NET Runtime 6.0 or later"
        },
        @{
            Name = "PowerShell Version"
            Test = { $PSVersionTable.PSVersion.Major -ge 5 }
            Message = "PowerShell 5.0 or later is required"
        },
        @{
            Name = "Administrator Rights"
            Test = { ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
            Message = "Run this script as Administrator"
        },
        @{
            Name = "Disk Space"
            Test = { (Get-PSDrive C).Free -gt 10GB }
            Message = "At least 10GB of free disk space is required"
        },
        @{
            Name = "Internet Connectivity"
            Test = { Test-NetConnection -ComputerName "www.microsoft.com" -Port 80 -WarningAction SilentlyContinue }
            Message = "Internet connection is required"
        }
    )
    
    $failed = @()
    foreach ($prereq in $prerequisites) {
        Write-DeploymentLog "Checking $($prereq.Name)..." -Level "INFO"
        if (-not (& $prereq.Test)) {
            $failed += "$($prereq.Name): $($prereq.Message)"
        }
    }
    
    return $failed
}

# Start initialization
Write-Host "Windows Deployment Tool v1.0.0" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Cyan

# Run prerequisite checks
if (-not $SkipPreReqCheck) {
    $failed = Test-Prerequisites
    if ($failed.Count -gt 0) {
        Write-Host "`nPrerequisite check failed:" -ForegroundColor Red
        $failed | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
        
        if (-not $Force) {
            Write-Host "`nUse -Force to continue anyway, or -SkipPreReqCheck to skip these checks" -ForegroundColor Yellow
            exit 1
        }
        else {
            Write-Host "`nContinuing despite failed prerequisites (-Force specified)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "All prerequisites satisfied" -ForegroundColor Green
    }
}

# Import and initialize deployment tools module
$modulePath = Join-Path $PSScriptRoot "..\..\Tools\DeploymentTools.psm1"
if (-not (Test-Path $modulePath)) {
    Write-Error "DeploymentTools module not found at: $modulePath"
    exit 1
}

try {
    Import-Module $modulePath -Force -ErrorAction Stop
    Write-Host "Deployment tools module loaded successfully" -ForegroundColor Green
    
    # Initialize logging and configuration
    Initialize-DeploymentTools -LogDirectory "$PSScriptRoot\..\Logs" -ConfigFile $ConfigPath
    Write-Host "Deployment tools initialized" -ForegroundColor Green
}
catch {
    Write-Error "Failed to initialize deployment tools: $_"
    exit 1
}

# Import deployment tools module
$modulePath = Join-Path $PSScriptRoot "..\..\Tools\DeploymentTools.psm1"
if (-not (Test-Path $modulePath)) {
    Write-Error "DeploymentTools module not found at: $modulePath"
    exit 1
}
Import-Module $modulePath -Force

# Initialize deployment tools
Initialize-DeploymentTools -LogDirectory "$PSScriptRoot\..\Logs" -ConfigFile $ConfigPath

# Backup current system state
$backupItems = @(
    "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName",
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
)
$backupPath = Backup-SystemState -BackupPath "$PSScriptRoot\..\Backups" -Items $backupItems
if (-not $backupPath) {
    Write-DeploymentLog "Failed to create system backup" -Level "ERROR"
    exit 1
}

# Validate running as Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Exit-WithError "This script must be run as Administrator"
}

# Create required directories
$directories = @(
    "$PSScriptRoot\..\Logs",
    "$PSScriptRoot\..\Installers",
    "$PSScriptRoot\..\Backups"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        try {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-DeploymentLog "Created directory: $dir" -Level "SUCCESS"
        }
        catch {
            Write-DeploymentLog "Failed to create directory $dir : $_" -Level "ERROR"
            exit 1
        }
    }
}

# Load and validate configuration
$Config = Get-DeploymentConfig
if (-not $Config) {
    Write-DeploymentLog "Failed to load configuration file" -Level "ERROR"
    exit 1
}

Write-DeploymentLog "Configuration loaded successfully" -Level "SUCCESS"
#endregion

#region Software Installation
if ($Config.Deployment.Software -and $Config.Deployment.Software.Package) {
    Write-DeploymentLog "=== Installing Software Packages ===" -Level "INFO"
    $totalPackages = $Config.Deployment.Software.Package.Count
    $currentPackage = 0
    
    foreach ($package in $Config.Deployment.Software.Package) {
        $currentPackage++
        $installerPath = "$PSScriptRoot\..\Installers\$($package.Name)"
        
        if (-not (Test-Path $installerPath)) {
            Write-DeploymentLog "Installer not found: $($package.Name)" -Level "WARNING"
            continue
        }
        
        Write-DeploymentLog "[$currentPackage/$totalPackages] Installing $($package.Name)..." -Level "INFO"
        
        Invoke-WithRetry -Operation "Install $($package.Name)" -MaxAttempts 3 -DelaySeconds 30 -ScriptBlock {
            $installArgs = @{
                FilePath = $installerPath
                Wait = $true
                NoNewWindow = $true
                PassThru = $true
            }
            
            if ($package.Arguments) {
                $installArgs['ArgumentList'] = $package.Arguments
            }
            
            try {
                $process = Start-Process @installArgs
                
                if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) { # 3010 = restart required
                    Write-DeploymentLog "$($package.Name) installed successfully (Exit code: $($process.ExitCode))" -Level "SUCCESS"
                }
                else {
                    throw "Installation failed with exit code: $($process.ExitCode)"
                }
            }
            catch {
                Write-DeploymentLog "Installation attempt failed: $_" -Level "WARNING"
                throw
            }
            $exitCode = $process.ExitCode
            
            if ($exitCode -eq 0 -or $exitCode -eq 3010) { # 3010 = success, restart required
                Write-Log "Successfully installed $($package.Name) (Exit code: $exitCode)"
            } else {
                Write-Log "Warning: $($package.Name) installation completed with non-zero exit code $exitCode" -Level "WARNING"
            }
        } catch {
            Write-Log "Error installing $($package.Name): $_" -Level "ERROR"
            # Continue with next package instead of failing entire deployment
        }
    }
}
#endregion

#region System Configuration
Update-DeploymentProgress -StepName "Set System Properties"
Write-DeploymentLog "=== Configuring System ===" -Level "INFO"

# Set Hostname
if ($Config.Deployment.Hostname) {
    $newName = $Config.Deployment.Hostname
    Write-DeploymentLog "Setting hostname to $newName..." -Level "INFO"
    
    # Backup current computer name
    Backup-SystemState -BackupPath "$PSScriptRoot\..\Backups" -Items @(
        "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName"
    )
    
    Invoke-WithRetry -Operation "Hostname Change" -MaxAttempts 2 -DelaySeconds 10 -ScriptBlock {
        try {
            Rename-Computer -NewName $newName -Force -ErrorAction Stop
            Write-DeploymentLog "Hostname set successfully to $newName" -Level "SUCCESS"
        }
        catch {
            Write-DeploymentLog "Failed to set hostname: $_" -Level "ERROR"
            throw
        }
    }
}

# Configure WiFi
if ($Config.Deployment.Network -and $Config.Deployment.Network.SSID) {
    $ssid = $Config.Deployment.Network.SSID
    Write-DeploymentLog "Configuring WiFi network: $ssid" -Level "INFO"
    
    # Backup current network configuration
    Backup-SystemState -BackupPath "$PSScriptRoot\..\Backups" -Items @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList"
    )
    
    # Check if wireless adapter is available
    $adapter = Get-NetAdapter | Where-Object { $_.PhysicalMediaType -eq 'Native 802.11' -and $_.Status -eq 'Up' }
    if (-not $adapter) {
        Write-DeploymentLog "No wireless adapter found or enabled" -Level "ERROR"
    }
    else {
        Write-DeploymentLog "Found wireless adapter: $($adapter.Name)" -Level "INFO"
        
        # Create and configure WiFi profile
        Invoke-WithRetry -Operation "WiFi Configuration" -MaxAttempts 3 -DelaySeconds 15 -ScriptBlock {
            try {
                $password = $Config.Deployment.Network.Password
                $profilePath = "$env:TEMP\$ssid.xml"
                
                $profileXml = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$ssid</name>
    <SSIDConfig>
        <SSID>
            <name>$ssid</name>
        </SSID>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>$password</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@
                # Save and import profile
                $profileXml | Out-File -FilePath $profilePath -Encoding ASCII
                Write-DeploymentLog "Adding WiFi profile for $ssid" -Level "INFO"
                netsh wlan add profile filename="$profilePath" user=all
                Remove-Item $profilePath -Force
                
                # Connect to network
                Write-DeploymentLog "Connecting to $ssid..." -Level "INFO"
                netsh wlan connect name=$ssid
                
                # Verify connection
                if (Wait-ForCondition -TimeoutSeconds 60 -DelaySeconds 5 -Message "WiFi connection" -Condition {
                    $currentNetwork = netsh wlan show interfaces |
                        Select-String "SSID\s+:\s(.+)$" |
                        ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
                    return $currentNetwork -eq $ssid
                }) {
                    Write-DeploymentLog "Successfully connected to $ssid" -Level "SUCCESS"
                    
                    # Test internet connectivity
                    if (Test-NetConnection -ComputerName "www.microsoft.com" -Port 80 -WarningAction SilentlyContinue) {
                        Write-DeploymentLog "Internet connectivity verified" -Level "SUCCESS"
                    }
                    else {
                        Write-DeploymentLog "Connected to WiFi but no internet access" -Level "WARNING"
                    }
                }
                else {
                    throw "Failed to connect to WiFi network"
                }
            }
            catch {
                Write-DeploymentLog "WiFi configuration attempt failed: $_" -Level "WARNING"
                throw
            }
        }
    }
}
#endregion

#region Windows Activation
if ($Config.Deployment.WindowsActivation -and $Config.Deployment.WindowsActivation.ProductKey) {
    $productKey = $Config.Deployment.WindowsActivation.ProductKey
    Write-DeploymentLog "=== Activating Windows ===" -Level "INFO"
    
    # Backup current activation status
    Backup-SystemState -BackupPath "$PSScriptRoot\..\Backups" -Items @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform"
    )
    
    Invoke-WithRetry -Operation "Windows Activation" -MaxAttempts 3 -DelaySeconds 30 -ScriptBlock {
        try {
            # Install product key
            Write-DeploymentLog "Installing product key..." -Level "INFO"
            $result = & cscript //NoLogo //B $env:windir\system32\slmgr.vbs /ipk $productKey 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to install product key: $result"
            }
            
            # Activate Windows
            Write-DeploymentLog "Activating Windows..." -Level "INFO"
            $result = & cscript //NoLogo //B $env:windir\system32\slmgr.vbs /ato 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Activation failed: $result"
            }
            
            # Verify activation
            $status = & cscript //NoLogo //B $env:windir\system32\slmgr.vbs /xpr 2>&1
            if ($status -match "permanently activated|volume activation expiration") {
                Write-DeploymentLog "Windows successfully activated" -Level "SUCCESS"
            }
            else {
                throw "Activation status verification failed: $status"
            }
        }
        catch {
            Write-DeploymentLog "Activation attempt failed: $_" -Level "WARNING"
            throw
        }
    }
}
#endregion

# Error handling and cleanup
$ErrorActionPreference = "Continue"

try {
    # Get final deployment status
    $stats = Get-DeploymentStatistics
    $duration = $stats.EndTime - $stats.StartTime
    $needsRestart = $false
    
    # Check for pending operations
    $pendingOperations = @(
        @{ Name = "Windows Update"; Key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" },
        @{ Name = "Component Servicing"; Key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" },
        @{ Name = "File Rename"; Key = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations" }
    )
    
    foreach ($op in $pendingOperations) {
        if (Test-Path $op.Key) {
            Write-DeploymentLog "Pending operation detected: $($op.Name)" -Level "WARNING"
            $needsRestart = $true
        }
    }
    
    # Generate deployment report
    $reportPath = "$PSScriptRoot\..\Logs\DeploymentReport-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
    
    $reportContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Deployment Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #2c3e50; }
        .summary { margin: 20px 0; padding: 10px; background-color: #f8f9fa; }
        .pass { color: green; }
        .fail { color: red; }
        .warn { color: orange; }
    </style>
</head>
<body>
    <h1>Windows Deployment Report</h1>
    <div class="summary">
        <h2>Summary</h2>
        <p>Duration: $([math]::Round($duration.TotalMinutes, 1)) minutes</p>
        <p>Errors: <span class="$(if ($stats.Errors -gt 0) { 'fail' } else { 'pass' })">$($stats.Errors)</span></p>
        <p>Warnings: <span class="$(if ($stats.Warnings -gt 0) { 'warn' } else { 'pass' })">$($stats.Warnings)</span></p>
        <p>Restart Required: <span class="warn">$($needsRestart)</span></p>
    </div>
</body>
</html>
"@
    
    $reportContent | Out-File -FilePath $reportPath -Encoding utf8
    Write-DeploymentLog "Deployment report saved to: $reportPath" -Level "SUCCESS"
    
    # Handle restart if needed
    if ($Config.Deployment.RestartAfter -eq "true" -and ($needsRestart -or $stats.Errors -eq 0)) {
        if ($stats.Errors -gt 0) {
            Write-DeploymentLog "Skipping restart due to deployment errors" -Level "WARNING"
        }
        elseif ($needsRestart) {
            Write-DeploymentLog "System restart required - restarting in 30 seconds..." -Level "WARNING"
            Start-Sleep -Seconds 30
            Restart-Computer -Force
        }
    }
    else {
        Write-DeploymentLog "Deployment completed $(if ($stats.Errors -gt 0) { 'with errors' } else { 'successfully' })" `
            -Level $(if ($stats.Errors -gt 0) { "ERROR" } else { "SUCCESS" })
        
        if ($needsRestart) {
            Write-DeploymentLog "NOTE: System restart recommended" -Level "WARNING"
        }
    }
}
catch {
    Write-DeploymentLog "Fatal error during deployment finalization: $_" -Level "ERROR"
    exit 1
}
finally {
    # Clean up sensitive data
    if (-not $Config.Deployment.Debug) {
        & "$PSScriptRoot\..\..\Tools\Clear-SensitiveData.ps1" -KeepLogs
    }
}

#region Windows Features
Update-DeploymentProgress -StepName "Install Windows Features"

if ($Config.Deployment.Features -and $Config.Deployment.Features.Feature) {
    Write-DeploymentLog "=== Installing Windows Features ===" -Level "INFO"
    $totalFeatures = $Config.Deployment.Features.Feature.Count
    $currentFeature = 0
    
    # Backup Windows features state
    Backup-SystemState -BackupPath "$PSScriptRoot\..\Backups" -Items @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing"
    )
    
    foreach ($feature in $Config.Deployment.Features.Feature) {
        $currentFeature++
        Write-DeploymentLog "[$currentFeature/$totalFeatures] Processing feature: $feature" -Level "INFO"
        
        # Check if feature is already enabled
        $state = Get-WindowsOptionalFeature -Online -FeatureName $feature
        if ($state.State -eq "Enabled") {
            Write-DeploymentLog "Feature $feature is already enabled" -Level "INFO"
            continue
        }
        
        Invoke-WithRetry -Operation "Enable Feature $feature" -MaxAttempts 2 -DelaySeconds 15 -ScriptBlock {
            try {
                Write-DeploymentLog "Enabling feature: $feature" -Level "INFO"
                $result = Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -All
                
                if ($result.RestartNeeded) {
                    Write-DeploymentLog "Feature $feature enabled - restart required" -Level "WARNING"
                }
                else {
                    Write-DeploymentLog "Feature $feature enabled successfully" -Level "SUCCESS"
                }
            }
            catch {
                Write-DeploymentLog "Failed to enable feature: $_" -Level "ERROR"
                throw
            }
        }
    }
    
    # Check final state of all features
    $failed = @()
    foreach ($feature in $Config.Deployment.Features.Feature) {
        $state = Get-WindowsOptionalFeature -Online -FeatureName $feature
        if ($state.State -ne "Enabled") {
            $failed += $feature
        }
    }
    
    if ($failed.Count -gt 0) {
        Write-DeploymentLog "Some features failed to enable: $($failed -join ', ')" -Level "ERROR"
    }
    else {
        Write-DeploymentLog "All features enabled successfully" -Level "SUCCESS"
    }
}
#endregion

#region Domain Join
if ($Config.Deployment.Domain -and $Config.Deployment.Domain.JoinDomain -eq "true") {
    try {
        $domain = $Config.Deployment.Domain.DomainName
        $username = $Config.Deployment.Domain.DomainUser
        $password = ConvertTo-SecureString $Config.Deployment.Domain.DomainPassword -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($username, $password)
        
        Write-Host "Joining domain $domain"
        Add-Computer -DomainName $domain -Credential $credential -Force
    } catch {
        Exit-WithError "Failed to join domain: $_"
    }
}
#endregion

#region Completion
# Get deployment statistics
$stats = Get-DeploymentStatistics
$duration = $stats.EndTime - $stats.StartTime

Write-DeploymentLog "`n=== Deployment Summary ===" -Level "INFO"
Write-DeploymentLog "Duration: $([math]::Round($duration.TotalMinutes, 1)) minutes" -Level "INFO"
Write-DeploymentLog "Error Count: $($stats.Errors)" -Level $(if ($stats.Errors -gt 0) { "ERROR" } else { "SUCCESS" })
Write-DeploymentLog "Warning Count: $($stats.Warnings)" -Level $(if ($stats.Warnings -gt 0) { "WARNING" } else { "INFO" })
Write-DeploymentLog "Log File: $($stats.LogFile)" -Level "INFO"

# Run post-deployment tests if no errors occurred
if ($stats.Errors -eq 0) {
    Write-DeploymentLog "`nRunning post-deployment validation..." -Level "INFO"
    & "$PSScriptRoot\..\..\Tools\Test-PostDeployment.ps1" -GenerateReport
}

if ($Config.Deployment.RestartAfter -eq "true") {
    if ($stats.Errors -gt 0) {
        Write-DeploymentLog "Skipping restart due to deployment errors" -Level "WARNING"
    }
    else {
        Write-DeploymentLog "Restarting computer in 30 seconds..." -Level "WARNING"
        Write-DeploymentLog "Deployment completed successfully" -Level "SUCCESS"
        Start-Sleep -Seconds 30
        Restart-Computer -Force
    }
}
else {
    Write-DeploymentLog "Deployment completed $(if ($stats.Errors -gt 0) { 'with errors' } else { 'successfully' })" `
        -Level $(if ($stats.Errors -gt 0) { "ERROR" } else { "SUCCESS" })
}
#endregion