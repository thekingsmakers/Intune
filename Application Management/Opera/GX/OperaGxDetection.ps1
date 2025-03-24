# Detection Script for Opera GX across all user profiles when run as SYSTEM

# Initialize detection flag
$operaGXFound = $false

# Get the list of user profiles, excluding system profiles
$userProfiles = Get-ChildItem -Path C:\Users -Directory | Where-Object {
    $_.Name -notmatch '^(Public|Default|Default User|All Users|LocalService|NetworkService)$'
}

# Define the relative path to the Opera GX executable within the AppData directory
$operaGXRelativePath = "AppData\Local\Programs\Opera GX\launcher.exe"

# Iterate through each user profile to check for the Opera GX executable
foreach ($user in $userProfiles) {
    $operaGXPath = Join-Path -Path $user.FullName -ChildPath $operaGXRelativePath
    if (Test-Path $operaGXPath) {
        Write-Host "Opera GX detected for user $($user.Name) at $operaGXPath"
        $operaGXFound = $true
        break # Stop checking after finding the first instance
    }
}

# Determine exit code based on detection status
if ($operaGXFound) {
    exit 1 # Exit code 1 indicates Opera GX is found (action needed)
} else {
    Write-Host "Opera GX not detected in any user profile."
    exit 0 # Exit code 0 indicates no action required
}
