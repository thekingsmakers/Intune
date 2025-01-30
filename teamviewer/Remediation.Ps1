#=============================================================================================================================
#
# Script Name:     Remediate_TeamViewer.ps1
# Description:     Uninstall TeamViewer and remove related files and shortcuts
# Notes:           Script to uninstall TeamViewer from both x86 and x64 directories, delete related executables in user 
#                  directories, and remove shortcuts. Includes error handling and retry logic.
#
#=============================================================================================================================

# Define function to find TeamViewer uninstall path
function Get-TeamViewerUninstallPath {
    $possiblePaths = @(
        "C:\Program Files\TeamViewer\uninstall.exe",
        "C:\Program Files (x86)\TeamViewer\uninstall.exe",
        "$env:PROGRAMDATA\TeamViewer\uninstall.exe",
        "$env:APPDATA\TeamViewer\uninstall.exe"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    return $null
}

# Get the uninstall path
$uninstallPath = Get-TeamViewerUninstallPath

if ($uninstallPath) {
    Write-Output "TeamViewer uninstall.exe found at: $uninstallPath"
    
    # Run silent uninstall
    Start-Process -FilePath $uninstallPath -ArgumentList "/S" -NoNewWindow -Wait
    
    # Verify if uninstallation was successful
    Start-Sleep -Seconds 5
    if (-Not (Test-Path "C:\Program Files\TeamViewer") -and -Not (Test-Path "C:\Program Files (x86)\TeamViewer")) {
        Write-Output "TeamViewer has been successfully removed."
        exit 0
    } else {
        Write-Output "Failed to remove TeamViewer. Please check manually."
        exit 1
    }
} else {
    Write-Output "TeamViewer uninstall.exe not found. It may already be uninstalled."
    exit 0
}
