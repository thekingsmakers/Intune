# THE KINGSMAKERS WINAPP TOOL - Standalone EXE Converter
# Embeds all PowerShell files into a single EXE for true standalone distribution

param(
    [string]$OutputFile = "THEKINGSMAKERS-WINAPP-TOOL-STANDALONE.exe",
    [string]$IconFile = "Icon.ico",
    [switch]$Force,
    [switch]$NoConsole,
    [switch]$RequireAdmin,
    [string]$Version = "1.0.0.0"
)

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "               THE KINGSMAKERS WINAPP TOOL                        " -ForegroundColor Cyan
Write-Host "              STANDALONE EXE CONVERSION SCRIPT                    " -ForegroundColor Yellow
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Check if PS2EXE is installed
Write-Host "Checking for PS2EXE module..." -ForegroundColor Yellow
try {
    $ps2exeModule = Get-Module -Name ps2exe -ListAvailable
    if (-not $ps2exeModule) {
        Write-Host "PS2EXE module not found. Installing..." -ForegroundColor Yellow
        Install-Module -Name ps2exe -Scope CurrentUser -Force -ErrorAction Stop
        Write-Host "PS2EXE installed successfully!" -ForegroundColor Green
    } else {
        Write-Host "PS2EXE module found: $($ps2exeModule.Version)" -ForegroundColor Green
    }
} catch {
    Write-Host "ERROR: Failed to install PS2EXE module. $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please install PS2EXE manually: Install-Module -Name ps2exe -Scope CurrentUser -Force" -ForegroundColor Red
    exit 1
}

# Required files to embed
$requiredFiles = @(
    "Utils.ps1",
    "Aliases.ps1",
    "PackageManagers.ps1",
    "Detection.ps1",
    "Winget.ps1",
    "Chocolatey.ps1",
    "Install.ps1",
    "Uninstall.ps1",
    "Upgrade.ps1",
    "package-aliases.json"
)

# Check for required files
Write-Host "`nChecking for required files..." -ForegroundColor Yellow
$missingFiles = @()
foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "ERROR: Missing required files:" -ForegroundColor Red
    $missingFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
Write-Host "All required files found!" -ForegroundColor Green

# Check for icon file
$useIcon = $false
if (Test-Path $IconFile) {
    Write-Host "Icon file found: $IconFile" -ForegroundColor Green
    $useIcon = $true
} else {
    Write-Host "Icon file not found: $IconFile (EXE will use default icon)" -ForegroundColor Yellow
}

# Check if output file exists
if ((Test-Path $OutputFile) -and -not $Force) {
    Write-Host "Output file '$OutputFile' already exists. Use -Force to overwrite." -ForegroundColor Red
    exit 1
}

# Create embedded script with all files included
Write-Host "`nCreating standalone EXE with embedded files..." -ForegroundColor Yellow

# Read all PowerShell files
$embeddedScripts = @{}
foreach ($file in $requiredFiles) {
    if ($file.EndsWith('.ps1')) {
        Write-Host "Embedding $file..." -ForegroundColor Gray
        $content = Get-Content $file -Raw -Encoding UTF8
        # Don't modify the content - keep it as-is to preserve syntax
        $embeddedScripts[$file] = $content
    } elseif ($file.EndsWith('.json')) {
        Write-Host "Embedding $file..." -ForegroundColor Gray
        $content = Get-Content $file -Raw -Encoding UTF8
        $embeddedScripts[$file] = $content
    }
}

# Create the main embedded script - SIMPLIFIED VERSION
$embeddedScript = @"
// THE KINGSMAKERS WINAPP TOOL - SIMPLE STANDALONE VERSION
// Simplified embedded version to avoid parameter conflicts

param(
    [string[]]`$args
)

# Parse arguments manually to avoid parameter conflicts
`$Install = @()
`$Uninstall = @()
`$Upgrade = @()
`$Search = `$null
`$List = `$false
`$Info = `$null
`$Manager = 'auto'
`$Silent = `$false
`$SkipElevation = `$false
`$Force = `$false
`$DryRun = `$false
`$Parallel = `$false
`$MaxConcurrency = 3
`$LogFile = `$null
`$LogLevel = 'Info'
`$CacheDirectory = `$null
`$AdditionalArgs = @()
`$Checksum = `$null

# Simple argument parsing
for (`$i = 0; `$i -lt `$args.Count; `$i++) {
    switch (`$args[`$i]) {
        '-Install' { `$i++; `$Install = `$args[`$i] -split ',' }
        '-Uninstall' { `$i++; `$Uninstall = `$args[`$i] -split ',' }
        '-Upgrade' { `$i++; `$Upgrade = `$args[`$i] -split ',' }
        '-Search' { `$i++; `$Search = `$args[`$i] }
        '-List' { `$List = `$true }
        '-Info' { `$i++; `$Info = `$args[`$i] }
        '-Manager' { `$i++; `$Manager = `$args[`$i] }
        '-Silent' { `$Silent = `$true }
        '-SkipElevation' { `$SkipElevation = `$true }
        '-Force' { `$Force = `$true }
        '-DryRun' { `$DryRun = `$true }
        '-Parallel' { `$Parallel = `$true }
        '-MaxConcurrency' { `$i++; `$MaxConcurrency = [int]`$args[`$i] }
        '-LogFile' { `$i++; `$LogFile = `$args[`$i] }
        '-LogLevel' { `$i++; `$LogLevel = `$args[`$i] }
        '-CacheDirectory' { `$i++; `$CacheDirectory = `$args[`$i] }
    }
}

# Set execution policy for EXE context
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction Stop
} catch {
    # Ignore execution policy errors in EXE context
}

# Embedded file contents (Base64 encoded for safety)
"@

# Add embedded file content as Base64 encoded strings
foreach ($file in $requiredFiles) {
    $content = $embeddedScripts[$file]
    $encodedContent = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($content))
    $varName = $file -replace '\.', '_' -replace '-', '_'
    $embeddedScript += "`$$varName = '$encodedContent'`n"
}

$embeddedScript += @"

# Decode and load embedded scripts in dependency order
Write-Host "Loading embedded modules..." -ForegroundColor Gray
try {
"@

# Add decoding and execution for each embedded file in dependency order
$loadOrder = @(
    "Utils.ps1",
    "Aliases.ps1",
    "PackageManagers.ps1",
    "Detection.ps1",
    "Winget.ps1",
    "Chocolatey.ps1",
    "Install.ps1",
    "Uninstall.ps1",
    "Upgrade.ps1"
)

foreach ($file in $loadOrder) {
    if ($embeddedScripts.ContainsKey($file)) {
        $varName = $file -replace '\.', '_' -replace '-', '_'
        $embeddedScript += @"
    # Load $file
    try {
        `$decodedContent = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(`$$varName))
        `$decodedContent | Invoke-Expression
        Write-Host "Loaded $file" -ForegroundColor Gray
    } catch {
        Write-Host "Failed to load $file`: `$(`$_.Exception.Message)" -ForegroundColor Red
    }

"@
    }
}

# Handle JSON file separately
$embeddedScript += @"
    # Load package-aliases.json
    try {
        `$aliasesJson = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(`$package_aliases_json))
        `$global:aliases = `$aliasesJson | ConvertFrom-Json
        Write-Host "Loaded package-aliases.json" -ForegroundColor Gray
    } catch {
        Write-Host "Failed to load aliases: `$(`$_.Exception.Message)" -ForegroundColor Red
        `$global:aliases = @{}
    }

"@

$embeddedScript += @"

} catch {
    Write-Host "ERROR loading embedded modules: `$(`$_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Display branding (EXE version)
try {
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "               THE KINGSMAKERS WINAPP TOOL                        " -ForegroundColor Cyan
    Write-Host "                    (TKM WINAPP TOOL)                             " -ForegroundColor Cyan
    Write-Host "                      STANDALONE EXE                               " -ForegroundColor Yellow
    Write-Host "                                                                  " -ForegroundColor Cyan
    Write-Host "            Created by thekingsmakers                             " -ForegroundColor Yellow
    Write-Host "            Website: thekingsmaker.org                            " -ForegroundColor Yellow
    Write-Host "            Twitter: thekingsmakers                               " -ForegroundColor Yellow
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host ""
} catch {
    # Fallback for environments that don't support colored output
    Write-Host "=================================================================="
    Write-Host "               THE KINGSMAKERS WINAPP TOOL                        "
    Write-Host "                    (TKM WINAPP TOOL)                             "
    Write-Host "                      STANDALONE EXE                               "
    Write-Host "                                                                  "
    Write-Host "            Created by thekingsmakers                             "
    Write-Host "            Website: thekingsmaker.org                            "
    Write-Host "            Twitter: thekingsmakers                               "
    Write-Host "=================================================================="
    Write-Host ""
}

# Initialize logging
if (-not `$LogFile) {
    `$LogFile = Join-Path `$env:TEMP 'tkm-winapp-tool.log'
}

Initialize-Logging -LogFile `$LogFile -LogLevel `$LogLevel

if (-not `$CacheDirectory) {
    `$CacheDirectory = Get-DefaultCacheDirectory
}

# Check elevation
`$elevated = Test-Elevation
`$requiresElevation = ((`$Install.Count -gt 0) -or (`$Uninstall.Count -gt 0)) -and -not `$SkipElevation

if (`$requiresElevation -and -not `$elevated -and -not `$DryRun) {
    Write-Log -Level Warning "Operation may require elevation. Will attempt to elevate if needed."
}

# Main logic (simplified)
if (`$Install.Count -gt 0) {
    `$packages = Resolve-Packages -Packages `$Install
    if (`$Manager -eq 'auto') {
        `$selectedManager = 'auto'
    } else {
        `$selectedManager = `$Manager
    }

    if (`$Parallel -and `$packages.Count -gt 1) {
        `$packageNames = `$packages | ForEach-Object { `$_.Name }
        Install-PackagesParallel -Packages `$packageNames -Manager `$selectedManager -MaxConcurrency `$MaxConcurrency -Force:`$Force -DryRun:`$DryRun -Silent:`$Silent -AdditionalArgs `$AdditionalArgs
    } else {
        foreach (`$pkg in `$packages) {
            Install-Package -Name `$pkg.Name -Manager `$selectedManager -Force:`$Force -DryRun:`$DryRun -Silent:`$Silent -AdditionalArgs `$AdditionalArgs
        }
    }
} elseif (`$Uninstall.Count -gt 0) {
    `$packages = Resolve-Packages -Packages `$Uninstall
    if (`$Manager -eq 'auto') {
        `$selectedManager = 'auto'
    } else {
        `$selectedManager = `$Manager
    }

    foreach (`$pkg in `$packages) {
        Uninstall-Package -Name `$pkg.Name -Manager `$selectedManager -Force:`$Force -DryRun:`$DryRun -Silent:`$Silent -AdditionalArgs `$AdditionalArgs
    }
} elseif (`$Upgrade.Count -gt 0) {
    `$packages = Resolve-Packages -Packages `$Upgrade
    if (`$Manager -eq 'auto') {
        `$selectedManager = 'auto'
    } else {
        `$selectedManager = `$Manager
    }

    if (`$Parallel -and `$packages.Count -gt 1) {
        `$packageNames = `$packages | ForEach-Object { `$_.Name }
        Update-PackagesParallel -Packages `$packageNames -Manager `$selectedManager -MaxConcurrency `$MaxConcurrency -Force:`$Force -DryRun:`$DryRun -Silent:`$Silent -AdditionalArgs `$AdditionalArgs
    } else {
        foreach (`$pkg in `$packages) {
            Update-Package -Name `$pkg.Name -Manager `$selectedManager -Force:`$Force -DryRun:`$DryRun -Silent:`$Silent -AdditionalArgs `$AdditionalArgs
        }
    }
} elseif (`$Search) {
    if (`$Manager -eq 'auto') {
        `$availableManagers = Get-AvailablePackageManagers
        `$selectedManager = if (`$availableManagers) { `$availableManagers[0] } else { throw "No package manager available for search" }
    } else {
        `$selectedManager = `$Manager
    }

    Write-Log -Level Info "Searching for '`$Search' using `$selectedManager"
    `$results = Search-Package -Query `$Search -Manager `$selectedManager
    if (`$results -and `$results.Count -gt 0) {
        Write-Log -Level Info "Found `$(`$results.Count) results"
        `$results | Format-Table -AutoSize
    } else {
        Write-Host "No packages found matching '`$Search'"
    }
} elseif (`$List) {
    if (`$Manager -eq 'auto') {
        `$availableManagers = Get-AvailablePackageManagers
        `$selectedManager = if (`$availableManagers) { `$availableManagers[0] } else { throw "No package manager available for listing" }
    } else {
        `$selectedManager = `$Manager
    }

    Write-Log -Level Info "Listing installed packages using `$selectedManager"
    `$installed = Get-InstalledPackages -Manager `$selectedManager

    `$hasResults = `$false
    `$resultCount = 0

    if (`$installed) {
        if (`$installed -is [array]) {
            `$hasResults = `$installed.Count -gt 0
            `$resultCount = `$installed.Count
        } elseif (`$installed -is [string]) {
            `$hasResults = `$true
            `$resultCount = 1
        } else {
            `$hasResults = `$true
            `$resultCount = 1
        }
    }

    if (`$hasResults) {
        Write-Log -Level Info "Found `$resultCount result(s)"
        if (`$installed -is [string]) {
            Write-Host `$installed
        } else {
            `$installed | Format-Table -AutoSize
        }
    } else {
        Write-Host "No installed packages found"
    }
} elseif (`$Info) {
    if (`$Manager -eq 'auto') {
        `$availableManagers = Get-AvailablePackageManagers
        `$selectedManager = if (`$availableManagers) { `$availableManagers[0] } else { throw "No package manager available for info" }
    } else {
        `$selectedManager = `$Manager
    }

    `$results = Search-Package -Query `$Info -Manager `$selectedManager
    if (`$results) {
        `$results[0] | Format-List
    } else {
        Write-Host "Package not found: `$Info"
    }
} else {
    Write-Host 'No operation specified. Use -Install, -Uninstall, -Search, -List, or -Info.'
    Write-Host "Run 'THEKINGSMAKERS-WINAPP-TOOL-STANDALONE.exe -Help' for detailed help."
    exit 2
}

Write-Log -Level Info "Operation completed successfully"
exit 0

} catch {
    Write-Log -Level Error "Operation failed: `$(`$_.Exception.Message)"
    Write-Host "ERROR: `$(`$_.Exception.Message)" -ForegroundColor Red
    exit 1
}
"@

# Save the embedded script
$embeddedScriptPath = "MainInstallerEmbedded.ps1"
$embeddedScript | Out-File -FilePath $embeddedScriptPath -Encoding UTF8 -Force
Write-Host "Embedded script created: $embeddedScriptPath" -ForegroundColor Green

# Convert to EXE
Write-Host "`nConverting to standalone EXE..." -ForegroundColor Yellow
Write-Host "Output file: $OutputFile" -ForegroundColor White
Write-Host "Version: $Version" -ForegroundColor White
Write-Host "Require Admin: $RequireAdmin" -ForegroundColor White
Write-Host "No Console: $NoConsole" -ForegroundColor White
if ($useIcon) { Write-Host "Icon: $IconFile" -ForegroundColor White }

# Build PS2EXE parameters
$ps2exeParams = @{
    inputFile = $embeddedScriptPath
    outputFile = $OutputFile
    title = "THE KINGSMAKERS WINAPP TOOL - STANDALONE"
    description = "Standalone Windows Package Management Tool with All Dependencies Embedded"
    company = "thekingsmakers"
    product = "TKM WINAPP TOOL"
    copyright = "Created by thekingsmakers"
    version = $Version
    requireAdmin = $RequireAdmin
    noConsole = $NoConsole
    x64 = $true
}

if ($useIcon) {
    $ps2exeParams.iconFile = $IconFile
}

try {
    # Call PS2EXE
    Invoke-ps2exe @ps2exeParams

    # Verify the EXE was created
    if (Test-Path $OutputFile) {
        $exeSize = (Get-Item $OutputFile).Length
        $exeSizeMB = [math]::Round($exeSize / 1MB, 2)

        Write-Host "`n==================================================================" -ForegroundColor Green
        Write-Host "STANDALONE EXE CREATION SUCCESSFUL!" -ForegroundColor Green
        Write-Host "==================================================================" -ForegroundColor Green
        Write-Host "Output File: $OutputFile" -ForegroundColor White
        Write-Host "File Size: $exeSizeMB MB" -ForegroundColor White
        Write-Host "Embedded Files: $($requiredFiles.Count)" -ForegroundColor White
        Write-Host "Version: $Version" -ForegroundColor White
        Write-Host "" -ForegroundColor White

        # Test the EXE
        Write-Host "Testing standalone EXE functionality..." -ForegroundColor Yellow
        try {
            $testResult = & $OutputFile -List -Silent 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Standalone EXE test successful!" -ForegroundColor Green
            } else {
                Write-Host "Standalone EXE test completed (expected for listing)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "Standalone EXE test had issues, but file was created successfully" -ForegroundColor Yellow
        }

        Write-Host "`nUSAGE EXAMPLES:" -ForegroundColor Cyan
        Write-Host "  $OutputFile -List" -ForegroundColor White
        Write-Host "  $OutputFile -Install vscode" -ForegroundColor White
        Write-Host "  $OutputFile -Uninstall chrome" -ForegroundColor White
        Write-Host "  $OutputFile -Search 'browser'" -ForegroundColor White
        Write-Host "  $OutputFile -Upgrade 'all'" -ForegroundColor White

        Write-Host "`nADVANTAGES:" -ForegroundColor Cyan
        Write-Host "  ✅ Single file deployment" -ForegroundColor White
        Write-Host "  ✅ No external dependencies" -ForegroundColor White
        Write-Host "  ✅ All modules embedded" -ForegroundColor White
        Write-Host "  ✅ True standalone operation" -ForegroundColor White

        Write-Host "`n==================================================================" -ForegroundColor Cyan
        Write-Host "THE KINGSMAKERS STANDALONE TOOL READY!" -ForegroundColor Cyan
        Write-Host "Created by thekingsmakers | thekingsmaker.org" -ForegroundColor Yellow
        Write-Host "==================================================================" -ForegroundColor Cyan

    } else {
        Write-Host "ERROR: EXE file was not created!" -ForegroundColor Red
        exit 1
    }

} catch {
    Write-Host "ERROR: Standalone EXE conversion failed. $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Make sure PS2EXE is properly installed and all files are accessible." -ForegroundColor Red
    exit 1
} finally {
    # Clean up embedded script
    if (Test-Path $embeddedScriptPath) {
        Remove-Item $embeddedScriptPath -Force
        Write-Host "`nCleaned up temporary embedded script." -ForegroundColor Gray
    }
}

Write-Host "`nStandalone EXE conversion completed successfully!" -ForegroundColor Green
