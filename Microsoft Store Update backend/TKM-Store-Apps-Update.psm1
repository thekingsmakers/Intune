<#
.SYNOPSIS
  TKM module: discovery and update helpers for Store apps.

.DESCRIPTION
  Exports helper functions used by the TKM-Store-Apps-Update entry script.
#>

function Write-TKMLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateSet('Info','Warning','Error','Debug')][string] $Level,
        [Parameter(Mandatory=$true)][string] $Message,
        [string] $LogPath,
        [switch] $Structured,
        [hashtable] $Payload
    )

    $timestamp = (Get-Date).ToString('o')
    $entry = @{ time = $timestamp; level = $Level; message = $Message }
    if ($Payload) { $entry.payload = $Payload }

    if ($Structured) { $line = $entry | ConvertTo-Json -Compress } else { $line = "$timestamp [$Level] $Message" }

    if ($LogPath) {
        $dir = Split-Path -Path $LogPath -Parent
        if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        Add-Content -Path $LogPath -Value $line -ErrorAction SilentlyContinue
    }

    switch ($Level) {
        'Error'   { Write-Error $Message }
        'Warning' { Write-Warning $Message }
        'Debug'   { Write-Debug $Message }
        default   { Write-Verbose $Message }
    }
}

function Test-TKMElevation {
    <# Returns $true if running elevated #>
    (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-TKMInstalledStoreApps {
    [CmdletBinding()]
    param([switch] $AllUsers)

    try {
        $installed = if ($AllUsers) { Get-AppxPackage -AllUsers -ErrorAction Stop } else { Get-AppxPackage -ErrorAction Stop }
    } catch {
        Write-TKMLog -Level Error -Message "Get-AppxPackage failed: $_" -Structured -Payload @{exception=$_.Exception.Message}
        return @()
    }

    foreach ($pkg in $installed) {
        [PSCustomObject]@{
            Name = $pkg.Name
            PackageFullName = $pkg.PackageFullName
            PackageFamilyName = $pkg.PackageFamilyName
            Version = ($pkg.Version).ToString()
            InstallLocation = $pkg.InstallLocation
            IsFramework = $pkg.IsFramework
            IsResourcePackage = $pkg.IsResourcePackage
            NonRemovable = $pkg.NonRemovable
            SignatureKind = $pkg.SignatureKind
            Publisher = $pkg.Publisher
        }
    }
}

function Get-TKMPackageUpdateCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string] $PackageFamilyName,
        [int] $TimeoutSeconds = 300,
        [int] $RetryCount = 3,
        [int] $RetryDelaySeconds = 10,
        [string] $LogPath
    )

    $result = @{ PackageFamilyName = $PackageFamilyName; UpdateAvailable = $false; Method = 'None'; Details = $null }
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) { return $result }

    for ($i=0; $i -lt $RetryCount; $i++) {
        try {
            $out = winget upgrade --id $PackageFamilyName --silent 2>&1
            if ($LASTEXITCODE -eq 0 -and ($out -notmatch 'No applicable upgrade')) {
                $result.UpdateAvailable = $true
                $result.Method = 'winget'
                $result.Details = ($out -join "`n")
            }
            break
        } catch {
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }
    return $result
}

function Invoke-TKMUpdateStoreApp {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][PSCustomObject] $App,
        [switch] $Force,
        [switch] $DryRun,
        [int] $TimeoutSeconds = 300,
        [int] $RetryCount = 3,
        [int] $RetryDelaySeconds = 10,
        [string] $LogPath,
        [switch] $SkipReboot
    )

    $status = @{ PackageFamilyName = $App.PackageFamilyName; Success = $false; Action = 'none'; Message = $null }
    if (-not $PSCmdlet.ShouldProcess($App.PackageFamilyName, 'Update store app')) { return $status }
    if ($DryRun) { Write-TKMLog -Level Info -Message "[DryRun] Would attempt update for $($App.PackageFamilyName)" -LogPath $LogPath; $status.Message = 'DryRun'; $status.Success = $true; return $status }

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-TKMLog -Level Warning -Message "winget not available for $($App.PackageFamilyName)" -LogPath $LogPath
        $status.Message = 'No update mechanism available'
        return $status
    }

    for ($i=0; $i -lt $RetryCount; $i++) {
        try {
            Write-TKMLog -Level Info -Message "Attempting winget upgrade for $($App.PackageFamilyName) (try $($i+1))" -LogPath $LogPath
            $proc = Start-Process -FilePath winget -ArgumentList 'upgrade','--id',$App.PackageFamilyName,'--accept-source-agreements','--accept-package-agreements','--silent' -Wait -PassThru -NoNewWindow -ErrorAction Stop
            if ($proc.ExitCode -eq 0) { $status.Success = $true; $status.Action = 'winget'; $status.Message = 'Upgraded via winget'; break }
            $status.Message = "winget exit $($proc.ExitCode)"
        } catch {
            Write-TKMLog -Level Warning -Message "winget failed: $_" -LogPath $LogPath
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }
    return $status
}

function Invoke-TKMUpdateAllStoreApps {
    [CmdletBinding()]
    param(
        [switch] $DryRun,
        [int] $RetryCount = 3,
        [int] $RetryDelaySeconds = 10,
        [int] $TimeoutSeconds = 300,
        [string] $LogPath,
        [switch] $SkipReboot
    )

    $apps = Get-TKMInstalledStoreApps -AllUsers
    $results = @()
    foreach ($a in $apps) {
        $res = Invoke-TKMUpdateStoreApp -App $a -DryRun:$DryRun -RetryCount $RetryCount -RetryDelaySeconds $RetryDelaySeconds -TimeoutSeconds $TimeoutSeconds -LogPath $LogPath -SkipReboot:$SkipReboot
        $results += $res
    }
    return $results
}

function Test-TKMStoreAppUpdatePrereqs {
    [CmdletBinding()]
    param()
    @(
        @{ Name = 'RunningAsAdmin'; Passed = (Test-TKMElevation) },
        @{ Name = 'Get-AppxPackageAvailable'; Passed = ($null -ne (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)) },
        @{ Name = 'wingetAvailable'; Passed = ($null -ne (Get-Command winget -ErrorAction SilentlyContinue)) }
    )
}

Export-ModuleMember -Function *-TKM*  # exported TKM helpers
