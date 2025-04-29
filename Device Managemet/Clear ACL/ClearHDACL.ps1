<#
    ###############################################################################

    The script now checks the ACL of the entire "Users" folder and removes permissions for any user with a username ending in "-hd." 
    Script was created based on the security request
    Script created by Omar Osman Mahat 
    Credits: 
            Twitter: Thekingsmakers
            Github:  Thekingsmakers


    ###############################################################################
#>


param (
    [string]$userFolder = "C:\Users"
)

$folders = Get-ChildItem -Path $userFolder -Directory

foreach ($folder in $folders) {
    $path = $folder.FullName
    
    #Skip any HD account and continue
    if ($folder.Name -match '-hd$') {
        Write-Host "Skipping folder: $path (matches -PW)"
        continue
    }
    
    $acl = Get-Acl -Path $path
    
    foreach ($access in $acl.Access) {
        if ($access.IdentityReference -match '-hd$') {
            Write-Host "Removing permissions for: $($access.IdentityReference) from $path"
            $acl.RemoveAccessRule($access)
        }
    }
    
    Set-Acl -Path $path -AclObject $acl
}

Write-Host "Remediation completed."

