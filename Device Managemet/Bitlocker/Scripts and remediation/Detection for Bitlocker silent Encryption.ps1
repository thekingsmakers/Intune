<#
.SYNOPSIS
    This script checks if the system meets the requirements for BitLocker silent encryption, including TPM version 2.0, UEFI boot mode, and Secure Boot status.

.DESCRIPTION
    The script performs a series of checks to validate that the system is equipped for BitLocker silent encryption. It checks:
    - TPM (Trusted Platform Module) availability and version (requires version 2.0 or higher).
    - UEFI firmware mode, ensuring the system is not in Legacy BIOS mode.
    - Secure Boot status, verifying if Secure Boot is enabled.

    If any of these requirements are not met, the script provides guidance for remediation.

.NOTES
    Author: Omar Osman Mahat
    Twitter: https://x.com/thekingsmakers

.PARAMETER None
    This script does not accept any parameters.

.EXAMPLE
    Run the script to check if the system is BitLocker ready:
    
    ```powershell
    .\Check-BitLockerRequirements.ps1
    ```

.OUTPUTS
    Exit code 0: All requirements are met.
    Exit code 1: One or more requirements are not met.

.LINK
    https://x.com/thekingsmakers
#>
# Function to check TPM version
function Check-TPM {
    $tpm = Get-WmiObject -Namespace "Root\CIMv2\Security\MicrosoftTpm" -Class Win32_Tpm
    if ($tpm -eq $null) {
        Write-Host "TPM is not available on this system."
        return $false
    } elseif ($tpm.SpecVersion -ge "2.0") {
        Write-Host "TPM version 2.0 or higher is available."
        return $true
    } else {
        Write-Host "TPM version is lower than 2.0."
        return $false
    }
}

# Function to check UEFI firmware using $env:firmware_type
function Check-UEFI {
    if ($env:firmware_type -eq "UEFI") {
        Write-Host "System is booting in UEFI mode."
        return $true
    } else {
        Write-Host "System is booting in Legacy BIOS mode."
        return $false
    }
}

# Function to check Secure Boot status
function Check-SecureBoot {
    $secureBoot = (Confirm-SecureBootUEFI)
    if ($secureBoot) {
        Write-Host "Secure Boot is enabled."
        return $true
    } else {
        Write-Host "Secure Boot is not enabled."
        return $false
    }
}

# Main Detection Block
$tpmCheck = Check-TPM
$uefiCheck = Check-UEFI
$secureBootCheck = Check-SecureBoot

# If all requirements are met, return success
if ($tpmCheck -and $uefiCheck -and $secureBootCheck) {
    Write-Host "All requirements for BitLocker silent encryption are met."
    exit 0  # Exit with code 0 for success
} else {
    Write-Host "Some requirements for BitLocker silent encryption are not met."
    exit 1  # Exit with code 1 for failure
}
