# Get the Company Portal package (UWP apps installed from the Store)
$app = Get-AppxPackage -Name "Microsoft.CompanyPortal" -ErrorAction SilentlyContinue

if ($null -eq $app) {
    Write-Output "Company Portal not detected."
    exit 1
}

# Convert the Version property to a System.Version object
try {
    $installedVersion = [version]$app.Version
} catch {
    Write-Output "Error reading Company Portal version."
    exit 1
}

$requiredVersion = [version]"11.2.1393.0"

if ($installedVersion -ge $requiredVersion) {
    Write-Output "Company Portal version $installedVersion detected."
    exit 0
} else {
    Write-Output "Company Portal version $installedVersion is below the required version $requiredVersion."
    exit 1
}
