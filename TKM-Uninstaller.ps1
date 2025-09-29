<#
    TKM-Uninstaller
    Author: The Kingsmakers
    Website: https://thekingsmaker.org
    GitHub: https://github.com/thekingsmakers
    Twitter: @thekingsmakers
    Email: redomarjobs@gmail.com

    Description:
    Command-line software uninstaller & detector for Intune / automation.
    Supports logging, flags, and multiple uninstall methods.
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false, Position=0)][string]$Action,
    [Parameter(Mandatory=$false)][string[]]$Software,
    [Alias('quiet')][switch]$Silent,
    [ValidateSet('normal','verbose','debug')][string]$Verbosity = 'normal',
    [switch]$AutoSign,
    [switch]$ExportCsv,
    [Alias('l')][switch]$List,
    [Alias('d')][string[]]$Detect,
    [Alias('i')][string[]]$Info,
    [Alias('u')][string[]]$Uninstall
)

# Globals
$LogDir   = "C:\ProgramData\TKM\uninstaller\logs"
$FlagFile = "C:\ProgramData\TKM\uninstaller\flag"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$LogFile  = Join-Path $LogDir "TKM-Uninstaller-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Logging helper
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('info','debug')][string]$Level = 'info'
    )
    if ($Level -eq 'debug' -and ($Verbosity -ne 'debug' -and $Verbosity -ne 'verbose')) { return }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Output $entry
}

# Branding / Header
function Show-Header {
    Write-Output @"
============================================================
  TKM Uninstaller  |  created by The Kingsmakers
  Website: thekingsmaker.org   GitHub: thekingsmakers
============================================================

About:
  Command-line software detector and uninstaller for Windows.
  Safe registry-based detection, smart silent uninstall mapping,
  dry-run support, detailed logging, and CSV export.

Usage (native switches):
  -List | -l                          List installed software
  -Detect <name>[,<name>...]          Detect software
  -Info <name>[,<name>...]            Show detailed info
  -Uninstall <name>[,<name>...]       Uninstall software

Options:
  -Silent                             Attempt silent uninstall
  -WhatIf                             Dry-run; show actions only
  -Verbosity normal|verbose|debug     Logging detail (default: normal)
  -ExportCsv                          Export list to CSV (with -List)
  -AutoSign                           Self-sign the script (optional)

Examples:
  .\\TKM-Uninstaller.ps1 -List
  .\\TKM-Uninstaller.ps1 -Detect "wireshark","cursor"
  .\\TKM-Uninstaller.ps1 -Info "wireshark"
  .\\TKM-Uninstaller.ps1 -Uninstall "wireshark" -Silent -WhatIf
  .\\TKM-Uninstaller.ps1 -List -ExportCsv
"@
}

# Flag helper
function Write-Flag {
    param([string]$Content)
    Set-Content -Path $FlagFile -Value $Content -Force
}

# Auto-signing functionality
function Initialize-TKMSigning {
    [CmdletBinding()]
    param()
    
    $CertName = "TKM Uninstaller"
    $CertStore = "Cert:\CurrentUser\My"
    $TimestampServer = "http://timestamp.digicert.com"
    $ScriptPath = $PSCommandPath
    
    Write-Log "Initializing auto-signing..." 'debug'
    
    # Check if script is already signed
    $currentSignature = Get-AuthenticodeSignature -FilePath $ScriptPath
    if ($currentSignature.Status -eq "Valid") {
        Write-Log "Script is already signed and valid." 'debug'
        return $true
    }
    
    # Get or create certificate
    $cert = Get-ChildItem $CertStore -CodeSigningCert | Where-Object { $_.Subject -like "*$CertName*" } | Select-Object -First 1
    
    if (-not $cert) {
        Write-Log "Creating new self-signed certificate..." 'debug'
        try {
            $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=$CertName" -CertStoreLocation $CertStore -KeyExportPolicy Exportable -KeyLength 2048 -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" -HashAlgorithm SHA256 -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3")
            Write-Log "Certificate created successfully. Thumbprint: $($cert.Thumbprint)" 'debug'
        } catch {
            Write-Log "Failed to create certificate: $_" 'debug'
            return $false
        }
    } else {
        Write-Log "Using existing certificate: $($cert.Thumbprint)" 'debug'
    }
    
    # Sign the script
    try {
        Write-Log "Signing script with certificate..." 'debug'
        $signature = Set-AuthenticodeSignature -FilePath $ScriptPath -Certificate $cert -TimestampServer $TimestampServer
        
        if ($signature.Status -eq "Valid") {
            Write-Log "Script signed successfully!" 'debug'
            return $true
        } else {
            Write-Log "Script signing failed. Status: $($signature.Status)" 'debug'
            return $false
        }
    } catch {
        Write-Log "Failed to sign script: $_" 'debug'
        return $false
    }
}

# List installed software with uninstall parameters
function Show-Supported {
    Write-Output "Installed software (from registry):"
    try {
        $apps = Get-InstalledApps
        if (-not $apps -or $apps.Count -eq 0) {
            Write-Output "No installed software found."
            return
        }
        
        # Filter apps with uninstall strings and sort
        $filteredApps = $apps | 
            Where-Object { $_.DisplayName -and $_.UninstallString } |
            Sort-Object DisplayName
        
        if (-not $filteredApps -or $filteredApps.Count -eq 0) {
            Write-Output "No software with uninstall strings found."
            return
        }
        
        # Display in table format with better formatting
        $filteredApps | 
            Select-Object DisplayName, DisplayVersion, Publisher, UninstallString |
            Format-Table -AutoSize -Wrap -Property @{
                Name = 'DisplayName'
                Expression = { $_.DisplayName }
                Width = 50
            }, @{
                Name = 'Version'
                Expression = { $_.DisplayVersion }
                Width = 15
            }, @{
                Name = 'Publisher'
                Expression = { $_.Publisher }
                Width = 30
            }, @{
                Name = 'UninstallString'
                Expression = { $_.UninstallString }
                Width = 60
            } |
            Out-String |
            Write-Output
        
        $count = ($filteredApps | Measure-Object | Select-Object -ExpandProperty Count)
        Write-Output ("Total: {0} applications with uninstall capability" -f $count)
        
        # Export to CSV if requested
        if ($ExportCsv) {
            $csvFile = "InstalledSoftware_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            $filteredApps | 
                Select-Object DisplayName, DisplayVersion, Publisher, UninstallString, QuietUninstall, InstallLocation, RegistryPath |
                Export-Csv -Path $csvFile -NoTypeInformation
            Write-Output "`nExported to: $csvFile"
        }
        
        # Also show apps without uninstall strings for reference
        $noUninstall = $apps | 
            Where-Object { $_.DisplayName -and -not $_.UninstallString } |
            Sort-Object DisplayName
        
        if ($noUninstall -and $noUninstall.Count -gt 0) {
            Write-Output "`nApplications without uninstall strings (may be system components):"
            $noUninstall | 
                Select-Object DisplayName, DisplayVersion, Publisher |
                Format-Table -AutoSize |
                Out-String |
                Write-Output
            Write-Output ("Additional: {0} applications without uninstall capability" -f ($noUninstall | Measure-Object | Select-Object -ExpandProperty Count))
        }
        
    } catch {
        Write-Log "Error listing installed software: $_"
    }
}

# Detect installed software (registry-based; avoids Win32_Product side effects)
function Get-InstalledApps {
    [CmdletBinding()]
    param()

    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $apps = @()
    foreach ($path in $paths) {
        try {
            $items = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
            foreach ($it in $items) {
                if ([string]::IsNullOrWhiteSpace($it.DisplayName)) { continue }
                $apps += [pscustomobject]@{
                    DisplayName      = $it.DisplayName
                    DisplayVersion   = $it.DisplayVersion
                    Publisher        = $it.Publisher
                    UninstallString  = $it.UninstallString
                    QuietUninstall   = $it.QuietUninstallString
                    InstallLocation  = $it.InstallLocation
                    EstimatedSizeKB  = $it.EstimatedSize
                    RegistryPath     = $path
                }
            }
        } catch {
            # ignore inaccessible paths
        }
    }

    return $apps
}

# Normalize a string for fuzzy matching (lowercase, remove non-alphanumerics)
function Normalize-Text {
    param([AllowNull()][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $lower = $Text.ToLowerInvariant()
    return ([regex]::Replace($lower, "[^a-z0-9]", ""))
}

# Detect installer type and return appropriate silent parameters
function Get-InstallerSilentParams {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$UninstallString,
        [AllowNull()][AllowEmptyString()][string]$QuietUninstallString = $null
    )
    
    # If QuietUninstallString exists, prefer it
    if (-not [string]::IsNullOrWhiteSpace($QuietUninstallString)) {
        Write-Log "Using QuietUninstallString: $QuietUninstallString" 'debug' | Out-Null
        return [string]$QuietUninstallString
    }
    
    # Detect installer type and apply appropriate silent flags
    $uninstallLower = $UninstallString.ToLower()
    
    # Google Chrome (setup.exe with --uninstall); add --force-uninstall when silent
    if ($uninstallLower -match "chrome" -and $uninstallLower -match "setup\.exe") {
        $silentCmd = [string]$UninstallString
        if ($silentCmd -notmatch "--uninstall") { $silentCmd += " --uninstall" }
        if ($silentCmd -notmatch "--system-level" -and $uninstallLower -match "system-level") { $silentCmd += " --system-level" }
        if ($silentCmd -notmatch "--channel=") { $silentCmd += " --channel=stable" }
        if ($silentCmd -notmatch "--force-uninstall") { $silentCmd += " --force-uninstall" }
        Write-Log "Chrome detected, normalized cmd: $silentCmd" 'debug' | Out-Null
        return [string]$silentCmd
    }

    # MSI Installer
    if ($uninstallLower -match "msiexec\.exe") {
        # Normalize to removal: convert /I to /x when GUID present
        $guidMatch = [regex]::Match($UninstallString, "\{[0-9A-Fa-f-]{36}\}")
        if ($guidMatch.Success) {
            $guid = $guidMatch.Value
            $msiArgString = "/x $guid"
        } else {
            # Fallback: keep existing args but prefer /x if /I is present
            $msiArgString = ($UninstallString -replace "/I", "/x") -replace "(?i)^\s*msiexec\.exe\s*", ""
        }
        if ($msiArgString -notmatch "/qn|/quiet|/passive") { $msiArgString = "/qn " + $msiArgString }
        $silentCmd = "msiexec.exe " + ($msiArgString.Trim())
        Write-Log "MSI detected, normalized cmd: $silentCmd" 'debug' | Out-Null
        return [string]$silentCmd
    }
    
    # InstallShield
    if ($uninstallLower -match "setup\.exe|installshield") {
        if ($uninstallLower -notmatch "/s|/silent|/quiet") {
            $silentCmd = $UninstallString + " /s"
            Write-Log "InstallShield detected, adding /s: $silentCmd" 'debug' | Out-Null
            return [string]$silentCmd
        }
        return $UninstallString
    }
    
    # NSIS (Nullsoft Scriptable Install System)
    if ($uninstallLower -match "uninst\.exe|uninstall\.exe") {
        if ($uninstallLower -notmatch "/s|/silent") {
            $silentCmd = $UninstallString + " /S"
            Write-Log "NSIS detected, adding /S: $silentCmd" 'debug' | Out-Null
            return [string]$silentCmd
        }
        return $UninstallString
    }
    
    # Inno Setup
    if ($uninstallLower -match "unins\d+\.exe") {
        if ($uninstallLower -notmatch "/silent|/verysilent") {
            $silentCmd = $UninstallString + " /SILENT"
            Write-Log "Inno Setup detected, adding /SILENT: $silentCmd" 'debug' | Out-Null
            return [string]$silentCmd
        }
        return $UninstallString
    }

    # Squirrel (e.g., apps with Update.exe --uninstall)
    if ($uninstallLower -match "update\.exe" -or $uninstallLower -match "squirrel") {
        if ($uninstallLower -notmatch "--uninstall") {
            $silentCmd = $UninstallString + " --uninstall"
            Write-Log "Squirrel detected, adding --uninstall: $silentCmd" 'debug' | Out-Null
            return [string]$silentCmd
        }
        return $UninstallString
    }
    
    # Wise Installer
    if ($uninstallLower -match "wise.*\.exe") {
        if ($uninstallLower -notmatch "/s|/silent") {
            $silentCmd = $UninstallString + " /s"
            Write-Log "Wise detected, adding /s: $silentCmd" 'debug' | Out-Null
            return [string]$silentCmd
        }
        return $UninstallString
    }
    
    # Advanced Installer
    if ($uninstallLower -match "advanced.*installer") {
        if ($uninstallLower -notmatch "/silent|/quiet") {
            $silentCmd = $UninstallString + " /silent"
            Write-Log "Advanced Installer detected, adding /silent: $silentCmd" 'debug' | Out-Null
            return [string]$silentCmd
        }
        return $UninstallString
    }
    
    # Generic fallback - try common silent flags
    if ($uninstallLower -notmatch "/s|/silent|/quiet|/qn|/passive") {
        $silentCmd = $UninstallString + " /S"
        Write-Log "Generic installer, adding /S: $silentCmd" 'debug' | Out-Null
        return [string]$silentCmd
    }
    
    Write-Log "No silent parameters needed or already present: $UninstallString" 'debug' | Out-Null
    return [string]$UninstallString
}

function Show-SoftwareInfo {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string[]]$Software)

    try {
        $apps = Get-InstalledApps
        if (-not $apps -or $apps.Count -eq 0) {
            Write-Log "No registry apps enumerated."
            return $false
        }

        $any = $false
        foreach ($name in $Software) {
            Write-Log ("Gathering info for '{0}'..." -f $name) 'debug'
            $needle = Normalize-Text $name
            $infoMatches = @($apps | Where-Object { $_.DisplayName -and (( $_.DisplayName -like "*${name}*" ) -or (Normalize-Text $_.DisplayName -like "*${needle}*")) })
            if (-not $infoMatches -or $infoMatches.Count -eq 0) {
                Write-Output ("No matches for '{0}'." -f $name)
                continue
            }

            foreach ($m in $infoMatches) {
                $scope = if ($m.RegistryPath -like "HKCU:*") { "User" } else { "Machine" }
                $arch  = if ($m.RegistryPath -like "*WOW6432Node*") { "x86" } else { "x64/Neutral" }
                $sizeMB = if ($m.EstimatedSizeKB) { [math]::Round($m.EstimatedSizeKB / 1024, 2) } else { $null }

                $obj = [pscustomobject]@{
                    DisplayName        = $m.DisplayName
                    DisplayVersion     = $m.DisplayVersion
                    Publisher          = $m.Publisher
                    Scope              = $scope
                    Architecture       = $arch
                    EstimatedSizeMB    = $sizeMB
                    InstallLocation    = $m.InstallLocation
                    UninstallString    = $m.UninstallString
                    QuietUninstall     = $m.QuietUninstall
                    RegistryPath       = $m.RegistryPath
                }

                $obj | Format-List | Out-String | Write-Output
                $any = $true
            }
        }

        return $any
    } catch {
        Write-Log "Error showing software info: $_"
        return $false
    }
}

function Find-Software {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string[]]$Software)

    try {
        $apps = Get-InstalledApps
        if (-not $apps -or $apps.Count -eq 0) {
            Write-Log "No registry apps enumerated."
            return $false
        }

        $anyFound = $false
        foreach ($name in $Software) {
            Write-Log "Detecting $name (registry)..."
            $needle = Normalize-Text $name
            $matchingApps = $apps | Where-Object { $_.DisplayName -and (( $_.DisplayName -like "*${name}*" ) -or (Normalize-Text $_.DisplayName -like "*${needle}*")) }
            if ($matchingApps) {
                $count = ($matchingApps | Measure-Object | Select-Object -ExpandProperty Count)
                Write-Log ("Found {0} matching entries for '{1}'." -f $count, $name)
                $matchingApps | Select-Object DisplayName, DisplayVersion, Publisher, UninstallString | Format-Table | Out-String | Write-Output
                $anyFound = $true
            } else {
                Write-Log "${name} not detected."
            }
        }

        return $anyFound
    } catch {
        Write-Log "Detection error for ${Software}: $_"
        return $false
    }
}

# Uninstall software
function Uninstall-Software {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([string[]]$SoftwareList, [switch]$Silent)

    $OverallSuccess = $true

    foreach ($Software in $SoftwareList) {
        Write-Log "Starting uninstall for ${Software}..."

        # Option 1 removed: Avoid Win32_Product due to MSI reconfiguration side effects

        # Option 2: Registry-based uninstall across HKLM/HKCU and WOW6432Node
        try {
            $allApps = Get-InstalledApps
            if (-not $allApps) { Write-Log "No installed apps found via registry." 'debug' }
            else { Write-Log ("Enumerated {0} installed app entries." -f ($allApps | Measure-Object | Select-Object -ExpandProperty Count)) 'debug' }

            $needle = Normalize-Text $Software
            $candidates = @($allApps | Where-Object {
                ($_.DisplayName -and ( ($_.DisplayName -like "*$Software*") -or (Normalize-Text $_.DisplayName -like "*${needle}*") )) -or
                ($_.UninstallString -and ($_.UninstallString -like "*$Software*"))
            })
            if (-not $candidates -or $candidates.Count -eq 0) {
                Write-Log ("No registry uninstall candidates matched '{0}'." -f $Software)
            }
            if ($candidates -and $candidates.Count -gt 0) {
                Write-Log ("Found {0} uninstall candidate(s) for '{1}'." -f $candidates.Count, $Software) 'debug'
                foreach ($app in $candidates) {
                    if (-not $app.UninstallString) { 
                        Write-Log "No uninstall string for '$($app.DisplayName)'." 'debug'
                        continue 
                    }

                    # Get appropriate silent command based on installer type
                    $cmd = if ($Silent) {
                        [string](Get-InstallerSilentParams -UninstallString $app.UninstallString -QuietUninstallString $app.QuietUninstall)
                    } else {
                        [string]$app.UninstallString
                    }

                    Write-Log ("Prepared uninstall for '{0}': {1}" -f $app.DisplayName, $cmd) 'debug'
                    if ($PSCmdlet.ShouldProcess($app.DisplayName, "Uninstall via registry uninstall string")) {
                        Write-Log "Running: $cmd"
                        try {
                            # Split command into executable and arguments safely
                            $exe = $null; $cmdArgs = $null
                            if ($cmd.StartsWith('"')) {
                                $firstQuoteEnd = $cmd.IndexOf('"',1)
                                $exe = $cmd.Substring(1, $firstQuoteEnd-1)
                                $cmdArgs = $cmd.Substring($firstQuoteEnd+1).Trim()
                            } else {
                                $parts = $cmd.Split(' ',2)
                                $exe = $parts[0]
                                $cmdArgs = if ($parts.Count -gt 1) { $parts[1] } else { "" }
                            }

                            Start-Process $exe $cmdArgs -Wait -PassThru | ForEach-Object { Write-Log ("ExitCode: {0}" -f $_.ExitCode) 'debug' }
                            Write-Log "Uninstall completed for '$($app.DisplayName)'" 'debug'
                        } catch {
                            Write-Log "Uninstall failed for '$($app.DisplayName)': $_" 'debug'
                        }
                    } else {
                        Write-Log "WhatIf: Would run -> $cmd"
                    }
                }
                Write-Log "${Software} uninstalled successfully via registry uninstall."
                continue
            }
        } catch {
            Write-Log "Option Two failed for ${Software}: $_"
        }

        Write-Log "Uninstall failed for ${Software}."
        $OverallSuccess = $false
    }

    if ($OverallSuccess) {
        if ($PSCmdlet.ShouldProcess("FlagFile", "Write Success flag")) { Write-Flag "Success" } else { Write-Log "WhatIf: Would write Success flag" }
        exit 0
    } else {
        if ($PSCmdlet.ShouldProcess("FlagFile", "Write Failed flag")) { Write-Flag "Failed" } else { Write-Log "WhatIf: Would write Failed flag" }
        exit 1
    }
}

# Main Execution
# Show header at startup (unless used with legacy -Action default help)
Show-Header
# Auto-sign if requested
if ($AutoSign) {
    Write-Log "Auto-signing requested..." 'debug'
    $signResult = Initialize-TKMSigning
    if ($signResult) {
        Write-Log "Auto-signing completed successfully." 'debug'
    } else {
        Write-Log "Auto-signing failed, continuing with normal execution." 'debug'
    }
}

if ($List -or $Action -eq "-l") { Show-Supported; exit 0 }
if ($Detect) { Find-Software -Software $Detect; exit 0 }
if ($Info) { Show-SoftwareInfo -Software $Info; exit 0 }
if ($Uninstall) { Uninstall-Software -SoftwareList $Uninstall -Silent:$Silent; exit $LASTEXITCODE }

switch ($Action) {
    "-l"        { Show-Supported }
    "-detect"   { if ($Software) { Find-Software -Software $Software } else { Write-Output "Usage: -detect <name>" } }
    "-info"     { if ($Software) { Show-SoftwareInfo -Software $Software } else { Write-Output "Usage: -info <name>" } }
    "-uninstall"{ if ($Software) { Uninstall-Software -SoftwareList $Software -Silent:$Silent } else { Write-Output "Usage: -uninstall <name>" } }
    default     {
        # For legacy -Action without valid subcommand, show header (already shown)
        Write-Output "Use -List/-l, -Detect, -Info, or -Uninstall. See above for options."
    }
}

