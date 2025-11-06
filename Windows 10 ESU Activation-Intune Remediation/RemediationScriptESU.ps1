<#
.SYNOPSIS
    Installs a Windows ESU (Extended Security Update) MAK key silently for Intune remediation.

.DESCRIPTION
    This script installs the provided ESU key using slmgr.vbs. It is designed for use as a remediation script in Microsoft Intune.

.NOTES
    Author: Omar Mahat (Thekingsmakers)
    Date: 2025-11-06
#>

# Replace with your actual ESU key
$ESU_KEY = "XXXX-XXXXX-XXXX-XXXX-XXXXX" #insert your ESU License Here

# Validate key format
if ($ESU_KEY -match "^[A-Z0-9]{5}(-[A-Z0-9]{5}){4}$") {
    try {
        $installResult = cscript.exe /nologo "$env:SystemRoot\system32\slmgr.vbs" /ipk $ESU_KEY 2>&1
        # Optional: log output to file if needed
        # $installResult | Out-File "$env:ProgramData\ESUKeyInstall.log" -Append
    }
    catch {
        # Optional: log error to file if needed
        # $_ | Out-File "$env:ProgramData\ESUKeyInstall_Error.log" -Append
    }
}