#=============================================================================
# Intune Remediation Script - WPS Office Complete Removal
# Description: Removes WPS Office from all user profiles on the device
# Run as: System
# Run in 64-bit: Yes
#=============================================================================

# Start transcript for logging
$LogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}
$TranscriptPath = Join-Path $LogPath "WPSOffice-Remediation-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Start-Transcript -Path $TranscriptPath -Force

Write-Output "=========================================="
Write-Output "WPS Office Remediation Script Started"
Write-Output "Date: $(Get-Date)"
Write-Output "=========================================="

# Function to forcefully close WPS Office processes
function Stop-WPSProcesses {
    Write-Output "`n=== Checking for running WPS Office processes ==="
    
    $wpsProcessNames = @(
        "wps",
        "et",
        "wpp",
        "wpscenter",
        "wpscloudsvr",
        "wpsnotify",
        "wpsdrive",
        "kso",
        "ksomisc",
        "promecefpluginhost",
        "wpsupdate",
        "wpsupdatesvr"
    )
    
    $foundProcesses = $false
    
    foreach ($processName in $wpsProcessNames) {
        $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
        
        if ($processes) {
            $foundProcesses = $true
            foreach ($process in $processes) {
                Write-Output "Terminating process: $($process.Name) (PID: $($process.Id))"
                try {
                    Stop-Process -Id $process.Id -Force -ErrorAction Stop
                    Write-Output "Successfully terminated: $($process.Name)"
                } catch {
                    Write-Output "WARNING: Could not terminate process $($process.Name): $($_.Exception.Message)"
                }
            }
        }
    }
    
    if ($foundProcesses) {
        Write-Output "Waiting for processes to fully terminate..."
        Start-Sleep -Seconds 3
    } else {
        Write-Output "No WPS Office processes running"
    }
}

# Function to find and uninstall WPS Office
function Uninstall-WPSOffice {
    param(
        [string]$RegistryPath,
        [string]$Context = "Unknown"
    )

    Write-Output "`nChecking registry path: $RegistryPath ($Context)..."
    
    $wpsInstallations = @()
    
    try {
        if (Test-Path $RegistryPath) {
            $wpsInstallations = Get-ChildItem -Path $RegistryPath -ErrorAction SilentlyContinue |
                ForEach-Object { Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue } |
                Where-Object { $_.DisplayName -like "*WPS Office*" -or $_.DisplayName -like "*Kingsoft*" }
        }
    } catch {
        Write-Output "WARNING: Could not access $RegistryPath via PowerShell: $($_.Exception.Message)"
    }

    if ($wpsInstallations) {
        foreach ($wps in $wpsInstallations) {
            $displayName = $wps.DisplayName
            $uninstallString = $wps.UninstallString
            
            Write-Output "Found: $displayName"
            
            if ($null -ne $uninstallString -and -not [string]::IsNullOrEmpty($uninstallString)) {
                Write-Output "Uninstall String: $uninstallString"
                
                try {
                    # Handle MSI-based installations
                    if ($uninstallString -match "msiexec") {
                        if ($uninstallString -match "/I({[A-F0-9-]+})") {
                            $productCode = $matches[1]
                            Write-Output "Executing MSI uninstall for product code: $productCode"
                            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/X$productCode /quiet /norestart" -Wait -PassThru -NoNewWindow
                            Write-Output "MSI uninstall completed with exit code: $($process.ExitCode)"
                        } else {
                            $msiArgs = $uninstallString.Replace("msiexec.exe", "").Replace("MsiExec.exe", "").Trim() + " /quiet /norestart"
                            Write-Output "Executing: msiexec.exe $msiArgs"
                            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow
                            Write-Output "MSI uninstall completed with exit code: $($process.ExitCode)"
                        }
                    }
                    # Handle EXE-based installations
                    elseif ($uninstallString -match "\.exe") {
                        # Extract the executable path (handle quoted paths)
                        if ($uninstallString -match '^"([^"]+)"(.*)$') {
                            $exePath = $matches[1]
                            $existingArgs = $matches[2].Trim()
                        } else {
                            $parts = $uninstallString -split '\.exe', 2
                            $exePath = $parts[0] + '.exe'
                            $existingArgs = if ($parts.Count -gt 1) { $parts[1].Trim() } else { "" }
                        }
                        
                        if (Test-Path $exePath) {
                            # Try multiple silent uninstall argument combinations
                            $silentArgs = @("/S", "/silent", "/quiet", "/uninstall /silent", "-uninstall -silent")
                            
                            foreach ($arg in $silentArgs) {
                                Write-Output "Attempting uninstall with: $exePath $arg"
                                $process = Start-Process -FilePath $exePath -ArgumentList $arg -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue
                                if ($process.ExitCode -eq 0) {
                                    Write-Output "Uninstall successful with exit code: $($process.ExitCode)"
                                    break
                                }
                            }
                        } else {
                            Write-Output "WARNING: Uninstaller executable not found: $exePath"
                        }
                    }
                    else {
                        Write-Output "WARNING: Unknown uninstall string format: $uninstallString"
                    }
                    
                } catch {
                    Write-Output "ERROR: Failed to execute uninstall: $($_.Exception.Message)"
                }
            } else {
                Write-Output "WARNING: No uninstall string found for $displayName"
            }
        }
    } else {
        Write-Output "No WPS Office installations found in $Context"
    }
}

# Function to remove WPS Office folders
function Remove-WPSFolders {
    param([string]$BasePath)
    
    $wpsPaths = @(
        "$BasePath\Kingsoft",
        "$BasePath\WPS Office"
    )
    
    foreach ($path in $wpsPaths) {
        if (Test-Path $path) {
            Write-Output "Removing folder: $path"
            try {
                Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                Write-Output "Successfully removed: $path"
            } catch {
                Write-Output "WARNING: Could not remove ${path}: $($_.Exception.Message)"
            }
        }
    }
}

try {
    # --- Force close all WPS Office processes first ---
    Stop-WPSProcesses

    # --- Uninstall for HKLM (all users, system-wide) ---
    Write-Output "`n=== Checking System-Wide Installations (HKLM) ==="
    Uninstall-WPSOffice -RegistryPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" -Context "HKLM 64-bit"
    Uninstall-WPSOffice -RegistryPath "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" -Context "HKLM 32-bit"

    # --- Uninstall for current user (HKCU) ---
    Write-Output "`n=== Checking Current User Installation (HKCU) ==="
    Uninstall-WPSOffice -RegistryPath "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" -Context "Current User"

    # --- Clean up Program Files folders ---
    Write-Output "`n=== Cleaning up Program Files ==="
    Remove-WPSFolders -BasePath "${env:ProgramFiles}"
    Remove-WPSFolders -BasePath "${env:ProgramFiles(x86)}"

    # --- Uninstall for other users via registry hive loading ---
    Write-Output "`n=== Checking Other User Profiles ==="

    $userProfiles = Get-WmiObject Win32_UserProfile | Where-Object { 
        -not $_.Special -and 
        $_.LocalPath -and 
        (Test-Path $_.LocalPath)
    }

    foreach ($profile in $userProfiles) {
        $sid = $profile.SID
        $profilePath = $profile.LocalPath
        $username = Split-Path $profilePath -Leaf
        
        # Skip the current user (already processed)
        if ($sid -eq [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value) {
            Write-Output "`nSkipping current user: $username (already processed)"
            continue
        }
        
        Write-Output "`n--- Processing user: $username ---"
        
        # Check if the hive is already loaded
        $testPath = "Registry::HKEY_USERS\$sid"
        $hiveAlreadyLoaded = Test-Path $testPath
        
        if (-not $hiveAlreadyLoaded) {
            $ntUserPath = Join-Path $profilePath "NTUSER.DAT"
            
            if (Test-Path $ntUserPath) {
                Write-Output "Loading registry hive from: $ntUserPath"
                $result = reg load "HKU\$sid" $ntUserPath 2>&1
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Output "WARNING: Failed to load registry hive. User may be logged in. Error: $result"
                    continue
                }
                
                Start-Sleep -Milliseconds 500
            } else {
                Write-Output "WARNING: NTUSER.DAT not found for user $username"
                continue
            }
        } else {
            Write-Output "Registry hive already loaded for user $username"
        }
        
        # Perform uninstall check
        $regPath = "Registry::HKEY_USERS\$sid\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
        Uninstall-WPSOffice -RegistryPath $regPath -Context "User: $username"
        
        # Clean up user-specific folders
        Remove-WPSFolders -BasePath "$profilePath\AppData\Local"
        Remove-WPSFolders -BasePath "$profilePath\AppData\Roaming"
        
        # Unload the hive if we loaded it
        if (-not $hiveAlreadyLoaded) {
            Write-Output "Unloading registry hive for user $username..."
            
            # Force close any lingering handles
            [gc]::Collect()
            [gc]::WaitForPendingFinalizers()
            Start-Sleep -Seconds 2
            
            $unloadResult = reg unload "HKU\$sid" 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                Write-Output "WARNING: Could not unload registry hive immediately. It will be unloaded on next reboot. Error: $unloadResult"
            } else {
                Write-Output "Successfully unloaded registry hive"
            }
        }
    }

    Write-Output "`n=========================================="
    Write-Output "WPS Office remediation completed successfully!"
    Write-Output "=========================================="
    
    Stop-Transcript
    
    # Exit with success code for Intune
    Exit 0

} catch {
    Write-Output "`n=========================================="
    Write-Output "ERROR: Remediation failed!"
    Write-Output "Error: $($_.Exception.Message)"
    Write-Output "=========================================="
    
    Stop-Transcript
    
    # Exit with error code for Intune
    Exit 1
}


