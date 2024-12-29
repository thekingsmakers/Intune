<#
.SYNOPSIS
    This script checks if the system meets the requirements for BitLocker silent encryption, including TPM version 1.2, UEFI boot mode, Secure Boot status, Kernel DMA Protection, and PCR7 Configuration status.

.DESCRIPTION
    The script performs a series of checks to validate that the system is equipped for BitLocker silent encryption. It checks:
    - TPM (Trusted Platform Module) availability and version (requires version 1.2 or higher).
    - UEFI firmware mode, ensuring the system is not in Legacy BIOS mode.
    - Secure Boot status, verifying if Secure Boot is enabled.
    - PCR7 Configuration status to confirm readiness for encryption.
    - Kernel DMA Protection status.

.NOTES
    Author: Omar Osman Mahat
    Twitter: https://x.com/thekingsmakers

.PARAMETER None
    This script does not accept any parameters.

.EXAMPLE
    Run the script to check if the system is BitLocker ready:
    
    ```powershell
    ".\All-Bitlocker-Requirements-Check- RemediationScript.ps1"
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
        Write-Host "TPM is not available on this system." -ForegroundColor Red
        return $false
    } elseif ($tpm.SpecVersion -ge "1.2") {
        Write-Host "TPM version 1.2 or higher is available." -ForegroundColor Green
        return $true
    } else {
        Write-Host "TPM version is lower than 1.2."
        return $false
    }
}

# Function to check UEFI firmware using $env:firmware_type
function Check-UEFI {
    if ($env:firmware_type -eq "UEFI") {
        Write-Host "System is booting in UEFI mode." -ForegroundColor Green
        return $true
    } else {
        Write-Host "System is booting in Legacy BIOS mode." -ForegroundColor Red
        return $false
    }
}

# Function to check Secure Boot status
function Check-SecureBoot {
    $secureBoot = (Confirm-SecureBootUEFI)
    if ($secureBoot) {
        Write-Host "Secure Boot is enabled." -ForegroundColor Green
        return $true
    } else {
        Write-Host "Secure Boot is not enabled." -ForegroundColor Red
        return $false
    }
}

# Function to check Kernel DMA Protection using the provided .NET code
function Check-KernelDMAProtection {
    $bootDMAProtectionCheck = @"
namespace SystemInfo
{
    using System;
    using System.Runtime.InteropServices;

    public static class NativeMethods
    {
        internal enum SYSTEM_DMA_GUARD_POLICY_INFORMATION : int
        {
            SystemDmaGuardPolicyInformation = 202
        }

        [DllImport("ntdll.dll")]
        internal static extern Int32 NtQuerySystemInformation(
            SYSTEM_DMA_GUARD_POLICY_INFORMATION SystemDmaGuardPolicyInformation,
            IntPtr SystemInformation,
            Int32 SystemInformationLength,
            out Int32 ReturnLength);

        public static byte BootDmaCheck() {
            Int32 result;
            Int32 SystemInformationLength = 1;
            IntPtr SystemInformation = Marshal.AllocHGlobal(SystemInformationLength);
            Int32 ReturnLength;

            result = NativeMethods.NtQuerySystemInformation(
                        NativeMethods.SYSTEM_DMA_GUARD_POLICY_INFORMATION.SystemDmaGuardPolicyInformation,
                        SystemInformation,
                        SystemInformationLength,
                        out ReturnLength);

            if (result == 0) {
                byte info = Marshal.ReadByte(SystemInformation, 0);
                return info;
            }

            return 0;
        }
    }
}
"@
    Add-Type -TypeDefinition $bootDMAProtectionCheck

    # Returns true or false depending on whether Kernel DMA Protection is on or off
    $bootDMAProtection = ([SystemInfo.NativeMethods]::BootDmaCheck()) -ne 0

    if ($bootDMAProtection) {
        Write-Host "Kernel DMA Protection: On" -ForegroundColor Green
        return $true
    } else {
        Write-Host "Kernel DMA Protection: Off or Not Supported" -ForegroundColor Red
        return $false
    }
}

# Function to check PCR7 Configuration status
function Check-PCR7Configuration {
    # Path to save the msinfo32 report as a text file
    $tempFile = "$env:TEMP\msinfo32_report.txt"

    # Run msinfo32 with the /categories parameter to only retrieve necessary info and save output
    Start-Process -FilePath "msinfo32.exe" -ArgumentList "/categories SystemSummary /report $tempFile" -NoNewWindow -Wait
    Start-Sleep -Milliseconds 500

    # Parse the file to find the "PCR7 Configuration" line
    $pcr7Status = Select-String -Path $tempFile -Pattern "PCR7 Configuration"

    # Evaluate PCR7 status for readiness
    $isPCR7Ready = $false
    if ($pcr7Status) {
        $isPCR7Ready = $pcr7Status -match "Binding Possible|Bound" 
        if ($isPCR7Ready) {
            Write-Host "PCR7 Configuration is ready for Encryption" -ForegroundColor Green
        } else {
            Write-Host "PCR7 is not ready for encryption" -ForegroundColor Red
        }
    } else {
        Write-Host "PCR7 Configuration line not found" -ForegroundColor Yellow
    }

    # Clean up the temporary file after parsing
    Remove-Item $tempFile -Force

    return $isPCR7Ready
}


# Function to check WinRE status
function Check-WinREStatus {
    try {
        # Query the WinRE status
        $winREConfig = (reagentc /info) 2>&1
        
        # Parse the output to check if it's enabled
        if ($winREConfig -match "Windows RE status.*Enabled") {
            Write-Host "WinRE is enabled." -ForegroundColor Green
            return $true
        } else {
            Write-Host "WinRE is either disabled or cannot be determined." -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "Error querying WinRE status: $_" -ForegroundColor Yellow
        return $false
    }
}

# Main Detection Block
$tpmCheck = Check-TPM
$uefiCheck = Check-UEFI
$secureBootCheck = Check-SecureBoot
$kernelDMACheck = Check-KernelDMAProtection
$pcr7Check = Check-PCR7Configuration
$winRECheck = Check-WinREStatus

# If all requirements are met, return success
if ($tpmCheck -and $uefiCheck -and $secureBootCheck -and $kernelDMACheck -and $pcr7Check -and $winRECheck) {
    Write-Host "All requirements for BitLocker silent encryption are met." -ForegroundColor Green
    exit 0  # Exit with code 0 for success
} else {
    Write-Host "Some requirements for BitLocker silent encryption are not met." -ForegroundColor Red
    exit 1  # Exit with code 1 for failure
}