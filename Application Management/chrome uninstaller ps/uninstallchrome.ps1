# Function to uninstall using registry
function Uninstall-ChromeUsingRegistry {
    Write-Output "Checking registry for Google Chrome uninstall string..."

    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($path in $uninstallPaths) {
        Write-Output "Checking path: $path"
        $subKeys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
        foreach ($subKey in $subKeys) {
            $displayName = (Get-ItemProperty -Path $subKey.PSPath -ErrorAction SilentlyContinue).DisplayName
            if ($displayName -like "*Google Chrome*") {
                Write-Output "Found Google Chrome in registry: $displayName"
                $uninstallString = (Get-ItemProperty -Path $subKey.PSPath -ErrorAction SilentlyContinue).UninstallString
                if ($uninstallString) {
                    Write-Output "Uninstall string found: $uninstallString"
                    $uninstallString = $uninstallString -replace '\"', ''
                    $uninstallString += " --force-uninstall --system-level"
                    try {
                        Write-Output "Uninstalling Google Chrome using registry..."
                        Start-Process -FilePath "cmd.exe" -ArgumentList "/c $uninstallString" -NoNewWindow -Wait
                        Write-Output "Google Chrome has been successfully uninstalled using registry."
                        return $true
                    } catch {
                        Write-Output "Failed to uninstall Google Chrome using registry: $_"
                    }
                }
            }
        }
    }
    Write-Output "Google Chrome not found in registry."
    return $false
}

# Function to uninstall using WMIC
function Uninstall-ChromeUsingWMIC {
    Write-Output "Trying to uninstall Google Chrome using WMIC..."
    try {
        $chrome = wmic product where "name like 'Google Chrome%'" call uninstall /nointeractive
        if ($chrome.ReturnValue -eq 0) {
            Write-Output "Google Chrome has been successfully uninstalled using WMIC."
            return $true
        } else {
            Write-Output "Failed to uninstall Google Chrome using WMIC. ReturnValue: $($chrome.ReturnValue)"
        }
    } catch {
        Write-Output "Failed to uninstall Google Chrome using WMIC: $_"
    }
    return $false
}

# Function to uninstall using Get-AppPackage
function Uninstall-ChromeUsingAppPackage {
    Write-Output "Trying to uninstall Google Chrome using Get-AppPackage..."
    try {
        $chromePackage = Get-AppxPackage -Name "*GoogleChrome*" -ErrorAction SilentlyContinue
        if ($chromePackage) {
            Write-Output "Found Google Chrome package: $($chromePackage.PackageFullName)"
            Remove-AppxPackage -Package $chromePackage.PackageFullName
            Write-Output "Google Chrome has been successfully uninstalled using Get-AppPackage."
            return $true
        } else {
            Write-Output "Google Chrome package not found using Get-AppPackage."
        }
    } catch {
        Write-Output "Failed to uninstall Google Chrome using Get-AppPackage: $_"
    }
    return $false
}

# Main script logic
$uninstalled = $false

# Try to uninstall using registry
Write-Output "Starting uninstallation process..."
if (-not $uninstalled) {
    $uninstalled = Uninstall-ChromeUsingRegistry
}

# Try to uninstall using WMIC if registry method fails
if (-not $uninstalled) {
    $uninstalled = Uninstall-ChromeUsingWMIC
}

# Try to uninstall using Get-AppPackage if WMIC method fails
if (-not $uninstalled) {
    $uninstalled = Uninstall-ChromeUsingAppPackage
}

if (-not $uninstalled) {
    Write-Output "Failed to uninstall Google Chrome using all methods."
} else {
    Write-Output "Google Chrome has been successfully uninstalled."
}
