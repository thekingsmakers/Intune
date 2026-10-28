# =====================================================================
# Intune Remediation
#
# Purpose:
#   Configure BlockNtlmv1SSO as:
#
#   Path:
#   HKLM\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0
#
#   Value:
#   BlockNtlmv1SSO
#
#   Type:
#   REG_DWORD
#
#   Data:
#   0
#
# Detection script determines whether remediation is required.
#
# Exit 0 = Remediation successful
# Exit 1 = Remediation failed
# =====================================================================

$RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0"
$ValueName    = "BlockNtlmv1SSO"
$DesiredValue = 0

Write-Output "============================================================"
Write-Output "INTUNE REMEDIATION - BlockNtlmv1SSO"
Write-Output "============================================================"
Write-Output "Computer Name : $env:COMPUTERNAME"
Write-Output "Registry Path : $RegistryPath"
Write-Output "Value Name    : $ValueName"
Write-Output "Desired Type  : REG_DWORD"
Write-Output "Desired Value : $DesiredValue"
Write-Output "------------------------------------------------------------"


# ---------------------------------------------------------------------
# STEP 1 - Ensure registry path exists
# ---------------------------------------------------------------------

try {

    if (-not (Test-Path -Path $RegistryPath)) {

        Write-Output "[INFO] Registry path does not exist."
        Write-Output "[INFO] Creating registry path..."

        New-Item `
            -Path $RegistryPath `
            -Force `
            -ErrorAction Stop | Out-Null

        Write-Output "[SUCCESS] Registry path created."
    }
    else {
        Write-Output "[PASS] Registry path already exists."
    }

}
catch {

    Write-Output "[FAILED] Unable to create/access registry path."
    Write-Output "Error : $($_.Exception.Message)"
    Write-Output ""
    Write-Output "RESULT"
    Write-Output "------------------------------------------------------------"
    Write-Output "Status : REMEDIATION FAILED"
    Write-Output "Action : Registry path could not be created."
    Write-Output "============================================================"

    exit 1
}


# ---------------------------------------------------------------------
# STEP 2 - Determine current value
# ---------------------------------------------------------------------

try {

    $RegistryKey = Get-Item -Path $RegistryPath -ErrorAction Stop

    $ValueExists = $RegistryKey.GetValueNames() -contains $ValueName

    if ($ValueExists) {

        $CurrentValue = $RegistryKey.GetValue(
            $ValueName,
            $null,
            [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
        )

        $CurrentType = $RegistryKey.GetValueKind($ValueName)

        Write-Output ""
        Write-Output "[INFO] Existing registry value detected."
        Write-Output "       Current Type  : $CurrentType"
        Write-Output "       Current Value : $CurrentValue"
    }
    else {

        Write-Output ""
        Write-Output "[INFO] Registry value does not currently exist."
        Write-Output "       Current Type  : NOT CONFIGURED"
        Write-Output "       Current Value : NOT CONFIGURED"
    }

}
catch {

    Write-Output "[FAILED] Unable to inspect registry value."
    Write-Output "Error : $($_.Exception.Message)"
    exit 1
}


# ---------------------------------------------------------------------
# STEP 3 - Apply required configuration
# ---------------------------------------------------------------------

try {

    Write-Output ""
    Write-Output "[INFO] Applying required registry configuration..."

    #
    # New-ItemProperty -Force handles:
    #   - Missing value
    #   - Incorrect value
    #   - Incorrect registry type
    #

    New-ItemProperty `
        -Path $RegistryPath `
        -Name $ValueName `
        -PropertyType DWord `
        -Value $DesiredValue `
        -Force `
        -ErrorAction Stop | Out-Null

    Write-Output "[SUCCESS] Registry configuration applied."

}
catch {

    Write-Output "[FAILED] Unable to configure registry value."
    Write-Output "Error : $($_.Exception.Message)"

    Write-Output ""
    Write-Output "RESULT"
    Write-Output "------------------------------------------------------------"
    Write-Output "Status        : REMEDIATION FAILED"
    Write-Output "Registry Fix  : FAILED"
    Write-Output "Action        : INVESTIGATION REQUIRED"
    Write-Output "============================================================"

    exit 1
}


# ---------------------------------------------------------------------
# STEP 4 - Verify configuration
# ---------------------------------------------------------------------

try {

    $RegistryKey = Get-Item -Path $RegistryPath -ErrorAction Stop

    $FinalValue = $RegistryKey.GetValue(
        $ValueName,
        $null,
        [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
    )

    $FinalType = $RegistryKey.GetValueKind($ValueName)

    Write-Output ""
    Write-Output "------------------------------------------------------------"
    Write-Output "POST-REMEDIATION VERIFICATION"
    Write-Output "------------------------------------------------------------"
    Write-Output "Registry Path : $RegistryPath"
    Write-Output "Value Name    : $ValueName"
    Write-Output "Current Type  : $FinalType"
    Write-Output "Current Value : $FinalValue"
    Write-Output "Expected Type : DWord"
    Write-Output "Expected Value: $DesiredValue"

}
catch {

    Write-Output "[FAILED] Unable to verify registry configuration."
    Write-Output "Error : $($_.Exception.Message)"
    exit 1
}


# ---------------------------------------------------------------------
# STEP 5 - Final compliance result
# ---------------------------------------------------------------------

$TypeCorrect  = $FinalType -eq [Microsoft.Win32.RegistryValueKind]::DWord
$ValueCorrect = [int]$FinalValue -eq $DesiredValue

if ($TypeCorrect -and $ValueCorrect) {

    Write-Output ""
    Write-Output "[PASS] Post-remediation validation successful."
    Write-Output ""
    Write-Output "============================================================"
    Write-Output "FINAL RESULT"
    Write-Output "============================================================"
    Write-Output "Status        : REMEDIATED SUCCESSFULLY"
    Write-Output "Registry Fix  : APPLIED"
    Write-Output "Value Name    : $ValueName"
    Write-Output "Value Type    : REG_DWORD"
    Write-Output "Value Data    : $FinalValue"
    Write-Output "Action        : NONE"
    Write-Output "============================================================"

    exit 0
}
else {

    Write-Output ""
    Write-Output "[FAIL] Post-remediation validation failed."
    Write-Output ""
    Write-Output "============================================================"
    Write-Output "FINAL RESULT"
    Write-Output "============================================================"
    Write-Output "Status        : REMEDIATION FAILED"
    Write-Output "Registry Fix  : NOT APPLIED CORRECTLY"
    Write-Output "Current Type  : $FinalType"
    Write-Output "Current Value : $FinalValue"
    Write-Output "Expected Type : REG_DWORD"
    Write-Output "Expected Value: $DesiredValue"
    Write-Output "Action        : INVESTIGATION REQUIRED"
    Write-Output "============================================================"

    exit 1
}


