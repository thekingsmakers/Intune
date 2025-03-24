# PowerShell Script to Uninstall Snip & Sketch using winget

# Function to check if Snip & Sketch is installed
Function CheckIfInstalled {
    $installedApps = winget list --name "Snip & Sketch"
    return $installedApps -match "Snip & Sketch"
}

# Proceed to uninstall Snip & Sketch if it's installed
try {
    if (CheckIfInstalled) {
        Write-Host "Snip & Sketch is installed. Proceeding with uninstallation..."
        winget uninstall --name "Snip & Sketch" --silent
        Write-Host "Uninstallation completed successfully."
    }
    else {
        Write-Host "Snip & Sketch is not installed. No action required."
    }
}
catch {
    Write-Host "An error occurred during the uninstallation."
    Exit
}
