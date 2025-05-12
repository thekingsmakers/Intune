# Detect-WinRARUpdate.ps1

function Get-InstalledWinRARVersion {
    try {
        $pkg = Get-Package | Where-Object { $_.Name -like '*winrar*' }
        if ($pkg -and $pkg.Version) {
            # Normalize like 7.11.0 → 711
            $verParts = $pkg.Version.ToString().Split('.')
            return "$($verParts[0])$($verParts[1])"
        }
    } catch {
        return $null
    }
}

function Get-LatestWinRARVersion {
    try {
        $downloadPage = "https://www.win-rar.com/download.html?&L=0"
        $html = Invoke-WebRequest -Uri $downloadPage -UseBasicParsing -ErrorAction Stop
        $match = [regex]::Match($html.Content, 'winrar-x64-(\d+)\.exe')
        if ($match.Success) {
            return $match.Groups[1].Value
        }
    } catch {
        Write-Output "Could not retrieve latest WinRAR version"
    }

    return $null
}

$installed = Get-InstalledWinRARVersion
$latest = Get-LatestWinRARVersion

if (-not $installed) {
    Write-Output "WinRAR not installed"
    exit 1
}

if (-not $latest) {
    Write-Output "Unable to detect latest WinRAR version"
    exit 1
}

if ([int]$installed -lt [int]$latest) {
    Write-Output "Outdated: Installed version $installed < Latest version $latest"
    exit 1
} else {
    Write-Output "WinRAR is up to date: $installed"
    exit 0
}
