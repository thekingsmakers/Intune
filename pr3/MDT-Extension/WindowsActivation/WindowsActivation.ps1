# WindowsActivation.ps1
# PowerShell script to activate Windows

Write-Host "Windows Activation script started."

# --- Configuration ---
$configFilePath = "MDT-Extension/Configuration/config.xml"
try {
    $xmlConfig = [xml](Get-Content $configFilePath)
}
catch {
    Write-Error "Error loading Windows Activation configuration from $($configFilePath): $_"
    [System.Windows.Forms.MessageBox]::Show("Error loading Windows Activation configuration from $($configFilePath).", "Configuration Load Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}

# --- Product Key ---
$productKey = $xmlConfig.Configuration.WindowsActivation.ProductKey
if (-not [string]::IsNullOrEmpty($productKey)) {
    Write-Host "Product Key found in configuration."
} else {
    Write-Warning "No Product Key found in configuration."
}

Write-Host "Attempting to activate Windows"

# --- Activation Command ---
try {
    if (-not [string]::IsNullOrEmpty($productKey)) {
        # Attempt to set product key and then activate Windows
        Write-Host "Setting Product Key..."
        $ProductKeyResult = cscript //NoLogo %windir%\system32\slmgr.vbs /ipk $productKey
        Write-Host "Product Key Setting Result: $($ProductKeyResult)"

        Write-Host "Activating Windows with Product Key..."
        $ActivationResult = cscript //NoLogo %windir%\system32\slmgr.vbs /ato
        Write-Host "Activation Result: $($ActivationResult)"
    } else {
        # Attempt to activate Windows using KMS or MAK key embedded in the image
        Write-Host "Activating Windows (no Product Key provided)..."
        $ActivationResult = cscript //NoLogo %windir%\system32\slmgr.vbs /ato
        Write-Host "Activation Result: $($ActivationResult)"
    }

    Write-Host "Windows activation process completed."
    [System.Windows.Forms.MessageBox]::Show("Windows activation process completed. Please check the output for details.", "Windows Activation Status", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

}
catch {
    Write-Error "Error during Windows activation: $_"
    [System.Windows.Forms.MessageBox]::Show("Error during Windows activation: $($_.Exception.Message). See error log for details.", "Windows Activation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}

Write-Host "Windows Activation script finished."