# Update winget sources
winget source update

# Uninstall Company Portal
winget uninstall --id 9wzdncrfj3pz -e --silent

# Wait a few seconds to ensure uninstallation completes
Start-Sleep -Seconds 05

# Install Company Portal
winget install --id 9wzdncrfj3pz -e --accept-package-agreements --accept-source-agreements --silent

# Wait for installation to complete
Start-Sleep -Seconds 10

# Check if Company Portal is installed
$companyPortal = winget list --id 9wzdncrfj3pz -e

if ($companyPortal -match "Company Portal") {
    Write-Output "Company Portal is installed successfully."
} else {
    winget install --id 9wzdncrfj3pz -e --accept-package-agreements --accept-source-agreements --silent
    Start-Sleep -Seconds 10


    # Final Check
    $companyPortal = winget list --id 9wzdncrfj3pz -e
    if ($companyPortal -match "Company Portal") {
        Write-Output "Company Portal installed successfully on second attempt."
    } else {
        Write-Output "Company Portal installation failed again."
    }
}
