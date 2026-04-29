# Ensure 64-bit execution (important for registry path)
if ($env:PROCESSOR_ARCHITEW6432) {
    & "$env:WINDIR\SysNative\WindowsPowerShell\v1.0\powershell.exe" -File $PSCommandPath
    exit
}

# Logging (optional but recommended)
$logFile = "C:\Temp\Sysprep.log"
New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
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
