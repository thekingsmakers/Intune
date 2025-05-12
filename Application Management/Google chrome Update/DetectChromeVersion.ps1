function Get-LatestChromeVersion {
    $url = "https://chromiumdash.appspot.com/fetch_releases?platform=Windows&channel=stable&num=1"
    try {
        $response = Invoke-RestMethod -Uri $url -UseBasicParsing
        return $response[0].version
    } catch {
        Write-Host "Failed to fetch latest Chrome version"
        return $null
    }
}

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
$latest = Get-LatestChromeVersion

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
