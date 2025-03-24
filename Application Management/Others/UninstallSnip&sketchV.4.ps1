# PowerShell Script to Uninstall Screen Sketch App

Write-Output "Attempting to uninstall Screen Sketch app..."
Get-AppxPackage *ScreenSketch* | Remove-AppxPackage
Write-Output "Command executed. Please check if the app is uninstalled."
