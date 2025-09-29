<#
.SYNOPSIS
    this script install any appxbundle with its dependancy as long as the script is in the same folder as the files

.DESCRIPTION
   this script install any appxbundle with its dependancy as long as the script is in the same folder as the files

.NOTES
    Author: Omar Osman Mahat
    Twitter: https://x.com/thekingsmakers

.PARAMETER None
    This script does not accept any parameters.

.EXAMPLE
    Run the script to do as described:
    
    # Usage: 
# To install: .\AppxBundleInstaller.ps1 /install
# To uninstall: .\AppxBundleInstaller.ps1 /uninstall



.LINK
    https://x.com/thekingsmakers
#>


# Install Any appxbundle



param (
    [string]$action = "/install"
)

# Define the path where the Appx packages and dependencies are stored
$folderPath = (Get-Location).Path

# Get the main app package file (with .appxbundle extension)
$appBundle = Get-ChildItem -Path $folderPath -Filter *.appxbundle | Select-Object -First 1

# Debug: Check if $appBundle is found
if ($null -eq $appBundle) {
    Write-Output "DEBUG: No .appxbundle file found. Please verify that the file exists and has the correct extension."
} else {
    Write-Output "DEBUG: Found appxbundle file: $($appBundle.Name)"
}

# Get all dependency packages (with .appx extension)
$dependencies = Get-ChildItem -Path $folderPath -Filter *.appx

# Function to install Appx packages with dependencies
function Install-AppBundleWithDependencies {
    param (
        [Object]$appBundleFile,
        [array]$dependencies
    )

    Write-Output "Installing dependencies..."
    foreach ($dependency in $dependencies) {
        Write-Output "Installing dependency: $($dependency.Name)"
        Add-AppxPackage -Path $dependency.FullName -ErrorAction Stop
    }

    if ($null -eq $appBundleFile) {
        Write-Output "ERROR: Main app bundle file is null. Exiting installation."
        return
    }

    Write-Output "Installing main app bundle: $($appBundleFile.Name)"
    Add-AppxPackage -Path $appBundleFile.FullName -ErrorAction Stop
}

# Function to uninstall Appx package based on the app bundle file
function Uninstall-AppxPackageByBundle {
    param (
        [Object]$appBundleFile
    )

    if ($null -eq $appBundleFile) {
        Write-Output "ERROR: Main app bundle file is null. Exiting uninstallation."
        return
    }

    # Get the package name from the main bundle file
    $packageName = (Get-AppxPackage -Path $appBundleFile.FullName).Name
    if ($packageName) {
        Write-Output "Uninstalling package: $packageName"
        Get-AppxPackage -Name $packageName | Remove-AppxPackage -ErrorAction Stop
    } else {
        Write-Output "App bundle not installed or package name not found."
    }
}

# Main script execution
try {
    if ($action -eq "/install") {
        if ($appBundle) {
            Install-AppBundleWithDependencies -appBundleFile $appBundle -dependencies $dependencies
            Write-Output "Installation completed."
        } else {
            Write-Output "No .appxbundle file found in the specified folder."
        }
    }
    elseif ($action -eq "/uninstall") {
        if ($appBundle) {
            Uninstall-AppxPackageByBundle -appBundleFile $appBundle
            Write-Output "Uninstallation completed."
        } else {
            Write-Output "No .appxbundle file found in the specified folder."
        }
    }
    else {
        Write-Output "Invalid action. Use /install or /uninstall."
    }
}
catch {
    Write-Output "An error occurred: $_"
}
