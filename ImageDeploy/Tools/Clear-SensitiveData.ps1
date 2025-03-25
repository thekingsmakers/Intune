<#
.SYNOPSIS
    Cleans up sensitive data after deployment
.DESCRIPTION
    Removes credentials, logs, and temporary files containing sensitive information
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Force,
    
    [Parameter()]
    [switch]$KeepLogs
)

$ErrorActionPreference = "Stop"
$cleanupLog = ".\Logs\Cleanup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-CleanupLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $cleanupLog -Value $logMessage
    
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host $logMessage -ForegroundColor $color
}

function Clear-ConfigurationFiles {
    Write-CleanupLog "Cleaning configuration files..."
    
    try {
        $configPath = ".\Deployment\Config\deploy-config.xml"
        if (Test-Path $configPath) {
            [xml]$config = Get-Content $configPath
            
            # Clear sensitive data
            $nodesToClear = @(
                "/Deployment/Domain/DomainPassword",
                "/Deployment/Network/Password",
                "/Deployment/WindowsActivation/ProductKey"
            )
            
            foreach ($xpath in $nodesToClear) {
                $node = $config.SelectSingleNode($xpath)
                if ($node) {
                    $node.InnerText = ""
                    Write-CleanupLog "Cleared $xpath" -Level "SUCCESS"
                }
            }
            
            # Save sanitized config
            $config.Save($configPath)
        }
    }
    catch {
        Write-CleanupLog "Failed to clean configuration: $_" -Level "ERROR"
    }
}

function Remove-LogFiles {
    if ($KeepLogs) {
        Write-CleanupLog "Keeping log files as requested" -Level "WARN"
        return
    }
    
    Write-CleanupLog "Removing log files..."
    
    try {
        $logPaths = @(
            ".\Deployment\Logs\*.log",
            ".\Tests\*.log",
            ".\Logs\*.log"
        )
        
        foreach ($path in $logPaths) {
            if (Test-Path $path) {
                Remove-Item $path -Force
                Write-CleanupLog "Removed logs: $path" -Level "SUCCESS"
            }
        }
    }
    catch {
        Write-CleanupLog "Failed to remove logs: $_" -Level "ERROR"
    }
}

function Clear-TempFiles {
    Write-CleanupLog "Cleaning temporary files..."
    
    try {
        # List of temp file patterns
        $tempPatterns = @(
            "*_temp_*",
            "*.tmp",
            "~*.*"
        )
        
        foreach ($pattern in $tempPatterns) {
            Get-ChildItem -Path . -Recurse -Filter $pattern | ForEach-Object {
                Remove-Item $_.FullName -Force
                Write-CleanupLog "Removed temp file: $($_.FullName)" -Level "SUCCESS"
            }
        }
    }
    catch {
        Write-CleanupLog "Failed to clean temp files: $_" -Level "ERROR"
    }
}

function Remove-InstallerCache {
    Write-CleanupLog "Cleaning installer cache..."
    
    try {
        $cachePaths = @(
            ".\Deployment\Installers\cache",
            ".\Deployment\Installers\temp"
        )
        
        foreach ($path in $cachePaths) {
            if (Test-Path $path) {
                Remove-Item $path -Recurse -Force
                Write-CleanupLog "Removed installer cache: $path" -Level "SUCCESS"
            }
        }
    }
    catch {
        Write-CleanupLog "Failed to clean installer cache: $_" -Level "ERROR"
    }
}

function Clear-PowerShellHistory {
    Write-CleanupLog "Clearing PowerShell history..."
    
    try {
        Clear-History -ErrorAction SilentlyContinue
        Remove-Item (Get-PSReadlineOption).HistorySavePath -Force -ErrorAction SilentlyContinue
        Write-CleanupLog "PowerShell history cleared" -Level "SUCCESS"
    }
    catch {
        Write-CleanupLog "Failed to clear PowerShell history: $_" -Level "ERROR"
    }
}

try {
    Write-Host "Windows Deployment - Sensitive Data Cleanup" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    
    if (-not $Force) {
        Write-Host "`nWARNING: This will remove sensitive data including:" -ForegroundColor Yellow
        Write-Host "- Credentials from configuration files" -ForegroundColor Yellow
        Write-Host "- Log files (unless -KeepLogs is specified)" -ForegroundColor Yellow
        Write-Host "- Temporary files and installer cache" -ForegroundColor Yellow
        Write-Host "- PowerShell command history" -ForegroundColor Yellow
        
        $confirm = Read-Host "`nDo you want to continue? (y/N)"
        if ($confirm -ne "y") {
            Write-Host "Operation cancelled by user" -ForegroundColor Yellow
            exit
        }
    }
    
    # Create logs directory if needed
    New-Item -ItemType Directory -Path ".\Logs" -Force | Out-Null
    
    # Perform cleanup
    Clear-ConfigurationFiles
    Remove-LogFiles
    Clear-TempFiles
    Remove-InstallerCache
    Clear-PowerShellHistory
    
    Write-Host "`nCleanup completed successfully" -ForegroundColor Green
    if (-not $KeepLogs) {
        Write-Host "Note: This log file will be removed on next cleanup." -ForegroundColor Yellow
    }
}
catch {
    Write-Error "Cleanup failed: $_"
    exit 1
}