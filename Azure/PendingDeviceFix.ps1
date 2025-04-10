# Fix-AzurePending.ps1
# Script to fix Azure pending issues for Windows 10
# This script requires elevated privileges (Run as Administrator)

# Start transcript for logging
$transcriptPath = "$env:USERPROFILE\Desktop\AzureFixLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Start-Transcript -Path $transcriptPath -ErrorAction SilentlyContinue

# Check if running as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires elevated privileges. Please run as Administrator." -ForegroundColor Red
    Stop-Transcript -ErrorAction SilentlyContinue
    exit
}


Write-Host "Script Created by Omar Osman @thekingsmakers..." -ForegroundColor Yellow

Write-Host "Starting Azure Pending fix script..." -ForegroundColor Cyan
Write-Host "Log file will be saved to: $transcriptPath" -ForegroundColor Gray

# First, clear cache
Write-Host "Clearing Azure AD cache..." -ForegroundColor Yellow
try {
    # Clear AAD Broker Plugin cache
    Remove-Item "$env:LOCALAPPDATA\Packages\Microsoft.AAD.BrokerPlugin_*\AC\TokenBroker\Cache\*" -Force -Recurse -ErrorAction SilentlyContinue
    # Clear Cloud Experience Host cache
    Remove-Item "$env:LOCALAPPDATA\Packages\Microsoft.Windows.CloudExperienceHost_*\AC\TokenBroker\Cache\*" -Force -Recurse -ErrorAction SilentlyContinue
    # Clear the SSO state
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\WSSO\*" -Force -Recurse -ErrorAction SilentlyContinue
    # Clear Windows login cache
    Remove-Item "$env:LOCALAPPDATA\IdentityCache\*" -Force -Recurse -ErrorAction SilentlyContinue
    # Clear WebAccount cache
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\WebCache\*" -Force -Recurse -ErrorAction SilentlyContinue
    
    Write-Host "Cache cleared successfully." -ForegroundColor Green
} catch {
    Write-Host "Warning: Some cache items could not be cleared. Continuing script..." -ForegroundColor Yellow
    Write-Host "Error details: $_" -ForegroundColor Gray
}

# Check device uptime
$bootUpTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
$currentTime = Get-Date
$uptime = $currentTime - $bootUpTime
$uptimeDays = $uptime.Days

Write-Host "Current device uptime: $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes" -ForegroundColor Cyan

if ($uptimeDays -ge 2) {
    Write-Host "Your device has been running for more than 2 days." -ForegroundColor Yellow
    Write-Host "It is recommended to restart your computer and run this script again for optimal results." -ForegroundColor Yellow
    
    $restart = Read-Host "Would you like to restart now? (Y/N)"
    if ($restart -eq "Y" -or $restart -eq "y") {
        Write-Host "Restarting computer in 10 seconds..." -ForegroundColor Red
        Start-Sleep -Seconds 10
        Restart-Computer -Force
        exit
    } else {
        Write-Host "Continuing with script execution..." -ForegroundColor Yellow
    }
}

# Run dsregcmd to leave Azure AD
Write-Host "Disconnecting from Azure AD..." -ForegroundColor Yellow
try {
    $leaveResult = dsregcmd /leave 2>&1
    Write-Host $leaveResult -ForegroundColor Gray
    
    # Verify leave operation
    $statusAfterLeave = dsregcmd /status
    Write-Host "Status after leave operation:" -ForegroundColor Gray
    Write-Host ($statusAfterLeave | Select-String "AzureAd" | Out-String).Trim() -ForegroundColor Gray
} catch {
    Write-Host "Error encountered during leave operation: $_" -ForegroundColor Red
    Write-Host "Continuing with script..." -ForegroundColor Yellow
}

# Wait for 3 minutes
Write-Host "Waiting for 3 minutes before reconnecting..." -ForegroundColor Yellow
$waitStartTime = Get-Date
$endTime = $waitStartTime.AddMinutes(3)

while ((Get-Date) -lt $endTime) {
    $timeLeft = $endTime - (Get-Date)
    $percentComplete = 100 - (($timeLeft.TotalSeconds / 180) * 100)
    Write-Progress -Activity "Waiting to reconnect" -Status "$([math]::Round($timeLeft.TotalSeconds)) seconds remaining" -PercentComplete $percentComplete
    Start-Sleep -Seconds 1
}
Write-Progress -Activity "Waiting to reconnect" -Completed

# Run dsregcmd to join Azure AD
Write-Host "Reconnecting to Azure AD..." -ForegroundColor Yellow
try {
    $joinResult = dsregcmd /join 2>&1
    Write-Host $joinResult -ForegroundColor Gray
    
    # Force a synchronization with Azure AD
    Write-Host "Forcing Azure AD sync..." -ForegroundColor Yellow
    Start-Process "C:\Windows\System32\deviceenroller.exe" -ArgumentList "/c /AutoEnrollMDM" -NoNewWindow -Wait -ErrorAction SilentlyContinue
} catch {
    Write-Host "Error encountered during join operation: $_" -ForegroundColor Red
}

# Check Azure AD Join status
Write-Host "Checking Azure AD Join status..." -ForegroundColor Yellow
$statusResult = dsregcmd /status
Write-Host "Detailed status information:" -ForegroundColor Gray

# Extract key status values more reliably using regex pattern matching
$statusOutput = $statusResult | Out-String
$azureAdJoinedMatch = [regex]::Match($statusOutput, "AzureAdJoined\s+:\s+(\w+)")
$domainJoinedMatch = [regex]::Match($statusOutput, "DomainJoined\s+:\s+(\w+)")
$workplaceJoinedMatch = [regex]::Match($statusOutput, "WorkplaceJoined\s+:\s+(\w+)")

# Get the actual status values
$azureAdJoined = $azureAdJoinedMatch.Success -and $azureAdJoinedMatch.Groups[1].Value -eq "YES"
$domainJoined = $domainJoinedMatch.Success -and $domainJoinedMatch.Groups[1].Value -eq "YES"
$workplaceJoined = $workplaceJoinedMatch.Success -and $workplaceJoinedMatch.Groups[1].Value -eq "YES"

# Display key status sections
Write-Host ($statusResult | Select-String -Pattern "Device State" -Context 0,2 | Out-String).Trim() -ForegroundColor Gray
Write-Host ($statusResult | Select-String -Pattern "Tenant Details" -Context 0,5 | Out-String).Trim() -ForegroundColor Gray
Write-Host ($statusResult | Select-String -Pattern "SSO State" -Context 0,5 | Out-String).Trim() -ForegroundColor Gray

# Provide clear status message
if ($azureAdJoined -and $domainJoined) {
    Write-Host "`nSuccess! Your device is now properly joined to Azure AD Hybrid." -ForegroundColor Green
    Write-Host "Please log out and log back in to complete the process." -ForegroundColor Green
    Write-Host "You should now be able to access your device resources." -ForegroundColor Green
} elseif ($azureAdJoined) {
    Write-Host "`nYour device is now joined to Azure AD, but not to a domain." -ForegroundColor Yellow
    Write-Host "Please log out and log back in to complete the process." -ForegroundColor Yellow
} elseif ($domainJoined) {
    Write-Host "`nYour device is domain-joined but not Azure AD joined." -ForegroundColor Yellow
    Write-Host "You may need to contact your IT administrator for further assistance." -ForegroundColor Yellow
    
    # Suggest additional troubleshooting
    Write-Host "`nTroubleshooting suggestions:" -ForegroundColor Cyan
    Write-Host "1. Check if the device is registered with Azure AD (WorkplaceJoined = YES)" -ForegroundColor Cyan
    Write-Host "2. Verify your internet connection and try running dsregcmd /join again" -ForegroundColor Cyan
    Write-Host "3. Ensure your user account has permissions to join devices to Azure AD" -ForegroundColor Cyan
} else {
    Write-Host "`nYour device is neither domain-joined nor Azure AD joined." -ForegroundColor Red
    Write-Host "Please contact your IT administrator for assistance." -ForegroundColor Red
}

# Restart the Windows Identity service to help finalize changes
Write-Host "`nRestarting the Windows Identity service..." -ForegroundColor Yellow
try {
    Restart-Service -Name "wlidsvc" -Force -ErrorAction SilentlyContinue
    Write-Host "Windows Identity service restarted successfully." -ForegroundColor Green
} catch {
    Write-Host "Could not restart the Windows Identity service. This is not critical." -ForegroundColor Yellow
}

Write-Host "`nScript execution completed." -ForegroundColor Cyan
Write-Host "Log file has been saved to: $transcriptPath" -ForegroundColor Gray
Stop-Transcript -ErrorAction SilentlyContinue
