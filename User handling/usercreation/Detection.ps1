<#
     #####################Detection Script######################
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



# Detection Script
function Detect-UserExists {
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

    # Check if user already exists
    $UserExists = Get-LocalUser | Where-Object { $_.Name -eq $Username }

    if ($UserExists) {
        Write-Host "User $Username exists. Exiting with code 0."
        exit 0
    } else {
        Write-Host "User $Username does not exist. Exiting with code 1."
        exit 1
    }
}

# Call detection
Detect-UserExists
