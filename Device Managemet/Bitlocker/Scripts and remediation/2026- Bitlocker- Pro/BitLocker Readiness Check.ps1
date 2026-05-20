# =====================================
# CONFIG
# AUTHOR: THEKINGSMAKERS
# =====================================
$FlowUrl = "URL FOR POWERAUTOMATE"

# =====================================
# FUNCTIONS
# =====================================

function Get-TPMInfo {
    try {
        $tpm = Get-CimInstance -Namespace "Root\CIMv2\Security\MicrosoftTpm" -ClassName Win32_Tpm -ErrorAction Stop
        if ($null -eq $tpm) {
            return @{ Present="No"; Version="None" }
        }

        return @{
            Present = "Yes"
            Version = ($tpm.SpecVersion -join ",")
        }
    } catch {
        return @{ Present="Error"; Version="Unknown" }
    }
}

function Get-UEFI {
    try {
        if ($env:firmware_type -eq "UEFI") { return "UEFI" }
        else { return "Legacy" }
    } catch { return "Unknown" }
}

function Get-SecureBoot {
    try {
        if (Confirm-SecureBootUEFI) { return "Enabled" }
        else { return "Disabled" }
    } catch {
        return "Not Supported"
    }
}

function Get-KernelDMA {
    try {
        $code = @"
using System;
using System.Runtime.InteropServices;
public class DMA {
    [DllImport("ntdll.dll")]
    public static extern int NtQuerySystemInformation(int SystemInformationClass, IntPtr SystemInformation, int SystemInformationLength, out int ReturnLength);
}
"@
        Add-Type $code -ErrorAction SilentlyContinue

        $ptr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(1)
        $out = 0
        $res = [DMA]::NtQuerySystemInformation(202, $ptr, 1, [ref]$out)

        if ($res -eq 0) {
            $val = [System.Runtime.InteropServices.Marshal]::ReadByte($ptr)
            if ($val -ne 0) { return "On" }
        }
        return "Off or Not Supported"
    } catch {
        return "Unknown"
    }
}

function Get-PCR7 {
    try {
        $tmp = "$env:TEMP\msinfo.txt"

        Start-Process msinfo32.exe -ArgumentList "/report $tmp" -Wait -WindowStyle Hidden

        $line = Select-String -Path $tmp -Pattern "PCR7 Configuration"

        Remove-Item $tmp -Force -ErrorAction SilentlyContinue

        if ($line -match "Binding Possible|Bound") { return "Ready" }
        elseif ($line) { return "Not Ready" }
        else { return "Unknown" }

    } catch {
        return "Error"
    }
}

function Get-WinRE {
    try {
        $output = reagentc /info 2>&1
        if ($output -match "Enabled") { return "Enabled" }
        else { return "Disabled" }
    } catch {
        return "Unknown"
    }
}

function Get-BitLockerStatus {
    try {
        $result = @{}

        # C Drive
        try {
            $c = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop

            if ($c.ProtectionStatus -eq 1) {
                $result.C = "Encrypted"
            } else {
                $result.C = "Not Encrypted"
            }

        } catch {
            $result.C = "Unknown"
        }

        # D Drive
        try {
            $dExists = Get-Volume -DriveLetter D -ErrorAction SilentlyContinue

            if ($dExists) {
                $d = Get-BitLockerVolume -MountPoint "D:" -ErrorAction Stop

                if ($d.ProtectionStatus -eq 1) {
                    $result.D = "Encrypted"
                } else {
                    $result.D = "Not Encrypted"
                }
            } else {
                $result.D = "Drive Not Found"
            }

        } catch {
            $result.D = "Unknown"
        }

        return $result
    }
    catch {
        return @{
            C = "Error"
            D = "Error"
        }
    }
}

function Get-DeviceInfo {
    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop

        return @{
            Manufacturer = $cs.Manufacturer
            Model        = $cs.Model
        }
    } catch {
        return @{
            Manufacturer = "Unknown"
            Model        = "Unknown"
        }
    }
}

# =====================================
# MAIN
# =====================================

try {
    $hostname = $env:COMPUTERNAME

    $tpm = Get-TPMInfo
    $uefi = Get-UEFI
    $secureboot = Get-SecureBoot
    $dma = Get-KernelDMA
    $pcr7 = Get-PCR7
    $winre = Get-WinRE
    $bitlocker = Get-BitLockerStatus
    $device = Get-DeviceInfo
    $Body = @{
    DeviceName      = $hostname
    Manufacturer    = $device.Manufacturer
    Model           = $device.Model
    TPM_Present     = $tpm.Present
    TPM_Version     = $tpm.Version
    UEFI_Mode       = $uefi
    SecureBoot      = $secureboot
    KernelDMA       = $dma
    PCR7            = $pcr7
    WinRE           = $winre
    BitLocker_C     = $bitlocker.C
    BitLocker_D     = $bitlocker.D
    Timestamp       = (Get-Date).ToString("s")
} | ConvertTo-Json -Depth 3

    Invoke-RestMethod -Uri $FlowUrl -Method POST -Body $Body -ContentType "application/json"

    Write-Output "SUCCESS: $hostname sent to Flow"
    exit 0
}
catch {
    Write-Output "ERROR: $($_.Exception.Message)"
    exit 1
}
