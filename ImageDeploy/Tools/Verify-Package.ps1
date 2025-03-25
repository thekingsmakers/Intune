<#
.SYNOPSIS
    Verifies Windows deployment package integrity
.DESCRIPTION
    Checks all required files, validates configurations, and tests components
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$verificationLog = ".\Logs\Verification-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$requiredFiles = @{
    "Core Files" = @(
        ".\Deploy.ps1",
        ".\README.md",
        ".\QuickStart.md",
        ".\autorun.inf"
    )
    "Deployment" = @(
        ".\Deployment\Scripts\Deploy-Windows.ps1",
        ".\Deployment\Config\deploy-config.xml"
    )
    "Tools" = @(
        ".\Tools\Prepare-USB.ps1",
        ".\Tools\Monitor-Deployment.ps1",
        ".\Tools\Test-Requirements.ps1",
        ".\Tools\Rollback-Deployment.ps1",
        ".\Tools\Build-Package.ps1"
    )
    "SetupGUI" = @(
        ".\SetupGUI\SetupGUI.csproj",
        ".\SetupGUI\MainForm.cs",
        ".\SetupGUI\Program.cs",
        ".\SetupGUI\app.manifest"
    )
}

function Write-VerificationLog {
    param(
        [string]$Component,
        [string]$Status,
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Status) {
        "PASS" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
        default { "White" }
    }
    
    $logMessage = "[$timestamp] [$Component] [$Status] $Message"
    Add-Content -Path $verificationLog -Value $logMessage
    Write-Host $logMessage -ForegroundColor $color
}

function Test-FileIntegrity {
    Write-Host "`nChecking file integrity..." -ForegroundColor Cyan
    
    $missingFiles = @()
    
    foreach ($category in $requiredFiles.Keys) {
        Write-Host "`nVerifying $category..." -ForegroundColor Yellow
        
        foreach ($file in $requiredFiles[$category]) {
            if (Test-Path $file) {
                $fileInfo = Get-Item $file
                Write-VerificationLog -Component $category -Status "PASS" -Message "$file ($(($fileInfo.Length/1KB).ToString('N2'))KB)"
            }
            else {
                Write-VerificationLog -Component $category -Status "FAIL" -Message "$file (Missing)"
                $missingFiles += $file
            }
        }
    }
    
    return $missingFiles
}

function Test-XMLConfiguration {
    Write-Host "`nValidating XML configuration..." -ForegroundColor Cyan
    
    try {
        $configPath = ".\Deployment\Config\deploy-config.xml"
        [xml]$config = Get-Content $configPath
        
        # Check required XML elements
        $requiredElements = @(
            "/Deployment",
            "/Deployment/Software",
            "/Deployment/Network",
            "/Deployment/WindowsActivation",
            "/Deployment/Features",
            "/Deployment/Domain"
        )
        
        foreach ($element in $requiredElements) {
            if ($config.SelectSingleNode($element)) {
                Write-VerificationLog -Component "XML" -Status "PASS" -Message "Found element: $element"
            }
            else {
                Write-VerificationLog -Component "XML" -Status "FAIL" -Message "Missing element: $element"
                return $false
            }
        }
        
        return $true
    }
    catch {
        Write-VerificationLog -Component "XML" -Status "FAIL" -Message "Failed to validate XML: $_"
        return $false
    }
}

function Test-PowerShellScripts {
    Write-Host "`nValidating PowerShell scripts..." -ForegroundColor Cyan
    
    $scriptFiles = Get-ChildItem -Path . -Recurse -Filter "*.ps1"
    $hasErrors = $false
    
    foreach ($script in $scriptFiles) {
        try {
            $tokens = $null
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $script.FullName, [ref]$tokens, [ref]$parseErrors)
            
            if ($parseErrors.Count -eq 0) {
                Write-VerificationLog -Component "Scripts" -Status "PASS" -Message $script.Name
            }
            else {
                Write-VerificationLog -Component "Scripts" -Status "FAIL" -Message "$($script.Name) - $($parseErrors.Count) errors"
                $hasErrors = $true
            }
        }
        catch {
            Write-VerificationLog -Component "Scripts" -Status "FAIL" -Message "$($script.Name) - $_"
            $hasErrors = $true
        }
    }
    
    return !$hasErrors
}

function Test-DotNetProjects {
    Write-Host "`nValidating .NET projects..." -ForegroundColor Cyan
    
    try {
        $projects = Get-ChildItem -Path . -Recurse -Filter "*.csproj"
        foreach ($project in $projects) {
            try {
                [xml]$projectXml = Get-Content $project.FullName
                $targetFramework = $projectXml.Project.PropertyGroup.TargetFramework
                
                if ($targetFramework -match "net6.0") {
                    Write-VerificationLog -Component "Projects" -Status "PASS" -Message "$($project.Name) - $targetFramework"
                }
                else {
                    Write-VerificationLog -Component "Projects" -Status "WARN" -Message "$($project.Name) - Unexpected framework: $targetFramework"
                }
            }
            catch {
                Write-VerificationLog -Component "Projects" -Status "FAIL" -Message "$($project.Name) - $_"
                return $false
            }
        }
        return $true
    }
    catch {
        Write-VerificationLog -Component "Projects" -Status "FAIL" -Message "Failed to validate projects: $_"
        return $false
    }
}

# Main verification process
try {
    Write-Host "Windows Deployment Package Verification" -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
    
    # Create logs directory if it doesn't exist
    New-Item -ItemType Directory -Path ".\Logs" -Force | Out-Null
    
    # Run verification checks
    $missingFiles = Test-FileIntegrity
    $xmlValid = Test-XMLConfiguration
    $scriptsValid = Test-PowerShellScripts
    $projectsValid = Test-DotNetProjects
    
    # Summary
    Write-Host "`nVerification Summary" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    
    if ($missingFiles.Count -eq 0) {
        Write-Host "File Integrity: " -NoNewline; Write-Host "PASS" -ForegroundColor Green
    }
    else {
        Write-Host "File Integrity: " -NoNewline; Write-Host "FAIL" -ForegroundColor Red
        Write-Host "Missing files:"
        $missingFiles | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    }
    
    Write-Host "XML Configuration: " -NoNewline
    if ($xmlValid) { Write-Host "PASS" -ForegroundColor Green } else { Write-Host "FAIL" -ForegroundColor Red }
    
    Write-Host "PowerShell Scripts: " -NoNewline
    if ($scriptsValid) { Write-Host "PASS" -ForegroundColor Green } else { Write-Host "FAIL" -ForegroundColor Red }
    
    Write-Host ".NET Projects: " -NoNewline
    if ($projectsValid) { Write-Host "PASS" -ForegroundColor Green } else { Write-Host "FAIL" -ForegroundColor Red }
    
    Write-Host "`nVerification log saved to: $verificationLog"
    
    # Final status
    if ($missingFiles.Count -eq 0 -and $xmlValid -and $scriptsValid -and $projectsValid) {
        Write-Host "`nPackage verification completed successfully." -ForegroundColor Green
        exit 0
    }
    else {
        Write-Host "`nPackage verification failed. Check the log for details." -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Error "Verification failed: $_"
    exit 1
}