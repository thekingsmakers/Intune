# -------------------------------
# Set the base path using $PSScriptRoot or current directory if empty
# -------------------------------
if ([string]::IsNullOrEmpty($PSScriptRoot)) {
    $BasePath = Get-Location
} else {
    $BasePath = $PSScriptRoot
}

Write-Host "Base Path: $BasePath"

$DependencyPath = Join-Path $BasePath "Dependencies"

# -------------------------------
# Determine device architecture
# -------------------------------
$Architecture = (Get-ComputerInfo).OsArchitecture
Write-Host "Detected Architecture: $Architecture"

switch ($Architecture) {
    "32-bit"       { $ArchFolder = "x86" }
    "64-bit"       { $ArchFolder = "x64" }
    "ARM-based"    { $ArchFolder = "arm" }
    "ARM64-based"  { $ArchFolder = "arm64" }
    default        { Throw "Unsupported architecture: $Architecture" }
}

$DependencyFullPath = Join-Path $DependencyPath $ArchFolder
Write-Host "Using dependency folder: $DependencyFullPath for architecture $Architecture."

if (-not (Test-Path $DependencyFullPath)) {
    Throw "Dependency folder not found: $DependencyFullPath"
}

# -------------------------------
# Function to install an APPX dependency file based on its extension
# -------------------------------
function Install-DependencyFile {
    param (
        [string]$FilePath
    )
    
    $ext = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
    
    switch ($ext) {
        ".appx" {
            Write-Host "Installing APPX dependency: $FilePath"
            Add-AppxPackage -Path $FilePath -ForceApplicationShutdown
            break
        }
        ".appxbundle" {
            Write-Host "Installing APPXBUNDLE dependency: $FilePath"
            Add-AppxPackage -Path $FilePath -ForceApplicationShutdown
            break
        }
        ".msixbundle" {
            Write-Host "Installing MSIXBUNDLE dependency: $FilePath"
            Add-AppxPackage -Path $FilePath -ForceApplicationShutdown
            break
        }
        default {
            Write-Host "Skipping file (unknown extension): $FilePath"
        }
    }
}

# -------------------------------
# Install all dependency APPX files recursively from the architecture folder
# -------------------------------
Write-Host "Installing all dependency APPX files from: $DependencyFullPath"
$depFiles = Get-ChildItem -Path $DependencyFullPath -Recurse -File | Where-Object {
    $_.Extension -in @(".appx", ".appxbundle", ".msixbundle")
}
if ($depFiles.Count -eq 0) {
    Write-Host "No dependency APPX files found in: $DependencyFullPath"
} else {
    foreach ($depFile in $depFiles) {
        Install-DependencyFile -FilePath $depFile.FullName
    }
}

# -------------------------------
# Install Winget (Microsoft Desktop App Installer)
# -------------------------------
$WingetInstaller = Join-Path $BasePath "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
if (-not (Test-Path $WingetInstaller)) {
    Throw "Winget installer not found in the script root: $WingetInstaller"
}

Write-Host "Installing Winget from: $WingetInstaller"
Add-AppxPackage -Path $WingetInstaller -ForceApplicationShutdown

# Verify Winget installation
Write-Host "Verifying Winget installation..."
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Throw "Winget installation failed. Ensure that all dependencies (such as Microsoft.UI.Xaml.2.8) are installed and try again."
} else {
    Write-Host "Winget installed successfully!"
}

# -------------------------------
# Remove and Reinstall Company Portal Using Winget Commands Silently
# -------------------------------
Write-Host "Uninstalling existing Company Portal using Winget..."

# Uninstall using the package ID with exact match and silent mode.
# Note: For uninstall, we do not include the accept-package-agreements options.
winget uninstall --id 9wzdncrfj3pz --exact --silent

Write-Host "Waiting 5 seconds for removal to take effect..."
Start-Sleep -Seconds 5

Write-Host "Installing Company Portal using Winget..."
winget install --id 9wzdncrfj3pz --silent --accept-package-agreements --accept-source-agreements

Write-Host "Installation process completed successfully!"
