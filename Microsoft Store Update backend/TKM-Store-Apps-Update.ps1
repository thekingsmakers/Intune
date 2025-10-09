<#
.SYNOPSIS
  TKM-Store-Apps-Update - Enterprise script to discover and update Microsoft Store (Appx/MSIX/UWP) apps.

.DESCRIPTION
  This script wraps the TKM module functions to provide a single entrypoint suitable for Intune Win32 App deployments
  or remediation scripting. It supports discovery, targeted updates by name or PackageFamilyName, DryRun/WhatIf,
  logging, telemetry and JSON output.

.PARAMETER Update
  Friendly names or aliases of apps to update (mutually exclusive with -All and -AppId).

.PARAMETER AppId
  PackageFamilyName(s) or product ids (supports wildcard patterns).

.PARAMETER All
  Update all detected store apps.

.PARAMETER DryRun
  Do not perform changes; show planned actions.

.PARAMETER Force
  Force reinstallation if update fails.

.PARAMETER RetryCount
  Network retry count. Default 3.

.PARAMETER RetryDelaySeconds
  Seconds between retries. Default 10.

.PARAMETER TimeoutSeconds
  Per-operation timeout. Default 300.

.PARAMETER LogPath
  Path for logs (default under C:\ProgramData\TKM\...).

.PARAMETER SkipReboot
  Do not auto-reboot even if required.

.PARAMETER TelemetryEndpoint
  Optional telemetry endpoint for structured reporting.

.PARAMETER ReturnJson
  Emit JSON report on exit.

.EXAMPLE
  .\TKM-Store-Apps-Update.ps1 -All -DryRun -LogPath C:\Temp\tkm.log -ReturnJson

#>

[CmdletBinding(DefaultParameterSetName='ByAll', SupportsShouldProcess=$true)]
param(
    [Parameter(ParameterSetName='ByName',Position=0)] [string[]] $Update,
    [Parameter(ParameterSetName='ById',Position=0)] [string[]] $AppId,
    [Parameter(ParameterSetName='ByAll')] [switch] $All,
    [switch] $DryRun,
    [switch] $Force,
    [int] $RetryCount = 3,
    [int] $RetryDelaySeconds = 10,
    [int] $TimeoutSeconds = 300,
    [string] $LogPath,
    [switch] $SkipReboot,
    [string] $TelemetryEndpoint,
    [switch] $ReturnJson
)

Set-StrictMode -Version Latest

Import-Module -Name "$PSScriptRoot\TKM-Store-Apps-Update.psm1" -Force -ErrorAction Stop

function Get-DefaultLogPath {
    param()
    $d = 'C:\ProgramData\TKM\TKM-Store-Apps-Update\logs'
    if (-not (Test-Path $d)) { New-Item -Path $d -ItemType Directory -Force | Out-Null }
    return Join-Path $d (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log'
}

if (-not $LogPath) { $LogPath = Get-DefaultLogPath }

# Basic validation
if ($Update -and $All) { Throw 'Parameters -Update and -All are mutually exclusive.' }
if ($AppId -and $All) { Throw 'Parameters -AppId and -All are mutually exclusive.' }

if (-not (Test-TKMElevation)) {
    Write-TKMLog -Level Warning -Message 'Not running elevated. Attempting to re-run elevated if interactive.' -LogPath $LogPath
    if ($Host.UI.RawUI.KeyAvailable -or $env:USERNAME) { # best-effort interactive check
        Start-Process -FilePath 'powershell.exe' -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit 0
    } else {
        Write-TKMLog -Level Error -Message 'Non-interactive session and not elevated; exiting.' -LogPath $LogPath
        exit 2
    }
}

$report = [ordered]@{
    Timestamp = (Get-Date).ToString('o')
    Hostname = $env:COMPUTERNAME
    Results = @()
}

try {
    Write-TKMLog -Level Info -Message "Starting TKM-Store-Apps-Update (DryRun=$DryRun)" -LogPath $LogPath

    if ($All) {
        $targets = Get-TKMInstalledStoreApps -AllUsers
    } elseif ($AppId) {
        $all = Get-TKMInstalledStoreApps -AllUsers
        $patterns = $AppId
        $targets = $all | Where-Object { foreach ($p in $patterns) { if ($_.PackageFamilyName -like $p -or $_.PackageFullName -like $p) { $true; break } } }
    } elseif ($Update) {
        # map friendly names using mapping file if present
        $mapPath = Join-Path $PSScriptRoot 'TKM-Store-App-Map.json'
        $map = @{}
        if (Test-Path $mapPath) { $map = Get-Content $mapPath -Raw | ConvertFrom-Json }
        $all = Get-TKMInstalledStoreApps -AllUsers
        $targets = @()
        foreach ($u in $Update) {
            if ($map.ContainsKey($u)) {
                $pf = $map[$u]
                $t = $all | Where-Object { $_.PackageFamilyName -eq $pf }
                if ($t) { $targets += $t } else { Write-TKMLog -Level Warning -Message "Mapped $u -> $pf but not installed on device" -LogPath $LogPath }
            } else {
                $t = $all | Where-Object { $_.Name -like "*$u*" -or $_.PackageFamilyName -like "*$u*" }
                if ($t) { $targets += $t } else { Write-TKMLog -Level Warning -Message "No installed package matched $u" -LogPath $LogPath }
            }
        }
    } else {
        Write-TKMLog -Level Error -Message 'No targets specified. Use -All, -Update, or -AppId.' -LogPath $LogPath
        exit 3
    }

    if (-not $targets) { Write-TKMLog -Level Info -Message 'No target apps found; exiting' -LogPath $LogPath; exit 0 }

    foreach ($t in $targets) {
        $res = Invoke-TKMUpdateStoreApp -App $t -DryRun:$DryRun -RetryCount $RetryCount -RetryDelaySeconds $RetryDelaySeconds -TimeoutSeconds $TimeoutSeconds -LogPath $LogPath -SkipReboot:$SkipReboot
        $report.Results += $res
    }

    # Finalize
    $report.Overall = @{ Success = ($report.Results | Where-Object { $_.Success -eq $false } | Measure-Object).Count -eq 0 }
    if ($ReturnJson) { $report | ConvertTo-Json -Depth 5 }
    if ($TelemetryEndpoint) {
        try {
            Invoke-RestMethod -Uri $TelemetryEndpoint -Method Post -Body ($report | ConvertTo-Json -Depth 5) -ContentType 'application/json' -TimeoutSec 30
        } catch {
            Write-TKMLog -Level Warning -Message "Telemetry publish failed: $_" -LogPath $LogPath
        }
    }

    if ($report.Overall.Success) { exit 0 } else { exit 1 }

} catch {
    Write-TKMLog -Level Error -Message "Unexpected error: $_" -LogPath $LogPath
    if ($ReturnJson) { @{ Error = $_.Exception.Message } | ConvertTo-Json }
    exit 2
}
