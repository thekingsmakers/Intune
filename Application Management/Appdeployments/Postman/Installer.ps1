# Postman Silent Installation Script
$InstallerUrl = "https://dl.pstmn.io/download/latest/win64"
$InstallerPath = "$env:TEMP\PostmanSetup.exe"

# Download Postman Installer
Write-Host "Downloading Postman installer..."
Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath

# Silent Install with Custom Installation Directory
$InstallDir = "C:\Program Files\Postman"
Write-Host "Installing Postman silently to $InstallDir..."
Start-Process -FilePath $InstallerPath -ArgumentList "/silent /InstallPath=`"$InstallDir`"" -Wait

# Verify Installation
if (Test-Path "$InstallDir\Postman.exe") {
    Write-Host "Postman installed successfully."
} else {
    Write-Host "Postman installation failed."
}

# Cleanup Installer
Write-Host "Cleaning up installer..."
Remove-Item -Path $InstallerPath -Force