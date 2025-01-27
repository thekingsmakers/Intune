# DomainJoin.ps1
# PowerShell script for domain join
# Configuration is loaded from config.xml

Write-Host "Domain Join script started."

# --- Configuration ---
$configFilePath = "MDT-Extension/Configuration/config.xml"
try {
    $xmlConfig = [xml](Get-Content $configFilePath)
    $DomainJoinEnabled = [System.Convert]::ToBoolean($xmlConfig.Configuration.DomainJoin.Enabled)
    $DomainName = $xmlConfig.Configuration.DomainJoin.DomainName
    $DomainIP = $xmlConfig.Configuration.DomainJoin.DomainIP
    $OUPath = $xmlConfig.Configuration.DomainJoin.OUPath
    $Username = $xmlConfig.Configuration.DomainJoin.Credentials.Username
    $Password = $xmlConfig.Configuration.DomainJoin.Credentials.Password # Consider secure credential handling
}
catch {
    Write-Error "Error loading domain join configuration from $($configFilePath): $_"
    Write-Warning "Domain join script will exit."
    exit 1
}

# --- Check if Domain Join is Enabled ---
if (-not $DomainJoinEnabled) {
    Write-Host "Domain Join is disabled in configuration. Skipping domain join."
    Write-Host "Domain Join script finished."
    exit 0
}

# --- Domain Join Logic ---
Write-Host "Joining domain: $($DomainName)"
if ($DomainIP) {
    Write-Host "Using Domain IP: $($DomainIP)"
}
Write-Host "Using OU Path: $($OUPath)"
Write-Host "Using Username: $($Username)"

try {
    if ($DomainIP) {
        # Join domain with IP specified
        Write-Host "Attempting to join domain $($DomainName) using IP $($DomainIP)"
        $credential = Get-Credential -UserName $Username -Message "Enter domain credentials for $($Username)"
        Add-Computer -DomainName $DomainName -DomainController $DomainIP -Credential $credential -OUPath $OUPath -Restart -ErrorAction Stop
    } else {
        # Standard domain join
        Write-Host "Attempting to join domain $($DomainName)"
        $credential = Get-Credential -UserName $Username -Message "Enter domain credentials for $($Username)"
        Add-Computer -DomainName $DomainName -Credential $credential -OUPath $OUPath -Restart -ErrorAction Stop
    }
    Write-Host "Successfully joined domain $($DomainName)."
}
catch {
    Write-Error "Error joining domain: $_"
    Write-Warning "Domain join failed. Check error details and configuration."
    exit 1
}

Write-Host "Domain Join script finished."