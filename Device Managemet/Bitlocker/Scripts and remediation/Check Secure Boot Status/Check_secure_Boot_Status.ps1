<#
.SYNOPSIS
    This script checks if the secure Boot is enabled or disabled

.DESCRIPTION
    The script performs 
    - Secure Boot status, verifying if Secure Boot is enabled.

.NOTES
    Author: Omar Osman Mahat
    Twitter: https://x.com/thekingsmakers

.PARAMETER None
    This script does not accept any parameters.

.EXAMPLE
    Run the script to check if the system is BitLocker ready:
    
    ```powershell
    .\Securebootcheck.ps1
    ```

.OUTPUTS
    Exit code 0: Requirements are met.
    Exit code 1: Requirements are not met.
#>

# Function to check Secure Boot status
function Check-SecureBoot {
    $secureBoot = (Confirm-SecureBootUEFI)
    if ($secureBoot) {
        #Write-Host "Secure Boot is enabled."
        return $true
    } else {
        Write-Host "Secure Boot is not enabled."
        return $false
    }
}

$secureBootCheck = Check-SecureBoot

# If all requirements are met, return success
if ($secureBootCheck) {
    Write-Host "Secure Boot is Enabled."
    exit 0  # Exit with code 0 for success
} else {
    Write-Host "Secure boot not enabled."
    exit 1  # Exit with code 1 for failure
    }