function Get-AvailablePackageManagers {
    <#
    .SYNOPSIS
        Gets a list of available package managers on the system.
    .OUTPUTS
        Array of available package manager names.
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

function Test-PackageManager {
    <#
    .SYNOPSIS
        Tests if a package manager is available.
    .PARAMETER Manager
        Package manager to test ('winget', 'choco').
    .OUTPUTS
        Boolean indicating availability.
    #>
    param (
        [Parameter(Mandatory)]
        [ValidateSet('winget', 'choco')]
        [string]$Manager
    )

    try {
        switch ($Manager) {
            'winget' {
                & winget --version 2>$null | Out-Null
                return $LASTEXITCODE -eq 0
            }
            'choco' {
                & choco --version 2>$null | Out-Null
                return $LASTEXITCODE -eq 0
            }
        }
    }
    catch {
        return $false
    }
}

function Search-Package {
    <#
    .SYNOPSIS
        Searches for packages.
    .PARAMETER Query
        Search query.
    .PARAMETER Manager
        Preferred package manager.
    .OUTPUTS
        Search results.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Query,
        [string]$Manager
    )

    $managers = Get-AvailablePackageManagers
    if (-not $Manager -or $Manager -notin $managers) {
        $Manager = $managers | Select-Object -First 1
    }

    if (-not $Manager) {
        throw "No package manager available."
    }

    switch ($Manager) {
        'winget' {
            $result = Invoke-WingetCommand -Arguments @('search', $Query) -JsonOutput
            if ($result -is [PSCustomObject] -and $result.Sources) {
                # Parse JSON results into clean objects
                $packages = $result.Sources[0].Packages | ForEach-Object {
                    [PSCustomObject]@{
                        Name = $_.PackageIdentifier
                        Version = $_.PackageVersion
                        Source = $_.Source
                        Match = if ($_.MatchType) { $_.MatchType } else { "Available" }
                    }
                }
                return $packages
            } else {
                # Fallback: parse text output into clean format
                $fallbackResult = Invoke-WingetCommand -Arguments @('search', $Query)
                if ($fallbackResult.Output) {
                    $lines = $fallbackResult.Output -split "`n" | Where-Object { $_ -and $_.Trim() -notmatch '^[-]+$' -and $_.Trim() -notmatch '^$' -and $_.Trim() -notmatch '^Name|Id|Version|Source' }

                    $parsedResults = @()

                    foreach ($line in $lines) {
                        # Try to parse winget text output format
                        if ($line -match '^([^|]+)\|([^|]+)\|([^|]+)\|?(.*)$') {
                            $parsedResults += [PSCustomObject]@{
                                Name = $matches[1].Trim()
                                Id = $matches[2].Trim()
                                Version = $matches[3].Trim()
                                Source = if ($matches[4]) { $matches[4].Trim() } else { "winget" }
                            }
                        } elseif ($line -match '^(.+?)\s{2,}(.+)$' -and $line -notmatch 'Name|Id|Version|Source') {
                            # Alternative parsing for some winget outputs
                            $parsedResults += [PSCustomObject]@{
                                Name = $line.Trim()
                                Id = ""
                                Version = ""
                                Source = "winget"
                            }
                        }
                    }

                    if ($parsedResults.Count -gt 0) {
                        return $parsedResults | Where-Object { $_.Name -match $Query -or $_.Id -match $Query }
                    }

                    # If parsing fails, return raw output as string
                    return "Winget search results for '$Query':`n$($fallbackResult.Output)"
                }
            }
        }
        'choco' {
            $result = Invoke-ChocoCommand -Arguments @('search', $Query)
            if ($result.Output) {
                $lines = $result.Output -split "`n" | Where-Object { $_ -and $_.Trim() -notmatch '^[-]+$' -and $_.Trim() -notmatch '^$' }
                $parsedResults = @()

                foreach ($line in $lines) {
                    if ($line -match '^([^|]+)\|([^|]+)\|?(.*)$') {
                        $parsedResults += [PSCustomObject]@{
                            Name = $matches[1].Trim()
                            Version = $matches[2].Trim()
                            Source = if ($matches[3]) { $matches[3].Trim() } else { "choco" }
                        }
                    }
                }

                return $parsedResults
            }
        }
    }
}

function Get-InstalledPackages {
    <#
    .SYNOPSIS
        Lists installed packages.
    .PARAMETER Manager
        Preferred package manager ('winget', 'choco', 'auto').
    .OUTPUTS
        List of installed packages.
    #>
    param (
        [string]$Manager
    )

    $managers = Get-AvailablePackageManagers
    if (-not $Manager -or $Manager -notin $managers) {
        if ($Manager -eq 'auto' -and $managers.Count -gt 0) {
            # For 'auto', collect from all available managers
            $allPackages = @()
            foreach ($mgr in $managers) {
                try {
                    switch ($mgr) {
                        'winget' {
                            $result = Invoke-WingetCommand -Arguments @('list') -JsonOutput
                            if ($result -is [PSCustomObject] -and $result.Sources) {
                                # Parse JSON results into clean objects
                                $packages = $result.Sources[0].Packages | ForEach-Object {
                                    [PSCustomObject]@{
                                        Name = $_.PackageIdentifier
                                        Id = $_.PackageIdentifier
                                        Version = $_.PackageVersion
                                        Source = $_.Source
                                    }
                                }
                                $allPackages += $packages
                            } else {
                                # Fallback: parse text output into clean format
                                $fallbackResult = Invoke-WingetCommand -Arguments @('list')
                                if ($fallbackResult.Output) {
                                    $lines = $fallbackResult.Output -split "`n" | Where-Object { $_ -and $_.Trim() -notmatch '^[-]+$' -and $_.Trim() -notmatch '^$' -and $_.Trim() -notmatch '^Name\s+Id\s+Version\s+Source' }

                                    foreach ($line in $lines) {
                                        $line = $line.Trim()
                                        if ($line) {
                                            # Split by 2 or more spaces
                                            $parts = $line -split '\s{2,}' | Where-Object { $_ }

                                            if ($parts.Count -ge 2) {
                                                $name = $parts[0].Trim()
                                                $id = if ($parts.Count -ge 2) { $parts[1].Trim() } else { "" }

                                                # Clean up the ID - remove .EXE extensions that winget sometimes adds
                                                if ($id -match '\.exe$') {
                                                    $id = $id -replace '\.exe$', ''
                                                }

                                                # Detect format by checking if last element is a known source
                                                $lastElement = $parts[$parts.Count - 1].Trim()
                                                $knownSources = @('winget', 'msstore', 'steam', 'epic', 'gog', 'uplay', 'origin', 'battlenet')
                                                
                                                if ($parts.Count -ge 4 -and $knownSources -contains $lastElement.ToLower()) {
                                                    # Standard format: Name | Id | Version | Source
                                                    $name = $parts[0].Trim()
                                                    $id = $parts[1].Trim()
                                                    $version = $parts[2].Trim()
                                                    $source = $lastElement
                                                } elseif ($parts.Count -ge 5 -and $knownSources -contains $lastElement.ToLower()) {
                                                    # Extended format: Name | Id | InstalledVersion | AvailableVersion | Source
                                                    $name = $parts[0].Trim()
                                                    $id = $parts[1].Trim()
                                                    $version = $parts[2].Trim()  # Use installed version
                                                    $source = $lastElement
                                                } else {
                                                    # Fallback: assume 4-column format
                                                    $name = $parts[0].Trim()
                                                    $id = if ($parts.Count -ge 2) { $parts[1].Trim() } else { "" }
                                                    $version = if ($parts.Count -ge 3) { $parts[2].Trim() } else { "" }
                                                    $source = "winget"  # Default to winget
                                                }

                                                $allPackages += [PSCustomObject]@{
                                                    Name = $name
                                                    Id = $id
                                                    Version = $version
                                                    Source = $source
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        'choco' {
                            $result = Invoke-ChocoCommand -Arguments @('list')
                            if ($result.Output) {
                                $lines = $result.Output -split "`n" | Where-Object { $_ -and $_.Trim() -notmatch '^[-]+$' -and $_.Trim() -notmatch '^$' }
                                $parsedResults = @()

                                foreach ($line in $lines) {
                                    if ($line -match '^([^|]+)\s+([^|]+)$') {
                                        $parsedResults += [PSCustomObject]@{
                                            Name = $matches[1].Trim()
                                            Id = $matches[1].Trim()  # Choco uses name as ID
                                            Version = $matches[2].Trim()
                                            Source = "choco"
                                        }
                                    }
                                }
                                $allPackages += $parsedResults
                            }
                        }
                    }
                }
                catch {
                    Write-Warning "Failed to get packages from $mgr`: $($_.Exception.Message)"
                }
            }
            return $allPackages
        } else {
            # For specific manager or if no managers available
            $Manager = $managers | Select-Object -First 1
        }
    }

    if (-not $Manager) {
        throw "No package manager available."
    }

    # Original logic for specific manager
    switch ($Manager) {
        'winget' {
            $result = Invoke-WingetCommand -Arguments @('list') -JsonOutput
            if ($result -is [PSCustomObject] -and $result.Sources) {
                # Parse JSON results into clean objects
                $packages = $result.Sources[0].Packages | ForEach-Object {
                    [PSCustomObject]@{
                        Name = $_.PackageIdentifier
                        Id = $_.PackageIdentifier
                        Version = $_.PackageVersion
                        Source = $_.Source
                    }
                }
                return $packages
            } else {
                # Fallback: parse text output into clean format
                $fallbackResult = Invoke-WingetCommand -Arguments @('list')
                if ($fallbackResult.Output) {
                    $lines = $fallbackResult.Output -split "`n" | Where-Object { $_ -and $_.Trim() -notmatch '^[-]+$' -and $_.Trim() -notmatch '^$' -and $_.Trim() -notmatch '^Name\s+Id\s+Version\s+Source' }

                    $parsedResults = @()

                    foreach ($line in $lines) {
                        $line = $line.Trim()
                        if ($line) {
                            # Split by 2 or more spaces
                            $parts = $line -split '\s{2,}' | Where-Object { $_ }

                            if ($parts.Count -ge 2) {
                                $name = $parts[0].Trim()
                                $id = if ($parts.Count -ge 2) { $parts[1].Trim() } else { "" }

                                # Clean up the ID - remove .EXE extensions that winget sometimes adds
                                if ($id -match '\.exe$') {
                                    $id = $id -replace '\.exe$', ''
                                }

                                # Detect format by checking if last element is a known source
                                $lastElement = $parts[$parts.Count - 1].Trim()
                                $knownSources = @('winget', 'msstore', 'steam', 'epic', 'gog', 'uplay', 'origin', 'battlenet')
                                
                                if ($parts.Count -ge 4 -and $knownSources -contains $lastElement.ToLower()) {
                                    # Standard format: Name | Id | Version | Source
                                    $name = $parts[0].Trim()
                                    $id = $parts[1].Trim()
                                    $version = $parts[2].Trim()
                                    $source = $lastElement
                                } elseif ($parts.Count -ge 5 -and $knownSources -contains $lastElement.ToLower()) {
                                    # Extended format: Name | Id | InstalledVersion | AvailableVersion | Source
                                    $name = $parts[0].Trim()
                                    $id = $parts[1].Trim()
                                    $version = $parts[2].Trim()  # Use installed version
                                    $source = $lastElement
                                } else {
                                    # Fallback: assume 4-column format
                                    $name = $parts[0].Trim()
                                    $id = if ($parts.Count -ge 2) { $parts[1].Trim() } else { "" }
                                    $version = if ($parts.Count -ge 3) { $parts[2].Trim() } else { "" }
                                    $source = "winget"  # Default to winget
                                }

                                # Clean up the name (remove truncated parts with ...)
                                if ($name -match '(.+?)\s*\.\.\..*') {
                                    $name = $matches[1].Trim()
                                }

                                $parsedResults += [PSCustomObject]@{
                                    Name = $name
                                    Id = $id
                                    Version = $version
                                    Source = $source
                                }
                            } else {
                                # Fallback for lines that don't match expected format
                                $parsedResults += [PSCustomObject]@{
                                    Name = $line
                                    Id = ""
                                    Version = ""
                                    Source = "winget"
                                }
                            }
                        }
                    }

                    if ($parsedResults.Count -gt 0) {
                        return $parsedResults
                    }

                    # If parsing fails completely, return raw output as string
                    return "Winget installed packages:`n$($fallbackResult.Output)"
                }
            }
        }
        'choco' {
            $result = Invoke-ChocoCommand -Arguments @('list')
            if ($result.Output) {
                $lines = $result.Output -split "`n" | Where-Object { $_ -and $_.Trim() -notmatch '^[-]+$' -and $_.Trim() -notmatch '^$' }
                $parsedResults = @()

                foreach ($line in $lines) {
                    if ($line -match '^([^|]+)\s+([^|]+)$') {
                        $parsedResults += [PSCustomObject]@{
                            Name = $matches[1].Trim()
                            Id = $matches[1].Trim()  # Choco uses name as ID
                            Version = $matches[2].Trim()
                            Source = "choco"
                        }
                    }
                }

                return $parsedResults
            }
        }
    }
}

function Get-PackageInfo {
    <#
    .SYNOPSIS
        Get detailed information about installed packages.
    .PARAMETER Name
        Package name or ID to search for.
    .PARAMETER Manager
        Package manager to use ('auto', 'winget', 'choco').
    .OUTPUTS
        Array of package information objects.
    #>
    param (
        [string]$Name,
        [string]$Manager = 'auto'
    )

    $packageInfo = @()

    # Get available managers
    $availableManagers = Get-AvailablePackageManagers

    if ($Manager -eq 'auto') {
        $managersToCheck = $availableManagers
    } else {
        $managersToCheck = @($Manager) | Where-Object { $_ -in $availableManagers }
    }

    foreach ($mgr in $managersToCheck) {
        try {
            $installedPackages = Get-InstalledPackages -Manager $mgr

            foreach ($pkg in $installedPackages) {
                if ($pkg.Name -like "*$Name*" -or $pkg.Id -like "*$Name*") {
                    # Get additional package information
                    $detailedInfo = Get-DetailedPackageInfo -Package $pkg -Manager $mgr

                    $packageInfo += [PSCustomObject]@{
                        Name = $pkg.Name
                        Id = $pkg.Id
                        Version = $pkg.Version
                        Source = $pkg.Source
                        Manager = $mgr
                        InstallDate = $detailedInfo.InstallDate
                        InstallLocation = $detailedInfo.InstallLocation
                        Publisher = $detailedInfo.Publisher
                        Size = $detailedInfo.Size
                        UninstallString = $detailedInfo.UninstallString
                        IsSystemComponent = $detailedInfo.IsSystemComponent
                        IsRemovable = $detailedInfo.IsRemovable
                    }
                }
            }
        }
        catch {
            Write-Warning "Failed to get package info from $mgr`: $($_.Exception.Message)"
        }
    }

    return $packageInfo
}

function Get-DetailedPackageInfo {
    <#
    .SYNOPSIS
        Get detailed information about a specific package.
    .PARAMETER Package
        Package object from Get-InstalledPackages.
    .PARAMETER Manager
        Package manager.
    #>
    param (
        [PSCustomObject]$Package,
        [string]$Manager
    )

    $info = @{
        InstallDate = $null
        InstallLocation = $null
        Publisher = $null
        Size = $null
        UninstallString = $null
        IsSystemComponent = $false
        IsRemovable = $true
    }

    try {
        if ($Manager -eq 'winget') {
            # Try to get detailed info from winget show command
            $result = Invoke-WingetCommand -Arguments @('show', $Package.Id) -JsonOutput

            if ($result -is [PSCustomObject] -and $result.Sources) {
                $sourceInfo = $result.Sources[0]
                if ($sourceInfo.Packages -and $sourceInfo.Packages[0]) {
                    $pkgInfo = $sourceInfo.Packages[0]
                    $info.InstallDate = $pkgInfo.InstallDate
                    $info.InstallLocation = $pkgInfo.InstallLocation
                    $info.Publisher = $pkgInfo.Publisher
                    $info.Size = $pkgInfo.PackageSize
                }
            }
        }
        elseif ($Manager -eq 'choco') {
            # Try to get detailed info from registry
            $registryPaths = @(
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
                'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
                'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
            )

            foreach ($regPath in $registryPaths) {
                if (Test-Path $regPath) {
                    $uninstallKey = Get-ChildItem $regPath | Where-Object {
                        $displayName = (Get-ItemProperty -Path $_.PSPath -Name DisplayName -ErrorAction SilentlyContinue).DisplayName
                        $displayName -and ($displayName -eq $Package.Name -or $displayName -like "*$($Package.Name)*")
                    } | Select-Object -First 1

                    if ($uninstallKey) {
                        $properties = Get-ItemProperty -Path $uninstallKey.PSPath -ErrorAction SilentlyContinue

                        $info.InstallDate = $properties.InstallDate
                        $info.InstallLocation = $properties.InstallLocation
                        $info.Publisher = $properties.Publisher
                        $info.UninstallString = $properties.UninstallString
                        $info.IsSystemComponent = [bool]$properties.SystemComponent
                        $info.IsRemovable = -not [bool]$properties.NoRemove

                        # Estimate size if available
                        if ($properties.EstimatedSize) {
                            $info.Size = [math]::Round($properties.EstimatedSize / 1024, 2) # Convert KB to MB
                        }

                        break
                    }
                }
            }
        }
    }
    catch {
        Write-Verbose "Failed to get detailed info for $($Package.Name): $($_.Exception.Message)"
    }

    return $info
}

function Test-PackageInstalled {
    <#
    .SYNOPSIS
        Test if a package is installed.
    .PARAMETER Name
        Package name or ID to check.
    .PARAMETER Manager
        Package manager to check ('auto', 'winget', 'choco').
    .OUTPUTS
        [bool] True if package is installed.
    #>
    param (
        [string]$Name,
        [string]$Manager = 'auto'
    )

    $packageInfo = Get-PackageInfo -Name $Name -Manager $Manager
    return $packageInfo.Count -gt 0
}
