# Define the Policy ID provided
$PolicyId = ""

# Define the registry paths for Intune Remediation (SideCar)
$RegistryPath = "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\SideCarPolicies\Scripts\REMEDIATION\$PolicyId"
$UserRegistryPath = "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\SideCarPolicies\Status\$PolicyId"

Write-Host "Targeting Policy ID: $PolicyId" -ForegroundColor Cyan

# 1. Clear the Device-level execution history
if (Test-Path $RegistryPath) {
    Write-Host "Found device policy record. Clearing..." -ForegroundColor Yellow
    Remove-Item -Path $RegistryPath -Recurse -Force
}

# 2. Clear the Status/Report history
if (Test-Path $UserRegistryPath) {
    Write-Host "Found status record. Clearing..." -ForegroundColor Yellow
    Remove-Item -Path $UserRegistryPath -Recurse -Force
}

# 3. Restart the Intune Management Extension service to trigger immediate sync
Write-Host "Restarting Intune Management Extension service..." -ForegroundColor Magenta
Restart-Service -Name "IntuneManagementExtension" -Force

Write-Host "Done! The agent is now re-evaluating the remediation script." -ForegroundColor Green
Write-Host "You can monitor progress in: C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log"
