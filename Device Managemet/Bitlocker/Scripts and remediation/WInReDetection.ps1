# Function to check WinRE status
function Check-WinREStatus {
    try {
        # Query the WinRE status
        $winREConfig = (reagentc /info) 2>&1
        
        # Parse the output to check if it's enabled
        if ($winREConfig -match "Windows RE status.*Enabled") {
            Write-Output "WinRE is enabled."
            Exit 0  # Exit with success code
        } else {
            Write-Output "WinRE is either disabled or cannot be determined."
            Exit 1  # Exit with failure code
        }
    } catch {
        Write-Output "Error querying WinRE status: $_"
        Exit 1  # Exit with failure code
    }
}

# Run the function
Check-WinREStatus
