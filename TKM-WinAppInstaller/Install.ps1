function Install-Package {
    <#
    .SYNOPSIS
        Installs a package using multiple methods with fallbacks.
    .PARAMETER Name
        Package name or ID to install.
    .PARAMETER Manager
        Preferred package manager ('winget', 'choco', 'direct', 'powershell', 'auto').
    .PARAMETER Force
        Force installation.
    .PARAMETER DryRun
        Only show what would be done.
    .PARAMETER Silent
        Silent installation.
    .PARAMETER AdditionalArgs
        Additional arguments.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Name,
        [string]$Manager,
        [switch]$Force,
        [switch]$DryRun,
        [switch]$Silent,
        [string[]]$AdditionalArgs
    )

    Write-Log -Level Info "Installing $Name using multiple methods with fallbacks"

    if ($DryRun) {
        Write-Host "DRY RUN: Would install $Name trying multiple methods" -ForegroundColor Cyan
        return
    }

    $installMethods = @()
    $availableManagers = Get-AvailablePackageManagers

    # Determine install methods to try
    switch ($Manager) {
        'winget' {
            if ('winget' -in $availableManagers) {
                $installMethods += 'winget'
            }
        }
        'choco' {
            if ('choco' -in $availableManagers) {
                $installMethods += 'choco'
            }
        }
        'direct' {
            $installMethods += 'direct'
        }
        'powershell' {
            $installMethods += 'powershell'
        }
        'auto' {
            # Try managers in order of preference
            foreach ($mgr in $availableManagers) {
                $installMethods += $mgr
            }
            $installMethods += 'direct'
            $installMethods += 'powershell'
        }
        default {
            # Unknown manager, try all available methods
            foreach ($mgr in $availableManagers) {
                $installMethods += $mgr
            }
            $installMethods += 'direct'
            $installMethods += 'powershell'
        }
    }

    # Remove duplicates while preserving order
    $installMethods = $installMethods | Select-Object -Unique

    Write-Host "`n$(("=" * 60))" -ForegroundColor Cyan
    Write-Host "INSTALLING: $Name" -ForegroundColor Cyan -BackgroundColor Black
    Write-Host "$("=" * 60)" -ForegroundColor Cyan
    Write-Host "Package: $Name" -ForegroundColor White
    Write-Host "Methods to try: $($installMethods -join ' -> ')" -ForegroundColor White
    Write-Host "Silent mode: $($Silent.ToString().ToUpper())" -ForegroundColor White
    Write-Host "Force mode: $($Force.ToString().ToUpper())" -ForegroundColor White
    Write-Host "$("=" * 60)" -ForegroundColor Cyan

    Write-Log -Level Info "Will try install methods in order: $($installMethods -join ', ')"

    $lastError = $null

    foreach ($method in $installMethods) {
        Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Trying install method: $method" -ForegroundColor Magenta
        Write-Host ("=" * 50) -ForegroundColor Magenta

        try {
            Write-Log -Level Info "Attempting install with $method..."

            $result = Install-PackageWithMethod -Name $Name -Method $method -Force:$Force -Silent:$Silent -AdditionalArgs $AdditionalArgs

            if ($result.Success) {
                Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] SUCCESS: Package installed using $method" -ForegroundColor Green
                Write-Log -Level Info "Install succeeded using $method"
                return
            } else {
                Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] FAILED: $method failed - $($result.Error)" -ForegroundColor Red
                Write-Log -Level Warning "Install failed with $method`: $($result.Error)"
                $lastError = $result.Error
            }
        }
        catch {
            Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] EXCEPTION: $method threw an exception - $($_.Exception.Message)" -ForegroundColor Red
            Write-Log -Level Warning "Exception during $method install: $($_.Exception.Message)"
            $lastError = $_.Exception.Message
        }

        # Small delay between attempts
        if ($installMethods.IndexOf($method) -lt ($installMethods.Count - 1)) {
            Write-Host "Waiting 2 seconds before trying next method..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }

    # If we get here, all methods failed
    Write-Log -Level Error "All install methods failed. Last error: $lastError"
    throw "Install failed for '$Name'. Tried methods: $($installMethods -join ', '). Last error: $lastError"
}

function Install-PackageWithMethod {
    <#
    .SYNOPSIS
        Installs a package using a specific method.
    .PARAMETER Name
        Package name or ID.
    .PARAMETER Method
        Install method ('winget', 'choco', 'direct', 'powershell').
    .PARAMETER Force
        Force installation.
    .PARAMETER Silent
        Silent installation.
    .PARAMETER AdditionalArgs
        Additional arguments.
    #>
    param (
        [string]$Name,
        [string]$Method,
        [switch]$Force,
        [switch]$Silent,
        [string[]]$AdditionalArgs
    )

    try {
        switch ($Method) {
            'winget' {
                return Install-PackageWithWinget -Name $Name -Force:$Force -Silent:$Silent -AdditionalArgs $AdditionalArgs
            }
            'choco' {
                return Update-PackageWithChoco -Name $Name -Force:$Force -Silent:$Silent -AdditionalArgs $AdditionalArgs
            }
            'direct' {
                # Direct download installation logic would go here
                return @{ Success = $false; Error = "Direct download installation not implemented" }
            }
            'powershell' {
                # PowerShell-native installation logic would go here
                return @{ Success = $false; Error = "PowerShell-native installation not implemented" }
            }
            default {
                return @{ Success = $false; Error = "Unknown install method: $Method" }
            }
        }
    }
    catch {
        return @{ Success = $false; Error = "Exception in $Method install: $($_.Exception.Message)" }
    }
}

function Install-PackagesParallel {
    <#
    .SYNOPSIS
        Installs multiple packages concurrently.
    .PARAMETER Packages
        Array of package names or IDs.
    .PARAMETER Manager
        Preferred package manager.
    .PARAMETER MaxConcurrency
        Maximum concurrent installations.
    .PARAMETER Force
        Force installation.
    .PARAMETER DryRun
        Only show what would be done.
    .PARAMETER Silent
        Silent installation.
    .PARAMETER AdditionalArgs
        Additional arguments.
    #>
    param (
        [string[]]$Packages,
        [string]$Manager,
        [int]$MaxConcurrency = 3,
        [switch]$Force,
        [switch]$DryRun,
        [switch]$Silent,
        [string[]]$AdditionalArgs
    )

    if ($DryRun) {
        foreach ($pkg in $Packages) {
            Write-Host "DRY RUN: Would install $pkg using $Manager"
        }
        return
    }

    Write-Log -Level Info "Installing $($Packages.Count) packages with max concurrency $MaxConcurrency"

    $jobs = @()

    foreach ($pkg in $Packages) {
        # Wait for available slot
        while ($jobs.Count -ge $MaxConcurrency) {
            $jobs = $jobs | Where-Object { $_.State -eq 'Running' }
            Start-Sleep -Milliseconds 500
        }

        $job = Start-Job -ScriptBlock {
            param($name, $manager, $force, $silent, $installerArgs)
            try {
                . $using:PSScriptRoot\PackageManagers.ps1
                . $using:PSScriptRoot\Detection.ps1
                . $using:PSScriptRoot\Winget.ps1
                . $using:PSScriptRoot\Chocolatey.ps1
                . $using:PSScriptRoot\Install.ps1
                . $using:PSScriptRoot\Utils.ps1
                Initialize-Logging -LogLevel 'Info'

                Install-Package -Name $name -Manager $manager -Force:$force -Silent:$silent -AdditionalArgs $installerArgs
                return @{ Success = $true; Package = $name }
            }
            catch {
                return @{ Success = $false; Package = $name; Error = $_.Exception.Message }
            }
        } -ArgumentList $pkg, $Manager, $Force, $Silent, $AdditionalArgs

        $jobs += $job
    }

    # Wait for all jobs to complete
    while ($jobs | Where-Object { $_.State -eq 'Running' }) {
        Start-Sleep -Milliseconds 500
    }

    # Collect results
    $results = $jobs | ForEach-Object { Receive-Job -Job $_; Remove-Job -Job $_ }

    foreach ($result in $results) {
        if ($result.Success) {
            Write-Log -Level Info "Successfully installed $($result.Package)"
        } else {
            Write-Log -Level Error "Failed to install $($result.Package): $($result.Error)"
        }
    }

    Write-Log -Level Info "Parallel install completed"
}
