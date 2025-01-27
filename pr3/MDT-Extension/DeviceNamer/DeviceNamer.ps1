# DeviceNamer.ps1
# PowerShell script to dynamically name the device based on prefix, device type, and serial number
# Configuration is loaded from config.xml

Write-Host "Device Namer script started."

# --- Configuration ---
$configFilePath = "MDT-Extension/Configuration/config.xml"
try {
    $xmlConfig = [xml](Get-Content $configFilePath)
    $Prefix = $xmlConfig.Configuration.DeviceNaming.Prefix
    if (-not $Prefix) {
        $Prefix = "MOE" # Default prefix if not configured
        Write-Warning "Device prefix not configured in config.xml, using default 'MOE'."
    }
}
catch {
    Write-Error "Error loading configuration from $($configFilePath): $_"
    $Prefix = "MOE" # Default prefix in case of error
    Write-Warning "Using default device prefix 'MOE' due to configuration load error."
}

Write-Host "Using device name prefix: $($Prefix)"

# --- Functions ---
function Get-DeviceType {
    # Simple check for Chassis Type to determine if it's a Laptop or Desktop
    $ChassisType = Get-WmiObject -Class Win32_SystemEnclosure | Select-Object -ExpandProperty ChassisTypes
    if ($ChassisType -contains 9 -or $ChassisType -contains 10 -or $ChassisType -contains 11 -or $ChassisType -contains 12 -or $ChassisType -contains 14 -or $ChassisType -contains 18 -or $ChassisType -contains 21) {
        return "L" # Laptop
    } else {
        return "D" # Desktop (or other non-laptop type)
    }
}

function Get-SerialNumber {
    # Get Serial Number from BIOS
    return (Get-WmiObject -Class Win32_BIOS).SerialNumber
}

# --- Main Script ---

# Get Device Type
$DeviceTypeLetter = Get-DeviceType

# Get Serial Number
$SerialNumber = Get-SerialNumber

# Construct Computer Name
$ComputerName = "$Prefix-$DeviceTypeLetter-$SerialNumber"

# Limit Computer Name to 15 characters (NetBIOS limit) - truncate serial if needed
if ($ComputerName.Length -gt 15) {
    $ComputerName = $ComputerName.Substring(0, 15)
    Write-Warning "Computer name exceeds 15 characters. Truncated to: $($ComputerName)"
}

Write-Host "Generated Computer Name: $($ComputerName)"

# Set the Computer Name
try {
    Rename-Computer -NewName $ComputerName -LocalAccountCredential $null -Force -ErrorAction Stop
    Write-Host "Successfully set computer name to $($ComputerName). Device restart may be required for full effect."
}
catch {
    Write-Error "Error setting computer name: $_"
    Write-Warning "Please ensure this script is run with necessary privileges and before domain join."
}

Write-Host "Device Namer script finished."