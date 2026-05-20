# Main-Orchestrator.ps1
# Orchestrates the complete AutoPilot provisioning process
# Includes: WiFi auto-connect, Setup-CopyFiles (setup), AutoPilot-RegisterDevice (registration), Finalize-Sysprep (cleanup)

$ErrorActionPreference = 'Continue'
# The AutoPilot folder is in C:\Setup\AutoPilot during OEM setup
$scriptDir = "C:\Setup\AutoPilot"
# Verify the AutoPilot folder exists
if (-not (Test-Path $scriptDir)) {
    Write-Host "ERROR: AutoPilot folder not found at $scriptDir"
    exit 1
}

# =============================================================================
# FUNCTION: Auto-Connect to WiFi
# =============================================================================
function Connect-AutoWiFi {
    try {
        Write-Host "[WiFi] Checking for WiFi profile..."
        $wifiProfile = Join-Path $scriptDir "home.xml"
        
        if (-not (Test-Path $wifiProfile)) {
            Write-Host "[WiFi] Profile not found at $wifiProfile. Continuing without WiFi..."
            return $false
        }
        
        Write-Host "[WiFi] Found profile at $wifiProfile"
        Write-Host "[WiFi] Importing WiFi profile..."
        netsh wlan add profile filename="$wifiProfile" user=current 2>&1 | Out-Null
        
        # Extract SSID from XML
        [xml]$xmlContent = Get-Content $wifiProfile
        $ssid = $xmlContent.WLANProfile.SSIDConfig.SSID.name
        
        if ($ssid) {
            Write-Host "[WiFi] Connecting to: $ssid"
            netsh wlan connect name="$ssid" 2>&1 | Out-Null
            Start-Sleep -Seconds 3
            
            $wifiStatus = netsh wlan show interfaces | Select-String "State"
            Write-Host "[WiFi] Status: $wifiStatus"
            return $true
        } else {
            Write-Host "[WiFi] Could not extract SSID from profile"
            return $false
        }
    } catch {
        Write-Host "[WiFi] Error: $($_.Exception.Message)"
        return $false
    }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

Write-Host "========================================"
Write-Host "AutoPilot Provisioning - Started"
Write-Host "========================================"

# Step 1: Auto-connect WiFi
Write-Host "\n[Step 1/4] Connecting to WiFi..."
Connect-AutoWiFi
Start-Sleep -Seconds 2

# Step 2: Run Setup-CopyFiles.ps1 (Copy AutoPilot files)
Write-Host "\n[Step 2/4] Running Setup-CopyFiles (Setup)..."
$script1 = Join-Path $scriptDir 'Setup-CopyFiles.ps1'
if (Test-Path $script1) {
    try {
        & $script1
        Write-Host "[Setup-CopyFiles] Completed successfully"
    } catch {
        Write-Host "[Setup-CopyFiles] Error: $($_.Exception.Message)"
    }
} else {
    Write-Warning "[Setup-CopyFiles] Not found at $script1"
}

# Step 3: Run AutoPilot-RegisterDevice.ps1 (AutoPilot Registration)
Write-Host "\n[Step 3/4] Running AutoPilot-RegisterDevice (Registration)..."
$script2 = Join-Path $scriptDir 'AutoPilot-RegisterDevice.ps1'
if (Test-Path $script2) {
    try {
        & $script2
        Write-Host "[AutoPilot-RegisterDevice] Completed successfully"
    } catch {
        Write-Host "[AutoPilot-RegisterDevice] Error: $($_.Exception.Message)"
    }
} else {
    Write-Warning "[AutoPilot-RegisterDevice] Not found at $script2"
}

# Step 4: Run Finalize-Sysprep.ps1 (Sysprep)
Write-Host "\n[Step 4/4] Running Finalize-Sysprep (Finalize & Sysprep)..."
$script6 = Join-Path $scriptDir 'Finalize-Sysprep.ps1'
if (Test-Path $script6) {
    try {
        & $script6
        Write-Host "[Finalize-Sysprep] Completed successfully"
    } catch {
        Write-Host "[Finalize-Sysprep] Error: $($_.Exception.Message)"
    }
} else {
    Write-Warning "[Finalize-Sysprep] Not found at $script6"
}

Write-Host "\n========================================"
Write-Host "AutoPilot Provisioning - Finished"
Write-Host "========================================"