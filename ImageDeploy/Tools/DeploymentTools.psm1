<#
.SYNOPSIS
    Common functions for Windows deployment tools
.DESCRIPTION
    Provides shared functionality for deployment scripts including logging,
    error handling, and system configuration tasks
#>

# Define module-wide variables
$script:LogPath = $null
$script:ConfigPath = $null
$script:ErrorCount = 0
$script:WarningCount = 0

function Initialize-DeploymentTools {
    param(
        [Parameter(Mandatory=$true)]
        [string]$LogDirectory,
        
        [Parameter(Mandatory=$false)]
        [string]$ConfigFile = "deploy-config.xml"
    )
    
    # Setup logging
    if (-not (Test-Path $LogDirectory)) {
        New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
    }
    
    $script:LogPath = Join-Path $LogDirectory "Deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    $script:ConfigPath = $ConfigFile
    
    # Start transcript
    Start-Transcript -Path $script:LogPath -Append
}

function Write-DeploymentLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "ERROR" { 
            Write-Host $logMessage -ForegroundColor Red
            $script:ErrorCount++
        }
        "WARNING" { 
            Write-Host $logMessage -ForegroundColor Yellow
            $script:WarningCount++
        }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }
    
    if ($script:LogPath) {
        Add-Content -Path $script:LogPath -Value $logMessage
    }
}

function Test-AdminPrivileges {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-DeploymentConfig {
    param([string]$XPath)
    
    try {
        if (-not $script:ConfigPath -or -not (Test-Path $script:ConfigPath)) {
            throw "Configuration file not found: $script:ConfigPath"
        }
        
        [xml]$config = Get-Content $script:ConfigPath
        if ($XPath) {
            return $config.SelectSingleNode($XPath)
        }
        return $config
    }
    catch {
        Write-DeploymentLog "Failed to load configuration: $_" -Level "ERROR"
        return $null
    }
}

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxAttempts = 3,
        
        [Parameter(Mandatory=$false)]
        [int]$DelaySeconds = 10,
        
        [Parameter(Mandatory=$false)]
        [string]$Operation = "operation"
    )
    
    $attempt = 1
    $success = $false
    
    while (-not $success -and $attempt -le $MaxAttempts) {
        try {
            if ($attempt -gt 1) {
                Write-DeploymentLog "Retrying $Operation (Attempt $attempt of $MaxAttempts)..." -Level "WARNING"
                Start-Sleep -Seconds $DelaySeconds
            }
            
            & $ScriptBlock
            $success = $true
        }
        catch {
            if ($attempt -eq $MaxAttempts) {
                Write-DeploymentLog "All attempts failed for $Operation : $_" -Level "ERROR"
                throw
            }
            Write-DeploymentLog "Attempt $attempt failed: $_" -Level "WARNING"
            $attempt++
        }
    }
}

function Wait-ForCondition {
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$Condition,
        
        [Parameter(Mandatory=$false)]
        [int]$TimeoutSeconds = 300,
        
        [Parameter(Mandatory=$false)]
        [int]$DelaySeconds = 5,
        
        [Parameter(Mandatory=$false)]
        [string]$Message = "condition"
    )
    
    $timeout = [DateTime]::Now.AddSeconds($TimeoutSeconds)
    
    while ([DateTime]::Now -lt $timeout) {
        try {
            if (& $Condition) {
                return $true
            }
            Write-DeploymentLog "Waiting for $Message..." -Level "INFO"
            Start-Sleep -Seconds $DelaySeconds
        }
        catch {
            Write-DeploymentLog "Error checking $Message : $_" -Level "WARNING"
        }
    }
    
    Write-DeploymentLog "Timeout waiting for $Message" -Level "ERROR"
    return $false
}

function Backup-SystemState {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BackupPath,
        
        [Parameter(Mandatory=$false)]
        [string[]]$Items = @()
    )
    
    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupDir = Join-Path $BackupPath "Backup-$timestamp"
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        
        # Backup registry items
        $regBackupPath = Join-Path $backupDir "Registry"
        New-Item -ItemType Directory -Path $regBackupPath -Force | Out-Null
        
        foreach ($item in $Items) {
            if ($item.StartsWith("HKLM:") -or $item.StartsWith("HKCU:")) {
                $regKey = $item -replace "^[^\\]+\\(.+)$",'$1'
                $filename = ($regKey -replace "\\","-") + ".reg"
                $outFile = Join-Path $regBackupPath $filename
                reg export ($item -replace "^[^\\]+","`"HKLM") "`"$outFile`"" /y | Out-Null
            }
            else {
                Copy-Item -Path $item -Destination $backupDir -Recurse -Force
            }
        }
        
        Write-DeploymentLog "System state backed up to: $backupDir" -Level "SUCCESS"
        return $backupDir
    }
    catch {
        Write-DeploymentLog "Failed to backup system state: $_" -Level "ERROR"
        return $null
    }
}

function Get-DeploymentStatistics {
    return [PSCustomObject]@{
        Errors = $script:ErrorCount
        Warnings = $script:WarningCount
        LogFile = $script:LogPath
        StartTime = Get-Content $script:LogPath -TotalCount 1 | ForEach-Object { 
            [datetime]::ParseExact($_ -replace '^\[([^\]]+)\].*','$1', 'yyyy-MM-dd HH:mm:ss')
        }
        EndTime = Get-Date
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-DeploymentTools',
    'Write-DeploymentLog',
    'Test-AdminPrivileges',
    'Get-DeploymentConfig',
    'Invoke-WithRetry',
    'Wait-ForCondition',
    'Backup-SystemState',
    'Get-DeploymentStatistics'
)