# Script1.ps1 - Setup: Copy AutoPilot auxiliary files to ProgramFiles

try {
    $scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
    
    Write-Host "Copying AutoPilot scripts and modules..."
    
    if (Test-Path "$scriptDir\Scripts") {
        Copy-Item "$scriptDir\Scripts" $env:ProgramFiles -Force -Recurse -ErrorAction Stop
        Write-Host "Scripts copied successfully"
    }
    
    if (Test-Path "$scriptDir\PackageManagement") {
        Copy-Item "$scriptDir\PackageManagement" $env:ProgramFiles -Force -Recurse -ErrorAction Stop
        Write-Host "PackageManagement copied successfully"
    }
    
    if (Test-Path "$scriptDir\WindowsPowerShell") {
        Copy-Item "$scriptDir\WindowsPowerShell" $env:ProgramFiles -Force -Recurse -ErrorAction Stop
        Write-Host "WindowsPowerShell copied successfully"
    }
    
    Write-Host "Setup-CopyFiles: Setup completed successfully"
} catch {
    Write-Host "Setup-CopyFiles Error: $($_.Exception.Message)"
    exit 1
}

