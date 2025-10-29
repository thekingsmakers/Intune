# InstallerFunctions.ps1
# Core installer functions: Install, Uninstall, Search, Query, etc.

. $PSScriptRoot\PackageManagers.ps1
. $PSScriptRoot\Utils.ps1

function Install-Package {
    <#
    .SYNOPSIS
        Installs a package using multiple methods with fallbacks.
    .PARAMETER Name
        Package name, ID, or URL.
    .PARAMETER Manager
        Preferred package manager ('winget', 'choco', 'direct', 'auto').
    .PARAMETER Force
        Force installation even if already installed.
    .PARAMETER DryRun
        Only show what would be done.
    .PARAMETER Silent
        Silent installation.
    .PARAMETER AdditionalArgs
        Additional arguments for installer.
    .PARAMETER Checksum
        Expected checksum for direct downloads.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Name,
        [string]$Manager,
        [switch]$Force,
        [switch]$DryRun,
        [switch]$Silent,
        [string[]]$AdditionalArgs,
        [string]$Checksum
    )

    # Check if Name is a URL
    $isUrl = $Name -match '^https?://'

    Write-Log -Level Info "Installing $Name using multiple methods with fallbacks"

    if ($DryRun) {
        Write-Host "DRY RUN: Would install $Name trying multiple methods" -ForegroundColor Cyan
        return
    }

    # Determine installation methods to try
    $installMethods = @()
    $availableManagers = Get-AvailablePackageManagers

    # Determine installation methods to try
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
        'auto' {
            # Try managers in order of preference, then direct download
            foreach ($mgr in $availableManagers) {
                $installMethods += $mgr
            }
            if ($isUrl -or -not $availableManagers) {
                $installMethods += 'direct'
            }
        }
        default {
            # Unknown manager, try all available methods
            foreach ($mgr in $availableManagers) {
                $installMethods += $mgr
            }
            $installMethods += 'direct'
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

    Write-Log -Level Info "Will try installation methods in order: $($installMethods -join ', ')"

    $lastError = $null

    foreach ($method in $installMethods) {
        Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Trying installation method: $method" -ForegroundColor Magenta
        Write-Host ("=" * 50) -ForegroundColor Magenta
        
        try {
            Write-Log -Level Info "Attempting installation with $method..."

            $result = Install-PackageWithMethod -Name $Name -Method $method -Force:$Force -Silent:$Silent -AdditionalArgs $AdditionalArgs -Checksum $Checksum

            if ($result.Success) {
                Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] SUCCESS: Installation completed using $method" -ForegroundColor Green
                Write-Log -Level Info "Installation succeeded using $method"
                return
            } else {
                Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] FAILED: $method failed - $($result.Error)" -ForegroundColor Red
                Write-Log -Level Warning "Installation failed with $method`: $($result.Error)"
                $lastError = $result.Error
            }
        }
        catch {
            Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] EXCEPTION: $method threw an exception - $($_.Exception.Message)" -ForegroundColor Red
            Write-Log -Level Warning "Exception during $method installation: $($_.Exception.Message)"
            $lastError = $_.Exception.Message
        }
        
        # Small delay between attempts
        if ($installMethods.IndexOf($method) -lt ($installMethods.Count - 1)) {
            Write-Host "Waiting 2 seconds before trying next method..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }

    # If we get here, all methods failed
    Write-Log -Level Error "All installation methods failed. Last error: $lastError"
    throw "Installation failed for '$Name'. Tried methods: $($installMethods -join ', '). Last error: $lastError"
}

function Install-PackageWithMethod {
    <#
    .SYNOPSIS
        Installs a package using a specific method.
    .PARAMETER Name
        Package name, ID, or URL.
    .PARAMETER Method
        Installation method ('winget', 'choco', 'direct', 'powershell').
    .PARAMETER Force
        Force installation.
    .PARAMETER Silent
        Silent installation.
    .PARAMETER AdditionalArgs
        Additional arguments.
    .PARAMETER Checksum
        Checksum for direct downloads.
    #>
    param (
        [string]$Name,
        [string]$Method,
        [switch]$Force,
        [switch]$Silent,
        [string[]]$AdditionalArgs,
        [string]$Checksum
    )

    try {
        switch ($Method) {
            'winget' {
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
                        $lastError = "Winget failed: $($result.Output)"
                        $retryCount++
                        if ($retryCount -le $maxRetries) {
                            Write-Host "Winget failed, retrying in 3 seconds... ($retryCount/$maxRetries)" -ForegroundColor Yellow
                            Start-Sleep -Seconds 3
                        }
                    }
                } while ($retryCount -le $maxRetries)

                return @{ Success = $false; Error = $lastError }
            }
            'choco' {
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
                        $lastError = "Choco failed: $($result.Output)"
                        $retryCount++
                        if ($retryCount -le $maxRetries) {
                            Write-Host "Choco failed, retrying in 3 seconds... ($retryCount/$maxRetries)" -ForegroundColor Yellow
                            Start-Sleep -Seconds 3
                        }
                    }
                } while ($retryCount -le $maxRetries)

                return @{ Success = $false; Error = $lastError }
            }
            'direct' {
                Install-FromUrl -Url $Name -Silent:$Silent -AdditionalArgs $AdditionalArgs -Checksum $Checksum
                return @{ Success = $true; Method = 'direct' }
            }
            'powershell' {
                $result = Install-WithPowerShell -Name $Name -Force:$Force -Silent:$Silent -AdditionalArgs $AdditionalArgs
                return $result
            }
            default {
                return @{ Success = $false; Error = "Unknown installation method: $Method" }
            }
        }
    }
    catch {
        return @{ Success = $false; Error = "Exception in $Method`: $($_.Exception.Message)" }
    }
}

function Install-WithPowerShell {
    <#
    .SYNOPSIS
        Installs using PowerShell-native methods.
    .PARAMETER Name
        Package name or path.
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

    # Check if it's a local file
    if (Test-Path $Name) {
        $ext = [System.IO.Path]::GetExtension($Name).ToLower()

        switch ($ext) {
            '.msi' {
                $installerArgs = @('/i', $Name, '/quiet')
                if (-not $Silent) { $installerArgs = @('/i', $Name) }
                $installerArgs += $AdditionalArgs

                $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $installerArgs -Wait -PassThru
                if ($process.ExitCode -eq 0) {
                    return @{ Success = $true; Method = 'powershell-msi' }
                } else {
                    return @{ Success = $false; Error = "MSI installation failed with exit code $($process.ExitCode)" }
                }
            }
            '.exe' {
                $installerArgs = $AdditionalArgs
                if ($Silent) { $installerArgs += '/S' }

                $process = Start-Process -FilePath $Name -ArgumentList $installerArgs -Wait -PassThru
                if ($process.ExitCode -eq 0) {
                    return @{ Success = $true; Method = 'powershell-exe' }
                } else {
                    return @{ Success = $false; Error = "EXE installation failed with exit code $($process.ExitCode)" }
                }
            }
            '.zip' {
                # Extract ZIP file
                $extractPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetFileNameWithoutExtension($Name))
                if (Test-Path $extractPath) {
                    Remove-Item $extractPath -Recurse -Force
                }

                Expand-Archive -Path $Name -DestinationPath $extractPath -Force

                # Try to find and run setup.exe or install.exe
                $setupFiles = Get-ChildItem $extractPath -Filter "setup.exe" -Recurse | Select-Object -First 1
                if (-not $setupFiles) {
                    $setupFiles = Get-ChildItem $extractPath -Filter "install.exe" -Recurse | Select-Object -First 1
                }

                if ($setupFiles) {
                    $installerArgs = $AdditionalArgs
                    if ($Silent) { $installerArgs += '/S' }

                    $process = Start-Process -FilePath $setupFiles.FullName -ArgumentList $installerArgs -Wait -PassThru
                    if ($process.ExitCode -eq 0) {
                        return @{ Success = $true; Method = 'powershell-zip' }
                    } else {
                        return @{ Success = $false; Error = "ZIP extracted installer failed with exit code $($process.ExitCode)" }
                    }
                } else {
                    return @{ Success = $false; Error = "No setup.exe or install.exe found in extracted ZIP" }
                }
            }
            default {
                return @{ Success = $false; Error = "Unsupported file type for PowerShell installation: $ext" }
            }
        }
    } else {
        # Try to find the package in common locations or download it
        return @{ Success = $false; Error = "File not found and not a URL: $Name" }
    }
}

function Install-FromUrl {
    <#
    .SYNOPSIS
        Downloads and installs from a direct URL.
    .PARAMETER Url
        URL to download from.
    .PARAMETER Silent
        Silent installation.
    .PARAMETER AdditionalArgs
        Additional arguments for the installer.
    .PARAMETER Checksum
        Expected SHA256 checksum.
    #>
    param (
        [string]$Url,
        [switch]$Silent,
        [string[]]$AdditionalArgs,
        [string]$Checksum
    )

    $cacheDir = Get-DefaultCacheDirectory
    $fileName = [System.IO.Path]::GetFileName($Url)
    $localPath = Join-Path $cacheDir $fileName

    Write-Log -Level Info "Downloading $Url to $localPath"

    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $localPath)
    }
    catch {
        throw "Download failed: $($_.Exception.Message)"
    }

    # Verify checksum if provided
    if ($Checksum) {
        $actualHash = Get-FileHash -Path $localPath -Algorithm SHA256
        if ($actualHash.Hash -ne $Checksum.ToUpper()) {
            Remove-Item $localPath -Force
            throw "Checksum verification failed. Expected: $Checksum, Got: $($actualHash.Hash)"
        }
        Write-Log -Level Info "Checksum verified successfully"
    }

    # Determine installer type and run
    $ext = [System.IO.Path]::GetExtension($fileName).ToLower()
    switch ($ext) {
        '.msi' {
            $installerArgs = @('/i', $localPath, '/quiet')
            if (-not $Silent) { $installerArgs = @('/i', $localPath) }
            $installerArgs += $AdditionalArgs
            $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $installerArgs -Wait -PassThru
        }
        '.exe' {
            $installerArgs = $AdditionalArgs
            if ($Silent) { $installerArgs += '/S' }
            $process = Start-Process -FilePath $localPath -ArgumentList $installerArgs -Wait -PassThru
        }
        default {
            throw "Unsupported file type: $ext"
        }
    }

    if ($process.ExitCode -ne 0) {
        throw "Installation process failed with exit code $($process.ExitCode)"
    }

    Write-Log -Level Info "Direct installation completed successfully"
}

function Install-PackagesParallel {
    <#
    .SYNOPSIS
        Installs multiple packages concurrently.
    .PARAMETER Packages
        Array of package names or URLs.
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
        Additional arguments for installers.
    .PARAMETER Checksum
        Checksum for direct downloads (single value for all).
    #>
    param (
        [string[]]$Packages,
        [string]$Manager,
        [int]$MaxConcurrency = 3,
        [switch]$Force,
        [switch]$DryRun,
        [switch]$Silent,
        [string[]]$AdditionalArgs,
        [string]$Checksum
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
            param($name, $manager, $force, $silent, $installerArgs, $checksum)
            try {
                . $using:PSScriptRoot\PackageManagers.ps1
                . $using:PSScriptRoot\Utils.ps1
                . $using:PSScriptRoot\InstallerFunctions.ps1
                Initialize-Logging -LogLevel 'Info'

                Install-Package -Name $name -Manager $manager -Force:$force -Silent:$silent -AdditionalArgs $installerArgs -Checksum $checksum
                return @{ Success = $true; Package = $name }
            }
            catch {
                return @{ Success = $false; Package = $name; Error = $_.Exception.Message }
            }
        } -ArgumentList $pkg, $Manager, $Force, $Silent, $AdditionalArgs, $Checksum

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

    Write-Log -Level Info "Parallel installation completed"
}

function Uninstall-Package {
    <#
    .SYNOPSIS
        Uninstalls a package using multiple methods with fallbacks.
    .PARAMETER Name
        Package name or ID.
    .PARAMETER Manager
        Preferred package manager ('winget', 'choco', 'auto').
    .PARAMETER Force
        Force uninstallation.
    .PARAMETER DryRun
        Only show what would be done.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Name,
        [string]$Manager,
        [switch]$Force,
        [switch]$DryRun
    )

    Write-Log -Level Info "Uninstalling $Name using multiple methods with fallbacks"

    if ($DryRun) {
        Write-Host "DRY RUN: Would uninstall $Name trying multiple methods"
        return
    }

    $uninstallMethods = @()
    $availableManagers = Get-AvailablePackageManagers

    # Determine uninstallation methods to try
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
        'auto' {
            # Try managers in order of preference
            foreach ($mgr in $availableManagers) {
                $uninstallMethods += $mgr
            }
        }
        default {
            # Unknown manager, try all available methods
            foreach ($mgr in $availableManagers) {
                $uninstallMethods += $mgr
            }
        }
    }

    # Remove duplicates while preserving order
    $uninstallMethods = $uninstallMethods | Select-Object -Unique

    Write-Log -Level Info "Will try uninstallation methods in order: $($uninstallMethods -join ', ')"

    $lastError = $null

    foreach ($method in $uninstallMethods) {
        try {
            Write-Log -Level Info "Attempting uninstallation with $method..."

            $result = Uninstall-PackageWithMethod -Name $Name -Method $method -Force:$Force

            if ($result.Success) {
                Write-Log -Level Info "Uninstallation succeeded using $method"
                return
            } else {
                Write-Log -Level Warning "Uninstallation failed with $method`: $($result.Error)"
                $lastError = $result.Error
            }
        }
        catch {
            Write-Log -Level Warning "Exception during $method uninstallation: $($_.Exception.Message)"
            $lastError = $_.Exception.Message
        }
    }

    # If we get here, all methods failed
    Write-Log -Level Error "All uninstallation methods failed. Last error: $lastError"
    throw "Uninstallation failed for '$Name'. Tried methods: $($uninstallMethods -join ', '). Last error: $lastError"
}

function Uninstall-PackageWithMethod {
    <#
    .SYNOPSIS
        Uninstalls a package using a specific method.
    .PARAMETER Name
        Package name or ID.
    .PARAMETER Method
        Uninstallation method ('winget', 'choco', 'powershell').
    .PARAMETER Force
        Force uninstallation.
    #>
    param (
        [string]$Name,
        [string]$Method,
        [switch]$Force
    )

    try {
        switch ($Method) {
            'winget' {
                $installerArgs = @('uninstall', $Name)
                if ($Force) { $installerArgs += '--force' }

                $result = Invoke-WingetCommand -Arguments $installerArgs
                if ($result.ExitCode -eq 0) {
                    return @{ Success = $true; Method = 'winget' }
                } else {
                    return @{ Success = $false; Error = "Winget uninstall failed: $($result.Output)" }
                }
            }
            'choco' {
                $installerArgs = @('uninstall', $Name, '-y')
                if ($Force) { $installerArgs += '--force' }

                $result = Invoke-ChocoCommand -Arguments $installerArgs
                if ($result.ExitCode -eq 0) {
                    return @{ Success = $true; Method = 'choco' }
                } else {
                    return @{ Success = $false; Error = "Choco uninstall failed: $($result.Output)" }
                }
            }
            'powershell' {
                $result = Uninstall-WithPowerShell -Name $Name -Force:$Force
                return $result
            }
            default {
                return @{ Success = $false; Error = "Unknown uninstallation method: $Method" }
            }
        }
    }
    catch {
        return @{ Success = $false; Error = "Exception in $Method`: $($_.Exception.Message)" }
    }
}

function Uninstall-WithPowerShell {
    <#
    .SYNOPSIS
        Uninstalls using PowerShell-native methods.
    .PARAMETER Name
        Package name.
    .PARAMETER Force
        Force uninstallation.
    #>
    param (
        [string]$Name,
        [switch]$Force
    )

    # Try to find the package in installed programs and uninstall
    try {
        $uninstallKey = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" |
                        Get-ItemProperty |
                        Where-Object { $_.DisplayName -like "*$Name*" } |
                        Select-Object -First 1

        if ($uninstallKey) {
            $uninstallString = $uninstallKey.UninstallString
            if ($uninstallString) {
                # Handle different uninstall string formats
                if ($uninstallString -match '^"([^"]+)"\s*(.*)$') {
                    $exe = $matches[1]
                    $args = $matches[2]
                } elseif ($uninstallString -match '^([^\s]+)\s*(.*)$') {
                    $exe = $matches[1]
                    $args = $matches[2]
                } else {
                    $exe = $uninstallString
                    $args = ""
                }

                if ($args -and $Force) {
                    $args += " /quiet"
                }

                $process = Start-Process -FilePath $exe -ArgumentList $args -Wait -PassThru
                if ($process.ExitCode -eq 0) {
                    return @{ Success = $true; Method = 'powershell-registry' }
                } else {
                    return @{ Success = $false; Error = "Registry uninstall failed with exit code $($process.ExitCode)" }
                }
            }
        }

        # Try Programs and Features (appwiz.cpl)
        # This is more complex and would require COM automation
        return @{ Success = $false; Error = "Package not found in registry for PowerShell uninstall" }
    }
    catch {
        return @{ Success = $false; Error = "PowerShell uninstall failed: $($_.Exception.Message)" }
    }
}

function Upgrade-Package {
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
                    $searchResult = Invoke-WingetCommand -Arguments @('search', $upgradeName) -JsonOutput
                    if ($searchResult -is [PSCustomObject] -and $searchResult.Sources) {
                        $latestVersion = $searchResult.Sources[0].Packages[0].PackageVersion
                    } else {
                        # Fallback to text parsing
                        $searchResult = Invoke-WingetCommand -Arguments @('search', $upgradeName)
                        if ($searchResult.Output) {
                            # Parse version from text output
                            $lines = $searchResult.Output -split "`n" | Where-Object { $_ -and $_.Trim() -notmatch '^[-]+$' -and $_.Trim() -notmatch '^$' }
                            foreach ($line in $lines) {
                                if ($line -match $upgradeName -and $line -match '(\d+\.\d+\.\d+\.\d+|\d+\.\d+\.\d+)') {
                                    $latestVersion = $matches[0]
                                    break
                                }
                            }
                        }
                    }
                } elseif ($upgradeMethod -eq 'choco') {
                    $searchResult = Invoke-ChocoCommand -Arguments @('search', $upgradeName)
                    if ($searchResult.Output) {
                        # Parse choco search output to get latest version
                        $lines = $searchResult.Output -split "`n" | Where-Object { $_ -and $_.Trim() -notmatch '^[-]+$' -and $_.Trim() -notmatch '^$' }
                        foreach ($line in $lines) {
                            if ($line -match '^([^|]+)\s+([^|]+)\|?(.*)$') {
                                $pkgName = $matches[1].Trim()
                                if ($pkgName -eq $upgradeName -or $pkgName -eq $pkg.Name) {
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
            $result = Upgrade-PackageWithMethod -Name $upgradeName -Method $upgradeMethod -Force:$Force -Silent:$Silent -AdditionalArgs $AdditionalArgs

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
                        $fallbackResult = Upgrade-PackageWithMethod -Name $upgradeName -Method $fallbackMethod -Force:$Force -Silent:$Silent -AdditionalArgs $AdditionalArgs
                        
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

function Upgrade-PackageWithMethod {
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
            'choco' {
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

function Upgrade-PackagesParallel {
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
                . $using:PSScriptRoot\Utils.ps1
                . $using:PSScriptRoot\InstallerFunctions.ps1
                Initialize-Logging -LogLevel 'Info'

                Upgrade-Package -Name $name -Manager $manager -Force:$force -Silent:$silent -AdditionalArgs $installerArgs
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
                    $lines = $fallbackResult.Output -split "`n" | Where-Object { $_ -and $_.Trim() -notmatch '^[-]+$' -and $_.Trim() -notmatch '^$' }
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
                                                
                                                # Detect if this is 5-column format (Name, Id, InstalledVersion, AvailableVersion, Source)
                                                # or 4-column format (Name, Id, Version, Source)
                                                if ($parts.Count -ge 5 -and $parts[3] -match '^\d+(\.\d+)*') {
                                                    # 5-column format
                                                    $version = $parts[2].Trim()  # Installed version
                                                    $source = $parts[4].Trim()
                                                } elseif ($parts.Count -ge 4) {
                                                    # 4-column format
                                                    $version = $parts[2].Trim()
                                                    $source = $parts[3].Trim()
                                                } else {
                                                    # Fallback
                                                    $version = if ($parts.Count -ge 3) { $parts[2].Trim() } else { "" }
                                                    $source = "winget"
                                                }

                                                # Clean up the name (remove truncated parts with ...)
                                                if ($name -match '(.+?)\s*\.\.\..*') {
                                                    $name = $matches[1].Trim()
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
                            $result = Invoke-ChocoCommand -Arguments @('list', '--local-only')
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
                                
                                # Detect if this is 5-column format (Name, Id, InstalledVersion, AvailableVersion, Source)
                                # or 4-column format (Name, Id, Version, Source)
                                if ($parts.Count -ge 5 -and $parts[3] -match '^\d+(\.\d+)*') {
                                    # 5-column format
                                    $version = $parts[2].Trim()  # Installed version
                                    $source = $parts[4].Trim()
                                } elseif ($parts.Count -ge 4) {
                                    # 4-column format
                                    $version = $parts[2].Trim()
                                    $source = $parts[3].Trim()
                                } else {
                                    # Fallback
                                    $version = if ($parts.Count -ge 3) { $parts[2].Trim() } else { "" }
                                    $source = "winget"
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
            $result = Invoke-ChocoCommand -Arguments @('list', '--local-only')
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
