# Aliases.ps1
# Functions for loading and managing package aliases

function Load-PackageAliases {
    <#
    .SYNOPSIS
        Loads package aliases from JSON file.
    .PARAMETER Path
        Path to the aliases JSON file.
    .OUTPUTS
        [hashtable] Package aliases.
    #>
    param (
        [string]$Path = (Join-Path $PSScriptRoot 'package-aliases.json')
    )

    if (Test-Path $Path) {
        try {
            $json = Get-Content -Path $Path -Raw | ConvertFrom-Json
            $aliases = @{}
            $validationWarnings = @()

            foreach ($key in $json.PSObject.Properties.Name) {
                $aliasData = $json.$key

                # Validate required fields
                if (-not $aliasData.winget -and -not $aliasData.choco -and -not $aliasData.url) {
                    $validationWarnings += "Alias '$key' has no package sources (winget, choco, or url)"
                    continue
                }

                # Check for placeholder checksums
                if ($aliasData.checksum -and $aliasData.checksum -match '^([A-Fa-f0-9]{8,})$') {
                    # This looks like a placeholder - warn about it
                    if ($aliasData.checksum.Length -lt 64) { # SHA256 should be 64 chars
                        $validationWarnings += "Alias '$key' has suspiciously short checksum (likely placeholder)"
                    }
                }

                # Validate URL format if present
                if ($aliasData.url -and $aliasData.url -notmatch '^https?://') {
                    $validationWarnings += "Alias '$key' has invalid URL format: $($aliasData.url)"
                }

                $aliases[$key] = $aliasData
            }

            # Report validation warnings
            if ($validationWarnings.Count -gt 0) {
                Write-Warning "Package alias validation warnings:"
                foreach ($warning in $validationWarnings) {
                    Write-Warning "  - $warning"
                }
            }

            return $aliases
        }
        catch {
            Write-Warning "Failed to load aliases from $Path`: $($_.Exception.Message)"
        }
    }
    return @{}
}

function Save-PackageAliases {
    <#
    .SYNOPSIS
        Saves package aliases to JSON file.
    .PARAMETER Aliases
        Hashtable of aliases.
    .PARAMETER Path
        Path to save to.
    #>
    param (
        [hashtable]$Aliases,
        [string]$Path = (Join-Path $PSScriptRoot 'package-aliases.json')
    )

    try {
        $Aliases | ConvertTo-Json | Set-Content -Path $Path
    }
    catch {
        Write-Warning "Failed to save aliases to $Path`: $($_.Exception.Message)"
    }
}
