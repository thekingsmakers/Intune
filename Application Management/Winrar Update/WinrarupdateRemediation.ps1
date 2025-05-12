# Remediate-WinRARUpdate.ps1

function Get-LatestWinRARInstallerUrl {
    try {
        $downloadPage = "https://www.win-rar.com/download.html?&L=0"
        $html = Invoke-WebRequest -Uri $downloadPage -UseBasicParsing -ErrorAction Stop
        $matches = [regex]::Matches($html.Content, 'https:\/\/[^"]*winrar-x64-[\d\.]+\.exe')

        if ($matches.Count -gt 0) {
            return $matches[0].Value
        }
    } catch {
        Write-Output "Failed to fetch installer URL: $_"
    }
    return $null
}

$installerUrl = Get-LatestWinRARInstallerUrl

if ($installerUrl) {
    $installerPath = "$env:TEMP\winrar-latest.exe"

    try {
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing -ErrorAction Stop
        Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait
        Write-Output "WinRAR installed from $installerUrl"
    } catch {
        Write-Output "Installation failed: $_"
        exit 1
    } finally {
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force
        }
    }
} else {
    Write-Output "No installer URL found"
    exit 1
}
