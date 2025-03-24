# 

<#
.SYNOPSIS
   PowerShell script to detect Brave Browser installation with exit codes for Intune remediation

.DESCRIPTION
   PowerShell script to detect Brave Browser installation with exit codes for Intune remediation

.PARAMETER [ParameterName]
    All steps are pre described
    
.EXAMPLE
    script supports no parameters

.NOTES
    Author: Omar Osman Mahat
    Created: 2/12/2024
    Last Updated: 2/12/2024
    Version: 1.0

#>



# Function to check if Brave is installed in user profiles
Function Detect-BraveInUserProfiles {
    Write-Host "Detecting Brave Browser in user profiles..."
    $UserProfiles = Get-ChildItem -Path "C:\Users" -Directory
    $BravePaths = @("AppData\Local\BraveSoftware", "AppData\Roaming\BraveSoftware")
    $Found = $false

    foreach ($Profile in $UserProfiles) {
        foreach ($RelativePath in $BravePaths) {
            $FullPath = Join-Path -Path $Profile.FullName -ChildPath $RelativePath
            if (Test-Path $FullPath) {
                Write-Host "Brave detected in $FullPath"
                $Found = $true
            }
        }
    }

    return $Found
}

# Function to check if Brave is installed in Program Files
Function Detect-BraveInProgramFiles {
    Write-Host "Detecting Brave Browser in Program Files..."
    $ProgramFilesPaths = @(
        "C:\Program Files\BraveSoftware",
        "C:\Program Files (x86)\BraveSoftware"
    )
    $Found = $false

    $ProgramFilesPaths | ForEach-Object {
        if (Test-Path $_) {
            Write-Host "Brave detected in $_"
            $Found = $true
        }
    }

    return $Found
}

# Function to detect Brave-related registry entries
Function Detect-BraveInRegistry {
    Write-Host "Detecting Brave-related registry entries..."
    $RegistryPaths = @(
        "HKCU:\Software\BraveSoftware",
        "HKLM:\Software\BraveSoftware",
        "HKLM:\Software\WOW6432Node\BraveSoftware"
    )
    $Found = $false

    $RegistryPaths | ForEach-Object {
        if (Test-Path $_) {
            Write-Host "Brave-related registry key detected: $_"
            $Found = $true
        }
    }

    # Search for Brave-related keys dynamically
    $BaseKeys = @("HKLM:\Software", "HKCU:\Software")
    foreach ($BaseKey in $BaseKeys) {
        $SearchKeys = Get-ChildItem -Path $BaseKey -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -match "Brave"
        }

        foreach ($Key in $SearchKeys) {
            Write-Host "Brave-related registry key detected: $($Key.Name)"
            $Found = $true
        }
    }

    return $Found
}

# Function to check if Brave is currently running
Function Detect-BraveProcess {
    Write-Host "Checking if Brave Browser is running..."
    $Processes = Get-Process -Name "brave" -ErrorAction SilentlyContinue
    if ($Processes) {
        Write-Host "Brave Browser is currently running."
        return $true
    } else {
        Write-Host "Brave Browser is not running."
        return $false
    }
}

# Main Execution
Write-Host "Starting Brave Browser detection process..."
$ProcessDetected = Detect-BraveProcess
$UserProfileDetected = Detect-BraveInUserProfiles
$ProgramFilesDetected = Detect-BraveInProgramFiles
$RegistryDetected = Detect-BraveInRegistry

if ($ProcessDetected -or $UserProfileDetected -or $ProgramFilesDetected -or $RegistryDetected) {
    Write-Host "Brave Browser detected."
    exit 1  # Brave detected
} else {
    Write-Host "Brave Browser not detected."
    exit 0  # No Brave detected
}
