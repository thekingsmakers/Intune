function Update-Package {
    <#
    .SYNOPSIS
        Upgrades a package using multiple methods with fallbacks.
        Supports wildcard/partial name matching for installed packages.
    .PARAMETER Name
        Package name or ID to upgrade. Supports wildcards (*) for partial matching.
    .PARAMETER Manager
        Preferred package manager ('winget', 'choco', 'auto').
    .PARAMETER Force
        Force upgrade.
    .PARAMETER DryRun
        Only show what would be done.
    .PARAMETER Silent
        Silent upgrade.
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

    Write-Log -Level Info "Upgrading packages matching '$Name' using multiple methods with fallbacks"

    if ($DryRun) {
        Write-Host "DRY RUN: Would upgrade packages matching '$Name'" -ForegroundColor Cyan
        return
    }

    # Get all installed packages first
    Write-Log -Level Info "Searching for installed packages matching '$Name'"
    $installedPackages = Get-InstalledPackages -Manager 'auto'

    if (-not $installedPackages -or $installedPackages.Count -eq 0) {
        Write-Host "No installed packages found to upgrade." -ForegroundColor Yellow
        return
    }

    # Find packages that match the name pattern (support wildcards)
    $namePattern = $Name -replace '\*', '.*'  # Convert * to regex
    if (-not $namePattern.Contains('.*')) {
        # If no wildcards, add them around the name for partial matching
        $namePattern = ".*$($Name -replace '([.+?^${}()|[\]\\])', '\$1').*"  # Escape regex chars and add wildcards
    }

    $matchingPackages = $installedPackages | Where-Object {
        $_.Name -match $namePattern -or
        ($_.Id -and $_.Id -match $namePattern)
    }

    if (-not $matchingPackages -or $matchingPackages.Count -eq 0) {
        Write-Host "No installed packages found matching '$Name'. Available packages:" -ForegroundColor Yellow
        $installedPackages | Select-Object Name, Id, Version, Source | Format-Table -AutoSize
        return
    }

    Write-Host "`nFound $($matchingPackages.Count) installed package(s) matching '$Name':" -ForegroundColor Green
    $matchingPackages | Select-Object Name, Id, Version, Source | Format-Table -AutoSize

    # Upgrade each matching package
    $upgradeCount = 0
    foreach ($pkg in $matchingPackages) {
        try {
            Write-Host "`n$(("=" * 60))" -ForegroundColor Cyan
            Write-Host "UPGRADING: $($pkg.Name)" -ForegroundColor Cyan -BackgroundColor Black
            Write-Host "$("=" * 60)" -ForegroundColor Cyan

            # Use the package ID if available and from winget, otherwise use name
            $upgradeName = if ($pkg.Source -eq 'winget' -and $pkg.Id) { $pkg.Id } else { $pkg.Name }

            # Determine the appropriate upgrade method based on package source
            $upgradeMethod = switch ($pkg.Source) {
                'winget' { 'winget' }
                'choco' { 'choco' }
                default {
                    # If Manager is specified and not 'auto', use it; otherwise try all available
                    if ($Manager -and $Manager -ne 'auto') { $Manager } else { 'winget' }  # Default to winget
                }
            }

            # Check if upgrade is needed by comparing versions
            $upgradeNeeded = $false
            $latestVersion = $null

            try {
                # Try to get the latest available version
                if ($upgradeMethod -eq 'winget') {
                    # For winget, try searching with both ID and name
                    $searchTerms = @($pkg.Id, $pkg.Name) | Where-Object { $_ } | Select-Object -Unique
                    
                    foreach ($searchTerm in $searchTerms) {
                        $searchResult = Invoke-WingetCommand -Arguments @('search', $searchTerm) -JsonOutput
                        if ($searchResult.ExitCode -eq 0 -and $searchResult -is [PSCustomObject] -and $searchResult.Sources) {
                            $latestVersion = $searchResult.Sources[0].Packages[0].PackageVersion
                            break
                        }
                        
                        # Try text search
                        $searchResult = Invoke-WingetCommand -Arguments @('search', $searchTerm)
                        if ($searchResult.ExitCode -eq 0 -and $searchResult.Output) {
                            $lines = $searchResult.Output -split "`n" | Where-Object { $_ -and $_.Trim() -notmatch '^[-]+$' -and $_.Trim() -notmatch '^$' }
                            foreach ($line in $lines) {
                                if ($line -match $searchTerm -and $line -match '(\d+\.\d+\.\d+\.\d+|\d+\.\d+\.\d+)') {
                                    $latestVersion = $matches[0]
                                    break
                                }
                            }
                            if ($latestVersion) { break }
                        }
                    }
                } elseif ($upgradeMethod -eq 'choco') {
                    # For choco, try searching with package name
                    $searchResult = Invoke-ChocoCommand -Arguments @('search', $pkg.Name)
                    if ($searchResult.ExitCode -eq 0 -and $searchResult.Output) {
                        $lines = $searchResult.Output -split "`n" | Where-Object { $_ -and $_.Trim() -notmatch '^[-]+$' -and $_.Trim() -notmatch '^$' }
                        foreach ($line in $lines) {
                            if ($line -match '^([^|]+)\s+([^|]+)\|?(.*)$') {
                                $pkgName = $matches[1].Trim()
                                if ($pkgName -eq $pkg.Name -or $pkgName -replace '[\.\-]', '' -eq $pkg.Name -replace '[\.\-]', '') {
                                    $latestVersion = $matches[2].Trim()
                                    break
                                }
                            }
                        }
                    }
                }

                # Compare versions
                if ($latestVersion -and $pkg.Version) {
                    try {
                        if ([version]$latestVersion -gt [version]$pkg.Version) {
                            $upgradeNeeded = $true
                            Write-Log -Level Info "Upgrade needed: $($pkg.Version) -> $latestVersion"
                        } else {
                            Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Package $($pkg.Name) is already up to date (v$($pkg.Version))" -ForegroundColor Green
                            Write-Log -Level Info "Package $($pkg.Name) is already up to date (v$($pkg.Version))"
                            $upgradeCount++
                            continue  # Skip to next package
                        }
                    } catch {
                        # Version comparison failed, assume upgrade needed
                        $upgradeNeeded = $true
                        Write-Log -Level Warning "Version comparison failed, proceeding with upgrade: $($_.Exception.Message)"
                    }
                } else {
                    # If we can't determine versions, assume upgrade is needed
                    $upgradeNeeded = $true
                    Write-Log -Level Info "Unable to determine versions, proceeding with upgrade attempt"
                }
            } catch {
                # If version checking fails, assume upgrade is needed
                $upgradeNeeded = $true
                Write-Log -Level Warning "Version checking failed, proceeding with upgrade attempt: $($_.Exception.Message)"
            }

            if (-not $upgradeNeeded) {
                continue  # Skip to next package
            }

            Write-Log -Level Info "Upgrading package: $($pkg.Name) (ID: $upgradeName) using $upgradeMethod"

            # Try upgrade with primary method
            $result = Update-PackageWithMethod -Name $upgradeName -Method $upgradeMethod -Force:$Force -Silent:$Silent -AdditionalArgs $AdditionalArgs

            if ($result.Success) {
                Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] SUCCESS: Package $($pkg.Name) upgraded" -ForegroundColor Green
                Write-Log -Level Info "Successfully upgraded $($pkg.Name)"
                $upgradeCount++
            } else {
                Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Primary method ($upgradeMethod) failed for $($pkg.Name) - $($result.Error)" -ForegroundColor Yellow
                Write-Log -Level Warning "Primary upgrade failed for $($pkg.Name): $($result.Error)"

                # Try fallback methods
                $availableManagers = Get-AvailablePackageManagers
                $fallbackMethods = @()
                foreach ($mgr in $availableManagers) {
                    if ($mgr -ne $upgradeMethod) {
                        $fallbackMethods += $mgr
                    }
                }
                # Add PowerShell as a last resort fallback
                $fallbackMethods += 'powershell'
                $fallbackSuccess = $false

                foreach ($fallbackMethod in $fallbackMethods) {
                    Write-Host "Trying fallback method: $fallbackMethod..." -ForegroundColor Cyan

                    try {
                        $fallbackResult = Update-PackageWithMethod -Name $upgradeName -Method $fallbackMethod -Force:$Force -Silent:$Silent -AdditionalArgs $AdditionalArgs

                        if ($fallbackResult.Success) {
                            Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] SUCCESS: Package $($pkg.Name) upgraded using fallback method $fallbackMethod" -ForegroundColor Green
                            Write-Log -Level Info "Successfully upgraded $($pkg.Name) using fallback method $fallbackMethod"
                            $upgradeCount++
                            $fallbackSuccess = $true
                            break
                        } else {
                            Write-Host "Fallback method $fallbackMethod also failed: $($fallbackResult.Error)" -ForegroundColor Red
                        }
                    }
                    catch {
                        Write-Host "Exception with fallback method $fallbackMethod`: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }

                if (-not $fallbackSuccess) {
                    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] FAILED: Could not upgrade $($pkg.Name) with any method" -ForegroundColor Red
                    Write-Log -Level Warning "Failed to upgrade $($pkg.Name) with any method"
                }
            }
        }
        catch {
            Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] EXCEPTION: Error upgrading $($pkg.Name) - $($_.Exception.Message)" -ForegroundColor Red
            Write-Log -Level Error "Exception upgrading $($pkg.Name): $($_.Exception.Message)"
        }
    }

    Write-Host "`n$(("=" * 60))" -ForegroundColor Cyan
    Write-Host "UPGRADE SUMMARY: $upgradeCount/$($matchingPackages.Count) packages upgraded successfully" -ForegroundColor Cyan
    Write-Host "$("=" * 60)" -ForegroundColor Cyan

    if ($upgradeCount -eq 0) {
        throw "No packages were successfully upgraded"
    }
}

function Update-PackageWithMethod {
    <#
    .SYNOPSIS
        Upgrades a package using a specific method.
    .PARAMETER Name
        Package name or ID.
    .PARAMETER Method
        Upgrade method ('winget', 'choco').
    .PARAMETER Force
        Force upgrade.
    .PARAMETER Silent
        Silent upgrade.
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
                return Update-PackageWithWinget -Name $Name -Force:$Force -Silent:$Silent -AdditionalArgs $AdditionalArgs
            }
            'choco' {
                return Update-PackageWithChoco -Name $Name -Force:$Force -Silent:$Silent -AdditionalArgs $AdditionalArgs
            }
            'powershell' {
                # PowerShell upgrade is not typically supported for remote packages
                # This would only work for local MSI/EXE files
                return @{ Success = $false; Error = "PowerShell upgrade not supported for remote packages" }
            }
            default {
                return @{ Success = $false; Error = "Unknown upgrade method: $Method" }
            }
        }
    }
    catch {
        return @{ Success = $false; Error = "Exception in $Method upgrade: $($_.Exception.Message)" }
    }
}

function Update-PackagesParallel {
    <#
    .SYNOPSIS
        Upgrades multiple packages concurrently.
    .PARAMETER Packages
        Array of package names or IDs.
    .PARAMETER Manager
        Preferred package manager.
    .PARAMETER MaxConcurrency
        Maximum concurrent upgrades.
    .PARAMETER Force
        Force upgrade.
    .PARAMETER DryRun
        Only show what would be done.
    .PARAMETER Silent
        Silent upgrade.
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
            Write-Host "DRY RUN: Would upgrade $pkg using $Manager"
        }
        return
    }

    Write-Log -Level Info "Upgrading $($Packages.Count) packages with max concurrency $MaxConcurrency"

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
                . $using:PSScriptRoot\Upgrade.ps1
                . $using:PSScriptRoot\Utils.ps1
                Initialize-Logging -LogLevel 'Info'

                Update-Package -Name $name -Manager $manager -Force:$force -Silent:$silent -AdditionalArgs $installerArgs
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
            Write-Log -Level Info "Successfully upgraded $($result.Package)"
        } else {
            Write-Log -Level Error "Failed to upgrade $($result.Package): $($result.Error)"
        }
    }

    Write-Log -Level Info "Parallel upgrade completed"
}
