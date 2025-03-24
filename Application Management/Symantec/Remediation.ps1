<#

The script searches for the product symantec and uninstalls it 

created by : Omar Osman

27/2/2025
#>

﻿# Define the display name of Symantec Endpoint Protection
$appName = "Symantec Endpoint Protection"



# Get the App ID of the installed application
$app = Get-WmiObject -Class Win32_Product -Filter "Name LIKE '%$appName%'" | Select-Object -First 1



if ($app) {
    $appID = $app.IdentifyingNumber
    Write-Host "Found $appName with App ID: $appID"



    # Uninstall the application using the App ID with /qn (quiet uninstall)
    Write-Host "Uninstalling $appName..."
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $appID /qn" -Wait -NoNewWindow



    # Verify if the uninstallation was successful
    $uninstalledApp = Get-WmiObject -Class Win32_Product -Filter "IdentifyingNumber = '$appID'"
    if (-not $uninstalledApp) {
        Write-Host "$appName has been successfully uninstalled."
        exit 0 # Remediation successful
    } else {
        Write-Host "Failed to uninstall $appName."
        exit 1 # Remediation failed
    }
} else {
    Write-Host "$appName is not installed on this system."
    exit 0 # No remediation required
}
