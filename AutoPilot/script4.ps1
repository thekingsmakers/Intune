# ==============================================================================
# Script: Invoke-SCCMCleanup-Autopilot.ps1
# Description: Enterprise SCCM Client Cleanup and Sysprep preparation for
#              Intune Autopilot enrollment. Deployed via SCCM Task Sequence.
#
# Fixes Applied:
#   - WMI namespace removal corrected (pipe from parent namespace)
#   - Removed redundant process wait loop (incompatible with -Wait flag)
#   - Removed DeviceManageabilityCSP registry key (Intune/MDM key, not SCCM)
#   - Added smstsmgr to service stop list
#   - Added Start-Transcript for SCCM log supportability
# ==============================================================================

# --- Logging Setup ---
$LogPath = "C:\Windows\Logs\SCCMCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $LogPath -Force
Write-Host "Log file: $LogPath"
Write-Host "Starting Enterprise SCCM Client Cleanup..." -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date)"

# ==============================================================================
# STEP 1: Graceful Uninstall via ccmsetup.exe
# ==============================================================================
$ccmsetupPath = "$env:SystemRoot\ccmsetup\ccmsetup.exe"

if (Test-Path $ccmsetupPath) {
    Write-Host "`n[Step 1] Running ccmsetup.exe /uninstall..." -ForegroundColor Yellow
    # -Wait blocks until ccmsetup fully exits. The while loop is NOT used
    # alongside -Wait as they are mutually redundant.
    Start-Process -FilePath $ccmsetupPath -ArgumentList "/uninstall" -Wait -NoNewWindow
    Write-Host "ccmsetup /uninstall completed."
} else {
    Write-Host "[Step 1] ccmsetup.exe not found — skipping graceful uninstall."
}

# ==============================================================================
# STEP 2: Stop and Disable SCCM Services
# ==============================================================================
Write-Host "`n[Step 2] Stopping and disabling SCCM services..." -ForegroundColor Yellow

# smstsmgr added: Task Sequence Manager may still be running outside a TS context.
# cmrcservice: Remote Control service.
# CcmExec / ccmsetup: Core client services.
$sccmServices = @("CcmExec", "ccmsetup", "cmrcservice", "smstsmgr")

foreach ($serviceName in $sccmServices) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($service) {
        Write-Host "  Stopping and disabling: $serviceName"
        $service | Stop-Service -Force -ErrorAction SilentlyContinue
        Set-Service -Name $serviceName -StartupType Disabled -ErrorAction SilentlyContinue
    } else {
        Write-Host "  Service not found (skipping): $serviceName"
    }
}

# ==============================================================================
# STEP 3: WMI Namespace Removal (Fixed)
# ==============================================================================
Write-Host "`n[Step 3] Removing SCCM WMI namespaces..." -ForegroundColor Yellow

# FIX: Previously called Remove-WmiObject from within the target namespace,
# which removed child __Namespace instances but not the namespace itself.
# Correct approach: query the parent (root) for the named namespace object,
# then pipe that object directly to Remove-WmiObject.
$wmiNamespaceNames = @("ccm", "ccmsetup", "sms")

foreach ($nsName in $wmiNamespaceNames) {
    $nsObject = Get-WmiObject -Namespace "root" `
                              -Class "__Namespace" `
                              -Filter "Name='$nsName'" `
                              -ErrorAction SilentlyContinue
    if ($nsObject) {
        Write-Host "  Removing WMI namespace: root\$nsName"
        $nsObject | Remove-WmiObject -ErrorAction SilentlyContinue
    } else {
        Write-Host "  WMI namespace not found (skipping): root\$nsName"
    }
}

# ==============================================================================
# STEP 4: Registry Cleanup
# ==============================================================================
Write-Host "`n[Step 4] Cleaning SCCM registry keys..." -ForegroundColor Yellow

# FIX: Removed HKLM:\SOFTWARE\Microsoft\DeviceManageabilityCSP — this key is
# owned by MDM/Intune, not SCCM. Deleting it risks disrupting Autopilot enrollment.
$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\CCM",
    "HKLM:\SOFTWARE\Microsoft\CCMSetup",
    "HKLM:\SOFTWARE\Microsoft\SMS"
)

foreach ($regPath in $registryPaths) {
    if (Test-Path $regPath) {
        Write-Host "  Removing registry key: $regPath"
        Remove-Item -Path $regPath -Force -Recurse -ErrorAction SilentlyContinue
    } else {
        Write-Host "  Registry key not found (skipping): $regPath"
    }
}

# ==============================================================================
# STEP 5: File System Cleanup
# ==============================================================================
Write-Host "`n[Step 5] Removing SCCM folders..." -ForegroundColor Yellow

$folders = @(
    "$env:SystemRoot\CCM",
    "$env:SystemRoot\ccmsetup",
    "$env:SystemRoot\ccmcache"
)

foreach ($folder in $folders) {
    if (Test-Path $folder) {
        Write-Host "  Deleting folder: $folder"
        Remove-Item -Path $folder -Force -Recurse -ErrorAction SilentlyContinue
    } else {
        Write-Host "  Folder not found (skipping): $folder"
    }
}

# Remove stale .mif and smscfg.ini files using Get-ChildItem for wildcard safety
Write-Host "  Cleaning up .mif and smscfg.ini files..."
Get-ChildItem -Path "$env:SystemRoot\smscfg.ini", "$env:SystemRoot\sms*.mif" `
              -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

Write-Host "`nSCCM Cleanup complete." -ForegroundColor Green

# ==============================================================================
# STEP 6: Sysprep Execution
# ==============================================================================
Write-Host "`n[Step 6] Initiating Sysprep for Autopilot..." -ForegroundColor Cyan

# NOTE: /generalize is intentionally omitted.
#   - Required only when moving an image to different hardware.
#   -Including /generalize can disrupt Autopilot existing‑device scenarios
# by resetting OS identity and provisioning state.

#     (hardware hash), which would break enrollment.
#   - Confirm your Autopilot hash is pre-registered in Microsoft Endpoint Manager.
#
# /oobe   — Puts device into Out-of-Box Experience on next boot.
# /reboot — Reboots immediately after Sysprep completes.
# /quiet  — Suppresses the Sysprep UI.

$sysprepPath = "$env:SystemRoot\system32\sysprep\sysprep.exe"
$sysprepArgs = "/oobe /reboot /quiet"

# Optional: warn if a custom unattend.xml is expected but missing
$unattendPath = "$env:SystemRoot\system32\sysprep\unattend.xml"
if (Test-Path $unattendPath) {
    Write-Host "  unattend.xml found — Sysprep will use it."
    $sysprepArgs = "$sysprepArgs /unattend:$unattendPath"
} else {
    Write-Host "  No unattend.xml found — Sysprep will use defaults."
}

if (Test-Path $sysprepPath) {
    Write-Host "  Launching Sysprep with flags: $sysprepArgs"

    # Stop-Transcript before Sysprep launches — the reboot will terminate the
    # session and anything after Start-Process won't reliably execute anyway.
    Stop-Transcript

    # IMPORTANT: Do NOT use -Wait here.
    #   SCCM Task Sequence must receive Exit 0 BEFORE the reboot occurs.
    #   Using -Wait would cause SCCM to hang until the reboot kills the session,
    #   resulting in a failed TS step.
    Start-Process -FilePath $sysprepPath -ArgumentList $sysprepArgs

    # Return success to SCCM before Sysprep-triggered reboot fires.
    Exit 0
} else {
    Write-Error "Sysprep.exe not found at $sysprepPath"
    Stop-Transcript
    Exit 1
}