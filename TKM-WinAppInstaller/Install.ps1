# Install.ps1
# Installation functions extracted from InstallerFunctions.ps1

. $PSScriptRoot\PackageManagers.ps1
. $PSScriptRoot\Utils.ps1

function Install-Package {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Manager,
        [switch]$Force,
        [switch]$DryRun,
        [switch]$Silent,
        [string[]]$AdditionalArgs,
        [string]$Checksum
    )

    $isUrl = $Name -match '^https?://'

    Write-Log -Level Info "Installing $Name using multiple methods with fallbacks"

    if ($DryRun) {
        Write-Host "DRY RUN: Would install $Name trying multiple methods" -ForegroundColor Cyan
        return
    }

    $installMethods = @()
    $availableManagers = Get-AvailablePackageManagers

    switch ($Manager) {
        'winget' {
            if ('winget' -in $availableManagers) { $installMethods += 'winget' }
        }
        'choco' {
            if ('choco' -in $availableManagers) { $installMethods += 'choco' }
        }
        'psadt' { $installMethods += 'psadt' }
        'direct' { $installMethods += 'direct' }
        'auto' {
            foreach ($mgr in $availableManagers) { $installMethods += $mgr }
            if ($script:PSADTAvailable) { $installMethods += 'psadt' }
            if ($isUrl -or -not $availableManagers) { $installMethods += 'direct' }
        }
        default {
            foreach ($mgr in $availableManagers) { $installMethods += $mgr }
            if ($script:PSADTAvailable) { $installMethods += 'psadt' }
            $installMethods += 'direct'
        }
    }

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
        } catch {
            Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] EXCEPTION: $method threw an exception - $($_.Exception.Message)" -ForegroundColor Red
            Write-Log -Level Warning "Exception during $method installation: $($_.Exception.Message)"
            $lastError = $_.Exception.Message
        }

        if ($installMethods.IndexOf($method) -lt ($installMethods.Count - 1)) {
            Write-Host "Waiting 2 seconds before trying next method..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }

    Write-Log -Level Error "All installation methods failed. Last error: $lastError"
    throw "Installation failed for '$Name'. Tried methods: $($installMethods -join ', '). Last error: $lastError"
}

function Install-PackageWithMethod {
    param(
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
            'psadt' {
                if (-not $script:PSADTAvailable) { return @{ Success = $false; Error = 'PSADT not loaded' } }
                try {
                    if (Test-Path $Name) {
                        $ext = [System.IO.Path]::GetExtension($Name).ToLower()
                        if ($ext -eq '.msi') {
                            Start-ADTMsiProcess -Action Install -FilePath $Name
                        } elseif ($ext -eq '.msp') {
                            Start-ADTMspProcess -FilePath $Name
                        } else {
                            $argList = if ($Silent) { @('/S', '/silent', '/quiet', '/verysilent', '/qn') } else { @() }
                            Start-ADTProcess -FilePath $Name -ArgumentList $argList -WindowStyle Hidden -CreateNoWindow
                        }
                        return @{ Success = $true; Method = 'psadt' }
                    } else {
                        return @{ Success = $false; Error = "PSADT install requires a local file path; '$Name' is not a file" }
                    }
                } catch {
                    return @{ Success = $false; Error = "PSADT install failed: $($_.Exception.Message)" }
                }
            }
            default {
                return @{ Success = $false; Error = "Unknown installation method: $Method" }
            }
        }
    } catch {
        return @{ Success = $false; Error = "Exception in $Method`: $($_.Exception.Message)" }
    }
}

function Install-WithPowerShell {
    param(
        [string]$Name,
        [switch]$Force,
        [switch]$Silent,
        [string[]]$AdditionalArgs
    )

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
                $extractPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetFileNameWithoutExtension($Name))
                if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }

                Expand-Archive -Path $Name -DestinationPath $extractPath -Force

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
        return @{ Success = $false; Error = "File not found and not a URL: $Name" }
    }
}

function Install-FromUrl {
    param(
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
    } catch {
        throw "Download failed: $($_.Exception.Message)"
    }

    if ($Checksum) {
        $actualHash = Get-FileHash -Path $localPath -Algorithm SHA256
        if ($actualHash.Hash -ne $Checksum.ToUpper()) {
            Remove-Item $localPath -Force
            throw "Checksum verification failed. Expected: $Checksum, Got: $($actualHash.Hash)"
        }
        Write-Log -Level Info "Checksum verified successfully"
    }

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
    param(
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
        while ($jobs.Count -ge $MaxConcurrency) {
            $jobs = $jobs | Where-Object { $_.State -eq 'Running' }
            Start-Sleep -Milliseconds 500
        }

        $job = Start-Job -ScriptBlock {
            param($name, $manager, $force, $silent, $installerArgs, $checksum)
            try {
                . $using:PSScriptRoot\PackageManagers.ps1
                . $using:PSScriptRoot\Utils.ps1
                . $using:PSScriptRoot\AdvancedUninstall.ps1
                . $using:PSScriptRoot\Install.ps1
                Initialize-Logging -LogLevel 'Info'
                $null = Initialize-PSADT

                Install-Package -Name $name -Manager $manager -Force:$force -Silent:$silent -AdditionalArgs $installerArgs -Checksum $checksum
                return @{ Success = $true; Package = $name }
            } catch {
                return @{ Success = $false; Package = $name; Error = $_.Exception.Message }
            }
        } -ArgumentList $pkg, $Manager, $Force, $Silent, $AdditionalArgs, $Checksum

        $jobs += $job
    }

    while ($jobs | Where-Object { $_.State -eq 'Running' }) {
        Start-Sleep -Milliseconds 500
    }

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
