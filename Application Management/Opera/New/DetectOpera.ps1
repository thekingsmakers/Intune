# PowerShell Script to Detect Opera Browser Installation

# Requires -RunAsAdministrator

# Initialize a flag to track detection status
$operaFound = $false

# Function to check the presence of Opera directories
function Check-OperaDirectory {
    param (
        [string]$path
    )
    if (Test-Path $path) {
        Write-Output "Opera directory found: $path"
        $global:operaFound = $true
    }
}

# Function to check registry keys for Opera
function Check-OperaRegistryKeys {
    param (
        [string[]]$keyPaths
    )
    foreach ($keyPath in $keyPaths) {
        if (Test-Path $keyPath) {
            Write-Output "Opera registry key found: $keyPath"
            $global:operaFound = $true
        }
    }
}

# Loop through all user profiles and check for Opera directories
$userProfiles = Get-ChildItem -Path C:\Users
foreach ($user in $userProfiles) {
    $operaPath = "$($user.FullName)\AppData\Local\Programs\Opera"
    Check-OperaDirectory -path $operaPath
}

# Registry paths to check for Opera Browser and Opera GX
$registryPaths = @(
    "HKCU:\Software\Classes\OperaStable",
    "HKCU:\Software\Opera Software",
    "HKLM:\SOFTWARE\Classes\OperaStable",
    "HKLM:\SOFTWARE\Wow6432Node\Opera Software",
    "HKLM:\SOFTWARE\Opera Software",
    "HKCU:\Software\Classes\Wow6432Node\Opera GX Stable",
    "HKCU:\Software\Opera GX Stable",
    "HKLM:\SOFTWARE\Classes\Opera GX Stable",
    "HKLM:\SOFTWARE\Wow6432Node\Opera GX Stable",
    "HKLM:\SOFTWARE\Opera GX Stable"
)

# Check registry keys for Opera
Check-OperaRegistryKeys -keyPaths $registryPaths

# Determine the final detection status
if ($operaFound -eq $true) {
    Write-Output "Opera detected."
    exit 1 # Exit code 1 indicates Opera is found
} else {
    Write-Output "Opera not detected."
    exit 0 # Exit code 0 indicates Opera is not found
}
