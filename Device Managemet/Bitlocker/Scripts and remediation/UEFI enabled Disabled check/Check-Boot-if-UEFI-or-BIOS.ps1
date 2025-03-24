<#  


This is only for uefi check. all the others will be hashed out

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
#>
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

<# Function to check Secure Boot status
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

#>

<# Function to check Kernel DMA Protection using the provided .NET code
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
        Write-Host "Kernel DMA Protection: On"
        return $true
    } else {
        Write-Host "Kernel DMA Protection: Off or Not Supported"
        return $false
    }
}

#>


# Main Detection Block
#$tpmCheck = Check-TPM
$uefiCheck = Check-UEFI
#$secureBootCheck = Check-SecureBoot
#$kernelDMACheck = Check-KernelDMAProtection

# If all requirements are met, return success
if ($uefiCheck) {
    Write-Host "UEFI is enabled"
    exit 0  # Exit with code 0 for success
} else {
    Write-Host "Bios is enabled."
    exit 1  # Exit with code 1 for failure
}
