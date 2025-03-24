# Enhanced PowerShell script to remove and block Brave Browser

<#
.SYNOPSIS
    ﻿# Enhanced PowerShell script to remove and block Brave Browser

.DESCRIPTION
    ﻿# Enhanced PowerShell script to remove and block Brave Browser

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


# Function to check and remove Brave from all user profiles
Function Remove-BraveFromUserProfiles {
    Write-Host "Checking Brave Browser installation in user profiles..."
    $UserProfiles = Get-ChildItem -Path "C:\Users" -Directory
    $BravePaths = @("AppData\Local\BraveSoftware", "AppData\Roaming\BraveSoftware")

    foreach ($Profile in $UserProfiles) {
        foreach ($RelativePath in $BravePaths) {
            $FullPath = Join-Path -Path $Profile.FullName -ChildPath $RelativePath
            if (Test-Path $FullPath) {
                Write-Host "Removing Brave files in $FullPath"
                Remove-Item -Path $FullPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# Function to check and remove Brave from Program Files
Function Remove-BraveFromProgramFiles {
    Write-Host "Checking Brave Browser installation in Program Files..."
    $ProgramFilesPaths = @(
        "C:\Program Files\BraveSoftware",
        "C:\Program Files (x86)\BraveSoftware"
    )

    $ProgramFilesPaths | ForEach-Object {
        if (Test-Path $_) {
            Write-Host "Removing Brave files in $_"
            Remove-Item -Path $_ -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Function to remove Brave-related registry entries
Function Remove-BraveFromRegistry {
    Write-Host "Searching for Brave-related registry entries..."
    $RegistryPaths = @(
        "HKCU:\Software\BraveSoftware",
        "HKLM:\Software\BraveSoftware",
        "HKLM:\Software\WOW6432Node\BraveSoftware"
    )

    $RegistryPaths | ForEach-Object {
        if (Test-Path $_) {
            Write-Host "Removing registry key: $_"
            Remove-Item -Path $_ -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Search for Brave-related keys dynamically
    $SearchKeys = Get-ChildItem -Path "HKLM:\Software" -Recurse -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match "Brave"
    }

    foreach ($Key in $SearchKeys) {
        Write-Host "Removing registry key: $($Key.Name)"
        Remove-Item -Path $Key.Name -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Function to close Brave browser if running
Function Close-BraveBrowser {
    Write-Host "Checking if Brave Browser is running..."
    Get-Process -Name "brave" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "Brave Browser processes terminated."
}

# Function to block Brave installation via AppLocker
Function Block-BraveInstallation {
    Write-Host "Blocking Brave Browser installation..."
    $AppLockerPolicy = @"
<?xml version="1.0" encoding="utf-8"?>
<AppLockerPolicy Version="1">
  <RuleCollection Type="Exe" EnforcementMode="Enabled">
    <FilePathRule Id="{00000000-0000-0000-0000-000000000001}" Name="Block Brave" Description="Block Brave Browser" UserOrGroupSid="S-1-1-0" Action="Deny">
      <Conditions>
        <FilePathCondition Path="*\\Brave*.exe" />
      </Conditions>
    </FilePathRule>
  </RuleCollection>
</AppLockerPolicy>
"@
    $PolicyFile = "C:\Windows\Temp\AppLockerPolicy.xml"
    $AppLockerPolicy | Out-File -FilePath $PolicyFile -Encoding UTF8
    secedit /configure /db AppLocker.sdb /cfg $PolicyFile | Out-Null
    Write-Host "Brave installation blocked."
}

# Main Execution
Write-Host "Starting Brave Browser removal process..."
Close-BraveBrowser
Remove-BraveFromUserProfiles
Remove-BraveFromProgramFiles
Remove-BraveFromRegistry
Block-BraveInstallation
Write-Host "Brave Browser removal and blocking process completed."
