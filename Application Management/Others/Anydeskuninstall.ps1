# Path to the AnyDesk executable
$anyDeskPath = "C:\Program Files (x86)\AnyDesk\anydesk.exe"
$anyDeskFolder = "C:\Program Files (x86)\AnyDesk"

# Check if AnyDesk is installed
if (Test-Path $anyDeskPath) {
    # Run the uninstall command
    Write-Host "Uninstalling AnyDesk..."
    Start-Process $anyDeskPath -ArgumentList "--silent --remove" -Wait

    # Remove remaining folder if it exists
    if (Test-Path $anyDeskFolder) {
        Write-Host "Removing AnyDesk folder..."
        Remove-Item -Path $anyDeskFolder -Recurse -Force
        Write-Host "AnyDesk folder removed."
    }

    Write-Host "AnyDesk should be uninstalled."
} else {
    Write-Host "AnyDesk is not installed."
}
