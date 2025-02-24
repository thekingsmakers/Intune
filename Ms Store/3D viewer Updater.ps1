# Global exit code variable (0 = success; nonzero = error)
$global:exitCode = 0

# Define the App ID variable (replace with your specific app ID)
$AppID = "9nblggh42ths"
Write-Output "Script started. Target AppID: $AppID"

# Function to update the global exit code if an error occurs
function Update-ExitCode($code) {
    if ($global:exitCode -eq 0) {
        $global:exitCode = $code
    }
}

# Function to install winget if not already installed
function Install-Winget {
    Write-Output "Winget is not installed. Beginning installation process..."
    $wingetInstallerUrl = "https://aka.ms/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.appxbundle"
    $wingetInstallerPath = "$env:TEMP\winget.appxbundle"
    try {
        Write-Output "Downloading winget installer from $wingetInstallerUrl..."
        Invoke-WebRequest -Uri $wingetInstallerUrl -OutFile $wingetInstallerPath -UseBasicParsing -ErrorAction Stop
        Write-Output "Download complete. Installing winget..."
        Add-AppxPackage -Path $wingetInstallerPath -ErrorAction Stop
        Write-Output "Winget installed successfully."
    }
    catch {
        Write-Output "Error during winget installation: $_"
        Update-ExitCode 1
    }
}

# Function to attempt to uninstall winget (non-critical, as winget is a built-in component)
function Uninstall-Winget {
    Write-Output "Initiating winget uninstallation..."
    try {
        $pkg = Get-AppxPackage Microsoft.DesktopAppInstaller
        if ($pkg) {
            Remove-AppxPackage $pkg -ErrorAction Stop
            Write-Output "Winget uninstalled successfully."
        }
        else {
            Write-Output "Winget package not found; nothing to uninstall."
        }
    }
    catch {
        Write-Output "Winget uninstallation failed. This package is a built-in system component and cannot be uninstalled per-user. Error: $_"
        # Do not update exit code because this failure is non-critical for remediation
    }
}

# Set verbosity to silent (but we still use Write-Output for logging)
$VerbosePreference = "SilentlyContinue"

# Step 1: Check if winget is installed
Write-Output "Checking for winget installation..."
$wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
if (-not $wingetCommand) {
    Write-Output "Winget not found."
    Install-Winget
} else {
    Write-Output "Winget is already installed."
}

# Step 2: Uninstall the specified app using its App ID
Write-Output "Attempting to uninstall the app with ID '$AppID'..."
try {
    winget uninstall --id $AppID --silent --disable-interactivity
    Write-Output "Uninstall command executed for AppID '$AppID'."
}
catch {
    Write-Output "Error during uninstallation of AppID '$AppID': $_"
    Update-ExitCode 2
}

# Step 3: Reinstall the specified app using its App ID
Write-Output "Attempting to install the app with ID '$AppID'..."
try {
    winget install --id $AppID --silent --disable-interactivity --accept-package-agreements --accept-source-agreements
    Write-Output "Install command executed for AppID '$AppID'."
}
catch {
    Write-Output "Error during installation of AppID '$AppID': $_"
    Update-ExitCode 3
}

# Step 4: Attempt to uninstall winget (non-critical step)
#Uninstall-Winget

Write-Output "Script completed. Exit code: $global:exitCode"
exit $global:exitCode
