#Script Name:    Detect Team Viewer
# Description:     Detects TeamViewer presence on machine
# Notes:          
#                


# Define function to check registry for installed software
function Check-TeamViewerRegistry {
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            $installedApps = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
            foreach ($app in $installedApps) {
                if ($app.DisplayName -match "TeamViewer") {
                    Write-Output "TeamViewer found in registry: $($app.DisplayName)"
                    return $true
                }
            }
        }
    }
    return $false
}

# Define function to check running processes
function Check-TeamViewerProcesses {
    $processes = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match "TeamViewer" }
    if ($processes) {
        Write-Output "TeamViewer is running as a process."
        return $true
    }
    return $false
}

# Define function to check common installation paths
function Check-TeamViewerPaths {
    $possiblePaths = @(
        "C:\Program Files\TeamViewer",
        "C:\Program Files (x86)\TeamViewer",
        "$env:APPDATA\TeamViewer",
        "$env:PROGRAMDATA\TeamViewer"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            Write-Output "TeamViewer installation found at: $path"
            return $true
        }
    }
    return $false
}

# Run all detection functions
$foundRegistry = Check-TeamViewerRegistry
$foundProcesses = Check-TeamViewerProcesses
$foundPaths = Check-TeamViewerPaths

# Determine final detection result and exit accordingly
if ($foundRegistry -or $foundProcesses -or $foundPaths) {
    Write-Output "TeamViewer is detected on this system."
    exit 1
} else {
    Write-Output "TeamViewer is NOT detected on this system."
    exit 0
}
