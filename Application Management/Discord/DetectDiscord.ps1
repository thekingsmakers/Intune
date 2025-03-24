<#
.SYNOPSIS
    This script performs Discord app detection in windows 10 and later devices.

.DESCRIPTION
    The script will check if discord is installed on the computer. it will check files foldes and registry

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



# Define a detection function for Discord
function Detect-Discord {
    $FoundDiscord = $false

    # Check all user profiles for Discord folders
    $UserProfiles = Get-WmiObject -Class Win32_UserProfile | Where-Object { $_.Special -eq $false -and $_.LocalPath -match "^C:\\Users" }

    foreach ($Profile in $UserProfiles) {
        $LocalAppData = Join-Path -Path $Profile.LocalPath -ChildPath "AppData\Local"
        $DiscordPath = Join-Path -Path $LocalAppData -ChildPath "Discord"

        if (Test-Path -Path $DiscordPath) {
            Write-Output "Discord folder found at $DiscordPath"
            $FoundDiscord = $true
        }
    }

    # Check registry for Discord entries
    $RegistryPaths = @(
        "HKCU:\Software\Discord",
        "HKLM:\Software\Discord",
        "HKLM:\Software\WOW6432Node\Discord"
    )

    foreach ($Path in $RegistryPaths) {
        if (Test-Path -Path $Path) {
            Write-Output "Discord registry entry found at $Path"
            $FoundDiscord = $true
        }
    }

    # Return exit codes based on detection result
    if ($FoundDiscord) {
        Write-Output "Discord detected on this system."
        exit 1
    } else {
        Write-Output "No traces of Discord detected."
        exit 0
    }
}

# Call the detection function
Detect-Discord
