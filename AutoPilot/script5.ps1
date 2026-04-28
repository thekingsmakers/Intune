# ==============================================================================
# Script: Invoke-SCCMCleanup-Autopilot.ps1
# Cleaned Version – Production Safe
# ==============================================================================

# --- Logging Setup ---
$LogPath = "C:\Windows\Logs\SCCMCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $LogPath -Force

Write-Host "Log file: $LogPath"
Write-Host "Starting Enterprise SCCM Client Cleanup..." -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date)"

# ==============================================================================
# STEP 1: Graceful Uninstall
# ==============================================================================
$ccmsetupPath = "$env:SystemRoot\ccmsetup\ccmsetup.exe"

if (Test-Path $ccmsetupPath) {
    Write-Host "`n[Step 1] Running ccmsetup.exe /uninstall..." -ForegroundColor Yellow
    Start-Process -FilePath $ccmsetupPath -ArgumentList "/uninstall" -Wait -NoNewWindow -ErrorAction SilentlyContinue
    Write-Host "ccmsetup /uninstall completed."
} else {
    Write-Host "[Step 1] ccmsetup.exe not found — skipping."
}

# ==============================================================================
# STEP 2: Stop Services
# ==============================================================================
Write-Host "`n[Step 2] Stopping SCCM services..." -ForegroundColor Yellow

$sccmServices = @("CcmExec", "ccmsetup", "cmrcservice", "smstsmgr")

foreach ($serviceName in $sccmServices) {
    try {
        $service = Get-Service -Name $serviceName -ErrorAction Stop
        Write-Host "  Stopping: $serviceName"
        Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
        Set-Service -Name $serviceName -StartupType Disabled -ErrorAction SilentlyContinue
    } catch {
        Write-Host "  Service not found (skipping): $serviceName"
    }
}

# ==============================================================================
# STEP 3: WMI Cleanup (FIXED)
# ==============================================================================
Write-Host "`n[Step 3] Removing SCCM WMI namespaces..." -ForegroundColor Yellow

$namespaces = @("ccm", "ccmsetup", "sms")

foreach ($ns in $namespaces) {
    try {
        $nsObject = Get-WmiObject -Namespace "root" -Class "__Namespace" -Filter "Name='$ns'" -ErrorAction Stop
        if ($nsObject) {
            Write-Host "  Removing WMI namespace: root\$ns"
            $nsObject | Remove-WmiObject -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "  Namespace not found (skipping): root\$ns"
    }
}

# ==============================================================================
# STEP 4: Registry Cleanup
# ==============================================================================
Write-Host "`n[Step 4] Cleaning registry..." -ForegroundColor Yellow

$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\CCM",
    "HKLM:\SOFTWARE\Microsoft\CCMSetup",
    "HKLM:\SOFTWARE\Microsoft\SMS"
)

foreach ($path in $registryPaths) {
    if (Test-Path $path) {
        Write-Host "  Removing: $path"
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "  Not found: $path"
    }
}

# ==============================================================================
# STEP 5: File Cleanup
# ==============================================================================
Write-Host "`n[Step 5] Removing files..." -ForegroundColor Yellow

$folders = @(
    "$env:SystemRoot\CCM",
    "$env:SystemRoot\ccmsetup",
    "$env:SystemRoot\ccmcache"
)

foreach ($folder in $folders) {
    if (Test-Path $folder) {
        Write-Host "  Deleting: $folder"
        Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "  Not found: $folder"
    }
}

Write-Host "  Cleaning smscfg.ini and .mif files..."
Get-ChildItem -Path "$env:SystemRoot" -Filter "sms*.mif" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

if (Test-Path "$env:SystemRoot\smscfg.ini") {
    Remove-Item "$env:SystemRoot\smscfg.ini" -Force -ErrorAction SilentlyContinue
}

Write-Host "`nCleanup complete." -ForegroundColor Green

# ==============================================================================
# STEP 6: Sysprep
# ==============================================================================
Write-Host "`n[Step 6] Starting Sysprep..." -ForegroundColor Cyan

$sysprepPath = "$env:SystemRoot\System32\Sysprep\sysprep.exe"
$sysprepArgs = "/oobe /reboot /quiet"

$unattend = "$env:SystemRoot\System32\Sysprep\unattend.xml"
if (Test-Path $unattend) {
    Write-Host "  Using unattend.xml"
    $sysprepArgs += " /unattend:$unattend"
} else {
    Write-Host "  No unattend.xml found"
}

if (Test-Path $sysprepPath) {
    Write-Host "  Launching Sysprep..."
    Stop-Transcript

    Start-Process -FilePath $sysprepPath -ArgumentList $sysprepArgs
    Exit 0
} else {
    Write-Error "Sysprep not found."
    Stop-Transcript
    Exit 1
}
