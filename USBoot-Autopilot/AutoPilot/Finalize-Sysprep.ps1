# Finalize-Sysprep.ps1 - Finalize with Sysprep and OOBE

# Ensure 64-bit execution (important for registry path)
if ($env:PROCESSOR_ARCHITEW6432) {
    & "$env:WINDIR\SysNative\WindowsPowerShell\v1.0\powershell.exe" -File $PSCommandPath
    exit
}

# Setup logging
$logPath = "C:\Windows\Temp"
if (-not (Test-Path $logPath)) { New-Item -Path $logPath -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logPath "Sysprep.log"

Write-Host "Finalize-Sysprep: Starting Sysprep finalization. Log: $logFile"
Start-Transcript -Path $logFile -Append

try {
    # Remove registry key
    $registryPath = "HKLM:\SOFTWARE\Microsoft\DeviceManageabilityCSP"

    if (Test-Path $registryPath) {
        Write-Output "Removing registry key..."
        Remove-Item $registryPath -Recurse -Force -ErrorAction Stop
    } else {
        Write-Output "Registry key not found."
    }

    # Small delay to stabilize
    Start-Sleep -Seconds 5

    # Run Sysprep
    $sysprepExe = "C:\Windows\System32\Sysprep\Sysprep.exe"
    $arguments = "/oobe /reboot /quiet"

    Write-Output "Starting Sysprep..."
    Start-Process -FilePath $sysprepExe -ArgumentList $arguments -Wait

} catch {
    Write-Output "Error: $_"
} finally {
    Stop-Transcript
}
