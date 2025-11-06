<#
.SYNOPSIS
    Checks for installed Windows ESU (Extended Security Update) licenses and reports their status.

.DESCRIPTION
    This script runs slmgr.vbs to list installed licenses, filters for ESU-related entries,
    and outputs a structured summary. It exits with code 0 if a valid ESU license is found,
    otherwise exits with code 1 for remediation.

.NOTES
    Author: Thekingsmakers
    Date: 2025-11-06
#>

try {
    Write-Host "Checking installed Windows licenses..." -ForegroundColor Cyan

    # Run slmgr.vbs and capture output, skipping the first line
    $rawOutput = cscript.exe /nologo "$env:SystemRoot\system32\slmgr.vbs" /dlv 2>&1 | Select-Object -Skip 1
    $licenseBlocks = ($rawOutput -join "`n") -split "`n`n+"

    $esuEntries = @()

    foreach ($block in $licenseBlocks) {
        $lines = $block -split "`n"
        $props = @{}

        foreach ($line in $lines) {
            if ($line -match "^(.*?):\s*(.*)$") {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                $props[$key] = $value
            }
        }

        if ($props['Name'] -like '*ESU*') {
            $esuEntry = [PSCustomObject]@{
                Name         = $props['Name']
                ActivationID = $props['Activation ID']
                Licensed     = $props['License Status']
            }
            $esuEntries += $esuEntry
        }
    }

    if ($esuEntries.Count -gt 0) {
        Write-Host "`nFound ESU License(s):" -ForegroundColor Green
        $esuEntries | Format-Table -AutoSize

        if ($esuEntries.Licensed -contains "Licensed") {
            Write-Host "`nAt least one ESU license is valid and active." -ForegroundColor Green
            Exit 0
        } else {
            Write-Host "`nESU license(s) found but not licensed. Remediation required." -ForegroundColor Yellow
            Exit 1
        }
    } else {
        Write-Host "`nNo ESU licenses found on this system." -ForegroundColor Red
        Exit 1
    }
}
catch {
    Write-Error "An error occurred while checking licenses: $_"
    Exit 1
}