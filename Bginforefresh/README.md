# BGInfo Intune Deployment Package

This package is designed to deploy Sysinternals BGInfo via Microsoft Intune to end-user workstations. It automatically applies standardized desktop wallpapers containing critical system information.

## Contents
* `Bginfo64.exe`: The 64-bit executable for Sysinternals BGInfo.
* `hostname.bgi`: The binary configuration template dictating what information is displayed.
* `bginforefresh.ps1`: The core execution script that accepts the EULA, handles duplicate text glitches, and runs BGInfo.
* `Install-Bginfo.ps1`: The Intune deployment wrapper script.
* `Uninstall-Bginfo.ps1`: The uninstallation script.

## How it Works
When deployed via Intune, `Install-Bginfo.ps1` runs under the SYSTEM context. It performs the following:
1. Creates a local directory at `C:\ProgramData\BginfoRefresh`.
2. Copies all necessary files into this hidden directory.
3. Registers a Scheduled Task named **"BGInfo User Refresh"**.
4. The Scheduled Task is configured to run automatically on three events:
   - User Logon
   - Session Lock
   - Session Unlock
5. Upon triggering, the task executes `bginforefresh.ps1` in the context of the interactive user, completely hidden from their view, bypassing strict execution policies via an memory-injection method.

## Intune Deployment Instructions
1. Package the entire directory using the **Microsoft Win32 Content Prep Tool** (`IntuneWinAppUtil.exe`).
   - Setup Folder: `(Path to this directory)`
   - Setup File: `Install-Bginfo.ps1`
2. Upload the `.intunewin` file to the Intune portal.
3. Configure the following parameters:
   - **Install Command**: `powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File .\Install-Bginfo.ps1`
   - **Uninstall Command**: `powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File .\Uninstall-Bginfo.ps1`
   - **Install Behavior**: `System`
   - **Detection Rule**:
     - Rule type: `File`
     - Path: `C:\ProgramData\BginfoRefresh`
     - File or folder: `bginforefresh.ps1`
     - Detection method: `File or folder exists`
