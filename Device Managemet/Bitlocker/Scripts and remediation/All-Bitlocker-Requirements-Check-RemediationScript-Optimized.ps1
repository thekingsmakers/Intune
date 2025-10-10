<#
.SYNOPSIS
    This script checks if the system meets the requirements for BitLocker silent encryption, including TPM version 1.2, UEFI boot mode, Secure Boot status, Kernel DMA Protection, and PCR7 Configuration status.
    It is designed for use with Intune Remediations. This version is optimized for speed.

.DESCRIPTION
    The script performs a series of checks to validate that the system is equipped for BitLocker silent encryption. It checks:
    - TPM (Trusted Platform Module) availability and version (requires version 1.2 or higher).
    - UEFI firmware mode, ensuring the system is not in Legacy BIOS mode.
    - Secure Boot status, verifying if Secure Boot is enabled.
    - PCR7 Configuration status (inferred from Secure Boot status for speed).
    - Kernel DMA Protection status.
    - WinRE (Windows Recovery Environment) status.

    The script outputs a summary report suitable for Intune and exits with code 0 for success (ready) or 1 for failure (not ready).

.NOTES
    Author: Omar Osman Mahat
    Twitter: https://x.com/thekingsmakers
    Enhanced for Intune Reporting and optimized for performance.

.PARAMETER None
    This script does not accept any parameters.

.EXAMPLE
    Run the script to check if the system is BitLocker ready:
    
    ```powershell
    ".\All-Bitlocker-Requirements-Check-RemediationScript-Optimized.ps1"
    ```

.OUTPUTS
    - A multi-line string report summarizing the status of each check.
    - Exit code 0: All requirements are met.
    - Exit code 1: One or more requirements are not met.

.LINK
    https://x.com/thekingsmakers
#>

# Function to check TPM version
function Check-TPM {
    $tpm = Get-WmiObject -Namespace "Root\CIMv2\Security\MicrosoftTpm" -Class Win32_Tpm
    if ($tpm -eq $null) {
        return [PSCustomObject]@{ Success = $false; Message = "TPM is not available on this system." }
    } elseif ($tpm.SpecVersion -ge "1.2") {
        return [PSCustomObject]@{ Success = $true; Message = "TPM version 1.2 or higher is available." }
    } else {
        return [PSCustomObject]@{ Success = $false; Message = "TPM version is lower than 1.2." }
    }
}

# Function to check UEFI firmware using $env:firmware_type
function Check-UEFI {
    if ($env:firmware_type -eq "UEFI") {
        return [PSCustomObject]@{ Success = $true; Message = "System is booting in UEFI mode." }
    } else {
        return [PSCustomObject]@{ Success = $false; Message = "System is booting in Legacy BIOS mode." }
    }
}

# Function to check Secure Boot status
function Check-SecureBoot {
    $secureBoot = (Confirm-SecureBootUEFI)
    if ($secureBoot) {
        return [PSCustomObject]@{ Success = $true; Message = "Secure Boot is enabled." }
    } else {
        return [PSCustomObject]@{ Success = $false; Message = "Secure Boot is not enabled." }
    }
}

# Function to check Kernel DMA Protection
function Check-KernelDMAProtection {
    $bootDMAProtectionCheck = @"
namespace SystemInfo
{
    using System;
    using System.Runtime.InteropServices;

    public static class NativeMethods
    {
        internal enum SYSTEM_DMA_GUARD_POLICY_INFORMATION : int { SystemDmaGuardPolicyInformation = 202 }

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
    Add-Type -TypeDefinition $bootDMAProtectionCheck -ErrorAction SilentlyContinue

    $bootDMAProtection = ([SystemInfo.NativeMethods]::BootDmaCheck()) -ne 0

    if ($bootDMAProtection) {
        return [PSCustomObject]@{ Success = $true; Message = "Kernel DMA Protection is On." }
    } else {
        return [PSCustomObject]@{ Success = $false; Message = "Kernel DMA Protection is Off or Not Supported." }
    }
}

# Function to check WinRE status
function Check-WinREStatus {
    try {
        $winREConfig = (reagentc /info) 2>&1
        if ($winREConfig -match "Windows RE status.*Enabled") {
            return [PSCustomObject]@{ Success = $true; Message = "WinRE is enabled." }
        } else {
            return [PSCustomObject]@{ Success = $false; Message = "WinRE is disabled or cannot be determined." }
        }
    } catch {
        return [PSCustomObject]@{ Success = $false; Message = "Error querying WinRE status: $_" }
    }
}

# --- Main Execution ---
$secureBootCheck = Check-SecureBoot
$pcr7Check = if ($secureBootCheck.Success) {
    [PSCustomObject]@{ Success = $true; Message = "PCR7 Configuration is supported (inferred from Secure Boot status)." }
} else {
    [PSCustomObject]@{ Success = $false; Message = "PCR7 Configuration is not supported because Secure Boot is disabled." }
}

$allChecks = @(
    @{ Name = "TPM"; Result = Check-TPM },
    @{ Name = "UEFI"; Result = Check-UEFI },
    @{ Name = "Secure Boot"; Result = $secureBootCheck },
    @{ Name = "Kernel DMA Protection"; Result = Check-KernelDMAProtection },
    @{ Name = "PCR7 Configuration"; Result = $pcr7Check },
    @{ Name = "WinRE"; Result = Check-WinREStatus }
)

$allChecksPassed = $true
$reportLines = @()

foreach ($check in $allChecks) {
    $status = if ($check.Result.Success) { "[PASS]" } else { "[FAIL]" }
    $reportLines += "$status $($check.Name): $($check.Result.Message)"
    if (-not $check.Result.Success) {
        $allChecksPassed = $false
    }
}

if ($allChecksPassed) {
    Write-Output "BitLocker Readiness Check: PASSED"
    Write-Output "---------------------------------"
    $reportLines | ForEach-Object { Write-Output $_ }
    exit 0
} else {
    Write-Output "BitLocker Readiness Check: FAILED"
    Write-Output "---------------------------------"
    $reportLines | ForEach-Object { Write-Output $_ }
    exit 1
}
