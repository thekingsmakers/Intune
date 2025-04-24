# Detection Script - Checks if device is connected to a specific public IP

# Define the list of specific public IPs to monitor
$specificPublicIPs = @(")

# Function to get the current public IP of the device
function Get-PublicIP {
    try {
        return (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content.Trim()
    } catch {
        Write-Host "Failed to retrieve public IP: $_"
        exit 1  # Exit code 1 indicates failure
    }
}

# Main detection logic
try {
    # Get the current public IP of the device
    $currentPublicIP = Get-PublicIP
    Write-Host "Current public IP: $currentPublicIP"

    # Check if the current public IP matches any of the specified public IPs
    $isMatch = $specificPublicIPs -contains $currentPublicIP

    if ($isMatch) {
        Write-Host "Device is connected to one of the specified public IPs."
        # Return exit code 1 to indicate blocking is needed
        exit 1
    } else {
        Write-Host "Device is not connected to any of the specified public IPs."
        # Return exit code 0 to indicate unblocking is needed
        exit 0
    }
} catch {
    Write-Host "An error occurred during detection: $_"
    # Return exit code 2 to indicate an error occurred
    exit 2
}
