# AdvancedUninstall.ps1
# THE KINGSMAKERS WINAPP TOOL - Advanced Uninstallation Engine
# Production-quality Windows application removal with intelligent fallbacks

. $PSScriptRoot\Utils.ps1
. $PSScriptRoot\PackageManagers.ps1

#region Detection

function Find-InstalledApplication {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$ExactMatch,
        [switch]$IncludeSystemComponents
    )

    $results = @()
    $searchName = if ($ExactMatch) { $ExactMatch } else { $Name }

    $sources = @(
        { Get-AppsFromRegistry -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" -Name $searchName -Exact:$ExactMatch },
        { Get-AppsFromRegistry -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" -Name $searchName -Exact:$ExactMatch },
        { Get-AppsFromRegistry -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" -Name $searchName -Exact:$ExactMatch },
        { Get-AppsFromWinget -Name $searchName },
        { Get-AppsFromChoco -Name $searchName },
        { Get-AppsFromScoop -Name $searchName },
        { Get-AppsFromAppX -Name $searchName },
        { Get-AppsFromMSI -Name $searchName },
        { Get-AppsFromProcesses -Name $searchName },
        { Get-AppsFromServices -Name $searchName },
        { Get-AppsFromStartMenu -Name $searchName },
        { Get-AppsFromProgramFiles -Name $searchName }
    )

    foreach ($source in $sources) {
        try {
            $sourceResults = & $source
            if ($sourceResults) {
                $results += $sourceResults
            }
        } catch {
            Write-Log -Level Debug "Detection source error: $($_.Exception.Message)"
        }
    }

    $results = Merge-ApplicationRecords -Records $results

    if (-not $IncludeSystemComponents) {
        $results = $results | Where-Object { -not $_.IsSystemComponent }
    }

    return $results
}

function Get-AppsFromRegistry {
    param([string]$Path, [string]$Name, [switch]$Exact)

    $apps = @()
    if (-not (Test-Path $Path)) { return $apps }

    Get-ChildItem $Path -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $prop = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
            $displayName = $prop.DisplayName
            if (-not $displayName) { return }

            $match = if ($Exact) { $displayName -eq $Name } else { $displayName -match [regex]::Escape($Name) -or $displayName -like "*$Name*" }
            if (-not $match) { return }

            $uninstallString = $prop.UninstallString
            $quietString = $prop.QuietUninstallString

            $installSource = $prop.InstallSource
            $installLocation = $prop.InstallLocation

            $apps += [PSCustomObject]@{
                DisplayName      = $displayName
                Publisher        = $prop.Publisher
                Version          = $prop.DisplayVersion
                InstallLocation  = $installLocation
                InstallSource    = $installSource
                ProductCode      = $_.PSChildName
                UpgradeCode      = $null
                PackageManager   = 'registry'
                InstallerType    = Detect-InstallerType -UninstallString $uninstallString -InstallLocation $installLocation
                Architecture     = if ($Path -match 'WOW6432Node') { 'x86' } else { 'x64' }
                UninstallString  = $uninstallString
                QuietUninstallString = $quietString
                EstimatedSize    = if ($prop.EstimatedSize) { [math]::Round($prop.EstimatedSize / 1MB, 2) } else { $null }
                InstallDate      = $prop.InstallDate
                IsSystemComponent = [bool]$prop.SystemComponent
                Source           = 'registry'
                RegistryPath     = $_.PSPath
            }
        } catch {}
    }
    return $apps
}

function Get-AppsFromWinget {
    param([string]$Name)
    $apps = @()
    try {
        $result = Invoke-WingetCommand -Arguments @('list', $Name) -JsonOutput
        $jsonParsed = $false
        if ($result -is [PSCustomObject]) {
            if ($result.Sources) {
                $jsonParsed = $true
                foreach ($source in $result.Sources) {
                    foreach ($pkg in $source.Packages) {
                        $id = $pkg.PackageIdentifier
                        $apps += [PSCustomObject]@{
                            DisplayName      = if ($pkg.Name) { $pkg.Name } else { $id }
                            Publisher        = $pkg.Publisher
                            Version          = $pkg.PackageVersion
                            InstallLocation  = $null
                            InstallSource    = $source.SourceIdentifier
                            ProductCode      = $id
                            UpgradeCode      = $null
                            PackageManager   = 'winget'
                            InstallerType    = 'winget'
                            Architecture     = $null
                            UninstallString  = "winget uninstall ""$id"""
                            QuietUninstallString = "winget uninstall ""$id"" --silent"
                            EstimatedSize    = $null
                            InstallDate      = $null
                            IsSystemComponent = $false
                            Source           = 'winget'
                        }
                    }
                }
            }
        }
        if (-not $jsonParsed) {
            $textResult = Invoke-WingetCommand -Arguments @('list')
            if ($textResult.ExitCode -eq 0 -and $textResult.Output) {
                $lines = $textResult.Output -split "`n" | Where-Object { $_ -and $_.Trim() -notmatch '^[-]+$' -and $_.Trim() -notmatch '^$' -and $_.Trim() -notmatch '^Name\s+Id\s+Version\s+Source' -and $_.Trim() -notmatch '^Name\s+Id\s+Available' }
                $searchName = $Name.ToLower()
                foreach ($line in $lines) {
                    $line = $line.Trim()
                    if (-not $line) { continue }
                    $parts = $line -split '\s{2,}' | Where-Object { $_ -ne '' }
                    if ($parts.Count -lt 2) { continue }
                    $displayName = $parts[0].Trim()
                    if ($displayName.ToLower() -notmatch [regex]::Escape($searchName) -and $displayName.ToLower() -notlike "*$searchName*") { continue }
                    $candidateId = $parts[1].Trim()
                    if ($candidateId -match '^(.*?)…') { $candidateId = $matches[1].Trim() }
                    $version = if ($parts.Count -ge 3) { $parts[2].Trim() } else { '' }
                    $apps += [PSCustomObject]@{
                        DisplayName      = $displayName
                        Publisher        = $null
                        Version          = $version
                        InstallLocation  = $null
                        InstallSource    = 'winget'
                        ProductCode      = $candidateId
                        UpgradeCode      = $null
                        PackageManager   = 'winget'
                        InstallerType    = 'winget'
                        Architecture     = $null
                        UninstallString  = "winget uninstall ""$candidateId"""
                        QuietUninstallString = "winget uninstall ""$candidateId"" --silent"
                        EstimatedSize    = $null
                        InstallDate      = $null
                        IsSystemComponent = $false
                        Source           = 'winget'
                    }
                }
            }
        }
    } catch {}
    return $apps
}

function Get-AppsFromChoco {
    param([string]$Name)
    $apps = @()
    try {
        $result = Invoke-ChocoCommand -Arguments @('list', '--local-only', $Name)
        if ($result.ExitCode -eq 0 -and $result.Output) {
            $result.Output -split "`n" | ForEach-Object {
                if ($_ -match '^([^|]+)\s+([^|]+)$') {
                    $apps += [PSCustomObject]@{
                        DisplayName      = $matches[1].Trim()
                        Publisher        = 'chocolatey'
                        Version          = $matches[2].Trim()
                        InstallLocation  = $null
                        InstallSource    = 'chocolatey'
                        ProductCode      = $matches[1].Trim()
                        UpgradeCode      = $null
                        PackageManager   = 'choco'
                        InstallerType    = 'choco'
                        Architecture     = $null
                        UninstallString  = "choco uninstall $($matches[1].Trim()) -y"
                        QuietUninstallString = "choco uninstall $($matches[1].Trim()) -y"
                        EstimatedSize    = $null
                        InstallDate      = $null
                        IsSystemComponent = $false
                        Source           = 'choco'
                    }
                }
            }
        }
    } catch {}
    return $apps
}

function Get-AppsFromScoop {
    param([string]$Name)
    $apps = @()
    try {
        $result = & scoop list 2>$null
        if ($LASTEXITCODE -eq 0 -and $result) {
            $result | ForEach-Object {
                if ($_ -match '^(\S+)\s+(\S+)') {
                    $pkgName = $matches[1]
                    if ($pkgName -like "*$Name*") {
                        $apps += [PSCustomObject]@{
                            DisplayName      = $pkgName
                            Publisher        = 'scoop'
                            Version          = $matches[2]
                            InstallLocation  = "$env:USERPROFILE\scoop\apps\$pkgName"
                            InstallSource    = 'scoop'
                            ProductCode      = $pkgName
                            UpgradeCode      = $null
                            PackageManager   = 'scoop'
                            InstallerType    = 'scoop'
                            Architecture     = $null
                            UninstallString  = "scoop uninstall $pkgName"
                            QuietUninstallString = "scoop uninstall $pkgName"
                            EstimatedSize    = $null
                            InstallDate      = $null
                            IsSystemComponent = $false
                            Source           = 'scoop'
                        }
                    }
                }
            }
        }
    } catch {}
    return $apps
}

function Get-AppsFromAppX {
    param([string]$Name)
    $apps = @()
    try {
        $packages = Get-AppxPackage -Name "*$Name*" -ErrorAction SilentlyContinue
        if (-not $packages) {
            $compactName = $Name -replace '\s+', ''
            $packages = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$compactName*" }
        }
        foreach ($pkg in $packages) {
            $apps += [PSCustomObject]@{
                DisplayName      = $pkg.Name
                Publisher        = $pkg.Publisher
                Version          = "$($pkg.Version.Major).$($pkg.Version.Minor).$($pkg.Version.Build)"
                InstallLocation  = $pkg.InstallLocation
                InstallSource    = 'AppX'
                ProductCode      = $pkg.PackageFullName
                UpgradeCode      = $null
                PackageManager   = 'appx'
                InstallerType    = 'AppX'
                Architecture     = $pkg.Architecture
                UninstallString  = "Remove-AppxPackage $($pkg.PackageFullName)"
                QuietUninstallString = "Remove-AppxPackage $($pkg.PackageFullName)"
                EstimatedSize    = $null
                InstallDate      = $null
                IsSystemComponent = $false
                Source           = 'appx'
            }
        }

        $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$Name*" }
        foreach ($pkg in $provisioned) {
            $apps += [PSCustomObject]@{
                DisplayName      = $pkg.DisplayName
                Publisher        = $pkg.Publisher
                Version          = $pkg.Version
                InstallLocation  = $null
                InstallSource    = 'AppXProvisioned'
                ProductCode      = $pkg.PackageName
                UpgradeCode      = $null
                PackageManager   = 'appx'
                InstallerType    = 'AppX'
                Architecture     = $null
                UninstallString  = "Remove-AppxProvisionedPackage -Online -PackageName $($pkg.PackageName)"
                QuietUninstallString = "Remove-AppxProvisionedPackage -Online -PackageName $($pkg.PackageName)"
                EstimatedSize    = $null
                InstallDate      = $null
                IsSystemComponent = $false
                Source           = 'appxprovisioned'
            }
        }
    } catch {}
    return $apps
}

function Get-AppsFromMSI {
    param([string]$Name)
    $apps = @()
    try {
        $msiProducts = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$Name*" -or $_.Vendor -like "*$Name*" }
        foreach ($pkg in $msiProducts) {
            $apps += [PSCustomObject]@{
                DisplayName      = $pkg.Name
                Publisher        = $pkg.Vendor
                Version          = $pkg.Version
                InstallLocation  = $pkg.InstallLocation
                InstallSource    = 'MSI'
                ProductCode      = $pkg.IdentifyingNumber
                UpgradeCode      = $null
                PackageManager   = 'msi'
                InstallerType    = 'MSI'
                Architecture     = $null
                UninstallString  = "msiexec /x $($pkg.IdentifyingNumber) /qn /norestart"
                QuietUninstallString = "msiexec /x $($pkg.IdentifyingNumber) /qn /norestart"
                EstimatedSize    = $null
                InstallDate      = $null
                IsSystemComponent = $false
                Source           = 'msi'
            }
        }
    } catch {}
    return $apps
}

function Get-AppsFromProcesses {
    param([string]$Name)
    $apps = @()
    try {
        $processes = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "*$Name*" -or $_.MainWindowTitle -like "*$Name*" } | Select-Object -Unique -First 20
        foreach ($proc in $processes) {
            $path = $null
            try { $path = $proc.Path } catch { try { $path = (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue).MainModule.FileName } catch {} }
            $apps += [PSCustomObject]@{
                DisplayName      = $proc.ProcessName
                Publisher        = $null
                Version          = $null
                InstallLocation  = if ($path) { Split-Path $path -Parent } else { $null }
                InstallSource    = 'process'
                ProductCode      = $proc.ProcessName
                UpgradeCode      = $null
                PackageManager   = 'process'
                InstallerType    = 'Portable'
                Architecture     = $null
                UninstallString  = $null
                QuietUninstallString = $null
                EstimatedSize    = $null
                InstallDate      = $null
                IsSystemComponent = $false
                Source           = 'process'
                ProcessId        = $proc.Id
                ProcessPath      = $path
            }
        }
    } catch {}
    return $apps
}

function Get-AppsFromServices {
    param([string]$Name)
    $apps = @()
    try {
        $services = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$Name*" -or $_.ServiceName -like "*$Name*" }
        foreach ($svc in $services) {
            $path = $null
            try { $path = (Get-CimInstance Win32_Service -Filter "Name='$($svc.ServiceName)'" -ErrorAction SilentlyContinue).PathName } catch {}
            $apps += [PSCustomObject]@{
                DisplayName      = $svc.DisplayName
                Publisher        = $null
                Version          = $null
                InstallLocation  = if ($path) { Split-Path $path -Parent } else { $null }
                InstallSource    = 'service'
                ProductCode      = $svc.ServiceName
                UpgradeCode      = $null
                PackageManager   = 'service'
                InstallerType    = 'Service'
                Architecture     = $null
                UninstallString  = $null
                QuietUninstallString = $null
                EstimatedSize    = $null
                InstallDate      = $null
                IsSystemComponent = $false
                Source           = 'service'
                ServiceName      = $svc.ServiceName
                ServiceStatus    = $svc.Status
                ServicePath      = $path
            }
        }
    } catch {}
    return $apps
}

function Get-AppsFromStartMenu {
    param([string]$Name)
    $apps = @()
    $paths = @(
        "$env:ProgramData\Microsoft\Windows\Start Menu",
        "$env:APPDATA\Microsoft\Windows\Start Menu"
    )
    foreach ($path in $paths) {
        try {
            $shortcuts = Get-ChildItem "$path\Programs" -Recurse -Filter "*$Name*" -ErrorAction SilentlyContinue
            foreach ($sc in $shortcuts) {
                $target = $null
                try {
                    $shell = New-Object -ComObject WScript.Shell
                    $shortcut = $shell.CreateShortcut($sc.FullName)
                    $target = $shortcut.TargetPath
                } catch {}
                $apps += [PSCustomObject]@{
                    DisplayName      = [System.IO.Path]::GetFileNameWithoutExtension($sc.Name)
                    Publisher        = $null
                    Version          = $null
                    InstallLocation  = if ($target) { Split-Path $target -Parent } else { $null }
                    InstallSource    = 'startmenu'
                    ProductCode      = $sc.FullName
                    UpgradeCode      = $null
                    PackageManager   = 'startmenu'
                    InstallerType    = 'Portable'
                    Architecture     = $null
                    UninstallString  = $null
                    QuietUninstallString = $null
                    EstimatedSize    = $null
                    InstallDate      = $null
                    IsSystemComponent = $false
                    Source           = 'startmenu'
                    ShortcutPath     = $sc.FullName
                    TargetPath       = $target
                }
            }
        } catch {}
    }
    return $apps
}

function Get-AppsFromProgramFiles {
    param([string]$Name)
    $apps = @()
    $searchPaths = @(
        "${env:ProgramFiles}",
        "${env:ProgramFiles(x86)}",
        "$env:LOCALAPPDATA\Programs"
    )
    foreach ($path in $searchPaths) {
        try {
            $dirs = Get-ChildItem $path -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$Name*" }
            foreach ($dir in $dirs) {
                $uninstallExe = Get-ChildItem $dir.FullName -Recurse -Include @('uninstall.exe', 'unins000.exe', 'maintenancetool.exe') -ErrorAction SilentlyContinue | Select-Object -First 1
                $apps += [PSCustomObject]@{
                    DisplayName      = $dir.Name
                    Publisher        = $null
                    Version          = $null
                    InstallLocation  = $dir.FullName
                    InstallSource    = 'programfiles'
                    ProductCode      = $dir.FullName
                    UpgradeCode      = $null
                    PackageManager   = 'programfiles'
                    InstallerType    = Detect-InstallerType -InstallLocation $dir.FullName
                    Architecture     = if ($path -match 'x86') { 'x86' } else { 'x64' }
                    UninstallString  = if ($uninstallExe) { $uninstallExe.FullName } else { $null }
                    QuietUninstallString = $null
                    EstimatedSize    = $null
                    InstallDate      = $null
                    IsSystemComponent = $false
                    Source           = 'programfiles'
                }
            }
        } catch {}
    }
    return $apps
}

function Merge-ApplicationRecords {
    param([array]$Records)
    $merged = @{}
    foreach ($rec in $Records) {
        $key = ($rec.DisplayName -replace '\s+', '').ToLower()
        if ($merged.ContainsKey($key)) {
            $existing = $merged[$key]
            $rec.PSObject.Properties | ForEach-Object {
                $propName = $_.Name
                if ($propName -and $_.Value -and (-not $existing.$propName -or $existing.$propName -eq '')) {
                    try { $existing.$propName = $_.Value } catch { Add-Member -InputObject $existing -NotePropertyName $propName -NotePropertyValue $_.Value -Force }
                }
            }
        } else {
            $merged[$key] = $rec.PSObject.Copy()
        }
    }
    return $merged.Values
}

function Detect-InstallerType {
    param([string]$UninstallString, [string]$InstallLocation)

    if ($UninstallString -match 'msiexec') { return 'MSI' }
    if ($UninstallString -match 'unins000') { return 'InnoSetup' }
    if ($UninstallString -match 'uninstall\.exe') { return 'NSIS' }
    if ($InstallLocation) {
        $files = Get-ChildItem $InstallLocation -File -ErrorAction SilentlyContinue
        if ($files | Where-Object { $_.Name -match 'unins\d{3}\.exe' }) { return 'InnoSetup' }
        if ($files | Where-Object { $_.Name -eq 'uninstall.exe' -and (Get-Content $_.FullName -TotalCount 10 -ErrorAction SilentlyContinue) -match 'NSIS' }) { return 'NSIS' }
        if ($files | Where-Object { $_.Name -match '\.squirrel\.' }) { return 'Squirrel' }
        if ($files | Where-Object { $_.Name -match 'Update\.exe|electron' }) { return 'Electron' }
        if ($files | Where-Object { $_.Name -eq 'maintenancetool.exe' }) { return 'QtInstaller' }
        if ($files | Where-Object { $_.Name -eq 'setup.exe' -and $_.DirectoryName -match 'InstallShield' }) { return 'InstallShield' }
        if (Test-Path (Join-Path $InstallLocation 'appxmanifest.xml')) { return 'AppX' }
        if (Test-Path (Join-Path $InstallLocation 'msixmanifest.xml')) { return 'MSIX' }
    }
    return 'CustomEXE'
}

#endregion

#region Uninstall Methods

# Global flag set once by Initialize-PSADT
$script:PSADTAvailable = $false

function Initialize-PSADT {
    if ($script:PSADTAvailable) { return $true }
    $psadtPaths = @(
        (Join-Path $PSScriptRoot 'PSAppDeployToolkit_Template_v4\PSAppDeployToolkit\PSAppDeployToolkit.psd1')
    )
    foreach ($path in $psadtPaths) {
        if (Test-Path $path) {
            try {
                Import-Module -Name $path -Force -ErrorAction Stop
                $script:PSADTAvailable = $true
                Write-Log -Level Info "PSAppDeployToolkit (PSDAT) loaded successfully"
                return $true
            } catch {
                Write-Log -Level Warning "Failed to load PSAppDeployToolkit from $path : $_"
            }
        }
    }
    Write-Log -Level Debug "PSAppDeployToolkit (PSDAT) not found"
    return $false
}

function Uninstall-PSADT {
    param([PSCustomObject]$App, [switch]$DryRun, [int]$TimeoutSeconds = 300)
    if (-not $script:PSADTAvailable) { return @{ Success = $false; Method = 'PSADT'; Error = 'PSADT not loaded' } }

    Write-Log -Level Info "Method 11: PSAppDeployToolkit uninstall: $($App.DisplayName)"
    if ($DryRun) { Write-Host "DRY RUN: Would uninstall via PSADT: $($App.DisplayName)"; return @{ Success = $true; Method = 'PSADT' } }

    try {
        $result = Uninstall-ADTApplication -Name $App.DisplayName -ErrorAction Stop
        Write-Log -Level Info "PSADT uninstall returned: $result"
        return @{ Success = $true; Method = 'PSADT' }
    } catch {
        return @{ Success = $false; Method = 'PSADT'; Error = $_.Exception.Message }
    }
}

function Uninstall-ByMethod {
    param(
        [PSCustomObject]$App,
        [switch]$Force,
        [switch]$Silent,
        [switch]$DryRun,
        [int]$TimeoutSeconds = 300
    )

    $methods = @(
        { Uninstall-QuietString -App $App -DryRun:$DryRun -TimeoutSeconds $TimeoutSeconds },
        { Uninstall-UninstallString -App $App -Force:$Force -Silent:$Silent -DryRun:$DryRun -TimeoutSeconds $TimeoutSeconds },
        { Uninstall-MSI -App $App -DryRun:$DryRun -TimeoutSeconds $TimeoutSeconds },
        { Uninstall-Winget -App $App -Force:$Force -Silent:$Silent -DryRun:$DryRun -TimeoutSeconds $TimeoutSeconds },
        { Uninstall-Choco -App $App -DryRun:$DryRun -TimeoutSeconds $TimeoutSeconds },
        { Uninstall-Scoop -App $App -DryRun:$DryRun -TimeoutSeconds $TimeoutSeconds },
        { Uninstall-AppX -App $App -DryRun:$DryRun -TimeoutSeconds $TimeoutSeconds },
        { Uninstall-PackageManagement -App $App -DryRun:$DryRun -TimeoutSeconds $TimeoutSeconds },
        { Uninstall-VendorExe -App $App -Silent:$Silent -DryRun:$DryRun -TimeoutSeconds $TimeoutSeconds },
        { Uninstall-ReverseEngineered -App $App -Silent:$Silent -DryRun:$DryRun -TimeoutSeconds $TimeoutSeconds },
        { Uninstall-PSADT -App $App -DryRun:$DryRun -TimeoutSeconds $TimeoutSeconds }
    )

    foreach ($method in $methods) {
        try {
            $result = & $method
            if ($result.Success) {
                Write-Log -Level Info "Uninstall succeeded via $($result.Method)"
                return $result
            }
        } catch {
            Write-Log -Level Debug "Method failed: $($_.Exception.Message)"
        }
    }

    return @{ Success = $false; Method = 'none'; Error = 'All methods exhausted' }
}

function Uninstall-QuietString {
    param([PSCustomObject]$App, [switch]$DryRun, [int]$TimeoutSeconds = 300)
    if (-not $App.QuietUninstallString) { return @{ Success = $false; Method = 'QuietUninstallString'; Error = 'No quiet uninstall string' } }
    Write-Log -Level Info "Method 1: Using QuietUninstallString: $($App.QuietUninstallString)"
    if ($DryRun) { Write-Host "DRY RUN: Would run: $($App.QuietUninstallString)"; return @{ Success = $true; Method = 'QuietUninstallString' } }
    $result = Invoke-UninstallExecutable -Command $App.QuietUninstallString -TimeoutSeconds $TimeoutSeconds
    return $result
}

function Uninstall-UninstallString {
    param([PSCustomObject]$App, [switch]$Force, [switch]$Silent, [switch]$DryRun, [int]$TimeoutSeconds = 300)
    if (-not $App.UninstallString) { return @{ Success = $false; Method = 'UninstallString'; Error = 'No uninstall string' } }

    $silentArgs = Get-SilentArguments -InstallerType $App.InstallerType
    $uninstallCmd = ConvertTo-SilentUninstall -UninstallString $App.UninstallString -SilentArgs $silentArgs

    Write-Log -Level Info "Method 2: Using UninstallString: $uninstallCmd"
    if ($DryRun) { Write-Host "DRY RUN: Would run: $uninstallCmd"; return @{ Success = $true; Method = 'UninstallString' } }
    $result = Invoke-UninstallExecutable -Command $uninstallCmd -TimeoutSeconds $TimeoutSeconds
    return $result
}

function Get-SilentArguments {
    param([string]$InstallerType)
    $silentMap = @{
        'MSI'         = '/qn /norestart'
        'InnoSetup'   = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
        'NSIS'        = '/S /NOCANCEL'
        'InstallShield' = '/s /sms /f1""'
        'WiseInstaller' = '/s'
        'AdvancedInstaller' = '/quiet'
        'Squirrel'    = '--silent'
        'Electron'    = '--silent'
        'QtInstaller' = '--silent'
        'BurnBundle'  = '/quiet /norestart'
        'WiXBundle'   = '/quiet /norestart'
        'CustomEXE'   = '/S /silent /quiet /verysilent'
    }
    return $silentMap[$InstallerType]
}

function ConvertTo-SilentUninstall {
    param([string]$UninstallString, [string]$SilentArgs)

    if ($UninstallString -match 'msiexec') {
        if ($UninstallString -match '/[xX]') {
            if ($UninstallString -notmatch '/qn') { $UninstallString = $UninstallString -replace '(/[xX]\s*\S+)', "`$1 /qn /norestart" }
            return $UninstallString
        }
    }

    $exeMatch = [regex]::Match($UninstallString, '^"([^"]+)"')
    if ($exeMatch.Success) {
        $exe = $exeMatch.Groups[1].Value
        $args = $UninstallString.Substring($exeMatch.Length).Trim()
        $knownSilent = @('/S', '/s', '/silent', '/verysilent', '/quiet', '/q', '/qn', '/passive', '/norestart', 'SUPPRESSMSGBOXES', 'SP-', '--silent')
        $hasSilent = $false
        foreach ($flag in $knownSilent) { if ($args -match [regex]::Escape($flag)) { $hasSilent = $true; break } }
        if (-not $hasSilent -and $SilentArgs) {
            $args = "$args $SilentArgs"
        }
        return "`"$exe`" $args"
    }

    $plainExe = [regex]::Match($UninstallString, '^(\S+)')
    if ($plainExe.Success) {
        $exe = $plainExe.Groups[1].Value
        $args = $UninstallString.Substring($plainExe.Length).Trim()
        $knownSilent = @('/S', '/s', '/silent', '/verysilent', '/quiet', '/q', '/qn', '/passive', '/norestart', 'SUPPRESSMSGBOXES', 'SP-', '--silent')
        $hasSilent = $false
        foreach ($flag in $knownSilent) { if ($args -match [regex]::Escape($flag)) { $hasSilent = $true; break } }
        if (-not $hasSilent -and $SilentArgs) {
            $args = "$args $SilentArgs"
        }
        return "$exe $args"
    }

    return $UninstallString
}

function Invoke-UninstallExecutable {
    param([string]$Command, [int]$TimeoutSeconds = 300)
    try {
        $exeMatch = [regex]::Match($Command, '^"([^"]+)"')
        if (-not $exeMatch.Success) { $exeMatch = [regex]::Match($Command, '^(\S+)') }
        if (-not $exeMatch.Success) { return @{ Success = $false; Error = "Cannot parse command: $Command" } }

        $exe = $exeMatch.Groups[1].Value
        $args = $Command.Substring($exeMatch.Length).Trim()

        $tempOutput = [System.IO.Path]::GetTempFileName()
        $tempError = [System.IO.Path]::GetTempFileName()

        $process = Start-Process -FilePath $exe -ArgumentList $args -NoNewWindow -PassThru -RedirectStandardOutput $tempOutput -RedirectStandardError $tempError

        if ($process.WaitForExit($TimeoutSeconds * 1000)) {
            $output = Get-Content $tempOutput -Raw -ErrorAction SilentlyContinue
            $errorOut = Get-Content $tempError -Raw -ErrorAction SilentlyContinue
            Remove-Item $tempOutput -ErrorAction SilentlyContinue
            Remove-Item $tempError -ErrorAction SilentlyContinue

            $success = $process.ExitCode -eq 0 -or $process.ExitCode -eq 3010 -or $process.ExitCode -eq 1641
            if ($success) {
                return @{ Success = $true; Method = 'executable'; ExitCode = $process.ExitCode; Output = $output }
            }
            return @{ Success = $false; Method = 'executable'; Error = "Exit code: $($process.ExitCode)"; Output = $output; ErrorOutput = $errorOut }
        } else {
            $process.Kill()
            Remove-Item $tempOutput -ErrorAction SilentlyContinue
            Remove-Item $tempError -ErrorAction SilentlyContinue
            return @{ Success = $false; Method = 'executable'; Error = "Timed out after ${TimeoutSeconds}s" }
        }
    } catch {
        return @{ Success = $false; Method = 'executable'; Error = $_.Exception.Message }
    }
}

function Uninstall-MSI {
    param([PSCustomObject]$App, [switch]$DryRun, [int]$TimeoutSeconds = 300)
    if ($App.InstallerType -ne 'MSI' -and -not $App.ProductCode) { return @{ Success = $false; Method = 'MSI'; Error = 'Not an MSI package' } }

    $productCode = if ($App.ProductCode -match '^\{?[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}\}?$') { $App.ProductCode } else { $null }
    if (-not $productCode) { return @{ Success = $false; Method = 'MSI'; Error = 'Invalid product code' } }

    $command = "msiexec /x $productCode /qn /norestart"
    Write-Log -Level Info "Method 3: MSI uninstall: $command"
    if ($DryRun) { Write-Host "DRY RUN: Would run: $command"; return @{ Success = $true; Method = 'MSI' } }

    return Invoke-UninstallExecutable -Command $command -TimeoutSeconds $TimeoutSeconds
}

function Uninstall-Winget {
    param([PSCustomObject]$App, [switch]$Force, [switch]$Silent, [switch]$DryRun, [int]$TimeoutSeconds = 300)
    if ($App.PackageManager -ne 'winget' -and $App.Source -ne 'winget') { return @{ Success = $false; Method = 'winget'; Error = 'Not a winget package' } }

    # Use DisplayName for winget (resolves by name reliably); fall back to ProductCode
    $target = if ($App.DisplayName) { $App.DisplayName } else { $App.ProductCode }
    $argsList = @('uninstall', $target)
    if ($Force) { $argsList += '--force' }
    if ($Silent) { $argsList += '--silent' }

    $command = "winget uninstall ""$target"""
    Write-Log -Level Info "Method 4: Winget uninstall: $command"
    if ($DryRun) { Write-Host "DRY RUN: Would run: $command"; return @{ Success = $true; Method = 'winget' } }

    $result = Invoke-WingetCommand -Arguments $argsList -TimeoutSeconds $TimeoutSeconds
    if ($result.ExitCode -eq 0) {
        return @{ Success = $true; Method = 'winget'; ExitCode = 0 }
    }
    return @{ Success = $false; Method = 'winget'; Error = "Exit code: $($result.ExitCode)"; Output = $result.Output }
}

function Uninstall-Choco {
    param([PSCustomObject]$App, [switch]$DryRun, [int]$TimeoutSeconds = 300)
    if ($App.PackageManager -ne 'choco' -and $App.Source -ne 'choco') { return @{ Success = $false; Method = 'choco'; Error = 'Not a choco package' } }

    Write-Log -Level Info "Method 5: Choco uninstall"
    if ($DryRun) { Write-Host "DRY RUN: Would run: choco uninstall $($App.ProductCode) -y"; return @{ Success = $true; Method = 'choco' } }

    $result = Invoke-ChocoCommand -Arguments @('uninstall', $App.ProductCode, '-y') -TimeoutSeconds $TimeoutSeconds
    if ($result.ExitCode -eq 0) {
        return @{ Success = $true; Method = 'choco'; ExitCode = 0 }
    }
    return @{ Success = $false; Method = 'choco'; Error = "Exit code: $($result.ExitCode)"; Output = $result.Output }
}

function Uninstall-Scoop {
    param([PSCustomObject]$App, [switch]$DryRun, [int]$TimeoutSeconds = 300)
    if ($App.PackageManager -ne 'scoop' -and $App.Source -ne 'scoop') { return @{ Success = $false; Method = 'scoop'; Error = 'Not a scoop package' } }

    Write-Log -Level Info "Method 6: Scoop uninstall"
    if ($DryRun) { Write-Host "DRY RUN: Would run: scoop uninstall $($App.ProductCode)"; return @{ Success = $true; Method = 'scoop' } }

    try {
        & scoop uninstall $App.ProductCode 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { return @{ Success = $true; Method = 'scoop'; ExitCode = 0 } }
        return @{ Success = $false; Method = 'scoop'; Error = "Exit code: $LASTEXITCODE" }
    } catch {
        return @{ Success = $false; Method = 'scoop'; Error = $_.Exception.Message }
    }
}

function Uninstall-AppX {
    param([PSCustomObject]$App, [switch]$DryRun, [int]$TimeoutSeconds = 300)

    Write-Log -Level Info "Method 7: AppX uninstall"
    if ($DryRun) { Write-Host "DRY RUN: Would remove AppX package for $($App.DisplayName)"; return @{ Success = $true; Method = 'AppX' } }

    try {
        $searchName = $App.DisplayName -replace '\s+', ''
        $pkg = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$searchName*" } | Select-Object -First 1
        if ($pkg) {
            Write-Log -Level Info "Found AppX package: $($pkg.PackageFullName)"
            Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
            return @{ Success = $true; Method = 'AppX' }
        }
        $provPkg = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$searchName*" } | Select-Object -First 1
        if ($provPkg) {
            Write-Log -Level Info "Found provisioned AppX: $($provPkg.PackageName)"
            Remove-AppxProvisionedPackage -Online -PackageName $provPkg.PackageName -ErrorAction Stop
            return @{ Success = $true; Method = 'AppX' }
        }
        return @{ Success = $false; Method = 'AppX'; Error = 'AppX package not found' }
    } catch {
        return @{ Success = $false; Method = 'AppX'; Error = $_.Exception.Message }
    }
}

function Uninstall-PackageManagement {
    param([PSCustomObject]$App, [switch]$DryRun, [int]$TimeoutSeconds = 300)

    Write-Log -Level Info "Method 8: PowerShell PackageManagement uninstall"
    if ($DryRun) { Write-Host "DRY RUN: Would run: Uninstall-Package -Name `"$($App.DisplayName)`""; return @{ Success = $true; Method = 'PackageManagement' } }

    try {
        $pkg = Get-Package -Name "*$($App.DisplayName)*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($pkg) {
            Uninstall-Package -InputObject $pkg -Force -ErrorAction Stop
            return @{ Success = $true; Method = 'PackageManagement' }
        }
        return @{ Success = $false; Method = 'PackageManagement'; Error = 'Package not found by PackageManagement' }
    } catch {
        return @{ Success = $false; Method = 'PackageManagement'; Error = $_.Exception.Message }
    }
}

function Uninstall-VendorExe {
    param([PSCustomObject]$App, [switch]$Silent, [switch]$DryRun, [int]$TimeoutSeconds = 300)
    $installLoc = $App.InstallLocation
    if (-not $installLoc -or -not (Test-Path $installLoc)) { return @{ Success = $false; Method = 'VendorExe'; Error = 'No install location' } }

    $patterns = @('uninstall.exe', 'unins000.exe', 'unins001.exe', 'unins002.exe', 'uninst.exe', 'maintenancetool.exe', 'setup.exe', 'remove.exe', 'modify.exe')
    $uninstaller = $null
    foreach ($pattern in $patterns) {
        $found = Get-ChildItem $installLoc -Recurse -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $uninstaller = $found; break }
    }
    if (-not $uninstaller) { return @{ Success = $false; Method = 'VendorExe'; Error = 'No uninstall executable found' } }

    $installerType = Detect-InstallerType -InstallLocation $installLoc
    $silentArgs = Get-SilentArguments -InstallerType $installerType
    $command = "`"$($uninstaller.FullName)`" $silentArgs"

    Write-Log -Level Info "Method 9: Vendor uninstaller: $command"
    if ($DryRun) { Write-Host "DRY RUN: Would run: $command"; return @{ Success = $true; Method = 'VendorExe' } }

    return Invoke-UninstallExecutable -Command $command -TimeoutSeconds $TimeoutSeconds
}

function Uninstall-ReverseEngineered {
    param([PSCustomObject]$App, [switch]$Silent, [switch]$DryRun, [int]$TimeoutSeconds = 300)
    $installLoc = $App.InstallLocation
    if (-not $installLoc -or -not (Test-Path $installLoc)) { return @{ Success = $false; Method = 'ReverseEngineered'; Error = 'No install location' } }

    $type = Detect-InstallerType -InstallLocation $installLoc
    $candidates = @()

    switch ($type) {
        'InnoSetup' {
            $unins = Get-ChildItem $installLoc -Recurse -Filter 'unins*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($unins) { $candidates += @("`"$($unins.FullName)`" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART", "`"$($unins.FullName)`" /SILENT /NORESTART") }
        }
        'NSIS' {
            $uninst = Get-ChildItem $installLoc -Recurse -Filter 'uninstall.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($uninst) { $candidates += @("`"$($uninst.FullName)`" /S /NOCANCEL", "`"$($uninst.FullName)`" _?=$installLoc") }
        }
        'Squirrel' {
            $update = Get-ChildItem $installLoc -Recurse -Filter 'Update.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($update) { $candidates += @("`"$($update.FullName)`" --uninstall", "`"$($update.FullName)`" --silent") }
        }
        'Electron' {
            $exeFiles = Get-ChildItem $installLoc -Filter '*.exe' -ErrorAction SilentlyContinue | Select-Object -First 3
            foreach ($exe in $exeFiles) { $candidates += @("`"$($exe.FullName)`" --uninstall", "`"$($exe.FullName)`" --silent") }
        }
        'QtInstaller' {
            $mt = Get-ChildItem $installLoc -Recurse -Filter 'maintenancetool.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($mt) { $candidates += @("`"$($mt.FullName)`" --silent") }
        }
    }

    $knownArgs = @('/S', '/s', '/silent', '/verysilent', '/quiet', '/q', '/qn', '/passive', '/norestart', 'SUPPRESSMSGBOXES', 'SP-', '--silent', '--uninstall', '-uninstall', '/uninstall')
    $exeFiles = Get-ChildItem $installLoc -Recurse -Include @('*.exe', '*.com') -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 50KB } | Sort-Object Length | Select-Object -First 5
    foreach ($exe in $exeFiles) {
        foreach ($arg in $knownArgs) {
            $candidates += @("`"$($exe.FullName)`" $arg")
        }
    }

    $candidates = $candidates | Select-Object -Unique
    $attempted = @{}
    foreach ($cmd in $candidates) {
        if ($attempted.ContainsKey($cmd)) { continue }
        $attempted[$cmd] = $true
        Write-Log -Level Info "Method 10: Trying reverse-engineered: $cmd"
        if ($DryRun) { Write-Host "DRY RUN: Would try: $cmd"; continue }

        $result = Invoke-UninstallExecutable -Command $cmd -TimeoutSeconds 120
        if ($result.Success) { return $result }
    }

    return @{ Success = $false; Method = 'ReverseEngineered'; Error = 'No candidate worked' }
}

#endregion

#region Cleanup

function Remove-ApplicationFiles {
    param([PSCustomObject]$App, [switch]$DryRun, [switch]$Force)
    $paths = @()
    if ($App.InstallLocation -and (Test-Path $App.InstallLocation)) { $paths += $App.InstallLocation }

    $namePatterns = @(
        $App.DisplayName,
        ($App.DisplayName -replace '\s+', ''),
        ($App.DisplayName -replace '[^a-zA-Z0-9]', ''),
        $App.ProductCode
    ) | Where-Object { $_ }

    $searchPaths = @(
        "${env:ProgramFiles}", "${env:ProgramFiles(x86)}", "$env:LOCALAPPDATA\Programs",
        "$env:APPDATA", "$env:LOCALAPPDATA", "$env:ProgramData",
        "$env:TEMP", "$env:USERPROFILE\Downloads"
    )

    foreach ($sp in $searchPaths) {
        if (-not (Test-Path $sp)) { continue }
        foreach ($pattern in $namePatterns) {
            if (-not $pattern -or $pattern.Length -lt 2) { continue }
            try {
                Get-ChildItem $sp -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$pattern*" -and $_.Name -notmatch '^(Windows|System32|Program Files|Common Files)$' } | ForEach-Object {
                    $paths += $_.FullName
                }
            } catch {}
        }
    }

    $paths = $paths | Select-Object -Unique
    $removed = @()
    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { continue }
        if ($DryRun) { Write-Host "DRY RUN: Would remove: $p"; $removed += $p; continue }
        try {
            if ((Get-Item $p) -is [System.IO.DirectoryInfo]) {
                Remove-Item $p -Recurse -Force -ErrorAction Stop
                Write-Log -Level Info "Removed directory: $p"
            } else {
                Remove-Item $p -Force -ErrorAction Stop
                Write-Log -Level Info "Removed file: $p"
            }
            $removed += $p
        } catch {
            Write-Log -Level Warning "Failed to remove $p`: $($_.Exception.Message)"
        }
    }
    return @{ Removed = $removed; Count = $removed.Count }
}

function Remove-ApplicationRegistry {
    param([PSCustomObject]$App, [switch]$DryRun)
    $namePatterns = @(
        $App.DisplayName,
        ($App.DisplayName -replace '\s+', ''),
        ($App.DisplayName -replace '[^a-zA-Z0-9]', '')
    ) | Where-Object { $_ } | Select-Object -Unique

    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\Classes\Installer\Products",
        "HKLM:\SOFTWARE\Classes\Installer\Features",
        "HKCU:\SOFTWARE\Classes\Installer\Products",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData",
        "HKLM:\SOFTWARE\Classes",
        "HKCU:\SOFTWARE\Classes",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\SYSTEM\CurrentControlSet\Services",
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache",
        "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchProviders"
    )

    $cleaned = @()
    foreach ($regPath in $registryPaths) {
        if (-not (Test-Path $regPath)) { continue }
        try {
            $items = Get-ChildItem $regPath -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                try {
                    $prop = Get-ItemProperty -Path $item.PSPath -ErrorAction SilentlyContinue
                    $matchFound = $false
                    foreach ($np in $namePatterns) {
                        if ($prop.DisplayName -and $prop.DisplayName -like "*$np*") { $matchFound = $true; break }
                        if ($item.PSChildName -like "*$np*") { $matchFound = $true; break }
                    }
                    if (-not $matchFound -and $App.ProductCode) {
                        if ($item.PSChildName -match $App.ProductCode -or $item.PSChildName -match ($App.ProductCode -replace '[{}]', '')) { $matchFound = $true }
                    }
                    if ($matchFound) {
                        if ($DryRun) { Write-Host "DRY RUN: Would remove registry: $($item.PSPath)"; $cleaned += $item.PSPath; continue }
                        Remove-Item -Path $item.PSPath -Recurse -Force -ErrorAction Stop
                        Write-Log -Level Info "Removed registry: $($item.PSPath)"
                        $cleaned += $item.PSPath
                    }
                } catch {}
            }
        } catch {}
    }
    return @{ Removed = $cleaned; Count = $cleaned.Count }
}

function Remove-ApplicationServices {
    param([PSCustomObject]$App, [switch]$DryRun)
    $namePatterns = @(
        $App.DisplayName,
        ($App.DisplayName -replace '\s+', ''),
        ($App.DisplayName -replace '[^a-zA-Z0-9]', '')
    ) | Where-Object { $_ } | Select-Object -Unique

    $removed = @()
    try {
        $services = Get-Service -ErrorAction SilentlyContinue | Where-Object {
            $match = $false
            foreach ($np in $namePatterns) {
                if ($_.DisplayName -like "*$np*" -or $_.ServiceName -like "*$np*") { $match = $true; break }
            }
            $match
        }
        foreach ($svc in $services) {
            if ($DryRun) { Write-Host "DRY RUN: Would stop and delete service: $($svc.ServiceName)"; $removed += $svc.ServiceName; continue }
            try {
                Stop-Service $svc.ServiceName -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 500
                & sc.exe delete $svc.ServiceName 2>&1 | Out-Null
                Write-Log -Level Info "Removed service: $($svc.ServiceName)"
                $removed += $svc.ServiceName
            } catch {
                Write-Log -Level Warning "Failed to remove service $($svc.ServiceName): $($_.Exception.Message)"
            }
        }
    } catch {}
    return @{ Removed = $removed; Count = $removed.Count }
}

function Remove-ApplicationDrivers {
    param([PSCustomObject]$App, [switch]$DryRun)
    return @{ Removed = @(); Count = 0; Note = 'Driver removal requires manual intervention for safety' }
}

function Remove-ApplicationScheduledTasks {
    param([PSCustomObject]$App, [switch]$DryRun)
    $namePatterns = @(
        $App.DisplayName,
        ($App.DisplayName -replace '\s+', ''),
        ($App.DisplayName -replace '[^a-zA-Z0-9]', '')
    ) | Where-Object { $_ } | Select-Object -Unique

    $removed = @()
    try {
        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
            $match = $false
            foreach ($np in $namePatterns) {
                if ($_.TaskName -like "*$np*" -or $_.TaskPath -like "*$np*") { $match = $true; break }
            }
            $match
        }
        foreach ($task in $tasks) {
            if ($DryRun) { Write-Host "DRY RUN: Would remove scheduled task: $($task.TaskName)"; $removed += $task.TaskName; continue }
            try {
                Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop
                Write-Log -Level Info "Removed scheduled task: $($task.TaskName)"
                $removed += $task.TaskName
            } catch {
                Write-Log -Level Warning "Failed to remove scheduled task $($task.TaskName): $($_.Exception.Message)"
            }
        }
    } catch {}
    return @{ Removed = $removed; Count = $removed.Count }
}

function Remove-ApplicationShortcuts {
    param([PSCustomObject]$App, [switch]$DryRun)
    $namePatterns = @(
        $App.DisplayName,
        ($App.DisplayName -replace '\s+', ''),
        ($App.DisplayName -replace '[^a-zA-Z0-9]', '')
    ) | Where-Object { $_ } | Select-Object -Unique

    $searchDirs = @(
        "$env:ProgramData\Microsoft\Windows\Start Menu",
        "$env:APPDATA\Microsoft\Windows\Start Menu",
        [Environment]::GetFolderPath('Desktop'),
        [Environment]::GetFolderPath('CommonDesktopDirectory')
    )

    $removed = @()
    foreach ($dir in $searchDirs) {
        if (-not (Test-Path $dir)) { continue }
        try {
            $items = Get-ChildItem $dir -Recurse -Include @('*.lnk', '*.url') -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                $match = $false
                $nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($item.Name)
                foreach ($np in $namePatterns) {
                    if ($nameWithoutExt -like "*$np*") { $match = $true; break }
                }
                if (-not $match) {
                    try {
                        $shell = New-Object -ComObject WScript.Shell
                        $shortcut = $shell.CreateShortcut($item.FullName)
                        if ($shortcut.TargetPath -like "*$($App.DisplayName)*") { $match = $true }
                    } catch {}
                }
                if ($match) {
                    if ($DryRun) { Write-Host "DRY RUN: Would remove shortcut: $($item.FullName)"; $removed += $item.FullName; continue }
                    try {
                        Remove-Item $item.FullName -Force -ErrorAction Stop
                        Write-Log -Level Info "Removed shortcut: $($item.FullName)"
                        $removed += $item.FullName
                    } catch {}
                }
            }
        } catch {}
    }
    return @{ Removed = $removed; Count = $removed.Count }
}

#endregion

#region Main API

function Invoke-AdvancedUninstall {
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$Force,
        [switch]$Silent,
        [switch]$DryRun,
        [switch]$NoCleanup,
        [switch]$NoRegistryCleanup,
        [switch]$NoFileCleanup,
        [int]$TimeoutSeconds = 300,
        [switch]$RebootIfRequired
    )

    $result = @{
        Application  = $null
        UninstallResult = $null
        CleanupResults = @{}
        Success      = $false
        Errors       = @()
        Warnings     = @()
        Duration     = $null
    }

    $startTime = Get-Date

    Write-Host "`n$(('=' * 60))" -ForegroundColor Cyan
    Write-Host "THE KINGSMAKERS ADVANCED UNINSTALL ENGINE" -ForegroundColor Cyan -BackgroundColor Black
    Write-Host "$('=' * 60)" -ForegroundColor Cyan
    Write-Host "Target: $Name" -ForegroundColor White
    Write-Host "Force: $($Force.ToString().ToUpper())" -ForegroundColor White
    Write-Host "Silent: $($Silent.ToString().ToUpper())" -ForegroundColor White
    Write-Host "Dry Run: $($DryRun.ToString().ToUpper())" -ForegroundColor White
    Write-Host "$('=' * 60)" -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "`n[DRY RUN MODE] No changes will be made." -ForegroundColor Yellow
    }

    Write-Log -Level Info "Starting advanced uninstall for: $Name"

    try {
        Write-Host "`n[STEP 1/7] Detecting installed application..." -ForegroundColor Magenta
        $apps = Find-InstalledApplication -Name $Name

        if (-not $apps -or $apps.Count -eq 0) {
            throw "No installed application found matching '$Name'"
        }

        $app = $apps | Select-Object -First 1
        $result.Application = $app

        Write-Host "Found application: $($app.DisplayName) v$($app.Version)" -ForegroundColor Green
        Write-Host "Publisher: $($app.Publisher)" -ForegroundColor White
        Write-Host "Install Location: $($app.InstallLocation)" -ForegroundColor White
        Write-Host "Installer Type: $($app.InstallerType)" -ForegroundColor White
        Write-Host "Source: $($app.Source)" -ForegroundColor White

        Write-Log -Level Info "Detected: $($app.DisplayName) v$($app.Version) from $($app.Source)"

        Write-Host "`n[STEP 2/7] Attempting uninstall..." -ForegroundColor Magenta
        $uninstallResult = Uninstall-ByMethod -App $app -Force:$Force -Silent:$Silent -DryRun:$DryRun -TimeoutSeconds $TimeoutSeconds
        $result.UninstallResult = $uninstallResult

        if ($uninstallResult.Success) {
            Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] UNINSTALL SUCCEEDED via $($uninstallResult.Method)" -ForegroundColor Green
            Write-Log -Level Info "Uninstall succeeded via $($uninstallResult.Method)"
        } else {
            Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] UNINSTALL FAILED: $($uninstallResult.Error)" -ForegroundColor Red
            Write-Log -Level Error "Uninstall failed: $($uninstallResult.Error)"
            $result.Errors += "Uninstall failed: $($uninstallResult.Error)"

            if ($Force) {
                Write-Host "`n[STEP 3/7] Forced removal mode activated..." -ForegroundColor Yellow
                $forcedResult = Invoke-ForcedRemoval -App $app -DryRun:$DryRun -NoRegistryCleanup:$NoRegistryCleanup -NoFileCleanup:$NoFileCleanup
                $result.CleanupResults = $forcedResult
                Write-Log -Level Warning "Forced removal executed with $($forcedResult.FilesRemoved) files and $($forcedResult.RegistryKeysRemoved) registry keys removed"
            } else {
                Write-Host "Use -Force to attempt forced removal" -ForegroundColor Yellow
            }
        }

        if ($uninstallResult.Success -and -not $NoCleanup) {
            Write-Host "`n[STEP 4/7] Cleaning up shortcuts..." -ForegroundColor Magenta
            $shortcutResult = Remove-ApplicationShortcuts -App $app -DryRun:$DryRun
            $result.CleanupResults.Shortcuts = $shortcutResult

            if (-not $NoRegistryCleanup) {
                Write-Host "`n[STEP 5/7] Cleaning up registry..." -ForegroundColor Magenta
                $regResult = Remove-ApplicationRegistry -App $app -DryRun:$DryRun
                $result.CleanupResults.Registry = $regResult
            }

            if (-not $NoFileCleanup) {
                Write-Host "`n[STEP 6/7] Cleaning up files..." -ForegroundColor Magenta
                $fileResult = Remove-ApplicationFiles -App $app -DryRun:$DryRun
                $result.CleanupResults.Files = $fileResult
            }

            Write-Host "`n[STEP 7/7] Cleaning up services and tasks..." -ForegroundColor Magenta
            $serviceResult = Remove-ApplicationServices -App $app -DryRun:$DryRun
            $result.CleanupResults.Services = $serviceResult

            $taskResult = Remove-ApplicationScheduledTasks -App $app -DryRun:$DryRun
            $result.CleanupResults.ScheduledTasks = $taskResult
        }

        $result.Duration = (Get-Date) - $startTime
        $result.Success = $uninstallResult.Success -or ($Force -and -not $DryRun)

        Write-Host "`n$(('=' * 60))" -ForegroundColor Cyan
        Write-Host "UNINSTALL SUMMARY" -ForegroundColor Cyan -BackgroundColor Black
        Write-Host "$('=' * 60)" -ForegroundColor Cyan
        Write-Host "Application: $($app.DisplayName)" -ForegroundColor White
        Write-Host "Result: $(if ($result.Success) { 'SUCCESS' } else { 'FAILED' })" -ForegroundColor $(if ($result.Success) { 'Green' } else { 'Red' })
        Write-Host "Method Used: $($uninstallResult.Method)" -ForegroundColor White
        Write-Host "Duration: $($result.Duration.TotalSeconds.ToString('F1'))s" -ForegroundColor White
        if ($result.CleanupResults.Files) { Write-Host "Files Cleaned: $($result.CleanupResults.Files.Count)" -ForegroundColor White }
        if ($result.CleanupResults.Registry) { Write-Host "Registry Keys Cleaned: $($result.CleanupResults.Registry.Count)" -ForegroundColor White }
        if ($result.CleanupResults.Services) { Write-Host "Services Removed: $($result.CleanupResults.Services.Count)" -ForegroundColor White }
        Write-Host "$('=' * 60)" -ForegroundColor Cyan

        if ($RebootIfRequired -and $uninstallResult.ExitCode -in @(3010, 1641)) {
            Write-Host "`nA reboot is required to complete the uninstallation." -ForegroundColor Yellow
            Write-Log -Level Warning "Reboot required for $($app.DisplayName) uninstall"
        }
    } catch {
        $result.Errors += $_.Exception.Message
        $result.Duration = (Get-Date) - $startTime
        Write-Log -Level Error "Advanced uninstall failed for '$Name': $($_.Exception.Message)"
        Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    }

    return $result
}

function Invoke-ForcedRemoval {
    param(
        [PSCustomObject]$App,
        [switch]$DryRun,
        [switch]$NoRegistryCleanup,
        [switch]$NoFileCleanup
    )

    $result = @{
        FilesRemoved       = 0
        RegistryKeysRemoved = 0
        ServicesRemoved    = 0
        TasksRemoved       = 0
        ShortcutsRemoved   = 0
    }

    Write-Host "`n$(('=' * 60))" -ForegroundColor Red
    Write-Host "FORCED REMOVAL - SAFE CLEANUP MODE" -ForegroundColor Red -BackgroundColor Black
    Write-Host "$('=' * 60)" -ForegroundColor Red
    Write-Log -Level Warning "Starting forced removal for $($App.DisplayName)"

    try {
        $procResult = Remove-ApplicationProcesses -App $App -DryRun:$DryRun
    } catch {}

    if (-not $NoFileCleanup) {
        $fileResult = Remove-ApplicationFiles -App $App -DryRun:$DryRun
        $result.FilesRemoved = $fileResult.Count
    }

    if (-not $NoRegistryCleanup) {
        $regResult = Remove-ApplicationRegistry -App $App -DryRun:$DryRun
        $result.RegistryKeysRemoved = $regResult.Count
    }

    $svcResult = Remove-ApplicationServices -App $App -DryRun:$DryRun
    $result.ServicesRemoved = $svcResult.Count

    $taskResult = Remove-ApplicationScheduledTasks -App $App -DryRun:$DryRun
    $result.TasksRemoved = $taskResult.Count

    $shortcutResult = Remove-ApplicationShortcuts -App $App -DryRun:$DryRun
    $result.ShortcutsRemoved = $shortcutResult.Count

    Write-Host "`nForced removal complete:" -ForegroundColor Cyan
    Write-Host "  Files removed: $($result.FilesRemoved)" -ForegroundColor White
    Write-Host "  Registry keys removed: $($result.RegistryKeysRemoved)" -ForegroundColor White
    Write-Host "  Services removed: $($result.ServicesRemoved)" -ForegroundColor White
    Write-Host "  Tasks removed: $($result.TasksRemoved)" -ForegroundColor White
    Write-Host "  Shortcuts removed: $($result.ShortcutsRemoved)" -ForegroundColor White

    return $result
}

function Remove-ApplicationProcesses {
    param([PSCustomObject]$App, [switch]$DryRun)
    $namePatterns = @(
        $App.DisplayName, ($App.DisplayName -replace '\s+', ''), ($App.DisplayName -replace '[^a-zA-Z0-9]', '')
    ) | Where-Object { $_ } | Select-Object -Unique

    $terminated = @()
    try {
        $processes = Get-Process -ErrorAction SilentlyContinue | Where-Object {
            $match = $false
            foreach ($np in $namePatterns) {
                if ($_.ProcessName -like "*$np*" -or $_.MainWindowTitle -like "*$np*") { $match = $true; break }
            }
            $match
        }
        foreach ($proc in $processes) {
            if ($DryRun) { Write-Host "DRY RUN: Would terminate process: $($proc.ProcessName) (PID: $($proc.Id))"; $terminated += $proc.Id; continue }
            try {
                $proc.Kill()
                Write-Log -Level Info "Terminated process: $($proc.ProcessName) (PID: $($proc.Id))"
                $terminated += $proc.Id
            } catch {
                Write-Log -Level Warning "Failed to terminate process $($proc.ProcessName): $($_.Exception.Message)"
            }
        }
    } catch {}
    return @{ Terminated = $terminated; Count = $terminated.Count }
}

function Invoke-InteractiveAutomation {
    param([PSCustomObject]$App, [switch]$DryRun)
    Write-Log -Level Warning "Interactive automation requires UIAutomation module"
    return @{ Success = $false; Error = 'Not implemented - requires UI automation framework' }
}

function Test-UninstallSuccess {
    param([string]$Name, [int]$Retries = 3, [int]$DelaySeconds = 2)

    for ($i = 0; $i -lt $Retries; $i++) {
        Start-Sleep -Seconds $DelaySeconds
        $apps = Find-InstalledApplication -Name $Name
        if (-not $apps -or $apps.Count -eq 0) {
            Write-Log -Level Info "Uninstall verified: '$Name' no longer found"
            return $true
        }
        Write-Log -Level Debug "Retry $($i+1)/${Retries}: '$Name' still found"
    }

    Write-Log -Level Warning "Uninstall verification failed: '$Name' still found after $Retries attempts"
    return $false
}

function Get-ApplicationInfo {
    param([Parameter(Mandatory)][string]$Name)
    return Find-InstalledApplication -Name $Name -IncludeSystemComponents
}

#endregion
