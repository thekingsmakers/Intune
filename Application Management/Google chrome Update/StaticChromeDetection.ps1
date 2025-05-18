<#

- Checks chrome version based on the version provided on the $latest = "136.0.7103.114"
- if the version matches $latest = "136.0.7103.114" then no action is required else 
    -  chrome should be updated using the parameter for the remediation 




#>
$latest = "136.0.7103.114"

function Get-InstalledChromeVersion {
    try {
        $chromePackage = Get-Package | Where-Object { $_.Name -like "*chrome*" } | Select-Object -First 1
        return $chromePackage.Version
    } catch {
        Write-Host "Chrome package not found"
        return $null
    }
}

$installed = Get-InstalledChromeVersion

if (-not $installed) {
    Write-Host "Chrome not installed"
    exit 1
}

if (-not $latest) {
    Write-Host "Could not retrieve latest version info"
    exit 1
}

if ($installed -eq $latest) {
    Write-Host "Chrome is up to date ($installed)"
    exit 0
} else {
    Write-Host "Chrome is outdated. Installed: $installed, Latest: $latest"
    exit 1
}
