# Uninstall ScreenSketch
$package = Get-AppxPackage -Name "*ScreenSketch*"
if ($package -ne $null) {
    $package | Remove-AppxPackage
    Write-Host "ScreenSketch has been uninstalled."
} else {
    Write-Host "ScreenSketch is not installed on this system."
}
