# PowerShell Script to Remove Opera from All User Profiles and Clean Registry

# Requires -RunAsAdministrator

# Function to remove directories safely
function Remove-DirectorySafely {
    param (
        [string]$path
    )
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force
        Write-Host "Removed directory: $path"
    }
    else {
        Write-Host "Directory not found: $path"
    }
}

# Function to clean registry keys safely
function Remove-RegistryKeysForAllUsers {
    param (
        [string[]]$keyPaths
    )
    foreach ($keyPath in $keyPaths) {
        try {
            if (Test-Path $keyPath) {
                Remove-Item -Path $keyPath -Recurse -Force
                Write-Host "Removed registry key: $keyPath"
            }
            else {
                Write-Host "Registry key not found: $keyPath"
            }
        } catch {
            Write-Warning "Error removing registry key: $_"
        }
    }
}

# Loop through all user profiles and delete Opera directories
$userProfiles = Get-ChildItem -Path C:\Users
foreach ($user in $userProfiles) {
    $operaPath = "$($user.FullName)\AppData\Local\Programs\Opera"
    Remove-DirectorySafely -path $operaPath
}

# Registry paths to remove for Opera Browser and Opera GX
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

# Remove registry keys
Remove-RegistryKeysForAllUsers -keyPaths $registryPaths

Write-Host "Opera removal process completed for all users."
