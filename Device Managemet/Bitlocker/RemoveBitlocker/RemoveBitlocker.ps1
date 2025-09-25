# SCRIPT TO REMOVE BITLOCKER, CLEAR RELATED LOGS, AND PREPARE FOR RE-ENCRYPTION
# Script Created by Thekingsmakers thekingsmaker.org and tested
# --- STEP 1: DISABLE AUTO-UNLOCK FOR ALL VOLUMES ---
Write-Host "Clearing auto-unlock keys for all volumes..."
# This is required before disabling BitLocker on the OS drive.
Clear-BitLockerAutoUnlock

# --- STEP 2: DECRYPT DRIVES C AND D ---
# Note: The decryption process will take a long time and must be allowed to complete.

Write-Host "Checking BitLocker status for drive C:..."
if ((Get-BitLockerVolume -MountPoint "C:").VolumeStatus -eq "FullyEncrypted") {
    Write-Host "Disabling BitLocker on drive C:..."
    Disable-BitLocker -MountPoint "C:"
    Write-Host "Decryption of drive C: started. Do not shut down or restart the computer."
} else {
    Write-Host "BitLocker is not enabled on drive C: or is already in progress."
}

Write-Host "Checking BitLocker status for drive D:..."
if ((Get-BitLockerVolume -MountPoint "D:").VolumeStatus -eq "FullyEncrypted") {
    Write-Host "Disabling BitLocker on drive D:..."
    Disable-BitLocker -MountPoint "D:"
    Write-Host "Decryption of drive D: started. Do not shut down or restart the computer."
} else {
    Write-Host "BitLocker is not enabled on drive D: or is already in progress."
}

# Wait for decryption to finish. This check will pause the script.
$drivesToWait = @("C", "D")
while ($drivesToWait) {
    foreach ($driveLetter in $drivesToWait.Clone()) {
        $status = (Get-BitLockerVolume -MountPoint "${driveLetter}:").VolumeStatus
        if ($status -ne "FullyDecrypted") {
            Write-Host "Waiting for drive ${driveLetter}: to decrypt. Status: $status"
            # Optional: Add a progress bar here
        } else {
            Write-Host "Decryption of drive ${driveLetter}: is complete."
            $drivesToWait.Remove($driveLetter)
        }
    }
    if ($drivesToWait) {
        Start-Sleep -Seconds 60 # Check again in 60 seconds
    }
}

# --- STEP 3: CLEAR RELEVANT EVENT LOGS ---
# Using the correct command for modern Windows Event Logs: wevtutil.exe
Write-Host "Clearing relevant event logs..."
wevtutil.exe cl "Microsoft-Windows-BitLocker/Operational"
wevtutil.exe cl "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin"

Write-Host "Event logs cleared."

# --- STEP 4: CLEAN UP COMPANY PORTAL AND TRIGGER INTUNE SYNC ---
Write-Host "Performing Company Portal cleanup and triggering Intune sync..."
# Reset the Company Portal app to clear its cache and local data.
# This helps ensure a clean enrollment and re-encryption.
# Note: This is an instruction for a manual step as the process can require user interaction.
Start-Process "ms-settings:appsfeatures"
Write-Host "Please find 'Company Portal', click 'Advanced options', and select 'Reset'."
Write-Host "Press any key to continue after resetting the app..."
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null

Write-Host "Triggering Intune device sync..."
Start-ScheduledTask -TaskName "\Microsoft\Windows\EnterpriseMgmt\EnterpriseMgmt" -ErrorAction SilentlyContinue

Write-Host "Script finished. Drives have been decrypted, logs cleared, and sync triggered."
Write-Host "Intune should now re-evaluate the device's compliance status."
