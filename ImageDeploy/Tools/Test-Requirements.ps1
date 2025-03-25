<#
.SYNOPSIS
    Validates system requirements and deployment prerequisites
.DESCRIPTION
    Checks hardware requirements, software dependencies, and validates installation packages
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = "..\Deployment\Config\deploy-config.xml"
)

$ErrorActionPreference = "Stop"
$global:testsFailed = 0
$global:testsWarning = 0
$global:testsPassed = 0

function Write-TestResult {
    param(
        [string]$TestName,
        [string]$Status,
        [string]$Message
    )
    
    $color = switch ($Status) {
        "PASS" { "Green"; $global:testsPassed++ }
        "WARN" { "Yellow"; $global:testsWarning++ }
        "FAIL" { "Red"; $global:testsFailed++ }
    }
    
    Write-Host ("[{0}] {1}" -f $Status, $TestName) -ForegroundColor $color
    if ($Message) {
        Write-Host ("  {0}" -f $Message) -ForegroundColor DarkGray
    }
}

function Test-HardwareRequirements {
    Write-Host "`nChecking Hardware Requirements..." -ForegroundColor Cyan
    
    # Check CPU cores
    $cpu = Get-WmiObject Win32_Processor
    $cores = $cpu.NumberOfLogicalProcessors
    if ($cores -ge 2) {
        Write-TestResult -TestName "CPU Cores" -Status "PASS" -Message "Found $cores logical processors"
    } else {
        Write-TestResult -TestName "CPU Cores" -Status "WARN" -Message "Only $cores logical processors found, recommend 2 or more"
    }
    
    # Check RAM
    $ram = (Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    $ram = [math]::Round($ram, 2)
    if ($ram -ge 4) {
        Write-TestResult -TestName "System Memory" -Status "PASS" -Message "Found $ram GB RAM"
    } else {
        Write-TestResult -TestName "System Memory" -Status "WARN" -Message "Only $ram GB RAM found, recommend 4GB or more"
    }
    
    # Check Disk Space
    $disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
    $freeSpace = [math]::Round($disk.FreeSpace / 1GB, 2)
    if ($freeSpace -ge 20) {
        Write-TestResult -TestName "Disk Space" -Status "PASS" -Message "Found $freeSpace GB free space"
    } else {
        Write-TestResult -TestName "Disk Space" -Status "FAIL" -Message "Only $freeSpace GB free space, require minimum 20GB"
    }
}

function Test-SoftwarePrerequisites {
    Write-Host "`nChecking Software Prerequisites..." -ForegroundColor Cyan
    
    # Check .NET Framework
    $dotnetKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue
    if ($dotnetKey.Release -ge 528040) {
        Write-TestResult -TestName ".NET Framework" -Status "PASS" -Message "Found .NET Framework $($dotnetKey.Version)"
    } else {
        Write-TestResult -TestName ".NET Framework" -Status "FAIL" -Message "Requires .NET Framework 4.8 or later"
    }
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -ge 5) {
        Write-TestResult -TestName "PowerShell Version" -Status "PASS" -Message "Found PowerShell $psVersion"
    } else {
        Write-TestResult -TestName "PowerShell Version" -Status "FAIL" -Message "Requires PowerShell 5.0 or later"
    }
}

function Test-NetworkConnectivity {
    Write-Host "`nChecking Network Connectivity..." -ForegroundColor Cyan
    
    # Check network adapter
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
    if ($adapter) {
        Write-TestResult -TestName "Network Adapter" -Status "PASS" -Message "Found active adapter: $($adapter.Name)"
    } else {
        Write-TestResult -TestName "Network Adapter" -Status "FAIL" -Message "No active network adapter found"
    }
    
    # Check internet connectivity
    $testUrls = @(
        "http://www.microsoft.com",
        "http://www.google.com"
    )
    
    $connected = $false
    foreach ($url in $testUrls) {
        try {
            $response = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 5 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                $connected = $true
                break
            }
        } catch {
            continue
        }
    }
    
    if ($connected) {
        Write-TestResult -TestName "Internet Connectivity" -Status "PASS" -Message "Successfully connected to internet"
    } else {
        Write-TestResult -TestName "Internet Connectivity" -Status "WARN" -Message "Could not verify internet connectivity"
    }
}

function Test-InstallationPackages {
    Write-Host "`nValidating Installation Packages..." -ForegroundColor Cyan
    
    try {
        # Load configuration
        [xml]$config = Get-Content $ConfigPath
        $installersPath = "..\Deployment\Installers"
        
        if (-not (Test-Path $installersPath)) {
            Write-TestResult -TestName "Installers Directory" -Status "FAIL" -Message "Installers directory not found"
            return
        }
        
        # Check each package in config
        foreach ($package in $config.Deployment.Software.Package) {
            $installerPath = Join-Path $installersPath $package.Name
            if (Test-Path $installerPath) {
                $fileInfo = Get-Item $installerPath
                Write-TestResult -TestName "Package: $($package.Name)" -Status "PASS" -Message "Found: $($fileInfo.Length) bytes"
            } else {
                Write-TestResult -TestName "Package: $($package.Name)" -Status "FAIL" -Message "File not found: $installerPath"
            }
        }
    } catch {
        Write-TestResult -TestName "Package Validation" -Status "FAIL" -Message $_.Exception.Message
    }
}

function Test-AdminPrivileges {
    Write-Host "`nChecking Administrative Rights..." -ForegroundColor Cyan
    
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
    
    if ($principal.IsInRole($adminRole)) {
        Write-TestResult -TestName "Admin Privileges" -Status "PASS" -Message "Running with administrative rights"
    } else {
        Write-TestResult -TestName "Admin Privileges" -Status "FAIL" -Message "Requires administrative rights"
    }
}

# Run all tests
Write-Host "Windows Deployment System Requirements Check" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

Test-AdminPrivileges
Test-HardwareRequirements
Test-SoftwarePrerequisites
Test-NetworkConnectivity
Test-InstallationPackages

# Display summary
Write-Host "`nTest Summary" -ForegroundColor Cyan
Write-Host "===========" -ForegroundColor Cyan
Write-Host "Passed: $global:testsPassed" -ForegroundColor Green
Write-Host "Warnings: $global:testsWarning" -ForegroundColor Yellow
Write-Host "Failed: $global:testsFailed" -ForegroundColor Red

if ($global:testsFailed -gt 0) {
    Write-Host "`nCritical requirements not met. Please address failed tests before proceeding." -ForegroundColor Red
    exit 1
} elseif ($global:testsWarning -gt 0) {
    Write-Host "`nWarning: Some tests generated warnings but deployment can proceed." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "`nAll requirements met. Ready for deployment." -ForegroundColor Green
    exit 0
}