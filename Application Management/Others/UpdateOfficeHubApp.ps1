# PowerShell script to update the Microsoft.MicrosoftOfficeHub app from the Microsoft Store

# Define the name of the package
$packageName = "Microsoft.MicrosoftOfficeHub"

# Attempt to fetch the app package
$appPackage = Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue

# If the app package is not found, output a message and exit
if ($null -eq $appPackage) {
    Write-Host "Microsoft Office Hub app not found."
    Read-Host "Press Enter to exit"
    exit
}

# Display the app name
Write-Host "Found Microsoft Office Hub, attempting to re-register (update)..."

# Re-register (essentially, updating) the app
Add-AppxPackage -DisableDevelopmentMode -Register "$($appPackage.InstallLocation)\AppXManifest.xml"

Write-Host "Re-registration (update) process completed."
Read-Host "Press Enter to exit"
