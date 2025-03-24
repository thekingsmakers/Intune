# Function to enable WinRE
function Enable-WinRE {
    try {
        # Check the current WinRE status
        $winREConfig = (reagentc /info) 2>&1
        
        if ($winREConfig -match "Windows RE status.*Enabled") {
            Write-Output "WinRE is already enabled."
            Exit 0  # Exit with success code
        } else {
            # Attempt to enable WinRE
            $enableResult = (reagentc /enable) 2>&1
            
            if ($enableResult -match "Operation successful") {
                Write-Output "WinRE has been successfully enabled."
                Exit 0  # Exit with success code
            } else {
                Write-Output "Failed to enable WinRE. Error: $enableResult"
                Exit 1  # Exit with failure code
            }
        }
    } catch {
        Write-Output "An error occurred while enabling WinRE: $_"
        Exit 1  # Exit with failure code
    }
}

# Run the function
Enable-WinRE
