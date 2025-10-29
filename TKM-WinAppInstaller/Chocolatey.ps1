function Invoke-ChocoCommand {
    <#
    .SYNOPSIS
        Executes choco commands with proper error handling.
    .PARAMETER Arguments
        Array of arguments to pass to choco.
    .PARAMETER Timeout
        Command timeout in seconds.
    .OUTPUTS
        Custom object with ExitCode, Output, and Error properties.
    #>
    param (
        [string[]]$Arguments,
        [int]$Timeout = 300
    )

    try {
        $tempOutput = [System.IO.Path]::GetTempFileName()
        $tempError = [System.IO.Path]::GetTempFileName()

        $process = Start-Process -FilePath 'choco' -ArgumentList $Arguments -NoNewWindow -PassThru -RedirectStandardOutput $tempOutput -RedirectStandardError $tempError

        if ($process.WaitForExit($Timeout * 1000)) {
            $output = Get-Content $tempOutput -Raw -ErrorAction SilentlyContinue
            $errorOutput = Get-Content $tempError -Raw -ErrorAction SilentlyContinue

            # Clean up temp files
            Remove-Item $tempOutput -ErrorAction SilentlyContinue
            Remove-Item $tempError -ErrorAction SilentlyContinue

            return [PSCustomObject]@{
                ExitCode = $process.ExitCode
                Output = $output
                Error = $errorOutput
            }
        } else {
            $process.Kill()
            Remove-Item $tempOutput -ErrorAction SilentlyContinue
            Remove-Item $tempError -ErrorAction SilentlyContinue
            throw "Choco command timed out after $Timeout seconds"
        }
    }
    catch {
        throw "Failed to execute choco command: $($_.Exception.Message)"
    }
}

function Install-PackageWithChoco {
    <#
    .SYNOPSIS
        Installs a package using choco.
    .PARAMETER Name
        Package name or ID.
    .PARAMETER Force
        Force installation.
    .PARAMETER Silent
        Silent installation.
    .PARAMETER AdditionalArgs
        Additional arguments.
    #>
    param (
        [string]$Name,
        [switch]$Force,
        [switch]$Silent,
        [string[]]$AdditionalArgs
    )

    $installerArgs = @('install', $Name, '-y')
    if ($Force) { $installerArgs += '--force' }
    if ($Silent) { $installerArgs += '--silent' }
    $installerArgs += $AdditionalArgs

    # Retry logic for choco operations
    $maxRetries = 2
    $retryCount = 0
    $lastError = $null

    do {
        $result = Invoke-ChocoCommand -Arguments $installerArgs
        if ($result.ExitCode -eq 0) {
            return @{ Success = $true; Method = 'choco' }
        } else {
            $lastError = "Choco install failed: $($result.Output)"
            $retryCount++
            if ($retryCount -le $maxRetries) {
                Write-Host "Choco install failed, retrying in 3 seconds... ($retryCount/$maxRetries)" -ForegroundColor Yellow
                Start-Sleep -Seconds 3
            }
        }
    } while ($retryCount -le $maxRetries)

    return @{ Success = $false; Error = $lastError }
}

function Update-PackageWithChoco {
    <#
    .SYNOPSIS
        Upgrades a package using choco.
    .PARAMETER Name
        Package name or ID.
    .PARAMETER Force
        Force upgrade.
    .PARAMETER Silent
        Silent upgrade.
    .PARAMETER AdditionalArgs
        Additional arguments.
    #>
    param (
        [string]$Name,
        [switch]$Force,
        [switch]$Silent,
        [string[]]$AdditionalArgs
    )

    $installerArgs = @('upgrade', $Name, '-y')
    if ($Force) { $installerArgs += '--force' }
    if ($Silent) { $installerArgs += '--silent' }
    $installerArgs += $AdditionalArgs

    # Retry logic for choco operations
    $maxRetries = 2
    $retryCount = 0
    $lastError = $null

    do {
        $result = Invoke-ChocoCommand -Arguments $installerArgs
        if ($result.ExitCode -eq 0) {
            return @{ Success = $true; Method = 'choco' }
        } else {
            $lastError = "Choco upgrade failed: $($result.Output)"
            $retryCount++
            if ($retryCount -le $maxRetries) {
                Write-Host "Choco upgrade failed, retrying in 3 seconds... ($retryCount/$maxRetries)" -ForegroundColor Yellow
                Start-Sleep -Seconds 3
            }
        }
    } while ($retryCount -le $maxRetries)

    return @{ Success = $false; Error = $lastError }
}

function Uninstall-PackageWithChoco {
    <#
    .SYNOPSIS
        Uninstalls a package using choco.
    .PARAMETER Name
        Package name or ID.
    .PARAMETER Force
        Force uninstallation.
    .PARAMETER Silent
        Silent uninstallation.
    .PARAMETER AdditionalArgs
        Additional arguments.
    #>
    param (
        [string]$Name,
        [switch]$Force,
        [switch]$Silent,
        [string[]]$AdditionalArgs
    )

    $installerArgs = @('uninstall', $Name, '-y')
    if ($Force) { $installerArgs += '--force' }
    if ($Silent) { $installerArgs += '--silent' }
    if ($AdditionalArgs -and $AdditionalArgs.Count -gt 0) {
        $installerArgs += $AdditionalArgs
    }

    # Retry logic for choco operations
    $maxRetries = 2
    $retryCount = 0
    $lastError = $null

    do {
        $result = Invoke-ChocoCommand -Arguments $installerArgs
        if ($result.ExitCode -eq 0) {
            return @{ Success = $true; Method = 'choco' }
        } else {
            $lastError = "Choco uninstall failed: $($result.Output)"
            $retryCount++
            if ($retryCount -le $maxRetries) {
                Write-Host "Choco uninstall failed, retrying in 3 seconds... ($retryCount/$maxRetries)" -ForegroundColor Yellow
                Start-Sleep -Seconds 3
            }
        }
    } while ($retryCount -le $maxRetries)

    return @{ Success = $false; Error = $lastError }
}
