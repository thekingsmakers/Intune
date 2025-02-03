# Remediate_SEP.ps1
# This script stops the SEP service and then uninstalls SEP by dynamically finding the product ID.

# Define the uninstall password (update as needed)
$UninstallPassword = "Symantec@#$1234"

# Define the path to smc.exe (adjust if SEP is installed in a different location)
$SmcPath = "C:\Program Files\Symantec\Symantec Endpoint Protection\smc.exe"

# Optional: log file path for troubleshooting
$LogFile = "C:\Windows\Temp\SEP_Uninstall.log"

# Function to log messages (optional)
Function Write-Log {
    param ([string]$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$TimeStamp - $Message" | Out-File -Append -Encoding utf8 $LogFile
}

if (Test-Path $SmcPath) {
    $arguments = '-p Symantec@#$1234 -stop'
    Write-Output "Stopping Symantec Endpoint Protection..."
    Start-Process -FilePath $SmcPath -ArgumentList $arguments -NoNewWindow -Wait
    Write-Output "Symantec Endpoint Protection has been stopped."
} else {
    Write-Output "Symantec Endpoint Protection service not found at the specified path."
}


# --- Step 2: Find the Product ID (MSI Product Code) for SEP ---
try {
    $sepProduct = Get-WmiObject Win32_Product | Where-Object { $_.Name -match "Symantec Endpoint Protection" }
    if ($sepProduct) {
        $ProductCode = $sepProduct.IdentifyingNumber
        Write-Log "Found SEP Product Code: $ProductCode"
        Write-Host "Found SEP Product Code: $ProductCode"
    }
    else {
        Write-Log "SEP is not installed."
        Write-Host "Symantec Endpoint Protection is not installed."
        exit 0
    }
}
catch {
    Write-Log "Error retrieving SEP Product Code: $_"
    exit 1
}

# --- Step 3: Uninstall SEP using msiexec.exe ---
try {
    # Build the uninstall command using the dynamic Product Code and uninstall password.
    $MsiArguments = "/x $ProductCode /qn /norestart UNINSTALLPASSWORD=$UninstallPassword"
    Write-Log "Executing msiexec.exe with arguments: $MsiArguments"
    Start-Process "msiexec.exe" -ArgumentList $MsiArguments -Wait -NoNewWindow
    Write-Log "Symantec Endpoint Protection uninstall command executed."
    Write-Host "Symantec Endpoint Protection is being uninstalled."
    exit 0
}
catch {
    Write-Log "Error during SEP uninstallation: $_"
    Write-Host "Error during SEP uninstallation: $_"
    exit 1
}
