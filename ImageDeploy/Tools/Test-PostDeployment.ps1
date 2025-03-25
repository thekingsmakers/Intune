<#
.SYNOPSIS
    Validates post-deployment configuration and installed software
.DESCRIPTION
    Performs comprehensive checks of system settings, software installation, and domain configuration
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ConfigPath = "..\Deployment\Config\deploy-config.xml",
    
    [Parameter()]
    [switch]$GenerateReport
)

$ErrorActionPreference = "Stop"
$testResults = @{
    Passed = 0
    Failed = 0
    Warnings = 0
    Details = @()
}

function Write-TestResult {
    param(
        [string]$Category,
        [string]$Test,
        [string]$Result,
        [string]$Details
    )
    
    $color = switch ($Result) {
        "PASS" { "Green"; $script:testResults.Passed++ }
        "FAIL" { "Red"; $script:testResults.Failed++ }
        "WARN" { "Yellow"; $script:testResults.Warnings++ }
    }
    
    $message = "[$Category] $Test : $Result"
    Write-Host $message -ForegroundColor $color
    
    if ($Details) {
        Write-Host "  $Details" -ForegroundColor DarkGray
    }
    
    $script:testResults.Details += [PSCustomObject]@{
        Category = $Category
        Test = $Test
        Result = $Result
        Details = $Details
        Timestamp = (Get-Date)
    }
}

function Test-InstalledSoftware {
    Write-Host "`nChecking Installed Software..." -ForegroundColor Cyan
    
    try {
        [xml]$config = Get-Content $ConfigPath
        
        foreach ($package in $config.Deployment.Software.Package) {
            $packageName = $package.Name
            $found = $false
            
            # Check both 64-bit and 32-bit registry paths
            $uninstallKeys = @(
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )
            
            $installedApp = Get-ItemProperty $uninstallKeys | 
                Where-Object { $_.DisplayName -like "*$packageName*" } |
                Select-Object -First 1
            
            if ($installedApp) {
                Write-TestResult -Category "Software" -Test $packageName -Result "PASS" `
                    -Details "Version: $($installedApp.DisplayVersion)"
            }
            else {
                Write-TestResult -Category "Software" -Test $packageName -Result "FAIL" `
                    -Details "Software not found"
            }
        }
    }
    catch {
        Write-TestResult -Category "Software" -Test "Package Verification" -Result "FAIL" `
            -Details $_.Exception.Message
    }
}

function Test-NetworkConfiguration {
    Write-Host "`nChecking Network Configuration..." -ForegroundColor Cyan
    
    # Check WiFi connection
    try {
        [xml]$config = Get-Content $ConfigPath
        $configuredSSID = $config.Deployment.Network.SSID
        
        $currentNetwork = netsh wlan show interfaces | 
            Select-String "SSID\s+:\s(.+)$" | 
            ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
        
        if ($currentNetwork -eq $configuredSSID) {
            Write-TestResult -Category "Network" -Test "WiFi" -Result "PASS" `
                -Details "Connected to $configuredSSID"
        }
        else {
            Write-TestResult -Category "Network" -Test "WiFi" -Result "FAIL" `
                -Details "Expected: $configuredSSID, Current: $currentNetwork"
        }
    }
    catch {
        Write-TestResult -Category "Network" -Test "WiFi" -Result "FAIL" `
            -Details $_.Exception.Message
    }
    
    # Check network connectivity
    try {
        $testUrls = @(
            "http://www.microsoft.com",
            "http://www.google.com"
        )
        
        $connected = $false
        foreach ($url in $testUrls) {
            if (Test-NetConnection -ComputerName $url.Replace("http://","") -Port 80 -WarningAction SilentlyContinue) {
                $connected = $true
                break
            }
        }
        
        if ($connected) {
            Write-TestResult -Category "Network" -Test "Internet" -Result "PASS" `
                -Details "Internet connectivity verified"
        }
        else {
            Write-TestResult -Category "Network" -Test "Internet" -Result "FAIL" `
                -Details "No internet connectivity"
        }
    }
    catch {
        Write-TestResult -Category "Network" -Test "Internet" -Result "FAIL" `
            -Details $_.Exception.Message
    }
}

function Test-DomainConfiguration {
    Write-Host "`nChecking Domain Configuration..." -ForegroundColor Cyan
    
    try {
        [xml]$config = Get-Content $ConfigPath
        $configuredDomain = $config.Deployment.Domain.DomainName
        
        if ($config.Deployment.Domain.JoinDomain -eq "true") {
            $computerSystem = Get-WmiObject Win32_ComputerSystem
            
            if ($computerSystem.PartOfDomain) {
                if ($computerSystem.Domain -eq $configuredDomain) {
                    Write-TestResult -Category "Domain" -Test "Join Status" -Result "PASS" `
                        -Details "Joined to $($computerSystem.Domain)"
                }
                else {
                    Write-TestResult -Category "Domain" -Test "Join Status" -Result "FAIL" `
                        -Details "Joined to incorrect domain: $($computerSystem.Domain)"
                }
            }
            else {
                Write-TestResult -Category "Domain" -Test "Join Status" -Result "FAIL" `
                    -Details "Not joined to any domain"
            }
        }
        else {
            Write-TestResult -Category "Domain" -Test "Join Status" -Result "PASS" `
                -Details "Domain join not configured"
        }
    }
    catch {
        Write-TestResult -Category "Domain" -Test "Join Status" -Result "FAIL" `
            -Details $_.Exception.Message
    }
}

function Test-WindowsFeatures {
    Write-Host "`nChecking Windows Features..." -ForegroundColor Cyan
    
    try {
        [xml]$config = Get-Content $ConfigPath
        
        foreach ($feature in $config.Deployment.Features.Feature) {
            $state = Get-WindowsOptionalFeature -Online -FeatureName $feature
            
            if ($state.State -eq "Enabled") {
                Write-TestResult -Category "Features" -Test $feature -Result "PASS" `
                    -Details "Feature is enabled"
            }
            else {
                Write-TestResult -Category "Features" -Test $feature -Result "FAIL" `
                    -Details "Feature is not enabled"
            }
        }
    }
    catch {
        Write-TestResult -Category "Features" -Test "Feature Verification" -Result "FAIL" `
            -Details $_.Exception.Message
    }
}

function Export-TestReport {
    if (-not $GenerateReport) { return }
    
    $reportPath = ".\Logs\PostDeployment-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Post-Deployment Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #2c3e50; }
        .summary { margin: 20px 0; padding: 10px; background-color: #f8f9fa; }
        .pass { color: green; }
        .fail { color: red; }
        .warn { color: orange; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Post-Deployment Test Report</h1>
    <div class="summary">
        <h2>Summary</h2>
        <p>Tests Passed: <span class="pass">$($testResults.Passed)</span></p>
        <p>Tests Failed: <span class="fail">$($testResults.Failed)</span></p>
        <p>Warnings: <span class="warn">$($testResults.Warnings)</span></p>
    </div>
    <table>
        <tr>
            <th>Category</th>
            <th>Test</th>
            <th>Result</th>
            <th>Details</th>
            <th>Timestamp</th>
        </tr>
"@

    foreach ($result in $testResults.Details) {
        $color = switch ($result.Result) {
            "PASS" { "green" }
            "FAIL" { "red" }
            "WARN" { "orange" }
        }
        
        $html += @"
        <tr>
            <td>$($result.Category)</td>
            <td>$($result.Test)</td>
            <td style="color: $color">$($result.Result)</td>
            <td>$($result.Details)</td>
            <td>$($result.Timestamp)</td>
        </tr>
"@
    }

    $html += @"
    </table>
</body>
</html>
"@

    $html | Out-File -FilePath $reportPath -Encoding utf8
    Write-Host "`nTest report generated: $reportPath" -ForegroundColor Green
}

try {
    Write-Host "Post-Deployment Configuration Test" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    
    Test-InstalledSoftware
    Test-NetworkConfiguration
    Test-DomainConfiguration
    Test-WindowsFeatures
    
    # Summary
    Write-Host "`nTest Summary" -ForegroundColor Cyan
    Write-Host "===========" -ForegroundColor Cyan
    Write-Host "Passed: $($testResults.Passed)" -ForegroundColor Green
    Write-Host "Failed: $($testResults.Failed)" -ForegroundColor Red
    Write-Host "Warnings: $($testResults.Warnings)" -ForegroundColor Yellow
    
    # Generate HTML report if requested
    Export-TestReport
    
    # Return appropriate exit code
    if ($testResults.Failed -gt 0) {
        exit 1
    }
    exit 0
}
catch {
    Write-Error "Test execution failed: $_"
    exit 1
}