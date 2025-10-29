# PackageManagers.ps1
# Functions for detecting and interacting with package managers (winget, choco)

function Test-PackageManager {
    <#
    .SYNOPSIS
        Tests if a package manager is available and up-to-date.
    .PARAMETER Manager
        The package manager to test ('winget' or 'choco').
    .OUTPUTS
        [bool] True if available and suitable, False otherwise.
    #>
    param (
        [Parameter(Mandatory)]
        [ValidateSet('winget', 'choco')]
        [string]$Manager
    )

    try {
        switch ($Manager) {
            'winget' {
                $version = & winget --version 2>$null
                if ($LASTEXITCODE -eq 0) {
                    # Check if version is recent enough (basic check)
                    $versionNumber = $version -replace '^v', ''
                    if ([version]$versionNumber -ge [version]'1.0.0') {
                        return $true
                    }
                }
            }
            'choco' {
                $version = & choco --version 2>$null
                if ($LASTEXITCODE -eq 0) {
                    return $true
                }
            }
        }
    }
    catch {
        Write-Warning "Error testing $Manager`: $($_.Exception.Message)"
    }
    return $false
}

function Get-AvailablePackageManagers {
    <#
    .SYNOPSIS
        Detects available package managers in order of preference.
    .OUTPUTS
        [string[]] Array of available managers ('winget', 'choco').
    #>
    $managers = @()
    if (Test-PackageManager -Manager 'winget') {
        $managers += 'winget'
    }
    if (Test-PackageManager -Manager 'choco') {
        $managers += 'choco'
    }
    return $managers
}

function Invoke-WingetCommand {
    <#
    .SYNOPSIS
        Executes a winget command and parses JSON output if available.
    .PARAMETER Arguments
        Arguments to pass to winget.
    .PARAMETER JsonOutput
        If true, uses --output json and parses output.
    .PARAMETER TimeoutSeconds
        Timeout in seconds (default: 300 = 5 minutes).
    #>
    param (
        [string[]]$Arguments,
        [switch]$JsonOutput,
        [int]$TimeoutSeconds = 300
    )

    # Validate arguments
    if (-not $Arguments -or $Arguments.Count -eq 0) {
        return [PSCustomObject]@{
            Output = "Error: No arguments provided to winget command"
            ExitCode = 1
            Error = $null
        }
    }

    $commandArgs = $Arguments
    if ($JsonOutput) {
        $commandArgs += '--output', 'json'
    }

    try {
        Write-Host "Executing: winget $($commandArgs -join ' ')" -ForegroundColor Cyan
        
        # Create temp files with proper paths
        $tempOutput = [System.IO.Path]::GetTempFileName()
        $tempError = [System.IO.Path]::GetTempFileName()
        
        # Use proper encoding to avoid weird characters
        $process = Start-Process -FilePath 'winget.exe' -ArgumentList $commandArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tempOutput -RedirectStandardError $tempError
        
        # Wait for process with timeout
        $startTime = Get-Date
        while (-not $process.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
            Start-Sleep -Milliseconds 500
            Write-Host "." -NoNewline -ForegroundColor Yellow
        }
        
        if (-not $process.HasExited) {
            Write-Host "`nTimeout reached, terminating winget process..." -ForegroundColor Red
            $process.Kill()
            # Clean up temp files
            Remove-Item $tempOutput -ErrorAction SilentlyContinue
            Remove-Item $tempError -ErrorAction SilentlyContinue
            return [PSCustomObject]@{
                Output = "Winget command timed out after $TimeoutSeconds seconds"
                ExitCode = -1
                Error = $null
            }
        }
        
        Write-Host " Done (Exit code: $($process.ExitCode))" -ForegroundColor Green
        
        $output = Get-Content $tempOutput -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        $errorOutput = Get-Content $tempError -Raw -Encoding UTF8 -ErrorAction SilentlyContinue

        # Clean up temp files
        Remove-Item $tempOutput -ErrorAction SilentlyContinue
        Remove-Item $tempError -ErrorAction SilentlyContinue

        # Combine output and error
        $combinedOutput = if ($output) { $output } else { "" }
        if ($errorOutput) { $combinedOutput += "`n$($errorOutput)" }

        if ($JsonOutput -and $process.ExitCode -eq 0) {
            try {
                return $combinedOutput | ConvertFrom-Json
            }
            catch {
                # If JSON parsing fails, return as text
                return [PSCustomObject]@{
                    Output = $combinedOutput
                    ExitCode = $process.ExitCode
                    Error = $null
                }
            }
        }
        return [PSCustomObject]@{
            Output = $combinedOutput
            ExitCode = $process.ExitCode
            Error = $null
        }
    }
    catch {
        return [PSCustomObject]@{
            Output = "Error executing winget: $($_.Exception.Message)"
            ExitCode = 1
            Error = $null
        }
    }
}

function Invoke-ChocoCommand {
    <#
    .SYNOPSIS
        Executes a choco command.
    .PARAMETER Arguments
        Arguments to pass to choco.
    .PARAMETER TimeoutSeconds
        Timeout in seconds (default: 300 = 5 minutes).
    .OUTPUTS
        Hashtable with Output and ExitCode.
    #>
    param (
        [string[]]$Arguments,
        [int]$TimeoutSeconds = 300
    )

    # Validate arguments
    if (-not $Arguments -or $Arguments.Count -eq 0) {
        return @{
            Output = "Error: No arguments provided to choco command"
            ExitCode = 1
        }
    }

    try {
        Write-Host "Executing: choco $($Arguments -join ' ')" -ForegroundColor Cyan
        
        # Create temp files with proper paths
        $tempOutput = [System.IO.Path]::GetTempFileName()
        $tempError = [System.IO.Path]::GetTempFileName()
        
        # Use proper encoding to avoid weird characters
        $process = Start-Process -FilePath 'choco.exe' -ArgumentList $Arguments -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tempOutput -RedirectStandardError $tempError
        
        # Wait for process with timeout
        $startTime = Get-Date
        while (-not $process.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
            Start-Sleep -Milliseconds 500
            Write-Host "." -NoNewline -ForegroundColor Yellow
        }
        
        if (-not $process.HasExited) {
            Write-Host "`nTimeout reached, terminating choco process..." -ForegroundColor Red
            $process.Kill()
            # Clean up temp files
            Remove-Item $tempOutput -ErrorAction SilentlyContinue
            Remove-Item $tempError -ErrorAction SilentlyContinue
            return @{
                Output = "Choco command timed out after $TimeoutSeconds seconds"
                ExitCode = -1
            }
        }
        
        Write-Host " Done (Exit code: $($process.ExitCode))" -ForegroundColor Green
        
        $output = Get-Content $tempOutput -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        $errorOutput = Get-Content $tempError -Raw -Encoding UTF8 -ErrorAction SilentlyContinue

        # Clean up temp files
        Remove-Item $tempOutput -ErrorAction SilentlyContinue
        Remove-Item $tempError -ErrorAction SilentlyContinue

        # Combine output and error
        $combinedOutput = if ($output) { $output } else { "" }
        if ($errorOutput) { $combinedOutput += "`n$($errorOutput)" }

        return @{
            Output = $combinedOutput
            ExitCode = $process.ExitCode
        }
    }
    catch {
        return @{
            Output = "Error executing choco: $($_.Exception.Message)"
            ExitCode = 1
        }
    }
}
