function Uninstall-Package {
    <#
    .SYNOPSIS
        Uninstalls a package using multiple methods with fallbacks.
    .PARAMETER Name
        Package name or ID to uninstall.
    .PARAMETER Manager
        Preferred package manager ('auto', 'winget', 'choco').
    .PARAMETER Force
        Force uninstallation.
    .PARAMETER Silent
        Silent uninstallation.
    .PARAMETER AdditionalArgs
        Additional arguments.
    #>
    param (
        [string]$Name,
        [string]$Manager = 'auto',
        [switch]$Force,
        [switch]$Silent,
        [string[]]$AdditionalArgs
    )

    Write-Log -Level Info "Uninstalling $Name using multiple methods with fallbacks"

    # STEP 1: DETECT INSTALLED PACKAGES
    Write-Host "`n$(("=" * 60))" -ForegroundColor Magenta
    Write-Host "DETECTING INSTALLED PACKAGES" -ForegroundColor Magenta -BackgroundColor Black
    Write-Host "$("=" * 60)" -ForegroundColor Magenta
    Write-Host "Searching for packages matching: '$Name'" -ForegroundColor White
    Write-Host "$("=" * 60)" -ForegroundColor Magenta

    $detectedPackages = Get-PackageInfo -Name $Name -Manager 'auto'

    if ($detectedPackages.Count -eq 0) {
        Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] No packages found matching '$Name'" -ForegroundColor Yellow
        Write-Host "Checking if '$Name' might be a partial name or abbreviation..." -ForegroundColor Yellow

        # Try fuzzy matching - check if any installed packages contain the letters
        $allInstalled = Get-InstalledPackages -Manager 'auto'
        $fuzzyMatches = $allInstalled | Where-Object {
            $_.Name -like "*$Name*" -or
            $_.Id -like "*$Name*" -or
            ($_.Name -replace '[^a-zA-Z0-9]', '').ToLower() -like "*$($Name -replace '[^a-zA-Z0-9]', '').ToLower()*"
        }

        if ($fuzzyMatches.Count -gt 0) {
            Write-Host "`nFound potential matches:" -ForegroundColor Cyan
            $fuzzyMatches | ForEach-Object {
                Write-Host "  - $($_.Name) (ID: $($_.Id), Manager: $($_.Source))" -ForegroundColor White
            }
            Write-Host "`nUse the exact package name or ID from above for uninstallation." -ForegroundColor Yellow
        } else {
            Write-Host "No similar packages found on the system." -ForegroundColor Yellow
        }

        Write-Log -Level Warning "No packages found matching '$Name'"
        throw "Package '$Name' is not installed or not found by any package manager."
    }

    Write-Host "`nFound $($detectedPackages.Count) matching package(s):" -ForegroundColor Green
    $detectedPackages | ForEach-Object {
        Write-Host "  - $($_.Name) (ID: $($_.Id), Version: $($_.Version), Manager: $($_.Manager))" -ForegroundColor White
        if ($_.InstallLocation) {
            Write-Host "    Location: $($_.InstallLocation)" -ForegroundColor DarkGray
        }
        if ($_.Publisher) {
            Write-Host "    Publisher: $($_.Publisher)" -ForegroundColor DarkGray
        }
    }

    # STEP 2: PROCEED WITH UNINSTALL FOR EACH DETECTED PACKAGE
    $successfulUninstalls = 0
    $totalPackages = $detectedPackages.Count

    foreach ($pkg in $detectedPackages) {
        Write-Host "`n$(("=" * 60))" -ForegroundColor Blue
        Write-Host "UNINSTALLING PACKAGE: $($pkg.Name)" -ForegroundColor Blue -BackgroundColor Black
        Write-Host "$("=" * 60)" -ForegroundColor Blue
        Write-Host "Package: $($pkg.Name) (ID: $($pkg.Id))" -ForegroundColor White
        Write-Host "Manager: $($pkg.Manager)" -ForegroundColor White
        Write-Host "Version: $($pkg.Version)" -ForegroundColor White
        Write-Host "$("=" * 60)" -ForegroundColor Blue

        # Determine uninstall methods to try
        $uninstallMethods = @()
        $availableManagers = Get-AvailablePackageManagers

        # Determine uninstall methods to try
        switch ($Manager) {
            'winget' {
                if ('winget' -in $availableManagers) {
                    $uninstallMethods += 'winget'
                }
            }
            'choco' {
                if ('choco' -in $availableManagers) {
                    $uninstallMethods += 'choco'
                }
            }
            'powershell' {
                $uninstallMethods += 'powershell'
            }
            'auto' {
                # Try managers in order of preference, plus PowerShell
                foreach ($mgr in $availableManagers) {
                    $uninstallMethods += $mgr
                }
                $uninstallMethods += 'powershell'
            }
            default {
                # Unknown manager, try all available methods plus PowerShell
                foreach ($mgr in $availableManagers) {
                    $uninstallMethods += $mgr
                }
                $uninstallMethods += 'powershell'
            }
        }

        # Remove duplicates while preserving order
        $uninstallMethods = $uninstallMethods | Select-Object -Unique

        Write-Host "`nMethods to try: $($uninstallMethods -join ' -> ')" -ForegroundColor White
        Write-Host "Silent mode: $($Silent.ToString().ToUpper())" -ForegroundColor White
        Write-Host "Force mode: $($Force.ToString().ToUpper())" -ForegroundColor White

        Write-Log -Level Info "Will try uninstall methods in order: $($uninstallMethods -join ', ')"

        $lastError = $null

        foreach ($method in $uninstallMethods) {
            Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Trying uninstall method: $method" -ForegroundColor Magenta
            Write-Host ("=" * 50) -ForegroundColor Magenta

            try {
                Write-Log -Level Info "Attempting uninstall with $method..."

                $result = Uninstall-PackageWithMethod -Name $pkg.Id -Method $method -Force:$Force -Silent:$Silent -AdditionalArgs $AdditionalArgs

                if ($result.Success) {
                    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] SUCCESS: Package '$($pkg.Name)' uninstalled using $method" -ForegroundColor Green
                    Write-Log -Level Info "Uninstall succeeded using $method"
                    $successfulUninstalls++
                    break  # Move to next package
                } else {
                    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] FAILED: $method failed - $($result.Error)" -ForegroundColor Red
                    Write-Log -Level Warning "Uninstall failed with $method`: $($result.Error)"
                    $lastError = $result.Error
                }
            }
            catch {
                Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] EXCEPTION: $method threw an exception - $($_.Exception.Message)" -ForegroundColor Red
                Write-Log -Level Warning "Exception during $method uninstall: $($_.Exception.Message)"
                $lastError = $_.Exception.Message
            }

            # Small delay between attempts
            if ($uninstallMethods.IndexOf($method) -lt ($uninstallMethods.Count - 1)) {
                Write-Host "Waiting 2 seconds before trying next method..." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
        }

        if (-not $result.Success) {
            Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] FAILED: All uninstall methods failed for '$($pkg.Name)'" -ForegroundColor Red
            Write-Host "Last error: $lastError" -ForegroundColor Red
        }
    }

    # SUMMARY
    Write-Host "`n$(("=" * 60))" -ForegroundColor Cyan
    Write-Host "UNINSTALL SUMMARY" -ForegroundColor Cyan -BackgroundColor Black
    Write-Host "$("=" * 60)" -ForegroundColor Cyan
    Write-Host "Total packages found: $totalPackages" -ForegroundColor White
    Write-Host "Successfully uninstalled: $successfulUninstalls" -ForegroundColor Green
    Write-Host "Failed to uninstall: $($totalPackages - $successfulUninstalls)" -ForegroundColor Red
    Write-Host "$("=" * 60)" -ForegroundColor Cyan

    if ($successfulUninstalls -eq $totalPackages) {
        Write-Log -Level Info "All packages uninstalled successfully"
        Write-Host "`nAll packages were successfully uninstalled!" -ForegroundColor Green
    } elseif ($successfulUninstalls -gt 0) {
        Write-Log -Level Warning "Some packages uninstalled successfully, others failed"
        Write-Host "`nPartial success: $successfulUninstalls out of $totalPackages packages uninstalled." -ForegroundColor Yellow
        throw "Partial uninstall success: $successfulUninstalls/$totalPackages packages uninstalled."
    } else {
        Write-Log -Level Error "All uninstall methods failed for all packages"
        Write-Host "`nAll uninstall attempts failed. No packages were uninstalled." -ForegroundColor Red
        throw "All uninstall methods failed. No packages were uninstalled."
    }
}

function Uninstall-PackageWithMethod {
    <#
    .SYNOPSIS
        Uninstalls a package using a specific method.
    .PARAMETER Name
        Package name or ID.
    .PARAMETER Method
        Uninstall method ('winget', 'choco', 'powershell').
    .PARAMETER Force
        Force uninstallation.
    .PARAMETER Silent
        Silent uninstallation.
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
                return Uninstall-PackageWithWinget -Name $Name -Force:$Force -Silent:$Silent -AdditionalArgs $AdditionalArgs
            }
            'choco' {
                return Uninstall-PackageWithChoco -Name $Name -Force:$Force -Silent:$Silent -AdditionalArgs $AdditionalArgs
            }
            'powershell' {
                return Uninstall-PackageWithPowerShell -Name $Name -Force:$Force -Silent:$Silent -AdditionalArgs $AdditionalArgs
            }
            default {
                return @{ Success = $false; Error = "Unknown uninstall method: $Method" }
            }
        }
    }
    catch {
        return @{ Success = $false; Error = "Exception in $Method uninstall: $($_.Exception.Message)" }
    }
}

function Uninstall-PackageWithPowerShell {
    <#
    .SYNOPSIS
        Advanced PowerShell-based uninstallation with registry cleanup.
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

    Write-Host "Performing advanced PowerShell uninstallation..." -ForegroundColor Cyan

    # Method 1: Try MSI uninstall
    $msiResult = Uninstall-PackageWithMSI -Name $Name -Force:$Force -Silent:$Silent
    if ($msiResult.Success) {
        Write-Host "MSI uninstall successful" -ForegroundColor Green
        return $msiResult
    }

    # Method 2: Try registry-based uninstall
    $registryResult = Uninstall-PackageWithRegistry -Name $Name -Force:$Force -Silent:$Silent
    if ($registryResult.Success) {
        Write-Host "Registry-based uninstall successful" -ForegroundColor Green
        return $registryResult
    }

    # Method 3: Try file-based uninstall
    $fileResult = Uninstall-PackageWithFiles -Name $Name -Force:$Force -Silent:$Silent
    if ($fileResult.Success) {
        Write-Host "File-based uninstall successful" -ForegroundColor Green
        return $fileResult
    }

    return @{ Success = $false; Error = "PowerShell uninstall failed: All methods exhausted" }
}

function Uninstall-PackageWithMSI {
    <#
    .SYNOPSIS
        Uninstall MSI-based packages.
    .PARAMETER Name
        Package name.
    .PARAMETER Force
        Force uninstallation.
    .PARAMETER Silent
        Silent uninstallation.
    #>
    param (
        [string]$Name,
        [switch]$Force,
        [switch]$Silent
    )

    try {
        # Get MSI packages
        $msiPackages = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*$Name*" }

        foreach ($package in $msiPackages) {
            Write-Host "Found MSI package: $($package.Name) (Version: $($package.Version))" -ForegroundColor Yellow

            $uninstallArgs = @('/x', $package.IdentifyingNumber)
            if ($Silent) { $uninstallArgs += '/quiet' }
            if ($Force) { $uninstallArgs += '/forcerestart' }

            $result = Start-Process -FilePath 'msiexec.exe' -ArgumentList $uninstallArgs -Wait -PassThru

            if ($result.ExitCode -eq 0 -or $result.ExitCode -eq 3010) { # 3010 = restart required
                # Clean up registry entries
                Clean-RegistryEntries -PackageName $Name
                # Clean up leftover files
                Clean-LeftoverFiles -PackageName $Name

                return @{ Success = $true; Method = 'powershell-msi' }
            }
        }

        return @{ Success = $false; Error = "No matching MSI packages found" }
    }
    catch {
        return @{ Success = $false; Error = "MSI uninstall failed: $($_.Exception.Message)" }
    }
}

function Uninstall-PackageWithRegistry {
    <#
    .SYNOPSIS
        Uninstall using registry uninstall strings.
    .PARAMETER Name
        Package name.
    .PARAMETER Force
        Force uninstallation.
    .PARAMETER Silent
        Silent uninstallation.
    #>
    param (
        [string]$Name,
        [switch]$Force,
        [switch]$Silent
    )

    try {
        # Search both 64-bit and 32-bit registry locations
        $registryPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
        )

        foreach ($regPath in $registryPaths) {
            if (Test-Path $regPath) {
                $uninstallKeys = Get-ChildItem $regPath | Where-Object {
                    $displayName = (Get-ItemProperty -Path $_.PSPath -Name DisplayName -ErrorAction SilentlyContinue).DisplayName
                    $displayName -and $displayName -like "*$Name*"
                }

                foreach ($key in $uninstallKeys) {
                    $properties = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
                    $uninstallString = $properties.UninstallString
                    $displayName = $properties.DisplayName

                    if ($uninstallString) {
                        Write-Host "Found registry uninstall entry: $displayName" -ForegroundColor Yellow

                        # Clean up the uninstall string (remove quotes, parameters)
                        $cleanUninstallString = $uninstallString -replace '^"([^"]*)".*', '$1'

                        if (Test-Path $cleanUninstallString) {
                            $uninstallArgs = if ($Silent) { @('/S', '/silent', '/quiet') } else { @() }

                            $result = Start-Process -FilePath $cleanUninstallString -ArgumentList $uninstallArgs -Wait -PassThru

                            if ($result.ExitCode -eq 0 -or $result.ExitCode -eq 3010) {
                                # Clean up registry entries
                                Clean-RegistryEntries -PackageName $Name
                                # Clean up leftover files
                                Clean-LeftoverFiles -PackageName $Name

                                return @{ Success = $true; Method = 'powershell-registry' }
                            }
                        }
                    }
                }
            }
        }

        return @{ Success = $false; Error = "No matching registry uninstall entries found" }
    }
    catch {
        return @{ Success = $false; Error = "Registry uninstall failed: $($_.Exception.Message)" }
    }
}

function Uninstall-PackageWithFiles {
    <#
    .SYNOPSIS
        Remove leftover files and attempt executable uninstall.
    .PARAMETER Name
        Package name.
    .PARAMETER Force
        Force uninstallation.
    .PARAMETER Silent
        Silent uninstallation.
    #>
    param (
        [string]$Name,
        [switch]$Force,
        [switch]$Silent
    )

    try {
        # Common uninstall executable patterns
        $uninstallPatterns = @(
            "${env:ProgramFiles}*\*uninstall*.exe",
            "${env:ProgramFiles(x86)}*\*uninstall*.exe",
            "${env:ProgramFiles}*\*uninst*.exe",
            "${env:ProgramFiles(x86)}*\*uninst*.exe",
            "${env:ProgramFiles}*\*${Name}*\uninstall*.exe",
            "${env:ProgramFiles(x86)}*\*${Name}*\uninstall*.exe"
        )

        foreach ($pattern in $uninstallPatterns) {
            $uninstallers = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue

            foreach ($uninstaller in $uninstallers) {
                Write-Host "Found uninstaller: $($uninstaller.FullName)" -ForegroundColor Yellow

                $uninstallArgs = if ($Silent) { @('/S', '/silent', '/quiet') } else { @() }

                $result = Start-Process -FilePath $uninstaller.FullName -ArgumentList $uninstallArgs -Wait -PassThru

                if ($result.ExitCode -eq 0 -or $result.ExitCode -eq 3010) {
                    # Clean up registry entries
                    Clean-RegistryEntries -PackageName $Name
                    # Clean up leftover files
                    Clean-LeftoverFiles -PackageName $Name

                    return @{ Success = $true; Method = 'powershell-files' }
                }
            }
        }

        # If no uninstaller found, just clean up
        Clean-RegistryEntries -PackageName $Name
        Clean-LeftoverFiles -PackageName $Name

        return @{ Success = $false; Error = "No uninstaller executables found, performed cleanup only" }
    }
    catch {
        return @{ Success = $false; Error = "File-based uninstall failed: $($_.Exception.Message)" }
    }
}

function Clean-RegistryEntries {
    <#
    .SYNOPSIS
        Clean up leftover registry entries for a package.
    .PARAMETER PackageName
        Name of the package to clean.
    #>
    param (
        [string]$PackageName
    )

    try {
        $registryPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
            'HKLM:\SOFTWARE\Classes\Installer\Products',
            'HKCU:\SOFTWARE\Classes\Installer\Products'
        )

        $cleanedEntries = 0

        foreach ($regPath in $registryPaths) {
            if (Test-Path $regPath) {
                $keysToRemove = Get-ChildItem $regPath -ErrorAction SilentlyContinue | Where-Object {
                    try {
                        $displayName = (Get-ItemProperty -Path $_.PSPath -Name DisplayName -ErrorAction SilentlyContinue).DisplayName
                        $displayName -and $displayName -like "*$PackageName*"
                    } catch {
                        $false
                    }
                }

                foreach ($key in $keysToRemove) {
                    try {
                        Remove-Item -Path $key.PSPath -Recurse -Force -ErrorAction Stop
                        $cleanedEntries++
                        Write-Host "Cleaned registry entry: $($key.PSPath)" -ForegroundColor DarkGreen
                    } catch {
                        Write-Host "Failed to remove registry entry: $($key.PSPath)" -ForegroundColor DarkYellow
                    }
                }
            }
        }

        if ($cleanedEntries -gt 0) {
            Write-Host "Cleaned $cleanedEntries registry entries" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Registry cleanup failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Clean-LeftoverFiles {
    <#
    .SYNOPSIS
        Clean up leftover files and folders for a package.
    .PARAMETER PackageName
        Name of the package to clean.
    #>
    param (
        [string]$PackageName
    )

    try {
        # Common locations to check for leftover files
        $searchPaths = @(
            "${env:ProgramFiles}",
            "${env:ProgramFiles(x86)}",
            "${env:ProgramData}",
            "${env:LOCALAPPDATA}",
            "${env:APPDATA}"
        )

        $cleanedFiles = 0
        $cleanedFolders = 0

        foreach ($searchPath in $searchPaths) {
            if (Test-Path $searchPath) {
                # Find directories that match the package name
                $dirsToRemove = Get-ChildItem -Path $searchPath -Directory -ErrorAction SilentlyContinue | Where-Object {
                    $_.Name -like "*$PackageName*" -or $_.Name -like "*$($PackageName -replace '[^a-zA-Z0-9]', '')*"
                }

                foreach ($dir in $dirsToRemove) {
                    try {
                        Remove-Item -Path $dir.FullName -Recurse -Force -ErrorAction Stop
                        $cleanedFolders++
                        Write-Host "Cleaned directory: $($dir.FullName)" -ForegroundColor DarkGreen
                    } catch {
                        Write-Host "Failed to remove directory: $($dir.FullName)" -ForegroundColor DarkYellow
                    }
                }

                # Find files that match the package name
                $filesToRemove = Get-ChildItem -Path $searchPath -File -Recurse -ErrorAction SilentlyContinue | Where-Object {
                    $_.Name -like "*$PackageName*" -or $_.Name -like "*$($PackageName -replace '[^a-zA-Z0-9]', '')*"
                }

                foreach ($file in $filesToRemove) {
                    try {
                        Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                        $cleanedFiles++
                        Write-Host "Cleaned file: $($file.FullName)" -ForegroundColor DarkGreen
                    } catch {
                        Write-Host "Failed to remove file: $($file.FullName)" -ForegroundColor DarkYellow
                    }
                }
            }
        }

        if ($cleanedFiles -gt 0 -or $cleanedFolders -gt 0) {
            Write-Host "Cleaned $cleanedFiles files and $cleanedFolders folders" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "File cleanup failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Uninstall-PackagesParallel {
    <#
    .SYNOPSIS
        Uninstalls multiple packages concurrently.
    .PARAMETER Packages
        Array of package names or IDs.
    .PARAMETER Manager
        Preferred package manager.
    .PARAMETER MaxConcurrency
        Maximum concurrent uninstallations.
    .PARAMETER Force
        Force uninstallation.
    .PARAMETER DryRun
        Only show what would be done.
    .PARAMETER Silent
        Silent uninstallation.
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
            Write-Host "DRY RUN: Would uninstall $pkg using $Manager"
        }
        return
    }

    Write-Log -Level Info "Uninstalling $($Packages.Count) packages with max concurrency $MaxConcurrency"

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
                . $using:PSScriptRoot\Uninstall.ps1
                . $using:PSScriptRoot\Utils.ps1
                Initialize-Logging -LogLevel 'Info'

                Uninstall-Package -Name $name -Manager $manager -Force:$force -Silent:$silent -AdditionalArgs $installerArgs
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
            Write-Log -Level Info "Successfully uninstalled $($result.Package)"
        } else {
            Write-Log -Level Error "Failed to uninstall $($result.Package): $($result.Error)"
        }
    }

    Write-Log -Level Info "Parallel uninstall completed"
}
