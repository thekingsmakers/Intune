# Enable the camera explicitly
$camera = Get-PnpDevice | Where-Object { $_.FriendlyName -like "*Camera*" }
if ($camera) {
    $camera | Enable-PnpDevice -Confirm:$false
    Write-Output "Camera has been enabled."
} else {
    Write-Output "Camera device not found."
}
