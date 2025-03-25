<#
.SYNOPSIS
    Windows Deployment Tool - Main Launcher
.DESCRIPTION
    Unified interface for managing Windows deployment process
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("Setup", "Deploy", "Monitor", "Test", "Rollback", "Build", "Prepare", "Verify", "Clean", "PostTest", "Menu")]
    [string]
    $Action = "Menu"
)

$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "Windows Deployment Tool"

function Show-Menu {
    Clear-Host
    Write-Host "Windows Deployment Tool" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    Write-Host
    Write-Host "1. Launch Setup GUI" -ForegroundColor Yellow
    Write-Host "2. Start Deployment" -ForegroundColor Yellow
    Write-Host "3. Monitor Progress" -ForegroundColor Yellow
    Write-Host "4. Test Requirements" -ForegroundColor Yellow
    Write-Host "5. Rollback Changes" -ForegroundColor Yellow
    Write-Host "6. Build Package" -ForegroundColor Yellow
    Write-Host "7. Prepare USB Drive" -ForegroundColor Yellow
    Write-Host "8. Verify Package" -ForegroundColor Yellow
    Write-Host "9. Clean Sensitive Data" -ForegroundColor Yellow
    Write-Host "10. Run Post-Deployment Tests" -ForegroundColor Yellow
    Write-Host
    Write-Host "Q. Quit" -ForegroundColor Red
    Write-Host
    
    $choice = Read-Host "Select an option"
    
    switch ($choice) {
        "1" { return "Setup" }
        "2" { return "Deploy" }
        "3" { return "Monitor" }
        "4" { return "Test" }
        "5" { return "Rollback" }
        "6" { return "Build" }
        "7" { return "Prepare" }
        "8" { return "Verify" }
        "9" { return "Clean" }
        "Q" { exit }
        default { return $null }
    }
}

function Test-AdminRights {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-WithErrorHandling {
    param(
        [scriptblock]$ScriptBlock,
        [string]$ErrorMessage
    )
    
    try {
        & $ScriptBlock
        if ($LASTEXITCODE -ne 0) {
            throw "Process exited with code $LASTEXITCODE"
        }
    }
    catch {
        Write-Host
        Write-Host "Error: $ErrorMessage" -ForegroundColor Red
        Write-Host "Details: $_" -ForegroundColor Red
        Write-Host
        Write-Host "Press any key to continue..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $false
    }
    return $true
}

# Ensure running as administrator
if (-not (Test-AdminRights)) {
    Write-Host "This tool requires administrator privileges." -ForegroundColor Red
    Write-Host "Please restart as administrator."
    Write-Host
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Get action from menu if not specified
if ($Action -eq "Menu") {
    do {
        $Action = Show-Menu
    } while ($null -eq $Action)
}

# Execute requested action
switch ($Action) {
    "Setup" {
        Invoke-WithErrorHandling `
            -ScriptBlock { Start-Process ".\SetupGUI\SetupGUI.exe" -Wait } `
            -ErrorMessage "Failed to launch Setup GUI"
    }
    
    "Deploy" {
        Invoke-WithErrorHandling `
            -ScriptBlock { & .\Deployment\Scripts\Deploy-Windows.ps1 } `
            -ErrorMessage "Deployment failed"
    }
    
    "Monitor" {
        Invoke-WithErrorHandling `
            -ScriptBlock { & .\Tools\Monitor-Deployment.ps1 } `
            -ErrorMessage "Monitoring failed"
    }
    
    "Test" {
        Invoke-WithErrorHandling `
            -ScriptBlock { & .\Tools\Test-Requirements.ps1 } `
            -ErrorMessage "Requirements check failed"
    }
    
    "Rollback" {
        Invoke-WithErrorHandling `
            -ScriptBlock { & .\Tools\Rollback-Deployment.ps1 } `
            -ErrorMessage "Rollback failed"
    }
    
    "Build" {
        Invoke-WithErrorHandling `
            -ScriptBlock { & .\Tools\Build-Package.ps1 } `
            -ErrorMessage "Build failed"
    }
    
    "Prepare" {
        # Get USB drive letter
        $drives = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 }
        if ($drives.Count -eq 0) {
            Write-Host "No USB drives found." -ForegroundColor Red
            exit 1
        }
        
        Write-Host "Available USB drives:"
        $drives | ForEach-Object { Write-Host "$($_.DeviceID) - $($_.VolumeName)" }
        $driveLetter = Read-Host "`nEnter USB drive letter (e.g., E)"
        
        # Get Windows ISO path
        $isoPath = Read-Host "Enter path to Windows ISO file"
        
        Invoke-WithErrorHandling `
            -ScriptBlock { & .\Tools\Prepare-USB.ps1 -DriveLetter $driveLetter -WindowsIsoPath $isoPath } `
            -ErrorMessage "USB preparation failed"
    }
    
    "Verify" {
        Invoke-WithErrorHandling `
            -ScriptBlock { & .\Tools\Verify-Package.ps1 } `
            -ErrorMessage "Package verification failed"
    }
    
    "Clean" {
        $keepLogs = Read-Host "Keep log files? (y/N)"
        Invoke-WithErrorHandling `
            -ScriptBlock {
                if ($keepLogs -eq "y") {
                    & .\Tools\Clear-SensitiveData.ps1 -KeepLogs
                }
                else {
                    & .\Tools\Clear-SensitiveData.ps1
                }
            } `
            -ErrorMessage "Cleanup failed"
    }
    
    "PostTest" {
        $generateReport = Read-Host "Generate HTML report? (y/N)"
        Invoke-WithErrorHandling `
            -ScriptBlock {
                if ($generateReport -eq "y") {
                    & .\Tools\Test-PostDeployment.ps1 -GenerateReport
                }
                else {
                    & .\Tools\Test-PostDeployment.ps1
                }
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "`nAll post-deployment tests passed!" -ForegroundColor Green
                }
                else {
                    Write-Host "`nSome tests failed. Please review the results above." -ForegroundColor Red
                }
            } `
            -ErrorMessage "Post-deployment testing failed"
    }
}