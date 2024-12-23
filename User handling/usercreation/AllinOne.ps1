<#
     
     - The script was created to create a local user in the computer. if the user exists then no action needed else created the user 

                    - Before the user creation the script does the following.
                            * Check the prefix of the hostname 
                            * use the prefix of the user and create the user based on that.
                            * provide an encrypted password which will not be seen in the system later 




    ##############################################################################################################################################

    Author: Omar Osman Mahat 
    System Admin - Intune 
    Twitter: Thekingsmakers
    github: https://github.com/thekingsmakers
   ###############################################################################################################################################

   Versions: 1

   Script doesnt support any parameters



#>



function Create-UserIfNotExists {
    param (
        [string]$Password
    )

    # Encrypt password
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    
    # Get the hostname
    $Hostname = (Get-CimInstance Win32_ComputerSystem).Name

    # Extract user prefix from hostname (everything before the first dash)
    if ($Hostname -match "^(?<prefix>[^-]+)-") {
        $UserPrefix = $matches['prefix']
    } else {
        Write-Host "Hostname format not recognized. Exiting."
        return
    }

    $Username = "$UserPrefix-labuser"

    # Check if user already exists
    $UserExists = Get-LocalUser | Where-Object { $_.Name -eq $Username }

    if ($UserExists) {
        Write-Host "User $Username already exists. No action needed."
    } else {
        # Create user if not exists
        New-LocalUser -Name $Username -Password $SecurePassword -FullName $Username -Description "Lab User"
        Add-LocalGroupMember -Group "Users" -Member $Username
        Write-Host "User $Username created successfully."
    }
}

# Call the function with an encrypted password
Create-UserIfNotExists -Password "YourSecurePassword123!"
