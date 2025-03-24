$installedPrograms = Get-WmiObject -Class Win32_Product

# Check if Symantec is installed
$SymantecInstalled = $installedPrograms | Where-Object { $_.Name -match "Symantec" } | Select-Object -First 1

# Initialize hash to store the discovered setting
$hash = @{}

# Populate the hash based on the discovery
if ($SymantecInstalled) {
    $hash["SymantecInstalled"] = $true
} else {
    $hash["SymantecInstalled"] = $false
}

# Return the hash as compressed JSON
return $hash | ConvertTo-Json -Compress