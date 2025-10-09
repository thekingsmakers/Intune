<#
Example detection and remediation snippet for Intune Win32 packaging.
Detection: return 0 when compliant, non-zero when remediation required.
Remediation: run the packaged updater script (commented example provided).
#>

param(
    [Parameter(Mandatory=$true)][string] $PackageFamilyName,
    [string] $DesiredVersion = ''
)

# If DesiredVersion provided, validate installed version; otherwise just check presence
if ($DesiredVersion) {
    $pkg = Get-AppxPackage -PackageFamilyName $PackageFamilyName -ErrorAction SilentlyContinue
    if ($pkg -and $pkg.Version -and ($pkg.Version.ToString() -ge $DesiredVersion)) { exit 0 } else { exit 1 }
} else {
    if (Get-AppxPackage -PackageFamilyName $PackageFamilyName -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }
}

# Remediation example (packaged call - uncomment when used as remediation):
# powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\TKM-Store-Apps-Update.ps1 -AppId "<PackageFamilyName>" -Force
