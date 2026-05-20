# Force IME installation by triggering policy + app workload

Write-Output "Triggering IME installation..."

# Force MDM sync
Get-ScheduledTask | Where-Object {
    $_.TaskPath -like "\Microsoft\Windows\EnterpriseMgmt\*"
} | ForEach-Object {
    Start-ScheduledTask $_.TaskName
}

Start-Sleep -Seconds 20

# Check if IME installed
$IMEPath = "C:\Program Files (x86)\Microsoft Intune Management Extension"

if (Test-Path $IMEPath) {
    Write-Output "IME Installed Successfully"
} else {
    Write-Output "IME still missing - trigger again or check assignments"
}
