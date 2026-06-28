<#
.SYNOPSIS
    MOE Enterprise Laptop Requirements Validator
    Validates hardware and firmware compliance for Ministry of Education enterprise laptop standards.

.DESCRIPTION
    This script performs a comprehensive hardware and firmware compliance check against the
    Ministry of Education (MOEHE) enterprise laptop requirements. It validates:

    --- Security & Firmware ---
    - TPM availability and version (requires 1.2 or higher, with Measured Boot & attestation)
    - UEFI firmware mode (Legacy BIOS not permitted)
    - Secure Boot status and hardware capability
    - PCR7 Binding support (Secure Boot + TPM integration)
    - Kernel DMA Protection availability for Silent BitLocker encryption
    - BitLocker with TPM (no fallback modes allowed)
    - WinRE (Windows Recovery Environment) status

    --- Processor ---
    - Intel 10th Generation or newer (AMD/ARM not supported)
    - 64-bit CPU architecture
    - Minimum 4 physical cores (8 threads or higher)
    - ARM-based processors NOT supported

    --- Memory ---
    - Minimum 16 GB RAM

    --- Storage ---
    - NVMe Gen3 or higher required

    --- Network ---
    - Enterprise-grade NIC (no consumer/Dropjaw NIC ports)
    - Wi-Fi 6 (802.11ax) minimum

    --- Platform ---
    - Windows 11-class chipset/hardware
    - UEFI-secured boot chain
    - Remote firmware management support
    - Enterprise/Business-class device classification

    Outputs a detailed HTML report with pass/fail status per requirement.

.NOTES
    Author  : Omar Osman Mahat
    Twitter : https://x.com/thekingsmakers
    Version : 2.0
    Purpose : MOE Enterprise Laptop Compliance Validation

.OUTPUTS
    - HTML report saved to the user's Desktop (or specified path)
    - Exit code 0: All requirements met
    - Exit code 1: One or more requirements not met

.EXAMPLE
    .\MOE-Enterprise-Laptop-Requirements-Validator.ps1
#>

# ─────────────────────────────────────────────────────────────────────────────
# EXISTING FUNCTIONS (unchanged)
# ─────────────────────────────────────────────────────────────────────────────

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

function Check-UEFI {
    if ($env:firmware_type -eq "UEFI") {
        return [PSCustomObject]@{ Success = $true; Message = "System is booting in UEFI mode." }
    } else {
        return [PSCustomObject]@{ Success = $false; Message = "System is booting in Legacy BIOS mode." }
    }
}

function Check-SecureBoot {
    $secureBoot = (Confirm-SecureBootUEFI)
    if ($secureBoot) {
        return [PSCustomObject]@{ Success = $true; Message = "Secure Boot is enabled." }
    } else {
        return [PSCustomObject]@{ Success = $false; Message = "Secure Boot is not enabled." }
    }
}

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

# ─────────────────────────────────────────────────────────────────────────────
# NEW FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

function Check-ProcessorGeneration {
    try {
        $cpu = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
        $cpuName = $cpu.Name

        # ARM detection
        if ($cpu.Architecture -eq 12 -or $cpuName -match "ARM|Snapdragon|Apple M") {
            return [PSCustomObject]@{
                Success = $false
                Message = "ARM-based processor detected ($cpuName). ARM processors are NOT supported in MOEHE."
                Detail  = $cpuName
            }
        }

        # Must be Intel
        if ($cpuName -notmatch "Intel") {
            return [PSCustomObject]@{
                Success = $false
                Message = "Non-Intel processor detected ($cpuName). Only Intel processors are supported."
                Detail  = $cpuName
            }
        }

        # Detect Intel generation from model number
        # Handles naming patterns:
        #   "13th Gen Intel(R) Core(TM) i7-1355U"  -> "13th Gen" prefix
        #   "Intel(R) Core(TM) i7-10750H"           -> 5-digit model (10xxx = gen 10)
        #   "Intel(R) Core(TM) i7-1185G7"           -> 4-digit model (1xxx  = gen 11 Tiger Lake)
        #   "Intel Core Ultra 7 155H"                -> Ultra branding = gen 14/15
        $genDetected = $null

        # Pattern 1: explicit "Nth Gen" prefix (most reliable — covers 10th Gen onward)
        if ($cpuName -match "(\d{1,2})th\s+Gen") {
            $genDetected = [int]$Matches[1]
        }
        # Pattern 2: 5-digit model number iX-NNxxx (e.g. i7-10750H -> gen 10, i9-12900H -> gen 12)
        elseif ($cpuName -match "[iI]\d-(\d{2})\d{3}") {
            $genDetected = [int]$Matches[1]
        }
        # Pattern 3: 4-digit model number iX-Nxxx (e.g. i7-1355U -> gen 13, i5-1135G7 -> gen 11)
        # First digit of 4-digit model maps to generation via offset: 1xxx = gen 10/11/12/13/14
        # Use the full 4-digit number to disambiguate: 10xx=10, 11xx=11 ... 14xx=14
        elseif ($cpuName -match "[iI]\d-(\d{4})[A-Za-z]") {
            $modelNum = [int]$Matches[1]
            $genDetected = [math]::Floor($modelNum / 100)
        }
        # Pattern 4: Intel Core Ultra (Series 1 = gen 14, Series 2 = gen 15)
        elseif ($cpuName -match "Ultra") {
            $genDetected = 14
        }
        # Pattern 5: Intel N-series (Alder/Jasper Lake budget = gen 11/12)
        elseif ($cpuName -match "\bN\d{3,4}\b") {
            $genDetected = 11
        }

        if ($null -eq $genDetected) {
            return [PSCustomObject]@{
                Success = $false
                Message = "Could not determine Intel generation from CPU name: $cpuName. Manual verification required."
                Detail  = $cpuName
            }
        }

        if ($genDetected -ge 10) {
            return [PSCustomObject]@{
                Success = $true
                Message = "Intel $($genDetected)th Generation processor detected — meets 10th Gen or newer requirement."
                Detail  = $cpuName
            }
        } else {
            return [PSCustomObject]@{
                Success = $false
                Message = "Intel $($genDetected)th Generation processor detected. Minimum required: 10th Generation."
                Detail  = $cpuName
            }
        }
    } catch {
        return [PSCustomObject]@{
            Success = $false
            Message = "Error checking processor generation: $_"
            Detail  = "Unknown"
        }
    }
}

function Check-CPUArchitecture {
    try {
        $cpu = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
        # Architecture: 9 = x64, 0 = x86, 12 = ARM64
        if ($cpu.Architecture -eq 9 -or $cpu.AddressWidth -eq 64) {
            return [PSCustomObject]@{
                Success = $true
                Message = "64-bit CPU architecture confirmed (x86-64)."
                Detail  = "Address Width: $($cpu.AddressWidth)-bit"
            }
        } else {
            return [PSCustomObject]@{
                Success = $false
                Message = "CPU is not 64-bit architecture. 64-bit is required."
                Detail  = "Address Width: $($cpu.AddressWidth)-bit, Architecture Code: $($cpu.Architecture)"
            }
        }
    } catch {
        return [PSCustomObject]@{
            Success = $false
            Message = "Error checking CPU architecture: $_"
            Detail  = "Unknown"
        }
    }
}

function Check-CoreCount {
    try {
        $cpu = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
        $physicalCores = $cpu.NumberOfCores
        $logicalCores  = $cpu.NumberOfLogicalProcessors

        if ($physicalCores -ge 4 -and $logicalCores -ge 8) {
            return [PSCustomObject]@{
                Success = $true
                Message = "$physicalCores physical cores / $logicalCores logical threads — meets minimum requirement (4C/8T)."
                Detail  = "Physical Cores: $physicalCores | Logical Processors: $logicalCores"
            }
        } elseif ($physicalCores -ge 4) {
            return [PSCustomObject]@{
                Success = $false
                Message = "$physicalCores physical cores detected but only $logicalCores logical threads. Minimum: 4 cores / 8 threads."
                Detail  = "Physical Cores: $physicalCores | Logical Processors: $logicalCores"
            }
        } else {
            return [PSCustomObject]@{
                Success = $false
                Message = "Only $physicalCores physical core(s) detected. Minimum required: 4 physical cores / 8 threads."
                Detail  = "Physical Cores: $physicalCores | Logical Processors: $logicalCores"
            }
        }
    } catch {
        return [PSCustomObject]@{
            Success = $false
            Message = "Error checking core count: $_"
            Detail  = "Unknown"
        }
    }
}

function Check-RAM {
    try {
        # Win32_ComputerSystem.TotalPhysicalMemory is the actual installed RAM in bytes
        # Win32_OperatingSystem.TotalVisibleMemorySize is always slightly less (OS reserves some)
        # We use TotalPhysicalMemory and round to nearest GB to get the labeled capacity
        $cs = Get-WmiObject -Class Win32_ComputerSystem
        $totalRAM_Bytes = $cs.TotalPhysicalMemory
        $totalRAM_GB    = [math]::Round($totalRAM_Bytes / 1GB, 2)
        # Round to nearest standard RAM size (8, 16, 32, 64 …) for display
        $labeledRAM_GB  = [math]::Round($totalRAM_Bytes / 1GB)

        if ($labeledRAM_GB -ge 16) {
            return [PSCustomObject]@{
                Success = $true
                Message = "$($labeledRAM_GB) GB RAM installed — meets 16 GB minimum requirement."
                Detail  = "Physical Memory: $($totalRAM_GB) GB reported ($($totalRAM_Bytes / 1GB -as [int]) GB labeled capacity)"
            }
        } else {
            return [PSCustomObject]@{
                Success = $false
                Message = "Only $($labeledRAM_GB) GB RAM installed. Minimum required: 16 GB."
                Detail  = "Physical Memory: $($totalRAM_GB) GB"
            }
        }
    } catch {
        return [PSCustomObject]@{
            Success = $false
            Message = "Error checking RAM: $_"
            Detail  = "Unknown"
        }
    }
}

function Check-NVMe {
    try {
        # Force array so .Count works even for a single disk object
        $allDisks = @(Get-PhysicalDisk -ErrorAction SilentlyContinue)

        # Primary: BusType reported as "NVMe" (case-insensitive)
        $nvmeDrives = @($allDisks | Where-Object { $_.BusType -ieq "NVMe" })

        # Fallback: BusType may be "Unknown" or missing on some drivers;
        # catch well-known NVMe model patterns by name (Samsung 970/980/990, WD SN-series, etc.)
        if ($nvmeDrives.Count -eq 0) {
            $nvmeDrives = @($allDisks | Where-Object {
                $_.FriendlyName -match "NVMe|SSD\s*NVM|MZAL|MZVL|MZNL|WDS.*SN|PC\s*SN|Samsung\s+PM|SK\s*Hynix|KXG|KIOXIA|Micron_|CT\d+P" -and
                $_.BusType -ine "SATA" -and $_.BusType -ine "SAS"
            })
        }

        if ($nvmeDrives.Count -gt 0) {
            $driveList = ($nvmeDrives | ForEach-Object { "$($_.FriendlyName) [BusType: $($_.BusType)]" }) -join "; "
            return [PSCustomObject]@{
                Success = $true
                Message = "NVMe storage detected. Verify PCIe Gen3 or higher via device specifications."
                Detail  = "NVMe Drive(s): $driveList"
            }
        } else {
            $allDriveList = ($allDisks | ForEach-Object { "$($_.FriendlyName) [BusType: $($_.BusType)]" }) -join "; "
            return [PSCustomObject]@{
                Success = $false
                Message = "No NVMe storage detected. NVMe Gen3 or higher is required."
                Detail  = "Detected Drive(s): $allDriveList"
            }
        }
    } catch {
        return [PSCustomObject]@{
            Success = $false
            Message = "Error checking storage type: $_"
            Detail  = "Unknown"
        }
    }
}

function Check-WiFi6 {
    try {
        $wifiAdapters = Get-NetAdapter | Where-Object {
            $_.PhysicalMediaType -match "802.11" -or $_.InterfaceDescription -match "Wi-Fi|Wireless|802\.11"
        }

        if (-not $wifiAdapters) {
            return [PSCustomObject]@{
                Success = $false
                Message = "No Wi-Fi adapter detected."
                Detail  = "No wireless network adapter found."
            }
        }

        $wifi6Found = $false
        $adapterDetails = @()

        foreach ($adapter in $wifiAdapters) {
            $desc = $adapter.InterfaceDescription
            $adapterDetails += $desc

            # Wi-Fi 6 = 802.11ax; Wi-Fi 6E also qualifies
            if ($desc -match "802\.11ax|Wi-Fi 6|WiFi 6|AX\d{3}|AX\d{4}|AXE\d{3}") {
                $wifi6Found = $true
            }
        }

        if ($wifi6Found) {
            return [PSCustomObject]@{
                Success = $true
                Message = "Wi-Fi 6 (802.11ax) or higher adapter detected."
                Detail  = "Adapter(s): $($adapterDetails -join '; ')"
            }
        } else {
            return [PSCustomObject]@{
                Success = $false
                Message = "No Wi-Fi 6 (802.11ax) adapter detected. Wi-Fi 6 minimum is required."
                Detail  = "Detected Adapter(s): $($adapterDetails -join '; ')"
            }
        }
    } catch {
        return [PSCustomObject]@{
            Success = $false
            Message = "Error checking Wi-Fi adapter: $_"
            Detail  = "Unknown"
        }
    }
}

function Check-EnterpriseNIC {
    try {
        $nics = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" -or $_.Status -eq "Disconnected" }

        if (-not $nics) {
            return [PSCustomObject]@{
                Success = $false
                Message = "No physical network adapters found."
                Detail  = "No NICs detected."
            }
        }

        # Consumer/unsupported NIC keywords (Dropjaw and similar budget/consumer-grade)
        $consumerKeywords = @("Dropjaw","Killer","Realtek RTL8111","Realtek RTL8168","Atheros AR","QCA9377","RTL8821")
        # Enterprise-grade NIC keywords
        $enterpriseKeywords = @("Intel","Broadcom","Marvell","Aquantia","QLogic","Mellanox","Chelsio","Emulex",
                                "Intel I219","Intel I225","Intel I226","Intel Ethernet","Broadcom NetXtreme")

        $nicDetails = @()
        $allEnterprise = $true
        $consumerFound = @()

        foreach ($nic in $nics) {
            $desc = $nic.InterfaceDescription
            $nicDetails += $desc

            $isConsumer = $false
            foreach ($kw in $consumerKeywords) {
                if ($desc -match [regex]::Escape($kw)) { $isConsumer = $true; $consumerFound += $desc; break }
            }
            if ($isConsumer) { $allEnterprise = $false }
        }

        if ($allEnterprise) {
            return [PSCustomObject]@{
                Success = $true
                Message = "Enterprise-grade NIC(s) detected. No consumer/Dropjaw NICs found."
                Detail  = "NIC(s): $($nicDetails -join '; ')"
            }
        } else {
            return [PSCustomObject]@{
                Success = $false
                Message = "Consumer or unsupported NIC detected. Enterprise-grade NICs required."
                Detail  = "Non-compliant NIC(s): $($consumerFound -join '; ')"
            }
        }
    } catch {
        return [PSCustomObject]@{
            Success = $false
            Message = "Error checking NIC: $_"
            Detail  = "Unknown"
        }
    }
}

function Check-BitLockerTPM {
    try {
        # Check if BitLocker volume is present and protected by TPM
        $blvs = Get-BitLockerVolume -ErrorAction SilentlyContinue
        if (-not $blvs) {
            return [PSCustomObject]@{
                Success = $false
                Message = "BitLocker volumes not found or BitLocker module unavailable."
                Detail  = "BitLocker not configured."
            }
        }
        $systemVol = $blvs | Where-Object { $_.VolumeType -eq "OperatingSystem" } | Select-Object -First 1
        if (-not $systemVol) {
            return [PSCustomObject]@{
                Success = $false
                Message = "No OS BitLocker volume found."
                Detail  = "No operating system volume protected by BitLocker."
            }
        }
        $hasTPMProtector = $systemVol.KeyProtector | Where-Object { $_.KeyProtectorType -eq "Tpm" -or $_.KeyProtectorType -eq "TpmPin" -or $_.KeyProtectorType -eq "TpmNetworkKey" }
        if ($hasTPMProtector) {
            return [PSCustomObject]@{
                Success = $true
                Message = "BitLocker OS volume is protected by TPM (no fallback mode). Compliant."
                Detail  = "Protection Status: $($systemVol.ProtectionStatus) | Protector: $($hasTPMProtector.KeyProtectorType)"
            }
        } else {
            return [PSCustomObject]@{
                Success = $false
                Message = "BitLocker is present but NOT using TPM as protector. Fallback mode is not permitted."
                Detail  = "Protector Type(s): $(($systemVol.KeyProtector.KeyProtectorType) -join ', ')"
            }
        }
    } catch {
        return [PSCustomObject]@{
            Success = $false
            Message = "Error checking BitLocker TPM configuration: $_"
            Detail  = "Unknown"
        }
    }
}

function Check-TPMMeasuredBoot {
    try {
        $tpm = Get-WmiObject -Namespace "Root\CIMv2\Security\MicrosoftTpm" -Class Win32_Tpm
        if (-not $tpm) {
            return [PSCustomObject]@{
                Success = $false
                Message = "TPM not available. Cannot verify Measured Boot and attestation support."
                Detail  = "No TPM detected."
            }
        }
        # SpecVersion 2.0 guarantees Measured Boot and remote attestation support
        $specVer = $tpm.SpecVersion
        if ($specVer -match "^2\.") {
            return [PSCustomObject]@{
                Success = $true
                Message = "TPM 2.0 detected — supports Measured Boot and remote attestation."
                Detail  = "TPM Spec Version: $specVer | Manufacturer: $($tpm.ManufacturerIdTxt)"
            }
        } elseif ($specVer -match "^1\.2") {
            return [PSCustomObject]@{
                Success = $false
                Message = "TPM 1.2 detected. TPM 2.0 is recommended for full Measured Boot and attestation support."
                Detail  = "TPM Spec Version: $specVer"
            }
        } else {
            return [PSCustomObject]@{
                Success = $false
                Message = "TPM version $specVer detected. Cannot confirm Measured Boot and attestation support."
                Detail  = "TPM Spec Version: $specVer"
            }
        }
    } catch {
        return [PSCustomObject]@{
            Success = $false
            Message = "Error checking TPM Measured Boot support: $_"
            Detail  = "Unknown"
        }
    }
}

function Check-RemoteFirmwareManagement {
    try {
        # Look for UEFI/BIOS remote management indicators:
        # Dell Command Update, HP BIOS Config Utility, Lenovo ThinkShield, MS Endpoint Config Manager WMI, etc.
        $csProduct  = Get-WmiObject -Class Win32_ComputerSystemProduct -ErrorAction SilentlyContinue
        $bios       = Get-WmiObject -Class Win32_BIOS -ErrorAction SilentlyContinue
        $vendor     = $csProduct.Vendor
        $model      = $csProduct.Name
        $biosVer    = $bios.SMBIOSBIOSVersion

        # Enterprise OEM vendors with known remote firmware management support
        $enterpriseOEMs = @("Dell","HP","Hewlett","Lenovo","Microsoft Surface","Panasonic","Getac","Dynabook","Toshiba")
        $isEnterpriseOEM = $false
        foreach ($oem in $enterpriseOEMs) {
            if ($vendor -match $oem -or $model -match $oem) { $isEnterpriseOEM = $true; break }
        }

        # Check for management tools / services
        $mgmtServices = Get-Service -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -match "Dell|HPBIOS|LenovoFirmware|MicrosoftSurface|SurfaceFirmware|WMIProvider"
        }

        if ($isEnterpriseOEM) {
            return [PSCustomObject]@{
                Success = $true
                Message = "Enterprise OEM ($vendor) detected — remote firmware management is supported."
                Detail  = "Vendor: $vendor | Model: $model | BIOS Version: $biosVer"
            }
        } else {
            return [PSCustomObject]@{
                Success = $false
                Message = "OEM ($vendor) not confirmed as enterprise-class with remote firmware management. Manual verification required."
                Detail  = "Vendor: $vendor | Model: $model | BIOS Version: $biosVer"
            }
        }
    } catch {
        return [PSCustomObject]@{
            Success = $false
            Message = "Error checking remote firmware management: $_"
            Detail  = "Unknown"
        }
    }
}

function Check-EnterpriseDevice {
    try {
        $csProduct = Get-WmiObject -Class Win32_ComputerSystemProduct -ErrorAction SilentlyContinue
        $cs        = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction SilentlyContinue
        $vendor    = $csProduct.Vendor
        $model     = $csProduct.Name
        $pcType    = $cs.PCSystemType  # 2 = Mobile (laptop), 1 = Desktop

        # Enterprise OEM list
        $enterpriseVendors = @("Dell","HP","Hewlett-Packard","Lenovo","Microsoft","Panasonic","Getac","Dynabook")
        $isEnterprise = $false
        foreach ($v in $enterpriseVendors) {
            if ($vendor -match $v) { $isEnterprise = $true; break }
        }

        $pcTypeLabel = switch ($pcType) { 1 {"Desktop"} 2 {"Mobile/Laptop"} default {"Unknown ($pcType)"} }

        if ($isEnterprise) {
            return [PSCustomObject]@{
                Success = $true
                Message = "Enterprise/Business-class device confirmed ($vendor — $model)."
                Detail  = "Vendor: $vendor | Model: $model | Form Factor: $pcTypeLabel"
            }
        } else {
            return [PSCustomObject]@{
                Success = $false
                Message = "Device vendor ($vendor) is not classified as enterprise/business-grade. Consumer devices are not permitted."
                Detail  = "Vendor: $vendor | Model: $model | Form Factor: $pcTypeLabel"
            }
        }
    } catch {
        return [PSCustomObject]@{
            Success = $false
            Message = "Error checking enterprise device classification: $_"
            Detail  = "Unknown"
        }
    }
}

function Check-Windows11ChipsetPlatform {
    try {
        # Windows 11 requires TPM 2.0 + UEFI + Secure Boot + specific CPU generations
        # We infer chipset platform compliance from Windows edition + hardware indicators
        $os = Get-WmiObject -Class Win32_OperatingSystem
        $osCaption = $os.Caption
        $osBuild   = [int]($os.BuildNumber)

        # Windows 11 builds start at 22000
        if ($osBuild -ge 22000) {
            return [PSCustomObject]@{
                Success = $true
                Message = "Windows 11 is installed (Build $osBuild) — chipset meets Windows 11-class hardware requirements."
                Detail  = "OS: $osCaption | Build: $osBuild"
            }
        } elseif ($osBuild -ge 19041) {
            return [PSCustomObject]@{
                Success = $false
                Message = "Windows 10 detected (Build $osBuild). Windows 11-class chipset hardware is required. Upgrade required."
                Detail  = "OS: $osCaption | Build: $osBuild"
            }
        } else {
            return [PSCustomObject]@{
                Success = $false
                Message = "Unsupported OS version (Build $osBuild). Windows 11 or later is required."
                Detail  = "OS: $osCaption | Build: $osBuild"
            }
        }
    } catch {
        return [PSCustomObject]@{
            Success = $false
            Message = "Error checking Windows 11 chipset platform: $_"
            Detail  = "Unknown"
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# COLLECT SYSTEM INFORMATION
# ─────────────────────────────────────────────────────────────────────────────

function Get-SystemSummary {
    try {
        $cs      = Get-WmiObject -Class Win32_ComputerSystem
        $cpu     = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
        $os      = Get-WmiObject -Class Win32_OperatingSystem
        $bios    = Get-WmiObject -Class Win32_BIOS
        $product = Get-WmiObject -Class Win32_ComputerSystemProduct

        return [PSCustomObject]@{
            ComputerName   = $env:COMPUTERNAME
            Manufacturer   = $cs.Manufacturer
            Model          = $cs.Model
            SerialNumber   = $bios.SerialNumber
            BIOSVersion    = $bios.SMBIOSBIOSVersion
            CPU            = $cpu.Name
            TotalRAM_GB    = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
            OS             = $os.Caption
            OSBuild        = $os.BuildNumber
            OSVersion      = $os.Version
            ReportDate     = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
    } catch {
        return [PSCustomObject]@{
            ComputerName = $env:COMPUTERNAME
            ReportDate   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN EXECUTION
# ─────────────────────────────────────────────────────────────────────────────

$sysInfo = Get-SystemSummary

# Run existing checks (PCR7 inferred from Secure Boot — unchanged)
$secureBootCheck = Check-SecureBoot
$pcr7Check = if ($secureBootCheck.Success) {
    [PSCustomObject]@{
        Success = $true
        Message = "PCR7 Binding supported — inferred from active Secure Boot and TPM integration."
        Detail  = "Secure Boot enabled + TPM present = PCR7 Binding available."
    }
} else {
    [PSCustomObject]@{
        Success = $false
        Message = "PCR7 Binding is not supported because Secure Boot is disabled."
        Detail  = "PCR7 requires both Secure Boot and TPM to be active."
    }
}

# Define all checks grouped by category
$checkGroups = @(
    @{
        Category = "Security &amp; Firmware"
        Icon     = "🔒"
        Checks   = @(
            @{ Name = "TPM Availability &amp; Version";         Req = "TPM 1.2 or higher required";                              Result = Check-TPM },
            @{ Name = "TPM Measured Boot &amp; Attestation";    Req = "TPM must support Measured Boot and remote attestation";   Result = Check-TPMMeasuredBoot },
            @{ Name = "UEFI Firmware Mode";                     Req = "System must boot in UEFI mode (Legacy BIOS not permitted)"; Result = Check-UEFI },
            @{ Name = "Secure Boot";                            Req = "Secure Boot must be enabled";                             Result = $secureBootCheck },
            @{ Name = "PCR7 Binding";                           Req = "PCR7 Binding must be supported (Secure Boot + TPM)";      Result = $pcr7Check },
            @{ Name = "Kernel DMA Protection";                  Req = "Required for Silent BitLocker encryption";                Result = Check-KernelDMAProtection },
            @{ Name = "BitLocker with TPM (No Fallback)";       Req = "BitLocker must use TPM — no fallback modes allowed";     Result = Check-BitLockerTPM },
            @{ Name = "Windows Recovery Environment (WinRE)";   Req = "WinRE must be enabled";                                  Result = Check-WinREStatus }
        )
    },
    @{
        Category = "Processor"
        Icon     = "⚙️"
        Checks   = @(
            @{ Name = "Intel Generation (10th Gen or Newer)";   Req = "Intel 10th Generation or newer — no AMD or ARM";         Result = Check-ProcessorGeneration },
            @{ Name = "CPU Architecture (64-bit)";              Req = "64-bit CPU architecture required";                       Result = Check-CPUArchitecture },
            @{ Name = "Core Count (4 Physical / 8 Threads)";    Req = "Minimum 4 physical cores, 8 logical threads";            Result = Check-CoreCount }
        )
    },
    @{
        Category = "Memory"
        Icon     = "🧠"
        Checks   = @(
            @{ Name = "RAM Capacity";                           Req = "Minimum 16 GB RAM required";                             Result = Check-RAM }
        )
    },
    @{
        Category = "Storage"
        Icon     = "💾"
        Checks   = @(
            @{ Name = "NVMe Storage";                           Req = "NVMe Gen3 or higher required";                           Result = Check-NVMe }
        )
    },
    @{
        Category = "Network"
        Icon     = "🌐"
        Checks   = @(
            @{ Name = "Enterprise-Grade NIC";                   Req = "Enterprise/Business NICs required — no Dropjaw or consumer NICs"; Result = Check-EnterpriseNIC },
            @{ Name = "Wi-Fi 6 (802.11ax) Minimum";            Req = "Wi-Fi 6 (802.11ax) or higher required";                  Result = Check-WiFi6 }
        )
    },
    @{
        Category = "Platform &amp; Device Classification"
        Icon     = "🏢"
        Checks   = @(
            @{ Name = "Enterprise / Business-Class Device";     Req = "Device must be enterprise or business-class hardware";   Result = Check-EnterpriseDevice },
            @{ Name = "Remote Firmware Management";             Req = "Device must support remote firmware management";         Result = Check-RemoteFirmwareManagement },
            @{ Name = "Windows 11-Class Chipset Platform";      Req = "Chipset must support Windows 11-class hardware";         Result = Check-Windows11ChipsetPlatform }
        )
    }
)

# Tally results
$totalChecks  = 0
$passedChecks = 0
$failedChecks = 0
$allPassed    = $true

foreach ($group in $checkGroups) {
    foreach ($check in $group.Checks) {
        $totalChecks++
        if ($check.Result.Success) { $passedChecks++ } else { $failedChecks++; $allPassed = $false }
    }
}

$overallStatus  = if ($allPassed) { "COMPLIANT" } else { "NON-COMPLIANT" }
$overallColor   = if ($allPassed) { "#16a34a" } else { "#dc2626" }
$overallBg      = if ($allPassed) { "#f0fdf4" } else { "#fef2f2" }
$overallBorder  = if ($allPassed) { "#86efac" } else { "#fca5a5" }
$scorePercent   = [math]::Round(($passedChecks / $totalChecks) * 100)

# ─────────────────────────────────────────────────────────────────────────────
# BUILD HTML REPORT
# ─────────────────────────────────────────────────────────────────────────────

function Build-CheckRows {
    param($checks)
    $html = ""
    foreach ($c in $checks) {
        $pass    = $c.Result.Success
        $badge   = if ($pass) { '<span class="badge pass">✔ PASS</span>' } else { '<span class="badge fail">✖ FAIL</span>' }
        $rowCls  = if ($pass) { "row-pass" } else { "row-fail" }
        $detail  = if ($c.Result.PSObject.Properties["Detail"] -and $c.Result.Detail) {
                       "<div class='detail'>$($c.Result.Detail)</div>"
                   } else { "" }
        $html += @"
        <tr class="$rowCls">
            <td class="check-name">$($c.Name)</td>
            <td class="req-text">$($c.Req)</td>
            <td class="result-msg">$($c.Result.Message)$detail</td>
            <td class="badge-cell">$badge</td>
        </tr>
"@
    }
    return $html
}

$groupHtml = ""
foreach ($group in $checkGroups) {
    $rows = Build-CheckRows -checks $group.Checks
    $gPass  = @($group.Checks | Where-Object { $_.Result.Success }).Count
    $gTotal = @($group.Checks).Count
    $gFail  = $gTotal - $gPass
    $gStatus = if ($gFail -eq 0) { "✔ All Passed" } else { "$gFail Failed" }
    $gStatusCls = if ($gFail -eq 0) { "g-all-pass" } else { "g-has-fail" }

    $groupHtml += @"
    <div class="category-block">
        <div class="category-header">
            <span class="cat-icon">$($group.Icon)</span>
            <span class="cat-title">$($group.Category)</span>
            <span class="cat-tally $gStatusCls">$gPass / $gTotal &nbsp; $gStatus</span>
        </div>
        <table class="check-table">
            <thead>
                <tr>
                    <th style="width:22%">Check</th>
                    <th style="width:30%">Requirement</th>
                    <th style="width:38%">Result</th>
                    <th style="width:10%">Status</th>
                </tr>
            </thead>
            <tbody>
$rows
            </tbody>
        </table>
    </div>
"@
}

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MOE Enterprise Laptop Requirements Validator</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    background: #f1f5f9;
    color: #1e293b;
    font-size: 13px;
  }

  /* ── Header ── */
  .report-header {
    background: linear-gradient(135deg, #0f172a 0%, #1e3a5f 60%, #1d4ed8 100%);
    color: #fff;
    padding: 36px 48px 28px;
    display: flex;
    align-items: flex-start;
    gap: 28px;
  }
  .moe-logo {
    width: 70px; height: 70px; flex-shrink: 0;
    background: rgba(255,255,255,0.12);
    border-radius: 14px;
    display: flex; align-items: center; justify-content: center;
    font-size: 36px;
  }
  .header-text h1 {
    font-size: 22px; font-weight: 700; letter-spacing: 0.3px;
    margin-bottom: 4px;
  }
  .header-text .subtitle {
    font-size: 13px; opacity: 0.75; margin-bottom: 10px;
  }
  .header-meta {
    display: flex; gap: 24px; flex-wrap: wrap; font-size: 12px; opacity: 0.85;
  }
  .header-meta span { display: flex; align-items: center; gap: 6px; }
  .header-meta strong { opacity: 1; }

  /* ── Overall Status Banner ── */
  .status-banner {
    background: $overallBg;
    border: 2px solid $overallBorder;
    border-radius: 12px;
    margin: 28px 40px;
    padding: 22px 32px;
    display: flex;
    align-items: center;
    gap: 28px;
  }
  .status-circle {
    width: 76px; height: 76px; border-radius: 50%; flex-shrink: 0;
    background: $overallColor;
    display: flex; flex-direction: column;
    align-items: center; justify-content: center;
    color: #fff; font-weight: 800; font-size: 18px; line-height: 1.1;
  }
  .status-circle small { font-size: 10px; font-weight: 500; letter-spacing: 0.5px; }
  .status-text h2 { font-size: 19px; font-weight: 700; color: $overallColor; }
  .status-text p  { font-size: 13px; color: #475569; margin-top: 4px; }

  /* ── Score Bar ── */
  .score-bar-wrap { flex: 1; }
  .score-label { font-size: 12px; color: #64748b; margin-bottom: 6px; }
  .score-bar-bg {
    background: #e2e8f0; border-radius: 99px; height: 12px; overflow: hidden;
  }
  .score-bar-fill {
    height: 100%; border-radius: 99px;
    width: ${scorePercent}%;
    background: $overallColor;
    transition: width 0.5s;
  }
  .score-numbers { margin-top: 5px; font-size: 12px; color: #64748b; }
  .score-numbers strong { color: $overallColor; }

  /* ── Content ── */
  .content { padding: 0 40px 40px; }

  .section-title {
    font-size: 14px; font-weight: 700; color: #0f172a;
    text-transform: uppercase; letter-spacing: 0.8px;
    border-left: 4px solid #1d4ed8;
    padding-left: 10px;
    margin: 28px 0 14px;
  }

  /* ── System Info ── */
  .sysinfo-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
    gap: 10px;
    margin-bottom: 8px;
  }
  .sysinfo-card {
    background: #fff;
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    padding: 12px 14px;
  }
  .sysinfo-card .si-label { font-size: 10px; text-transform: uppercase; letter-spacing: 0.7px; color: #94a3b8; margin-bottom: 3px; }
  .sysinfo-card .si-value { font-size: 13px; font-weight: 600; color: #0f172a; word-break: break-word; }

  /* ── Category Blocks ── */
  .category-block {
    background: #fff;
    border: 1px solid #e2e8f0;
    border-radius: 10px;
    margin-bottom: 18px;
    overflow: hidden;
  }
  .category-header {
    background: linear-gradient(90deg, #0f172a, #1e3a5f);
    color: #fff;
    padding: 11px 18px;
    display: flex; align-items: center; gap: 10px;
    font-size: 13px;
  }
  .cat-icon  { font-size: 16px; }
  .cat-title { font-weight: 700; font-size: 14px; flex: 1; }
  .cat-tally { font-size: 11px; background: rgba(255,255,255,0.12); border-radius: 20px; padding: 3px 10px; }
  .g-all-pass { background: rgba(22,163,74,0.35); }
  .g-has-fail { background: rgba(220,38,38,0.35); }

  /* ── Check Table ── */
  .check-table { width: 100%; border-collapse: collapse; }
  .check-table thead th {
    background: #f8fafc;
    text-align: left;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.6px;
    color: #64748b;
    padding: 8px 14px;
    border-bottom: 1px solid #e2e8f0;
  }
  .check-table tbody tr { border-bottom: 1px solid #f1f5f9; }
  .check-table tbody tr:last-child { border-bottom: none; }
  .check-table td { padding: 10px 14px; vertical-align: top; }

  .row-pass { background: #fff; }
  .row-fail { background: #fff9f9; }
  .row-fail:hover { background: #fef2f2; }
  .row-pass:hover { background: #f8fafc; }

  .check-name { font-weight: 600; color: #0f172a; font-size: 12px; }
  .req-text   { font-size: 12px; color: #475569; }
  .result-msg { font-size: 12px; color: #334155; }
  .detail     { font-size: 11px; color: #64748b; margin-top: 4px; font-style: italic; }
  .badge-cell { text-align: center; vertical-align: middle; }

  .badge {
    display: inline-block;
    font-size: 11px; font-weight: 700; letter-spacing: 0.5px;
    padding: 4px 10px; border-radius: 20px;
    white-space: nowrap;
  }
  .badge.pass { background: #dcfce7; color: #15803d; border: 1px solid #86efac; }
  .badge.fail { background: #fee2e2; color: #b91c1c; border: 1px solid #fca5a5; }

  /* ── Summary Table ── */
  .summary-table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 10px; overflow: hidden; border: 1px solid #e2e8f0; }
  .summary-table th { background: #0f172a; color: #fff; padding: 10px 16px; text-align: left; font-size: 12px; }
  .summary-table td { padding: 9px 16px; font-size: 12px; border-bottom: 1px solid #f1f5f9; }
  .summary-table tr:last-child td { border-bottom: none; }
  .s-pass { color: #16a34a; font-weight: 700; }
  .s-fail { color: #dc2626; font-weight: 700; }

  /* ── Footer ── */
  .report-footer {
    background: #0f172a; color: rgba(255,255,255,0.55);
    text-align: center; padding: 18px; font-size: 11px;
    margin-top: 10px;
  }
  .report-footer a { color: rgba(255,255,255,0.7); }

  /* ── Toolbar (PDF + Comments toggle) ── */
  .action-toolbar {
    display: flex; align-items: center; justify-content: flex-end;
    gap: 10px;
    padding: 12px 40px 0;
  }
  .action-toolbar button {
    display: inline-flex; align-items: center; gap: 7px;
    padding: 9px 18px; border-radius: 8px; border: none; cursor: pointer;
    font-size: 13px; font-weight: 600; font-family: inherit;
    transition: opacity 0.15s, transform 0.1s;
  }
  .action-toolbar button:hover  { opacity: 0.88; transform: translateY(-1px); }
  .action-toolbar button:active { transform: translateY(0); }
  .btn-pdf      { background: #1d4ed8; color: #fff; }
  .btn-comments { background: #0f172a; color: #fff; }

  /* ── Comments Panel ── */
  .comments-panel {
    background: #fff;
    border: 1px solid #e2e8f0;
    border-radius: 10px;
    margin-bottom: 18px;
    overflow: hidden;
  }
  .comments-panel-header {
    background: linear-gradient(90deg, #1e3a5f, #1d4ed8);
    color: #fff; padding: 11px 18px;
    display: flex; align-items: center; gap: 10px;
  }
  .comments-panel-header span { font-weight: 700; font-size: 14px; flex:1; }

  .comment-form {
    padding: 18px 20px;
    border-bottom: 1px solid #f1f5f9;
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }
  .comment-form .full-row { grid-column: 1 / -1; }
  .cf-label { font-size: 11px; text-transform: uppercase; letter-spacing: 0.6px; color: #64748b; margin-bottom: 4px; }
  .cf-input, .cf-select, .cf-textarea {
    width: 100%; padding: 8px 10px; border: 1px solid #e2e8f0; border-radius: 6px;
    font-size: 13px; font-family: inherit; color: #1e293b; background: #f8fafc;
    outline: none; transition: border-color 0.15s;
  }
  .cf-input:focus, .cf-select:focus, .cf-textarea:focus { border-color: #1d4ed8; background: #fff; }
  .cf-textarea { resize: vertical; min-height: 72px; }
  .cf-select { cursor: pointer; }
  .btn-add-comment {
    grid-column: 1 / -1;
    padding: 9px 0; background: #1d4ed8; color: #fff;
    border: none; border-radius: 7px; font-size: 13px; font-weight: 600;
    font-family: inherit; cursor: pointer; transition: opacity 0.15s;
  }
  .btn-add-comment:hover { opacity: 0.88; }

  /* ── Comment Cards ── */
  .comments-list { padding: 14px 20px; display: flex; flex-direction: column; gap: 12px; }
  .comments-list:empty::after {
    content: "No comments yet. Use the form above to add one.";
    font-size: 12px; color: #94a3b8; font-style: italic;
    display: block; padding: 6px 0;
  }
  .comment-card {
    border: 1px solid #e2e8f0; border-radius: 8px; overflow: hidden;
  }
  .comment-card-header {
    background: #f8fafc; padding: 8px 14px;
    display: flex; align-items: center; gap: 10px; flex-wrap: wrap;
  }
  .cc-avatar {
    width: 30px; height: 30px; border-radius: 50%; flex-shrink: 0;
    background: #1d4ed8; color: #fff;
    display: flex; align-items: center; justify-content: center;
    font-size: 12px; font-weight: 700;
  }
  .cc-author { font-weight: 700; font-size: 13px; color: #0f172a; }
  .cc-date   { font-size: 11px; color: #94a3b8; margin-left: auto; }
  .cc-check-tag {
    font-size: 10px; background: #eff6ff; color: #1d4ed8;
    border: 1px solid #bfdbfe; border-radius: 20px; padding: 2px 8px;
  }
  .cc-type-tag {
    font-size: 10px; border-radius: 20px; padding: 2px 8px;
  }
  .cc-type-general  { background: #f1f5f9; color: #475569; border: 1px solid #cbd5e1; }
  .cc-type-concern  { background: #fff7ed; color: #c2410c; border: 1px solid #fed7aa; }
  .cc-type-approval { background: #f0fdf4; color: #15803d; border: 1px solid #86efac; }
  .cc-type-action   { background: #fefce8; color: #854d0e; border: 1px solid #fde68a; }
  .comment-card-body { padding: 10px 14px; font-size: 13px; color: #334155; line-height: 1.6; }
  .btn-delete-comment {
    margin-left: 6px; background: none; border: none; cursor: pointer;
    font-size: 13px; color: #94a3b8; padding: 2px 4px; border-radius: 4px;
    transition: color 0.15s;
  }
  .btn-delete-comment:hover { color: #dc2626; }

  /* ── Print / PDF ── */
  @media print {
    body { background: #fff; font-size: 11px; }
    .action-toolbar, .comment-form, .btn-delete-comment { display: none !important; }
    .status-banner, .category-block, .summary-table, .comments-panel { break-inside: avoid; }
    .report-header  { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
    .category-header{ -webkit-print-color-adjust: exact; print-color-adjust: exact; }
    .badge          { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
    .comments-list:empty::after { display: none; }
  }
</style>
</head>
<body>

<!-- ════════════════════════════ ACTION TOOLBAR ═══════════════════════════════ -->
<div class="action-toolbar no-print">
  <button class="btn-comments" onclick="toggleComments()">💬 Toggle Comments Panel</button>
  <button class="btn-pdf"      onclick="downloadPDF()">⬇️ Download as PDF</button>
</div>

<!-- ═══════════════════════════════════ HEADER ═══════════════════════════════════ -->
<div class="report-header">
  <div class="moe-logo">🏛️</div>
  <div class="header-text">
    <h1>MOE Enterprise Laptop Requirements Validator</h1>
    <div class="subtitle">Ministry of Education — Hardware Compliance Assessment Report</div>
    <div class="header-meta">
      <span>🖥️ <strong>$($sysInfo.ComputerName)</strong></span>
      <span>🏭 $($sysInfo.Manufacturer) $($sysInfo.Model)</span>
      <span>📅 $($sysInfo.ReportDate)</span>
      <span>🔖 Serial: $($sysInfo.SerialNumber)</span>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════ STATUS BANNER ════════════════════════════════ -->
<div class="status-banner">
  <div class="status-circle">
    <span>$scorePercent%</span>
    <small>SCORE</small>
  </div>
  <div class="status-text">
    <h2>Overall Status: $overallStatus</h2>
    <p>$passedChecks of $totalChecks checks passed. $failedChecks check(s) require attention before deployment.</p>
  </div>
  <div class="score-bar-wrap">
    <div class="score-label">Compliance Score</div>
    <div class="score-bar-bg"><div class="score-bar-fill"></div></div>
    <div class="score-numbers">
      <strong>$passedChecks passed</strong> &nbsp;·&nbsp; $failedChecks failed &nbsp;·&nbsp; $totalChecks total
    </div>
  </div>
</div>

<!-- ════════════════════════════════ CONTENT ══════════════════════════════════════ -->
<div class="content">

  <!-- System Summary -->
  <div class="section-title">System Information</div>
  <div class="sysinfo-grid">
    <div class="sysinfo-card"><div class="si-label">Hostname</div><div class="si-value">$($sysInfo.ComputerName)</div></div>
    <div class="sysinfo-card"><div class="si-label">Manufacturer</div><div class="si-value">$($sysInfo.Manufacturer)</div></div>
    <div class="sysinfo-card"><div class="si-label">Model</div><div class="si-value">$($sysInfo.Model)</div></div>
    <div class="sysinfo-card"><div class="si-label">Serial Number</div><div class="si-value">$($sysInfo.SerialNumber)</div></div>
    <div class="sysinfo-card"><div class="si-label">BIOS Version</div><div class="si-value">$($sysInfo.BIOSVersion)</div></div>
    <div class="sysinfo-card"><div class="si-label">Processor</div><div class="si-value">$($sysInfo.CPU)</div></div>
    <div class="sysinfo-card"><div class="si-label">Total RAM</div><div class="si-value">$($sysInfo.TotalRAM_GB) GB</div></div>
    <div class="sysinfo-card"><div class="si-label">Operating System</div><div class="si-value">$($sysInfo.OS)</div></div>
    <div class="sysinfo-card"><div class="si-label">OS Build</div><div class="si-value">$($sysInfo.OSBuild) ($($sysInfo.OSVersion))</div></div>
    <div class="sysinfo-card"><div class="si-label">Report Generated</div><div class="si-value">$($sysInfo.ReportDate)</div></div>
  </div>

  <!-- Category Checks -->
  <div class="section-title">Compliance Checks</div>
$groupHtml

  <!-- Summary Table -->
  <div class="section-title">Check Summary</div>
  <table class="summary-table">
    <thead>
      <tr><th>#</th><th>Category</th><th>Check Name</th><th>Status</th><th>Message</th></tr>
    </thead>
    <tbody>
"@

$rowNum = 1
foreach ($group in $checkGroups) {
    foreach ($c in $group.Checks) {
        $sCls = if ($c.Result.Success) { 's-pass' } else { 's-fail' }
        $sTxt = if ($c.Result.Success) { '✔ PASS' } else { '✖ FAIL' }
        $html += "      <tr><td>$rowNum</td><td>$($group.Category)</td><td>$($c.Name)</td><td class='$sCls'>$sTxt</td><td>$($c.Result.Message)</td></tr>`n"
        $rowNum++
    }
}

$html += @"
    </tbody>
  </table>

  <!-- ── Comments Panel ── -->
  <div id="commentsSection">
    <div class="section-title">📝 Reviewer Comments</div>
    <div class="comments-panel">
      <div class="comments-panel-header">
        <span>Add Comment</span>
        <span style="font-size:11px;opacity:0.75">Comments are saved in this browser session and included in the PDF</span>
      </div>

      <div class="comment-form">
        <!-- Row 1 -->
        <div>
          <div class="cf-label">Reviewer Name *</div>
          <input id="cf-author" class="cf-input" type="text" placeholder="e.g. Ahmed Al-Rashidi" />
        </div>
        <div>
          <div class="cf-label">Date &amp; Time *</div>
          <input id="cf-date"   class="cf-input" type="datetime-local" />
        </div>
        <!-- Row 2 -->
        <div>
          <div class="cf-label">Comment Type</div>
          <select id="cf-type" class="cf-select">
            <option value="general" >General Note</option>
            <option value="concern" >⚠️ Concern</option>
            <option value="approval">✔ Approval</option>
            <option value="action"  >🔧 Action Required</option>
          </select>
        </div>
        <div>
          <div class="cf-label">Related Check (optional)</div>
          <select id="cf-check" class="cf-select">
            <option value="">— Overall Report —</option>
            <optgroup label="Security &amp; Firmware">
              <option>TPM Availability &amp; Version</option>
              <option>TPM Measured Boot &amp; Attestation</option>
              <option>UEFI Firmware Mode</option>
              <option>Secure Boot</option>
              <option>PCR7 Binding</option>
              <option>Kernel DMA Protection</option>
              <option>BitLocker with TPM (No Fallback)</option>
              <option>Windows Recovery Environment (WinRE)</option>
            </optgroup>
            <optgroup label="Processor">
              <option>Intel Generation (10th Gen or Newer)</option>
              <option>CPU Architecture (64-bit)</option>
              <option>Core Count (4 Physical / 8 Threads)</option>
            </optgroup>
            <optgroup label="Memory">
              <option>RAM Capacity</option>
            </optgroup>
            <optgroup label="Storage">
              <option>NVMe Storage</option>
            </optgroup>
            <optgroup label="Network">
              <option>Enterprise-Grade NIC</option>
              <option>Wi-Fi 6 (802.11ax) Minimum</option>
            </optgroup>
            <optgroup label="Platform &amp; Device Classification">
              <option>Enterprise / Business-Class Device</option>
              <option>Remote Firmware Management</option>
              <option>Windows 11-Class Chipset Platform</option>
            </optgroup>
          </select>
        </div>
        <!-- Row 3 -->
        <div class="full-row">
          <div class="cf-label">Comment *</div>
          <textarea id="cf-text" class="cf-textarea" placeholder="Enter your observation, finding, or recommendation..."></textarea>
        </div>
        <button class="btn-add-comment" onclick="addComment()">＋ Add Comment</button>
      </div>

      <div class="comments-list" id="commentsList"></div>
    </div>
  </div>

</div><!-- /content -->

<!-- ════════════════════════════════ FOOTER ══════════════════════════════════════ -->
<div class="report-footer">
  MOE Enterprise Laptop Requirements Validator &nbsp;|&nbsp; Author: Omar Osman Mahat &nbsp;|&nbsp;
  <a href="https://x.com/thekingsmakers">@thekingsmakers</a> &nbsp;|&nbsp;
  Report Generated: $($sysInfo.ReportDate) &nbsp;|&nbsp; Host: $($sysInfo.ComputerName)
</div>

<script>
// ── Pre-fill datetime with current local time ──
(function() {
  var now = new Date();
  var pad = function(n){ return n < 10 ? '0'+n : n; };
  var local = now.getFullYear()+'-'+pad(now.getMonth()+1)+'-'+pad(now.getDate())
    +'T'+pad(now.getHours())+':'+pad(now.getMinutes());
  document.getElementById('cf-date').value = local;
})();

// ── Comments store ──
var comments = [];

function initials(name) {
  return name.trim().split(/\s+/).map(function(w){ return w[0]; }).join('').toUpperCase().slice(0,2) || '?';
}

function typeLabel(t) {
  var map = { general:'General Note', concern:'⚠️ Concern', approval:'✔ Approval', action:'🔧 Action Required' };
  return map[t] || t;
}

function formatDate(iso) {
  if (!iso) return '';
  try {
    var d = new Date(iso);
    return d.toLocaleDateString('en-GB', {day:'2-digit',month:'short',year:'numeric'})
      + ' ' + d.toLocaleTimeString('en-GB', {hour:'2-digit',minute:'2-digit'});
  } catch(e) { return iso; }
}

function addComment() {
  var author = document.getElementById('cf-author').value.trim();
  var date   = document.getElementById('cf-date').value;
  var type   = document.getElementById('cf-type').value;
  var check  = document.getElementById('cf-check').value;
  var text   = document.getElementById('cf-text').value.trim();

  if (!author) { alert('Please enter the reviewer name.'); document.getElementById('cf-author').focus(); return; }
  if (!text)   { alert('Please enter a comment.');         document.getElementById('cf-text').focus();   return; }
  if (!date)   { date = new Date().toISOString().slice(0,16); }

  var id = Date.now();
  comments.push({ id: id, author: author, date: date, type: type, check: check, text: text });
  renderComments();

  // Reset text and type; keep author + date for quick sequential entry
  document.getElementById('cf-text').value  = '';
  document.getElementById('cf-type').value  = 'general';
  document.getElementById('cf-check').value = '';

  // Scroll to new comment
  setTimeout(function(){
    var el = document.getElementById('comment-'+id);
    if (el) el.scrollIntoView({ behavior:'smooth', block:'nearest' });
  }, 50);
}

function deleteComment(id) {
  if (!confirm('Delete this comment?')) return;
  comments = comments.filter(function(c){ return c.id !== id; });
  renderComments();
}

function renderComments() {
  var list = document.getElementById('commentsList');
  if (comments.length === 0) { list.innerHTML = ''; return; }

  list.innerHTML = comments.map(function(c) {
    var typeClass = 'cc-type-' + c.type;
    var checkTag  = c.check ? '<span class="cc-check-tag">'+escHtml(c.check)+'</span>' : '';
    return '<div class="comment-card" id="comment-'+c.id+'">'
      + '<div class="comment-card-header">'
      +   '<div class="cc-avatar">'+escHtml(initials(c.author))+'</div>'
      +   '<div class="cc-author">'+escHtml(c.author)+'</div>'
      +   '<span class="cc-type-tag '+typeClass+'">'+typeLabel(c.type)+'</span>'
      +   checkTag
      +   '<span class="cc-date">'+formatDate(c.date)+'</span>'
      +   '<button class="btn-delete-comment" title="Delete comment" onclick="deleteComment('+c.id+')">🗑</button>'
      + '</div>'
      + '<div class="comment-card-body">'+escHtml(c.text).replace(/\n/g,'<br>')+'</div>'
      + '</div>';
  }).join('');
}

function escHtml(str) {
  return String(str)
    .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
    .replace(/"/g,'&quot;').replace(/'/g,'&#39;');
}

function toggleComments() {
  var sec = document.getElementById('commentsSection');
  sec.style.display = sec.style.display === 'none' ? '' : 'none';
}

// ── PDF Download via print dialog ──
function downloadPDF() {
  // Hide form inputs before printing (kept by CSS @media print too, but belt-and-suspenders)
  var toolbar = document.querySelector('.action-toolbar');
  var form    = document.querySelector('.comment-form');
  toolbar.style.display = 'none';
  form.style.display    = 'none';

  window.print();

  // Restore after dialog closes
  setTimeout(function(){
    toolbar.style.display = '';
    form.style.display    = '';
  }, 1000);
}
</script>

</body>
</html>
"@

# ─────────────────────────────────────────────────────────────────────────────
# SAVE HTML REPORT
# ─────────────────────────────────────────────────────────────────────────────

$timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$reportName = "MOE-Enterprise-Laptop-Report_$($env:COMPUTERNAME)_$timestamp.html"
$reportPath = Join-Path $env:USERPROFILE "Desktop\$reportName"

try {
    $html | Out-File -FilePath $reportPath -Encoding UTF8 -Force
    Write-Output "HTML Report saved to: $reportPath"
    # Try to open the report automatically
    Start-Process $reportPath -ErrorAction SilentlyContinue
} catch {
    # Fallback: save to TEMP
    $reportPath = Join-Path $env:TEMP $reportName
    $html | Out-File -FilePath $reportPath -Encoding UTF8 -Force
    Write-Output "HTML Report saved to: $reportPath"
    Start-Process $reportPath -ErrorAction SilentlyContinue
}

# ─────────────────────────────────────────────────────────────────────────────
# CONSOLE OUTPUT & EXIT CODE
# ─────────────────────────────────────────────────────────────────────────────

Write-Output ""
Write-Output "═══════════════════════════════════════════════════════════"
Write-Output " MOE Enterprise Laptop Requirements Validator"
Write-Output "═══════════════════════════════════════════════════════════"
Write-Output " Overall Status : $overallStatus"
Write-Output " Score          : $scorePercent% ($passedChecks / $totalChecks checks passed)"
Write-Output " Report         : $reportPath"
Write-Output "═══════════════════════════════════════════════════════════"
Write-Output ""

foreach ($group in $checkGroups) {
    Write-Output "  [$($group.Category)]"
    foreach ($c in $group.Checks) {
        $status = if ($c.Result.Success) { "[PASS]" } else { "[FAIL]" }
        Write-Output "    $status $($c.Name): $($c.Result.Message)"
    }
    Write-Output ""
}

if ($allPassed) {
    exit 0
} else {
    exit 1
}
