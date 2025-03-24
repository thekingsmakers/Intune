<#
.SYNOPSIS
    This script performs Discord app detection and removal windows 10 and later devices.

.DESCRIPTION
    The script will check if discord is installed on the computer. it will check files foldes and registry then uninstalls and deletes all the reg and folders

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


function Uninstall-Discord {
    # Function to remove registry keys recursively
    function Remove-RegistryKeyRecursive {
        param (
            [string]$Path
        )
        
        if (Test-Path -Path $Path) {
            try {
                Get-ChildItem -Path $Path -Recurse | ForEach-Object {
                    try {
                        Remove-Item -Path $_.PsPath -Recurse -Force -ErrorAction Stop
                        Write-Host "Removed registry key: $($_.PsPath)"
                    } catch {
                        Write-Host "Could not remove registry key $($_.PsPath): $_"
                    }
                }
                Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
                Write-Host "Removed root registry path: $Path"
            } catch {
                Write-Host "Error removing registry path $Path : $_"
            }
        }
    }

    # Comprehensive list of potential Discord-related registry paths
    $RegistryPaths = @(
        # User-specific registry paths
        "HKCU:\Software\Discord",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Discord",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\discord.exe",
        
        # Machine-wide registry paths
        "HKLM:\Software\Discord",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Discord",
        "HKLM:\Software\WOW6432Node\Discord",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Discord",
        
        # Additional potential paths
        "HKCU:\Software\DiscordPTB",
        "HKCU:\Software\DiscordCanary",
        "HKLM:\Software\DiscordPTB",
        "HKLM:\Software\DiscordCanary"
    )

    # Get all user profiles
    $UserProfiles = Get-WmiObject -Class Win32_UserProfile | Where-Object { 
        $_.Special -eq $false -and $_.LocalPath -match "^C:\\Users" 
    }

    # Perform Discord uninstallation for each user profile
    foreach ($Profile in $UserProfiles) {
        # Construct paths to potential Discord locations
        $LocalAppData = Join-Path -Path $Profile.LocalPath -ChildPath "AppData\Local"
        $DiscordFolders = @(
            (Join-Path -Path $LocalAppData -ChildPath "Discord"),
            (Join-Path -Path $LocalAppData -ChildPath "DiscordPTB"),
            (Join-Path -Path $LocalAppData -ChildPath "DiscordCanary")
        )
        
        foreach ($DiscordPath in $DiscordFolders) {
            if (Test-Path -Path $DiscordPath) {
                # Look for Update.exe
                $UpdateExe = Join-Path -Path $DiscordPath -ChildPath "Update.exe"
                
                if (Test-Path -Path $UpdateExe) {
                    Write-Host "Running Discord uninstaller for user: $($Profile.LocalPath)"
                    
                    # Run uninstaller
                    try {
                        Start-Process $UpdateExe -ArgumentList "--uninstall" -Wait
                        
                        # Wait for 10 seconds after uninstallation
                        Start-Sleep -Seconds 10
                    } catch {
                        Write-Host "Error running uninstaller: $_"
                    }
                }
            }
        }
    }

    # Remove Discord-related registry entries
    foreach ($Path in $RegistryPaths) {
        Remove-RegistryKeyRecursive -Path $Path
    }

    # Additional registry search and removal
    $RootRegistryPaths = @(
        "HKCU:\Software",
        "HKLM:\Software",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($RootPath in $RootRegistryPaths) {
        try {
            $DiscordRelatedKeys = Get-ChildItem -Path $RootPath | 
                Where-Object { $_.Name -like "*Discord*" }
            
            foreach ($Key in $DiscordRelatedKeys) {
                try {
                    Remove-Item -Path $Key.PsPath -Recurse -Force
                    Write-Host "Removed additional Discord-related registry key: $($Key.PsPath)"
                } catch {
                    Write-Host "Could not remove registry key $($Key.PsPath): $_"
                }
            }
        } catch {
            #Write-Host "Error searching for Discord-related registry keys in $RootPath: $_"
        }
    }

    # Remove Discord folders for all users
    foreach ($Profile in $UserProfiles) {
        $LocalAppData = Join-Path -Path $Profile.LocalPath -ChildPath "AppData\Local"
        $DiscordFolders = @(
            (Join-Path -Path $LocalAppData -ChildPath "Discord"),
            (Join-Path -Path $LocalAppData -ChildPath "DiscordCanary"),
            (Join-Path -Path $LocalAppData -ChildPath "DiscordPTB")
        )

        foreach ($Folder in $DiscordFolders) {
            if (Test-Path -Path $Folder) {
                try {
                    Remove-Item -Path $Folder -Recurse -Force
                    Write-Host "Removed Discord folder: $Folder"
                } catch {
                    Write-Host "Error removing folder $Folder : $_"
                }
            }
        }
    }

    # Additional cleanup in common locations
    $AdditionalCleanupPaths = @(
        "$env:USERPROFILE\Desktop\Discord.lnk",
        "$env:PROGRAMDATA\Microsoft\Windows\Start Menu\Programs\Discord.lnk"
    )

    foreach ($Path in $AdditionalCleanupPaths) {
        if (Test-Path -Path $Path) {
            try {
                Remove-Item -Path $Path -Force
                Write-Host "Removed additional Discord link: $Path"
            } catch {
                #Write-Host "Could not remove $Path: $_"
            }
        }
    }

    Write-Host "Comprehensive Discord removal process completed."
}

# Run the uninstallation function
Uninstall-Discord