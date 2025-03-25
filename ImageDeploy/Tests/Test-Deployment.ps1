<#
.SYNOPSIS
    Test script for Windows Deployment Tool
.DESCRIPTION
    Validates configuration, checks file paths, and tests key functionality
#>

$ErrorActionPreference = "Stop"
$testLog = Join-Path $PSScriptRoot "test_results.log"
$successCount = 0
$failureCount = 0

function Write-TestLog {
    param(
        [string]$Message,
        [string]$Status
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Status] $Message"
    Add-Content -Path $testLog -Value $logMessage
    Write-Host $logMessage -ForegroundColor $(if ($Status -eq "PASS") { "Green" } elseif ($Status -eq "FAIL") { "Red" } else { "Yellow" })
}

function Test-RequiredFiles {
    $requiredFiles = @(
        "..\autorun.inf",
        "..\Deployment\Config\deploy-config.xml",
        "..\Deployment\Scripts\Deploy-Windows.ps1",
        "..\SetupGUI\bin\Release\net6.0-windows\SetupGUI.exe"
    )

    foreach ($file in $requiredFiles) {
        $fullPath = Join-Path $PSScriptRoot $file
        if (Test-Path $fullPath) {
            Write-TestLog "Found required file: $file" "PASS"
            $script:successCount++
        } else {
            Write-TestLog "Missing required file: $file" "FAIL"
            $script:failureCount++
        }
    }
}

function Test-ConfigurationXml {
    try {
        $configPath = Join-Path $PSScriptRoot "..\Deployment\Config\deploy-config.xml"
        [xml]$config = Get-Content $configPath
        
        # Validate required XML elements
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
                Write-TestLog "Configuration has required element: $element" "PASS"
                $script:successCount++
            } else {
                Write-TestLog "Configuration missing required element: $element" "FAIL"
                $script:failureCount++
            }
        }
    } catch {
        Write-TestLog "Failed to validate configuration XML: $_" "FAIL"
        $script:failureCount++
    }
}

function Test-PowerShellScript {
    try {
        $scriptPath = Join-Path $PSScriptRoot "..\Deployment\Scripts\Deploy-Windows.ps1"
        $tokens = $null
        $parseErrors = $null
        
        # Test script syntax
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $scriptPath, [ref]$tokens, [ref]$parseErrors)

        if ($parseErrors.Count -eq 0) {
            Write-TestLog "PowerShell script syntax validation passed" "PASS"
            $script:successCount++
        } else {
            foreach ($error in $parseErrors) {
                Write-TestLog "PowerShell script syntax error: $($error.Message)" "FAIL"
                $script:failureCount++
            }
        }

        # Test required functions
        $requiredFunctions = @(
            "Write-Log",
            "Exit-WithError"
        )

        foreach ($function in $requiredFunctions) {
            if ($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq $function }, $true)) {
                Write-TestLog "Found required function: $function" "PASS"
                $script:successCount++
            } else {
                Write-TestLog "Missing required function: $function" "FAIL"
                $script:failureCount++
            }
        }
    } catch {
        Write-TestLog "Failed to analyze PowerShell script: $_" "FAIL"
        $script:failureCount++
    }
}

function Test-AdminPrivileges {
    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        $adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator

        if ($principal.IsInRole($adminRole)) {
            Write-TestLog "Running with administrator privileges" "PASS"
            $script:successCount++
        } else {
            Write-TestLog "Not running with administrator privileges" "FAIL"
            $script:failureCount++
        }
    } catch {
        Write-TestLog "Failed to check admin privileges: $_" "FAIL"
        $script:failureCount++
    }
}

function Test-NetworkConnectivity {
    try {
        $networkAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        if ($networkAdapters) {
            Write-TestLog "Found active network adapters" "PASS"
            $script:successCount++
        } else {
            Write-TestLog "No active network adapters found" "WARN"
        }
    } catch {
        Write-TestLog "Failed to check network adapters: $_" "FAIL"
        $script:failureCount++
    }
}

# Run Tests
Write-Host "`nStarting Deployment Tests..." -ForegroundColor Cyan
"=== Test Results ===" | Set-Content $testLog

Test-RequiredFiles
Test-ConfigurationXml
Test-PowerShellScript
Test-AdminPrivileges
Test-NetworkConnectivity

# Summary
Write-Host "`nTest Summary:" -ForegroundColor Cyan
Write-Host "Passed: $successCount" -ForegroundColor Green
Write-Host "Failed: $failureCount" -ForegroundColor Red
Write-Host "`nDetailed results saved to: $testLog" -ForegroundColor Yellow

if ($failureCount -gt 0) {
    exit 1
} else {
    exit 0
}