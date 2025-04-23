# AzureAD Module Checker and Installer

This PowerShell snippet ensures that the correct version (`2.0.2.140`) of the **AzureAD** module is installed on the system before proceeding with the rest of your script. If the module is missing or a different version is installed, it will:

1. Uninstall all existing versions of the `AzureAD` module.
2. Install the required version (`2.0.2.140`).

## Usage

Copy and paste the script below at the **top** of your PowerShell script:

```powershell
# Ensure AzureAD module version 2.0.2.140 is installed
$requiredModule = "AzureAD"
$requiredVersion = "2.0.2.140"

$installedModule = Get-InstalledModule -Name $requiredModule -ErrorAction SilentlyContinue

if ($null -eq $installedModule -or $installedModule.Version.ToString() -ne $requiredVersion) {
    Write-Host "Ensuring $requiredModule version $requiredVersion is installed..." -ForegroundColor Yellow

    if ($installedModule) {
        Write-Host "Uninstalling existing version: $($installedModule.Version)" -ForegroundColor Cyan
        Uninstall-Module -Name $requiredModule -AllVersions -Force
    }

    Write-Host "Installing version $requiredVersion..." -ForegroundColor Cyan
    Install-Module -Name $requiredModule -RequiredVersion $requiredVersion -Force -AllowClobber
} else {
    Write-Host "$requiredModule version $requiredVersion is already installed." -ForegroundColor Green
}
```

## Requirements

- PowerShell 5.1 or later
- Administrator privileges (for installing/uninstalling modules)
- Internet access (to download the module from the PowerShell Gallery)

## Notes

- If running in a restricted environment (e.g., without internet access), ensure the required module is available from an internal repository.
- You can modify the version in the script if you want to enforce a different one.

---

# Or you can do the following 
- run the below in powershell and run the new bulkprimary user removal script

```powershell
 
Uninstall-Module -Name AzureAD
Install-Module AzureAD -RequiredVersion 2.0.2.140

```
