<#
     ###################################### Remediation Script#######################################
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



# Remediation Script
function Create-User {
    # Get the hostname
    $Hostname = (Get-CimInstance Win32_ComputerSystem).Name

    # Extract user prefix from hostname (everything before the first dash)
    if ($Hostname -match "^(?<prefix>[^-]+)-") {
        $UserPrefix = $matches['prefix']
    } else {
        Write-Host "Hostname format not recognized. Exiting with code 1."
        exit 1
    }

    $Username = "$UserPrefix-labuser"

    # Secure password
    $SecurePassword = ConvertTo-SecureString "YourSecurePassword123!" -AsPlainText -Force

    # Check if user exists before creating
    $UserExists = Get-LocalUser | Where-Object { $_.Name -eq $Username }

    if (-not $UserExists) {
        # Create the user
        New-LocalUser -Name $Username -Password $SecurePassword -PasswordNeverExpires:$true
        Write-Host "User $Username has been created. Exiting with code 0."
        exit 0
    } else {
        Write-Host "User $Username already exists. Exiting with code 1."
        exit 1
    }
}

# Call remediation
Create-User
