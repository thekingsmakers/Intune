<#
.SYNOPSIS
    Fully automated Hybrid Azure AD Join fix with enhanced diagnostics.
.DESCRIPTION
    Checks AzureAdJoined, DomainJoined, and DeviceAuthStatus.
    If device is not properly joined, performs remediation steps automatically.
    Only schedules restart if remediation was needed.
    Includes detailed diagnostics export and pre-flight checks.
.NOTES
    Designed for EXE deployment. Must run elevated.
    Version: 1.0 - Enhanced & Fully Automated
#>

#Requires -RunAsAdministrator

# --- Display Banner ---
Write-Host "=============================================="
Write-Host "     TKMs Fix Azure Hybrid Join Issue         "
Write-Host "               Version 4.0                    "
Write-Host "==============================================`n"

# --- Paths ---
$logFolder = "C:\Windows\Temp\HybridAAD"
$flagPath = "$logFolder\HybridAADJoin-Fix-Complete.log"
$diagnosticPath = "$logFolder\Diagnostic-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"

# Create log folder if it doesn't exist
if (-not (Test-Path -Path $logFolder)) {
    New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
}

# --- Logging Function ---
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] - $Message"
    
    try {
        $logEntry | Out-File -FilePath $flagPath -Append -ErrorAction SilentlyContinue
    } catch {
        # Silently continue if logging fails
    }
    
    switch ($Level) {
        "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        default   { Write-Host $logEntry }
    }
}

# --- Auto Elevate ---
$currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "Re-launching script with elevated privileges..." -ForegroundColor Yellow
    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    } catch {
        Write-Host "Failed to elevate. Please run as Administrator." -ForegroundColor Red
        Start-Sleep -Seconds 5
    }
    exit
}

# --- Export Diagnostic Info ---
function Export-DiagnosticInfo {
    Write-Log "Exporting diagnostic information..."
    
    $dsregOutput = & dsregcmd /status 2>&1 | Out-String
    
    $scheduledTask = try {
        Get-ScheduledTask -TaskName "Automatic-Device-Join" -TaskPath "\Microsoft\Windows\Workplace Join\" -ErrorAction Stop | 
        Select-Object TaskName, State, LastRunTime, LastTaskResult | Out-String
    } catch {
        "Task not found or inaccessible"
    }
    
    $aadService = try {
        Get-Service -Name "AADConnectProvisioningAgent" -ErrorAction Stop | Out-String
    } catch {
        "Service not found"
    }
    
    $certificates = try {
        Get-ChildItem -Path Cert:\LocalMachine\My -ErrorAction Stop | 
        Where-Object {$_.Subject -like "*MS-Organization-Access*"} | 
        Select-Object Subject, Thumbprint, NotAfter | Out-String
    } catch {
        "No certificates found"
    }
    
    $rebootPending = @(
        Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
        Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    )
    
    $diagnostic = @"
===  Hybrid Azure AD Join Diagnostic Report ===
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer: $env:COMPUTERNAME
User: $env:USERNAME
Domain: $env:USERDNSDOMAIN

=== DSREGCMD STATUS ===
$dsregOutput

=== SCHEDULED TASK STATUS ===
$scheduledTask

=== AZURE AD CONNECT HEALTH ===
$aadService

=== CERTIFICATE CHECK ===
$certificates

=== PENDING RESTART CHECK ===
CBS RebootPending: $($rebootPending[0])
WindowsUpdate RebootRequired: $($rebootPending[1])

=== SYSTEM INFO ===
OS: $([System.Environment]::OSVersion.VersionString)
PowerShell: $($PSVersionTable.PSVersion)

"@
    
    try {
        $diagnostic | Out-File -FilePath $diagnosticPath -ErrorAction Stop
        Write-Log "Diagnostic report saved to: $diagnosticPath" -Level "SUCCESS"
    } catch {
        Write-Log "Failed to save diagnostic report: $_" -Level "WARNING"
    }
}

# --- Check Hybrid Join Status ---
function Test-HybridJoinStatus {
    try {
        $status = & dsregcmd /status 2>&1 | Out-String
        
        $aadJoined = $status -match "AzureAdJoined\s*:\s*YES"
        $domainJoined = $status -match "DomainJoined\s*:\s*YES"
        $deviceAuth = $status -match "DeviceAuthStatus\s*:\s*SUCCESS"
        
        Write-Log "Status Check - AzureAdJoined: $aadJoined | DomainJoined: $domainJoined | DeviceAuth: $deviceAuth"
        
        return ($aadJoined -and $domainJoined -and $deviceAuth)
    } catch {
        Write-Log "Failed to check join status: $_" -Level "ERROR"
        return $false
    }
}

# --- Pre-flight Checks ---
function Test-Prerequisites {
    Write-Log "Running pre-flight checks..."
    
    # Check if domain joined
    try {
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        if ($computerSystem.PartOfDomain -eq $false) {
            Write-Log "Device is not domain joined. Cannot perform Hybrid Azure AD Join." -Level "ERROR"
            return $false
        }
        Write-Log "Domain joined: $($computerSystem.Domain)" -Level "SUCCESS"
    } catch {
        Write-Log "Failed to check domain join status: $_" -Level "ERROR"
        return $false
    }
    
    # Check if dsregcmd exists
    if (-not (Get-Command dsregcmd.exe -ErrorAction SilentlyContinue)) {
        Write-Log "dsregcmd.exe not found. This tool requires Windows 10/11 or Server 2016+." -Level "ERROR"
        return $false
    }
    
    Write-Log "Pre-flight checks passed." -Level "SUCCESS"
    return $true
}

# --- Main Execution ---
try {
    Write-Log "=== Starting Hybrid Azure AD Join Check ===" -Level "INFO"
    
    # Export diagnostics first
    Export-DiagnosticInfo
    
    # Run pre-flight checks
    if (-not (Test-Prerequisites)) {
        Write-Log "Pre-flight checks failed. Exiting." -Level "ERROR"
        Write-Host "`nCritical checks failed. Please review the log." -ForegroundColor Red
        Start-Sleep -Seconds 10
        exit 1
    }
    
    # Check current status
    if (Test-HybridJoinStatus) {
        Write-Log "Device is already Hybrid Azure AD joined and healthy." -Level "SUCCESS"
        Write-Host "`nYour device is properly configured. No action required." -ForegroundColor Green
        Start-Sleep -Seconds 5
        exit 0
    }
    
    # Device needs remediation
    Write-Log "Device is NOT properly joined. Starting remediation..." -Level "WARNING"
    
    # Step 1: Leave Azure AD
    Write-Log "Step 1/4: Unregistering device from Azure AD..."
    try {
        $leaveResult = Start-Process -FilePath "dsregcmd.exe" -ArgumentList "/leave" -NoNewWindow -Wait -PassThru
        if ($leaveResult.ExitCode -eq 0) {
            Write-Log "Step 1/4 completed." -Level "SUCCESS"
        } else {
            Write-Log "Step 1/4 completed with exit code: $($leaveResult.ExitCode)" -Level "WARNING"
        }
    } catch {
        Write-Log "Step 1/4 failed: $_" -Level "ERROR"
    }
    Start-Sleep -Seconds 3
    
    # Step 2: Cleanup cached accounts
    Write-Log "Step 2/4: Cleaning cached accounts..."
    try {
        $cleanupResult = Start-Process -FilePath "dsregcmd.exe" -ArgumentList "/cleanupaccounts" -NoNewWindow -Wait -PassThru
        if ($cleanupResult.ExitCode -eq 0) {
            Write-Log "Step 2/4 completed." -Level "SUCCESS"
        } else {
            Write-Log "Step 2/4 completed with exit code: $($cleanupResult.ExitCode)" -Level "WARNING"
        }
    } catch {
        Write-Log "Step 2/4 failed: $_" -Level "ERROR"
    }
    Start-Sleep -Seconds 3
    
    # Step 3: Enable scheduled task
    Write-Log "Step 3/4: Enabling Automatic-Device-Join scheduled task..."
    try {
        $taskResult = Start-Process -FilePath "schtasks.exe" -ArgumentList '/Change /TN "Microsoft\Windows\Workplace Join\Automatic-Device-Join" /Enable' -NoNewWindow -Wait -PassThru
        if ($taskResult.ExitCode -eq 0) {
            Write-Log "Step 3/4 completed." -Level "SUCCESS"
        } else {
            Write-Log "Step 3/4 completed with exit code: $($taskResult.ExitCode)" -Level "WARNING"
        }
    } catch {
        Write-Log "Step 3/4 failed: $_" -Level "ERROR"
    }
    Start-Sleep -Seconds 2
    
    # Step 4: Run scheduled task
    Write-Log "Step 4/4: Running Automatic-Device-Join scheduled task..."
    try {
        $runResult = Start-Process -FilePath "schtasks.exe" -ArgumentList '/Run /TN "Microsoft\Windows\Workplace Join\Automatic-Device-Join"' -NoNewWindow -Wait -PassThru
        if ($runResult.ExitCode -eq 0) {
            Write-Log "Step 4/4 completed." -Level "SUCCESS"
        } else {
            Write-Log "Step 4/4 completed with exit code: $($runResult.ExitCode)" -Level "WARNING"
        }
    } catch {
        Write-Log "Step 4/4 failed: $_" -Level "ERROR"
    }
    Start-Sleep -Seconds 5
    
 #Schedule restart
    Write-Log "Scheduling automatic restart in 30 minutes..."
    try {
        Start-Process -FilePath "shutdown.exe" -ArgumentList "/r /t 1800 /c `" Hybrid Azure AD Join Fix - Restart in 30 mins. Save your work!`"" -NoNewWindow -ErrorAction Stop
        Write-Log "Restart scheduled successfully." -Level "SUCCESS"
        
        Write-Host "`n=============================================="
        Write-Host "Remediation completed successfully!" -ForegroundColor Green
        Write-Host "Your device will restart in 30 minutes." -ForegroundColor Yellow
        Write-Host "Save all your work before then." -ForegroundColor Yellow
        Write-Host "Diagnostic report: $diagnosticPath" -ForegroundColor Cyan
        Write-Host "==============================================`n"
        Write-Host "To cancel the restart, run: shutdown /a" -ForegroundColor Cyan
    } catch {
        Write-Log "Failed to schedule restart: $_" -Level "WARNING"
        Write-Host "`nRemediation completed but couldn't schedule restart." -ForegroundColor Yellow
        Write-Host "Please restart your device manually." -ForegroundColor Yellow
    }
    
    Start-Sleep -Seconds 10
    
} catch {
    Write-Log "CRITICAL ERROR during remediation: $_" -Level "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR"
    
    Write-Host "`nA critical error occurred during remediation." -ForegroundColor Red
    Write-Host "Check log file: $flagPath" -ForegroundColor Yellow
    
    try {
        Start-Process -FilePath "shutdown.exe" -ArgumentList "/r /t 1800 /c `" Hybrid Azure AD Join Fix - Error Recovery Restart`"" -NoNewWindow -ErrorAction Stop
        Write-Host "`nScheduled restart in 30 minutes as fallback..." -ForegroundColor Yellow
    } catch {
        Write-Host "`nPlease restart your device manually." -ForegroundColor Yellow
    }
    
    Start-Sleep -Seconds 10
    exit 1
}

