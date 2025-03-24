# PowerShell Script to Uninstall Webp Image Extensions using winget

# Proceed to uninstall Webp Image Extensions
try {
    Write-Host "Uninstalling Webp Image Extensions from Microsoft Store..."
    winget uninstall --id 9PG2DK419DRG --source msstore
    Write-Host "Uninstallation completed successfully."
}
catch {
    Write-Host "An error occurred during the uninstallation."
    Exit
}
