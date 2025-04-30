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
#      that re-runs this script at the next logon of any user 
#      (with network-connected condition) to complete the join process.
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
    # Determine the current interactive user (for logging purposes only).
    $currentUser = "$env:USERDOMAIN\$env:USERNAME"
    
    # Define the folder and full task name.
    $folderName = "\Fixes Hybrid Join"
    $taskName = "${folderName}\JoinAfterRestart"

    # Check if the task already exists.
    try {
        $null = schtasks /query /tn "$taskName" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Scheduled task '$taskName' already exists. Skipping creation." -ForegroundColor Yellow
            return
        }
    } catch {
        Write-Host "Scheduled task '$taskName' not found. Creating task..." -ForegroundColor Cyan
    }

    # Get the full path to this script.
    $scriptPath = $MyInvocation.MyCommand.Path

    # Build the XML for the scheduled task.
    # Changes made:
    #   - Removed the <UserId> from the LogonTrigger so that the trigger runs at any user logon.
    #   - Set the principal to run as SYSTEM (S-1-5-18) with HighestAvailable privileges.
    $currentDate = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    $xmlContent = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>$currentDate</Date>
    <Author>$currentUser</Author>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <StartWhenAvailable>true</StartWhenAvailable>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <NetworkSettings>
      <Name>Any</Name>
    </NetworkSettings>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-NoProfile -ExecutionPolicy Bypass -File "$scriptPath"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

    # Write the XML content to a temporary file.
    $tempXml = [System.IO.Path]::GetTempFileName()
    $tempXml = [System.IO.Path]::ChangeExtension($tempXml, ".xml")
    [System.IO.File]::WriteAllText($tempXml, $xmlContent, [System.Text.Encoding]::Unicode)

    # Create the scheduled task using the XML definition.
    $createTaskCmd = "schtasks /create /tn `"$taskName`" /xml `"$tempXml`" /f"
    Write-Host "Executing: $createTaskCmd" -ForegroundColor Cyan
    Invoke-Expression $createTaskCmd
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Task '$taskName' created successfully in folder '$folderName'." -ForegroundColor Green
    } else {
        Write-Error "Failed to create scheduled task '$taskName'."
    }

    # Clean up the temporary XML file.
    Remove-Item $tempXml -Force
}

# Main script logic

# 1. Retrieve the current join status.
$statusOutput = Get-AzureJoinStatus

# 2. If the device is properly joined, exit.
if (Is-AzureJoinedAndDeviceAuthValid -StatusOutput $statusOutput) {
    Write-Host "Device is properly Azure AD joined with a successful DeviceAuthStatus. No action required." -ForegroundColor Green
    exit 0
} else {
    # Evaluate the status details.
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
        # Register the follow-up scheduled task (with a trigger for any user logon and network-connected condition).
        Register-JoinAfterRestartTask
        Write-Host "Restarting the device to complete the Azure AD join process..." -ForegroundColor Magenta
        Restart-Computer -Force
    } else {
        Write-Error "Unsatisfactory join state does not match expected condition (AzureAdJoined : NO without DeviceAuthStatus). Exiting."
        exit 1
    }
}
