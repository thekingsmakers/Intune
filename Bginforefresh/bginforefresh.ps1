# ============================================================================
# Apply-BGInfo.ps1
# Direct PowerShell equivalent of Apply_BGInfo.bat
# Must run in USER CONTEXT (logon / interactive session)
# ============================================================================

$ErrorActionPreference = 'SilentlyContinue'

# -- Configuration ----------------------------------------------------------
$ScriptDir = "C:\ProgramData\BginfoRefresh"
$BGINFO_EXE = "$ScriptDir\Bginfo64.exe"
$BGINFO_CFG = "$ScriptDir\hostname.bgi"
$LogFile    = "$env:TEMP\bginfo_apply.log"
# --------------------------------------------------------------------------

# -- 1. Accept BGInfo EULA silently -----------------------------------------
reg.exe add "HKU\.DEFAULT\Software\Sysinternals\BGInfo" /v EulaAccepted /t REG_DWORD /d 1 /f | Out-Null
reg.exe add "HKCU\Software\Sysinternals\BGInfo"         /v EulaAccepted /t REG_DWORD /d 1 /f | Out-Null

# -- 2. Kill any existing BGInfo instance -----------------------------------
Get-Process Bginfo,Bginfo64 -ErrorAction SilentlyContinue | Stop-Process -Force

# -- 3. DUPLICATE-TEXT FIX (IDENTICAL LOGIC TO BAT) --------------------------

# Read OriginalWallpaper saved by Windows
$OrigWallpaper = (Get-ItemProperty `
    -Path "HKCU:\Control Panel\Desktop" `
    -Name "OriginalWallpaper" `
    -ErrorAction SilentlyContinue).OriginalWallpaper

# Restore ONLY if it exists on disk
if ($OrigWallpaper -and (Test-Path $OrigWallpaper)) {

    Add-Type @"
using System.Runtime.InteropServices;
public class WP {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern int SystemParametersInfo(
        int action, int param, string path, int flags);
}
"@

    # SPI_SETDESKWALLPAPER = 20
    [WP]::SystemParametersInfo(20, 0, $OrigWallpaper, 0) | Out-Null
}

# -- 4. Run BGInfo immediately (USER SESSION) -------------------------------
& $BGINFO_EXE $BGINFO_CFG /TIMER:00 /silent /nolicprompt

# -- 5. Audit log (same as BAT) ---------------------------------------------
Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - BGInfo applied on $env:COMPUTERNAME by $env:USERNAME"

exit 0


