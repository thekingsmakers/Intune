# PowerShell Detection Script for Postman (Intune)

# Define the target version
$targetVersion = "11.23.3"
$installedVersion = $null

# Check for 64-bit installation in the Registry
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
$installedPostman = Get-ItemProperty -Path $registryPath | Where-Object { $_.DisplayName -like "Postman*" }

if ($installedPostman) {
    $installedVersion = $installedPostman.DisplayVersion
} else {
    # Fallback to check in the typical installation directory
    $postmanExePath = "C:\Users\$env:USERNAME\AppData\Local\Postman\Postman.exe"
    if (Test-Path -Path $postmanExePath) {
        $installedVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($postmanExePath).FileVersion
    }
}

# Compare versions
if ($installedVersion) {
    if ([version]$installedVersion -ge [version]$targetVersion) {
        Write-Host "Postman version $installedVersion is already installed. No action required."
        exit 0
    } else {
        Write-Host "Older Postman version $installedVersion detected. Update required."
        exit 1
    }
} else {
    Write-Host "Postman not installed. Installation required."
    exit 1
}
