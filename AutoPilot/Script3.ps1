#Uninstall SCCM Client Variables
$UninstallPath = "C:\Windows\ccmsetup"
$UninstallerName = "ccmsetup.exe"
$UninstallerArguments = "/Uninstall"

#Uninstall SCCM Client action
Start-Process -FilePath "$UninstallPath\$UninstallerName" -ArgumentList $UninstallerArguments -Wait -PassThru

# Ensure uninstallation completely finishes before moving on
while (Get-Process -Name "ccmsetup" -ErrorAction SilentlyContinue) {
    Start-Sleep -Seconds 5
}

#Remove register key
$registryPath = "HKLM:\SOFTWARE\Microsoft\DeviceManageabilityCSP"
if (Test-Path $registryPath) {
    Remove-Item $registryPath -Force -Recurse
}

#Sysprep Variables
$sysprepPath = "c:\windows\system32\sysprep"
$sysprepName = "sysprep.exe"
$sysprepArguments = "/oobe /reboot"

#sysprep execution
Start-Process -FilePath "$sysprepPath\$sysprepName" -ArgumentList $sysprepArguments




