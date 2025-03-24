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


# Function to enable TPM
function Enable-TPM {
    try {
        $tpm = Get-WmiObject -Namespace "Root\CIMv2\Security\MicrosoftTpm" -Class Win32_Tpm
        if ($tpm -eq $null) {
            Write-Host "TPM is not available on this system."
            return $false
        }
        
        if ($tpm.SpecVersion -lt "2.0") {
            Write-Host "TPM version is lower than 2.0. Attempting to update..."
            # Add code here to guide the user to update TPM if possible, or to enable it in BIOS
            return $false
        }

        # Check if TPM is enabled
        if ($tpm.TpmPresent -and $tpm.TpmEnabled -eq $false) {
            Write-Host "Enabling TPM..."
            # This part is typically done in BIOS; advise the user to enable TPM in BIOS settings
            return $false
        }
        
        Write-Host "TPM is already enabled."
        return $true
        
    } catch {
        Write-Host "Error checking TPM: $_"
        return $false
    }
}

# Function to check UEFI and switch if necessary
function Enable-UEFI {
    # Note: Changing firmware settings is not possible via script; provide guidance to the user
    if ($env:firmware_type -eq "UEFI") {
        Write-Host "System is already booting in UEFI mode."
        return $true
    } else {
        Write-Host "System is booting in Legacy BIOS mode. Please change to UEFI in BIOS settings."
        return $false
    }
}

# Function to enable Secure Boot
function Enable-SecureBoot {
    $secureBoot = (Confirm-SecureBootUEFI)
    if ($secureBoot) {
        Write-Host "Secure Boot is already enabled."
        return $true
    } else {
        Write-Host "Secure Boot is not enabled. Please enable it in BIOS settings."
        # This action typically requires manual intervention in BIOS settings
        return $false
    }
}

# Main Remediation Block
$tpmCheck = Enable-TPM
$uefiCheck = Enable-UEFI
$secureBootCheck = Enable-SecureBoot

# Determine remediation status
if ($tpmCheck -and $uefiCheck -and $secureBootCheck) {
    Write-Host "All requirements for BitLocker silent encryption are met."
    exit 0  # Exit with code 0 for success
} else {
    Write-Host "Some requirements for BitLocker silent encryption are not met. Manual intervention may be required."
    exit 1  # Exit with code 1 for failure
}
