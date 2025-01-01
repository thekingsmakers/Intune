# Uninstall Postman Script with Error Handling

# Stop Postman Process if Running
$process = Get-Process -Name "Postman" -ErrorAction SilentlyContinue
if ($process) {
    Write-Host "Stopping Postman process..."
    Stop-Process -Name "Postman" -Force -ErrorAction Continue
    Start-Sleep -Seconds 5
}

# Uninstall Postman via Winget (if available)
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Attempting to uninstall Postman via winget..."
    winget uninstall "Postman" --silent
} else {
    Write-Host "winget not found. Skipping winget uninstall."
}

# Remove Postman Directories (User Data and Local AppData)
$paths = @(
    "$env:APPDATA\Postman",
    "$env:LOCALAPPDATA\Postman"
)

foreach ($path in $paths) {
    if (Test-Path $path) {
        Write-Host "Attempting to delete $path..."
        
        # Attempt to remove and retry if files are locked
        $attempt = 0
        $maxAttempts = 5
        while ($attempt -lt $maxAttempts) {
            try {
                Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                Write-Host "$path successfully removed."
                break
            } catch {
                Write-Host "Failed to delete $path. Retrying... ($($attempt+1)/$maxAttempts)"
                Stop-Process -Name "Postman" -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 3
            }
            $attempt++
        }
        
        if (Test-Path $path) {
            Write-Host "Failed to delete $path after $maxAttempts attempts. Manual deletion may be required."
        }
    } else {
        Write-Host "$path not found. Skipping..."
    }
}

# Confirm Removal
if (-not (Test-Path "$env:LOCALAPPDATA\Postman") -and -not (Test-Path "$env:APPDATA\Postman")) {
    Write-Host "Postman successfully uninstalled."
} else {
    Write-Host "Postman uninstallation incomplete. Some files may still exist."
}
