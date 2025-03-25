<#
.SYNOPSIS
    Prepares a USB drive for Windows deployment
.DESCRIPTION
    Formats the USB drive, creates required folders, and copies deployment files
.PARAMETER DriveLetter
    The drive letter of the USB drive (e.g., "E:")
.PARAMETER WindowsIsoPath
    Path to the Windows ISO file to extract
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$DriveLetter,
    
    [Parameter(Mandatory=$true)]
    [string]$WindowsIsoPath
)

$ErrorActionPreference = "Stop"
$deploymentRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Write-Status {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-AdminPrivileges {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    $adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
    
    if (-not $principal.IsInRole($adminRole)) {
        throw "This script requires administrative privileges"
    }
}

function Format-USBDrive {
    param([string]$DriveLetter)
    
    Write-Status "Formatting USB drive $DriveLetter"
    
    # Remove trailing colon if present
    $drive = $DriveLetter.TrimEnd(":")
    
    try {
        # Format drive with NTFS
        $formatProcess = Start-Process -FilePath "format.com" -ArgumentList "$drive`: /FS:NTFS /Q /V:WinDeploy /Y" -NoNewWindow -Wait -PassThru
        if ($formatProcess.ExitCode -ne 0) {
            throw "Format process failed with exit code: $($formatProcess.ExitCode)"
        }
    }
    catch {
        throw "Failed to format USB drive: $_"
    }
}

function Create-FolderStructure {
    param([string]$DriveLetter)
    
    Write-Status "Creating folder structure"
    
    $folders = @(
        "Deployment",
        "Deployment\Config",
        "Deployment\Scripts",
        "Deployment\Logs",
        "Deployment\Installers",
        "SetupGUI"
    )
    
    foreach ($folder in $folders) {
        $path = Join-Path $DriveLetter $folder
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
}

function Copy-DeploymentFiles {
    param([string]$DriveLetter)
    
    Write-Status "Copying deployment files"
    
    # Core files
    Copy-Item -Path "$deploymentRoot\autorun.inf" -Destination $DriveLetter
    Copy-Item -Path "$deploymentRoot\README.md" -Destination $DriveLetter
    
    # Deployment files
    Copy-Item -Path "$deploymentRoot\Deployment\Scripts\*" -Destination "$DriveLetter\Deployment\Scripts" -Recurse
    Copy-Item -Path "$deploymentRoot\Deployment\Config\deploy-config.xml" -Destination "$DriveLetter\Deployment\Config"
    
    # Setup GUI
    Copy-Item -Path "$deploymentRoot\SetupGUI\bin\Release\net6.0-windows\*" -Destination "$DriveLetter\SetupGUI" -Recurse
}

function Extract-WindowsImage {
    param(
        [string]$IsoPath,
        [string]$DriveLetter
    )
    
    Write-Status "Extracting Windows image"
    
    try {
        $mountResult = Mount-DiskImage -ImagePath $IsoPath -PassThru
        $isoDrive = ($mountResult | Get-Volume).DriveLetter
        
        # Copy Windows image files
        Write-Status "Copying Windows files (this may take a while)..."
        Copy-Item -Path "${isoDrive}:\*" -Destination $DriveLetter -Recurse -Force
        
        Dismount-DiskImage -ImagePath $IsoPath
        Write-Status "Windows image extracted successfully"
    }
    catch {
        Write-Error "Failed to extract Windows image: $_"
        if ($mountResult) {
            Dismount-DiskImage -ImagePath $IsoPath
        }
        throw
    }
}

# Main execution
try {
    Write-Host "Windows Deployment USB Preparation Tool" -ForegroundColor Green
    Write-Host "====================================" -ForegroundColor Green
    
    # Validate inputs
    if (-not $DriveLetter.EndsWith(":")) {
        $DriveLetter = "$($DriveLetter):"
    }
    
    if (-not (Test-Path -Path $WindowsIsoPath)) {
        throw "Windows ISO file not found: $WindowsIsoPath"
    }
    
    # Check admin privileges
    Test-AdminPrivileges
    
    # Confirm with user
    Write-Host "`nWARNING: This will format drive $DriveLetter" -ForegroundColor Yellow
    $confirm = Read-Host "Continue? (y/N)"
    if ($confirm -ne "y") {
        Write-Host "Operation cancelled by user" -ForegroundColor Yellow
        exit
    }
    
    # Prepare USB drive
    Format-USBDrive -DriveLetter $DriveLetter
    Create-FolderStructure -DriveLetter $DriveLetter
    Copy-DeploymentFiles -DriveLetter $DriveLetter
    Extract-WindowsImage -IsoPath $WindowsIsoPath -DriveLetter $DriveLetter
    
    Write-Host "`nUSB drive preparation completed successfully!" -ForegroundColor Green
    Write-Host "You can now use this drive for Windows deployment." -ForegroundColor Green
}
catch {
    Write-Error "USB preparation failed: $_"
    exit 1
}