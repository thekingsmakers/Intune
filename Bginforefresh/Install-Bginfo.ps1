# ==============================================================================
# Script: Install-Bginfo.ps1
# Description: Intune deployment script for Sysinternals BGInfo.
#              Copies files to ProgramData and creates a Scheduled Task
#              to run at every user logon.
# ==============================================================================

$ErrorActionPreference = 'Stop'

# Define paths
$SourceDir = $PSScriptRoot
$TargetDir = "$env:ProgramData\BginfoRefresh"
$TaskName  = "BGInfo User Refresh"
$ScriptPath = "$TargetDir\bginforefresh.ps1"

Write-Host "Starting BGInfo installation process..."

# 1. Create target directory if it doesn't exist
if (-not (Test-Path -Path $TargetDir)) {
    Write-Host "Creating target directory: $TargetDir"
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

# 2. Copy files to target directory
Write-Host "Copying files from $SourceDir to $TargetDir..."
Copy-Item -Path "$SourceDir\Bginfo64.exe" -Destination $TargetDir -Force
Copy-Item -Path "$SourceDir\hostname.bgi" -Destination $TargetDir -Force
Copy-Item -Path "$SourceDir\bginforefresh.ps1" -Destination $TargetDir -Force

# Create a VBScript wrapper to completely prevent the PowerShell console flash
$VbsPath = "$TargetDir\runner.vbs"
$VbsContent = @"
Set objShell = CreateObject("WScript.Shell")
objShell.Run "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -Command ""Get-Content '$ScriptPath' -Raw | Invoke-Expression""", 0, False
"@
Set-Content -Path $VbsPath -Value $VbsContent -Force

# 3. Create Scheduled Task to run at user logon
Write-Host "Configuring Scheduled Task: $TaskName"

# Unregister existing task if present
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "Removing existing scheduled task..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# The action is to run the VBScript using wscript, which has no console window
$Action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$VbsPath`""

# The triggers include Logon, Unlock (8), and Lock (7)
$TriggerLogon = New-ScheduledTaskTrigger -AtLogon
$TriggerUnlock = New-CimInstance -ClassName MSFT_TaskSessionStateChangeTrigger -Namespace Root/Microsoft/Windows/TaskScheduler -ClientOnly -Property @{StateChange=[uint32]8}
$TriggerUnlock.PSTypeNames.Insert(0, "Microsoft.Management.Infrastructure.CimInstance#MSFT_TaskTrigger")
$TriggerLock = New-CimInstance -ClassName MSFT_TaskSessionStateChangeTrigger -Namespace Root/Microsoft/Windows/TaskScheduler -ClientOnly -Property @{StateChange=[uint32]7}
$TriggerLock.PSTypeNames.Insert(0, "Microsoft.Management.Infrastructure.CimInstance#MSFT_TaskTrigger")
$Triggers = @($TriggerLogon, $TriggerUnlock, $TriggerLock)

# The principal defines who runs the task. Using "Users" group so it runs interactively for the logged-on user
$Principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest

# Settings for the task
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -DontStopOnIdleEnd -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

# Register the task
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Triggers -Principal $Principal -Settings $Settings -Description "Runs BGInfo at user logon and session state changes to refresh desktop info" | Out-Null

Write-Host "Installation completed successfully."
Write-Host "Triggering BGInfo to display immediately..."
Start-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
exit 0
