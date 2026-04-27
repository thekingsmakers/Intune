# 🚀 AutoPilot Device Provisioning Toolset

A robust suite of PowerShell scripts designed to automate the gathering and uploading of Windows Autopilot hardware hashes to Microsoft Intune, with integrated system preparation and cleanup routines.

---

## 📖 Overview

This toolset simplifies the device enrollment process for Microsoft Intune by automating several manual steps. It handles everything from initial file setup and time synchronization to hardware hash uploading and final system preparation (Sysprep).

### Key Features
- **Automated Setup**: Installs necessary scripts and modules to standard system paths.
- **Robust Authentication**: Uses app-based authentication (Client ID/Secret) for seamless Intune connectivity.
- **Intelligent Time Sync**: Automatically corrects system clock skews (common in VMs) using both NTP and Web-based fallback to prevent authentication failures.
- **Post-Upload Cleanup**: Automates SCCM client removal and system preparation for the next user.

---

## 🛠️ Components

| Script | Description |
| :--- | :--- |
| **`Script1.ps1`** | **Deployment**: Copies the toolset and required modules to `C:\Program Files\Scripts`. |
| **`Script2.ps1`** | **Execution**: The main engine. Syncs time, authenticates to Intune, and uploads the hardware hash. |
| **`Script3.ps1`** | **Finalization**: Uninstalls SCCM, cleans registry keys, and runs `Sysprep /oobe /reboot`. |
| **`Get-WindowsAutoPilotInfo.ps1`** | **Core Logic**: The specialized script that gathers hardware data and communicates with Graph API. |

---

## 🚀 Getting Started

### Prerequisites
- Windows 10/11 device.
- PowerShell 5.1 or higher (run as **Administrator**).
- Internet connectivity.
- Azure AD App Registration with `DeviceManagementServiceConfig.ReadWrite.All` permissions.

### Usage Instructions

1. **Deploy the scripts**:
   Run `Script1.ps1` to install the toolset to the local machine.
   ```powershell
   .\Script1.ps1
   ```

2. **Upload Hardware Hash**:
   Run `Script2.ps1` to register the device with your Intune tenant.
   ```powershell
   .\Script2.ps1
   ```
   *Note: This script will automatically synchronize your system time to ensure the authentication token is valid.*

3. **Prepare for OOBE**:
   Run `Script3.ps1` to clean up the device and prepare it for the end user.
   ```powershell
   .\Script3.ps1
   ```

---

## 🔧 Troubleshooting

### Authentication Errors ("Token Expired")
If you see errors regarding expired tokens, the script now includes a **Robust Time Sync** engine. It will attempt to:
1. Sync with `time.windows.com`.
2. Fallback to an HTTP header sync from `login.microsoftonline.com` if the system clock is still off by >2 minutes.

### Module Dependencies
`Script2.ps1` will automatically attempt to install the `WindowsAutopilotIntune` and `Microsoft.Graph` modules if they are missing.

---

