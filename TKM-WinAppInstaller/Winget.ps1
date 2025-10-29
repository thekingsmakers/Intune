function Install-PackageWithWinget {
    <#
    .SYNOPSIS
        Installs a package using winget.
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

    $installerArgs = @('install', $Name)
    if ($Force) { $installerArgs += '--force' }
    if ($Silent) { $installerArgs += '--silent' }
    $installerArgs += $AdditionalArgs

    # Retry logic for winget operations
    $maxRetries = 2
    $retryCount = 0
    $lastError = $null

    do {
        $result = Invoke-WingetCommand -Arguments $installerArgs
        if ($result.ExitCode -eq 0) {
            return @{ Success = $true; Method = 'winget' }
        } else {
            $lastError = "Winget install failed: $($result.Output)"
            $retryCount++
            if ($retryCount -le $maxRetries) {
                Write-Host "Winget install failed, retrying in 3 seconds... ($retryCount/$maxRetries)" -ForegroundColor Yellow
                Start-Sleep -Seconds 3
            }
        }
    } while ($retryCount -le $maxRetries)

    return @{ Success = $false; Error = $lastError }
}

function Update-PackageWithWinget {
    <#
    .SYNOPSIS
        Upgrades a package using winget.
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

    $installerArgs = @('upgrade', $Name)
    if ($Force) { $installerArgs += '--force' }
    if ($Silent) { $installerArgs += '--silent' }
    $installerArgs += $AdditionalArgs

    # Retry logic for winget operations
    $maxRetries = 2
    $retryCount = 0
    $lastError = $null

    do {
        $result = Invoke-WingetCommand -Arguments $installerArgs
        if ($result.ExitCode -eq 0) {
            return @{ Success = $true; Method = 'winget' }
        } else {
            $lastError = "Winget upgrade failed: $($result.Output)"
            $retryCount++
            if ($retryCount -le $maxRetries) {
                Write-Host "Winget upgrade failed, retrying in 3 seconds... ($retryCount/$maxRetries)" -ForegroundColor Yellow
                Start-Sleep -Seconds 3
            }
        }
    } while ($retryCount -le $maxRetries)

    return @{ Success = $false; Error = $lastError }
}

function Uninstall-PackageWithWinget {
    <#
    .SYNOPSIS
        Uninstalls a package using winget.
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

    $installerArgs = @('uninstall', $Name)
    if ($Force) { $installerArgs += '--force' }
    if ($Silent) { $installerArgs += '--silent' }
    if ($AdditionalArgs -and $AdditionalArgs.Count -gt 0) {
        $installerArgs += $AdditionalArgs
    }

    # Retry logic for winget operations
    $maxRetries = 2
    $retryCount = 0
    $lastError = $null

    do {
        $result = Invoke-WingetCommand -Arguments $installerArgs
        if ($result.ExitCode -eq 0) {
            return @{ Success = $true; Method = 'winget' }
        } else {
            $lastError = "Winget uninstall failed: $($result.Output)"
            $retryCount++
            if ($retryCount -le $maxRetries) {
                Write-Host "Winget uninstall failed, retrying in 3 seconds... ($retryCount/$maxRetries)" -ForegroundColor Yellow
                Start-Sleep -Seconds 3
            }
        }
    } while ($retryCount -le $maxRetries)

    return @{ Success = $false; Error = $lastError }
}
