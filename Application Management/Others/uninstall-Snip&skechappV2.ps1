# PowerShell Script to Uninstall Snip & Sketch

try {
    Get-WindowsPackage -Online | Where-Object {$_.PackageName -like "*Microsoft.ScreenSketch*"} | Remove-WindowsPackage -Online
    Write-Host "Attempted to uninstall Snip & Sketch."
} catch {
    Write-Host "An error occurred during the uninstallation process."
    Write-Host $_.Exception.Message
}
