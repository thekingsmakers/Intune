# ================================================================
# Script: Repair-AzureHybridJoin.ps1
# Description:
# - Retrieves the Azure AD join status using dsregcmd /status.
# - Checks that:
#   • AzureAdJoined       : YES
#   • DeviceAuthStatus    : SUCCESS
#   If both are present, no action is required.
#
# - If the join status is unsatisfactory and the status shows:
#   AzureAdJoined : NO and no "DeviceAuthStatus" entry exists,
#   the script:
#   1. Runs dsregcmd /leave.
#   2. Registers a one-time scheduled task (in folder "Fixes Hybrid Join")
#      that re-runs this script at the next user logon (after device restart)
#      to complete the join process.
#   3. Restarts the device.
#
# Usage: Run this script as Administrator.
# ================================================================

function Get-AzureJoinStatus {
    try {
        Write-Host "Retrieving Azure AD join status using dsregcmd /status..." -ForegroundColor Cyan
        $output = dsregcmd /status 2>&1
        return $output
    } catch {
        Write-Error "Failed to execute dsregcmd /status: $_"
        exit 1
    }
}

function Is-AzureJoinedAndDeviceAuthValid {
    param (
        [string[]]$StatusOutput
    )
    $joinedValid = $StatusOutput -match "AzureAdJoined\s+:\s+YES"
    $deviceAuthValid = $StatusOutput -match "DeviceAuthStatus\s+:\s+SUCCESS"
    return ($joinedValid -and $deviceAuthValid)
}

function Register-JoinAfterRestartTask {
    try {
        # Define the folder and full task name (with leading backslash)
        $folderName = "\Fixes Hybrid Join"
        $taskName = "${folderName}\JoinAfterRestart"
        
        # Check if the task already exists
        $null = schtasks /query /tn "$taskName" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Scheduled task '$taskName' already exists. Skipping creation." -ForegroundColor Yellow
            return
        }
    } catch {
        # If task not found, proceed to creation.
        Write-Host "Scheduled task '$taskName' not found. Creating task..." -ForegroundColor Cyan
    }
    
    $scriptPath = $MyInvocation.MyCommand.Path
    $action = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    
    # Create the scheduled task with:
    # - Trigger: At user logon
    # - Run level: Highest
    # NOTE: The /Z flag (delete after run) is removed as it is only valid with /SC ONCE.
    $createTaskCmd = "schtasks /create /tn `"$taskName`" /tr `"$action`" /sc ONLOGON /rl HIGHEST /f"
    Write-Host "Executing: $createTaskCmd" -ForegroundColor Cyan
    Invoke-Expression $createTaskCmd
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Task '$taskName' created successfully in folder '$folderName'." -ForegroundColor Green
    } else {
        Write-Error "Failed to create scheduled task '$taskName'."
    }
}

# Main script logic
$statusOutput = Get-AzureJoinStatus

if (Is-AzureJoinedAndDeviceAuthValid -StatusOutput $statusOutput) {
    Write-Host "Device is properly Azure AD joined with a successful DeviceAuthStatus. No action required." -ForegroundColor Green
    exit 0
} else {
    $azureAdJoinedNo = $statusOutput -match "AzureAdJoined\s+:\s+NO"
    $deviceAuthExists = $statusOutput -match "DeviceAuthStatus\s*:"
    if ($azureAdJoinedNo -and (-not $deviceAuthExists)) {
        Write-Host "Device shows 'AzureAdJoined : NO' and no DeviceAuthStatus record." -ForegroundColor Yellow
        Write-Host "Running dsregcmd /leave to clear any stale join state..." -ForegroundColor Cyan
        try {
            $leaveOutput = dsregcmd /leave 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Error "dsregcmd /leave did not complete successfully: $leaveOutput"
                exit 1
            }
            Write-Host "Successfully left the Azure AD join state." -ForegroundColor Green
        } catch {
            Write-Error "Error executing dsregcmd /leave: $_"
            exit 1
        }
        Register-JoinAfterRestartTask
        Write-Host "Restarting the device to complete the Azure AD join process..." -ForegroundColor Magenta
        Restart-Computer -Force
    } else {
        Write-Error "Unsatisfactory join state does not match expected condition (AzureAdJoined : NO without DeviceAuthStatus). Exiting."
        exit 1
    }
}
