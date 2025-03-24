# Remediation Script to Remove Opera Browser and its Registry Entries

# Define the Opera installation path
$operaFolderPath = "C:\Users\$env:USERNAME\AppData\Local\Programs\Opera"

# Check if the Opera folder exists and delete it
if (Test-Path -Path $operaFolderPath) {
    Remove-Item -Path $operaFolderPath -Recurse -Force
    Write-Output "Opera folder deleted successfully."
} else {
    Write-Output "Opera folder not found."
}

# Define the paths for Opera registry keys
$registryPaths = @(
    "HKCU:\Software\Opera Software",
    "HKLM:\SOFTWARE\Classes\OperaStable",
    "HKLM:\SOFTWARE\Clients\StartMenuInternet\OperaStable",
    "HKLM:\SOFTWARE\WOW6432Node\Clients\StartMenuInternet\OperaStable"
)

# Delete the Opera registry keys
foreach ($path in $registryPaths) {
    if (Test-Path -Path $path) {
        Remove-Item -Path $path -Recurse -Force
        Write-Output "Deleted registry path: $path"
    } else {
        Write-Output "Registry path not found: $path"
    }
}

Write-Output "Opera removal process completed."
