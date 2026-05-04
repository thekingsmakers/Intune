# ==============================================================================
# Script: Uninstall-Bginfo.ps1
# Description: Intune uninstallation script for Sysinternals BGInfo.
#              Removes the Scheduled Task, kills running instances, and
#              deletes the ProgramData folder.
# ==============================================================================

$ErrorActionPreference = 'SilentlyContinue'

$TargetDir = "$env:ProgramData\BginfoRefresh"
$TaskName  = "BGInfo User Refresh"

Write-Host "Starting BGInfo uninstallation process..."

# 1. Kill any running BGInfo instances
Write-Host "Stopping any running BGInfo processes..."
Get-Process Bginfo,Bginfo64 -ErrorAction SilentlyContinue | Stop-Process -Force

# 2. Remove the Scheduled Task
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "Removing Scheduled Task: $TaskName"
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
} else {
    Write-Host "Scheduled Task '$TaskName' not found."
}

# 3. Remove the target directory and its contents
if (Test-Path -Path $TargetDir) {
    Write-Host "Removing directory: $TargetDir"
    Remove-Item -Path $TargetDir -Recurse -Force
} else {
    Write-Host "Directory '$TargetDir' not found."
}

# 4. Remove EULA registry keys (Optional cleanup)
Write-Host "Cleaning up registry keys..."
Remove-ItemProperty -Path "HKU\.DEFAULT\Software\Sysinternals\BGInfo" -Name "EulaAccepted" -Force
Remove-ItemProperty -Path "HKCU\Software\Sysinternals\BGInfo" -Name "EulaAccepted" -Force

Write-Host "Uninstallation completed successfully."
exit 0
