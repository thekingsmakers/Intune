# Ensure the script is run with administrative privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Please run this script as an Administrator." -ForegroundColor Red
    exit
}

Write-Host "Starting Opera GX deletion process for all user profiles..."

# Get all user profiles except system profiles
$userProfiles = Get-ChildItem -Path C:\Users -Directory | Where-Object {
    $_.Name -notmatch '^(Public|Default|Default User|All Users|LocalService|NetworkService)$'
}

foreach ($user in $userProfiles) {
    # Define paths for folder deletion within each user profile
    $searchPaths = @(
        "$($user.FullName)\AppData\Local\Programs\Opera GX", # Targeting Opera GX specifically
        "$($user.FullName)\AppData\Roaming\Opera Software",
        "$($user.FullName)\AppData\Local\Opera Software"
    )

    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force
            Write-Host "Deleted Opera GX folder for user $($user.Name): $path"
        } else {
            Write-Host "Opera GX folder not found for user $($user.Name), skipping: $path"
        }
    }

    # Attempt to delete Opera GX shortcuts from each user's Desktop and Start Menu
    $shortcutPaths = @(
        "$($user.FullName)\Desktop",
        "$($user.FullName)\AppData\Roaming\Microsoft\Windows\Start Menu\Programs"
    )

    foreach ($path in $shortcutPaths) {
        $shortcuts = Get-ChildItem -Path $path -Filter "*Opera GX*.lnk" -ErrorAction SilentlyContinue
        if ($shortcuts) {
            foreach ($shortcut in $shortcuts) {
                Remove-Item $shortcut.FullName -Force
                Write-Host "Deleted shortcut for user $($user.Name): $($shortcut.FullName)"
            }
        } else {
            Write-Host "No Opera GX shortcuts found for user $($user.Name) in $path."
        }
    }
}

# Due to script running under SYSTEM, targeting HKCU registry paths directly is not applicable
# The HKCU paths would need to be addressed in a user-context script or by other means

# Delete specified registry paths related to Opera GX for the local machine (HKLM)
$registryPaths = @(
    "HKLM:\Software\Opera Software",
    "HKLM:\Software\Classes\OperaGXStable",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Opera GX Stable",
    "HKLM:\Software\Wow6432Node\Opera Software",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Opera GX Stable"
)

foreach ($path in $registryPaths) {
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force
        Write-Host "Deleted registry entry: $path"
    } else {
        Write-Host "Registry path not found, skipping: $path"
    }
}

Write-Host "Opera GX deletion process for all users completed."
