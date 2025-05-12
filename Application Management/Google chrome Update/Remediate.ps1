# Define download path and URL for Chrome Enterprise (Stable Channel)
$installerPath = "$env:TEMP\ChromeEnterpriseInstaller.msi"
$downloadUrl = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"

try {
    Write-Host "Downloading Chrome Enterprise stable installer..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing

    Write-Host "Installing Chrome Enterprise..."
    Start-Process "msiexec.exe" -ArgumentList "/i `"$installerPath`" /qn /norestart" -Wait

    Remove-Item $installerPath -Force
    Write-Host "Chrome Enterprise updated successfully"
} catch {
    Write-Host "Chrome Enterprise update failed: $_"
    exit 1
}
