# Utils.ps1
# Utility functions for elevation, confirmations, logging setup, etc.

function Test-Elevation {
    <#
    .SYNOPSIS
        Checks if the current process is running elevated.
    .OUTPUTS
        [bool] True if elevated, False otherwise.
    #>
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-Elevation {
    <#
    .SYNOPSIS
        Attempts to restart the script elevated.
    .PARAMETER ScriptPath
        Path to the script to restart.
    .PARAMETER Arguments
        Arguments to pass to the elevated script.
    .OUTPUTS
        Does not return if elevation succeeds.
    #>
    param (
        [string]$ScriptPath,
        [string[]]$Arguments
    )

    try {
        # Check if we're already elevated
        if (Test-Elevation) {
            Write-Warning "Script is already running elevated."
            return
        }

        Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow

        $argString = $Arguments -join ' '

        # Use Start-Process with runas verb for better reliability
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = "-ExecutionPolicy Bypass -NoProfile -Command `"& '$ScriptPath' $argString`""
        $psi.Verb = 'runas'
        $psi.UseShellExecute = $true
        $psi.WindowStyle = 'Normal'

        $process = [System.Diagnostics.Process]::Start($psi)

        # Wait a moment to see if elevation dialog appears
        Start-Sleep -Seconds 2

        # If the original process is still running and elevation succeeded, exit
        if (-not $process.HasExited) {
            Write-Host "Elevation request sent. The script will restart with administrator privileges." -ForegroundColor Green
            exit
        } else {
            # Elevation was denied or failed
            throw "Elevation was denied by user or failed to start."
        }
    }
    catch [System.ComponentModel.Win32Exception] {
        # This exception occurs when UAC is disabled or elevation is denied
        if ($_.Exception.NativeErrorCode -eq 1223) {
            throw "Elevation was denied by the user."
        } else {
            throw "Failed to elevate: $($_.Exception.Message) (Error code: $($_.Exception.NativeErrorCode))"
        }
    }
    catch {
        throw "Failed to elevate: $($_.Exception.Message)"
    }
}

function Get-UserConfirmation {
    <#
    .SYNOPSIS
        Prompts user for confirmation unless -Force is specified.
    .PARAMETER Message
        The confirmation message.
    .PARAMETER Force
        If true, skips confirmation.
    .OUTPUTS
        [bool] True if confirmed or forced.
    #>
    param (
        [string]$Message,
        [switch]$Force
    )

    if ($Force) {
        return $true
    }

    $response = Read-Host "$Message (y/N)"
    return $response -eq 'y' -or $response -eq 'Y'
}

function Initialize-Logging {
    <#
    .SYNOPSIS
        Sets up logging to console and file.
    .PARAMETER LogFile
        Path to log file.
    .PARAMETER LogLevel
        Logging level (Error, Warning, Info, Debug, Trace).
    #>
    param (
        [string]$LogFile,
        [ValidateSet('Error', 'Warning', 'Info', 'Debug', 'Trace')]
        [string]$LogLevel = 'Info'
    )

    # Use global variables instead of script-scoped for better job compatibility
    $global:LogLevel = $LogLevel
    $global:LogFile = $LogFile
}

function Write-Log {
    <#
    .SYNOPSIS
        Writes a log message based on level.
    .PARAMETER Level
        Log level.
    .PARAMETER Message
        Log message.
    #>
    param (
        [ValidateSet('Error', 'Warning', 'Info', 'Debug', 'Trace')]
        [string]$Level,
        [string]$Message
    )

    $levels = @{
        'Error' = 1
        'Warning' = 2
        'Info' = 3
        'Debug' = 4
        'Trace' = 5
    }

    if ($levels[$Level] -le $levels[$global:LogLevel]) {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $logMessage = "[$timestamp] [$Level] $Message"

        Write-Host $logMessage

        if ($global:LogFile) {
            Add-Content -Path $global:LogFile -Value $logMessage
        }
    }
}

function Get-DefaultCacheDirectory {
    <#
    .SYNOPSIS
        Gets the default cache directory.
    .OUTPUTS
        [string] Path to cache directory.
    #>
    $cacheDir = Join-Path $env:USERPROFILE '.universal-installer-cache'
    if (-not (Test-Path $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir | Out-Null
    }
    return $cacheDir
}

function Get-PackageFromAlias {
    <#
    .SYNOPSIS
        Resolves a package name using aliases.
    .PARAMETER Name
        Package name to resolve.
    .PARAMETER Aliases
        Hashtable of aliases.
    .OUTPUTS
        Resolved package info or null.
    #>
    param (
        [string]$Name,
        [hashtable]$Aliases
    )

    if ($Aliases.ContainsKey($Name)) {
        return $Aliases[$Name]
    }
    return $null
}
