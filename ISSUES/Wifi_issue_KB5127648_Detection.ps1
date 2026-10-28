# =====================================================================
# Intune Remediation Detection
#
# Checks:
#   1. Whether KB5127648 is installed
#   2. Whether BlockNtlmv1SSO exists
#   3. Whether BlockNtlmv1SSO is REG_DWORD
#   4. Whether BlockNtlmv1SSO = 0
#
# Logic:
#
# KB5127648 NOT installed
#     -> COMPLIANT
#        Registry workaround is not required by this detection.
#
# KB5127648 installed + BlockNtlmv1SSO = DWORD 0
#     -> COMPLIANT
#
# KB5127648 installed + registry missing/incorrect
#     -> NON-COMPLIANT
#     -> Intune remediation will run
#
# Exit 0 = Compliant
# Exit 1 = Non-Compliant
# =====================================================================

$TargetKB       = "KB5127648"
$RegistryPath   = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0"
$ValueName      = "BlockNtlmv1SSO"
$ExpectedValue  = 0

# ---------------------------------------------------------------------
# System Information
# ---------------------------------------------------------------------

try {
    $OS = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop

    $OSName        = $OS.Caption
    $OSVersion     = $OS.Version
    $OSBuild       = $OS.BuildNumber
    $ComputerName  = $env:COMPUTERNAME
}
catch {
    $OSName       = "Unknown"
    $OSVersion    = "Unknown"
    $OSBuild      = "Unknown"
    $ComputerName = $env:COMPUTERNAME
}

Write-Output "============================================================"
Write-Output "INTUNE DETECTION - KB5127648 / BlockNtlmv1SSO"
Write-Output "============================================================"
Write-Output "Computer Name : $ComputerName"
Write-Output "Operating OS  : $OSName"
Write-Output "OS Version    : $OSVersion"
Write-Output "OS Build      : $OSBuild"
Write-Output "Target Update : $TargetKB"
Write-Output "------------------------------------------------------------"


# ---------------------------------------------------------------------
# CHECK 1 - KB5127648
# ---------------------------------------------------------------------

$KBInstalled = $false
$KBInstallDate = "Unknown"

try {

    $HotFix = Get-HotFix -Id $TargetKB -ErrorAction SilentlyContinue

    if ($null -ne $HotFix) {

        $KBInstalled = $true

        if ($HotFix.InstalledOn) {
            $KBInstallDate = $HotFix.InstalledOn
        }

        Write-Output "[PASS] Windows Update Detection"
        Write-Output "       Update      : $TargetKB"
        Write-Output "       Installed   : YES"
        Write-Output "       InstalledOn : $KBInstallDate"

    }
    else {

        Write-Output "[INFO] Windows Update Detection"
        Write-Output "       Update      : $TargetKB"
        Write-Output "       Installed   : NO"
    }
}
catch {

    Write-Output "[ERROR] Unable to query installed Windows updates."
    Write-Output "        Error: $($_.Exception.Message)"
    exit 1
}

Write-Output "------------------------------------------------------------"


# ---------------------------------------------------------------------
# If KB5127648 is NOT installed
# ---------------------------------------------------------------------

if (-not $KBInstalled) {

    Write-Output "RESULT"
    Write-Output "------------------------------------------------------------"
    Write-Output "Status        : COMPLIANT"
    Write-Output "KB5127648     : NOT INSTALLED"
    Write-Output "Registry Fix  : NOT REQUIRED"
    Write-Output "Action        : NONE"
    Write-Output ""
    Write-Output "Reason:"
    Write-Output "KB5127648 was not detected on this device."
    Write-Output "The BlockNtlmv1SSO workaround is therefore not required"
    Write-Output "by this remediation package."
    Write-Output "============================================================"

    exit 0
}


# ---------------------------------------------------------------------
# CHECK 2 - Registry Path
# ---------------------------------------------------------------------

Write-Output "[INFO] Checking registry workaround..."
Write-Output ""
Write-Output "Registry Path : $RegistryPath"
Write-Output "Value Name    : $ValueName"
Write-Output "Expected Type : REG_DWORD"
Write-Output "Expected Data : $ExpectedValue"
Write-Output ""

if (-not (Test-Path -Path $RegistryPath)) {

    Write-Output "[FAIL] Registry path does not exist."
    Write-Output ""
    Write-Output "RESULT"
    Write-Output "------------------------------------------------------------"
    Write-Output "Status        : NON-COMPLIANT"
    Write-Output "KB5127648     : INSTALLED"
    Write-Output "Registry Fix  : MISSING"
    Write-Output "Action        : REMEDIATION REQUIRED"
    Write-Output ""
    Write-Output "Reason:"
    Write-Output "$TargetKB is installed but the required registry"
    Write-Output "configuration could not be found."
    Write-Output "============================================================"

    exit 1
}


# ---------------------------------------------------------------------
# CHECK 3 - Registry Value
# ---------------------------------------------------------------------

try {

    $RegistryKey = Get-Item -Path $RegistryPath -ErrorAction Stop

    $ValueExists = $RegistryKey.GetValueNames() -contains $ValueName

    if (-not $ValueExists) {

        Write-Output "[FAIL] Registry value is missing."
        Write-Output ""
        Write-Output "Current Value : NOT CONFIGURED"
        Write-Output "Expected      : DWORD 0"
        Write-Output ""
        Write-Output "RESULT"
        Write-Output "------------------------------------------------------------"
        Write-Output "Status        : NON-COMPLIANT"
        Write-Output "KB5127648     : INSTALLED"
        Write-Output "Registry Fix  : MISSING"
        Write-Output "Action        : REMEDIATION REQUIRED"
        Write-Output ""
        Write-Output "Reason:"
        Write-Output "$TargetKB is installed and $ValueName is not configured."
        Write-Output "Intune remediation should create:"
        Write-Output ""
        Write-Output "BlockNtlmv1SSO = DWORD 0"
        Write-Output "============================================================"

        exit 1
    }


    # -----------------------------------------------------------------
    # Read current type/value
    # -----------------------------------------------------------------

    $CurrentValue = $RegistryKey.GetValue(
        $ValueName,
        $null,
        [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
    )

    $ValueKind = $RegistryKey.GetValueKind($ValueName)

    Write-Output "[INFO] Registry value found."
    Write-Output ""
    Write-Output "Current Type  : $ValueKind"
    Write-Output "Current Value : $CurrentValue"
    Write-Output "Expected Type : DWORD"
    Write-Output "Expected Value: $ExpectedValue"
    Write-Output ""


    # -----------------------------------------------------------------
    # CHECK 4 - Registry Type
    # -----------------------------------------------------------------

    if ($ValueKind -ne [Microsoft.Win32.RegistryValueKind]::DWord) {

        Write-Output "[FAIL] Registry type is incorrect."
        Write-Output ""
        Write-Output "RESULT"
        Write-Output "------------------------------------------------------------"
        Write-Output "Status        : NON-COMPLIANT"
        Write-Output "KB5127648     : INSTALLED"
        Write-Output "Registry Fix  : INCORRECT TYPE"
        Write-Output "Action        : REMEDIATION REQUIRED"
        Write-Output ""
        Write-Output "Current       : $ValueKind $CurrentValue"
        Write-Output "Expected      : DWORD $ExpectedValue"
        Write-Output "============================================================"

        exit 1
    }


    # -----------------------------------------------------------------
    # CHECK 5 - Registry Data
    # -----------------------------------------------------------------

    if ([int]$CurrentValue -ne $ExpectedValue) {

        Write-Output "[FAIL] Registry value is incorrect."
        Write-Output ""
        Write-Output "RESULT"
        Write-Output "------------------------------------------------------------"
        Write-Output "Status        : NON-COMPLIANT"
        Write-Output "KB5127648     : INSTALLED"
        Write-Output "Registry Fix  : INCORRECT VALUE"
        Write-Output "Action        : REMEDIATION REQUIRED"
        Write-Output ""
        Write-Output "Current       : DWORD $CurrentValue"
        Write-Output "Expected      : DWORD $ExpectedValue"
        Write-Output "============================================================"

        exit 1
    }


    # -----------------------------------------------------------------
    # Everything is correct
    # -----------------------------------------------------------------

    Write-Output "[PASS] Registry configuration is correct."
    Write-Output ""
    Write-Output "RESULT"
    Write-Output "------------------------------------------------------------"
    Write-Output "Status        : COMPLIANT"
    Write-Output "KB5127648     : INSTALLED"
    Write-Output "Registry Fix  : APPLIED"
    Write-Output "Action        : NONE"
    Write-Output ""
    Write-Output "Configuration:"
    Write-Output "$RegistryPath"
    Write-Output "$ValueName = DWORD $CurrentValue"
    Write-Output ""
    Write-Output "The required registry configuration is already present."
    Write-Output "============================================================"

    exit 0

}
catch {

    Write-Output "[ERROR] Unable to read registry configuration."
    Write-Output ""
    Write-Output "Error:"
    Write-Output $_.Exception.Message
    Write-Output ""
    Write-Output "RESULT"
    Write-Output "------------------------------------------------------------"
    Write-Output "Status        : NON-COMPLIANT"
    Write-Output "KB5127648     : INSTALLED"
    Write-Output "Registry Fix  : UNKNOWN"
    Write-Output "Action        : INVESTIGATION REQUIRED"
    Write-Output "============================================================"

    exit 1
}

