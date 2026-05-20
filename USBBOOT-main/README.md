A USB Boot Project for Fully Automated Installation & AutoPilot Provisioning

A complete, production-ready USB bootable image for fully automated Windows 10/11 installation with Azure AutoPilot provisioning. **Zero user interaction after F12 boot.**

A complete, production-ready USB bootable image for fully automated Windows 10/11 installation with Azure AutoPilot provisioning. **Zero user interaction after F12 boot.**

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Directory Structure](#directory-structure)
- [Configuration](#configuration)
- [Execution Flow](#execution-flow)
- [Scripts](#scripts)
- [Creating a Bootable USB](#creating-a-bootable-usb)
- [Deployment](#deployment)
- [Logs & Troubleshooting](#logs--troubleshooting)
- [Advanced Customization](#advanced-customization)
- [Support & Documentation](#support--documentation)
- [License](#license)

1. **Windows unattended install** – No OOBE screens.
2. **WiFi auto‑connect** – Optional, uses a pre‑exported profile.
3. **Azure AutoPilot registration** – Device hash upload and group tagging.
4. **Copy to bootable USB** using Rufus or Media Creation Tool
5. **Boot with F12** and walk away

## Overview

The project automates the entire Windows installation and provisioning process:

1. **Windows unattended install** – No OOBE screens.
2. **WiFi auto‑connect** – Optional, uses a pre‑exported profile.
3. **Azure AutoPilot registration** – Device hash upload and group tagging.
✅ **Multi-Pass Provisioning** - Setup, Registration, and Finalization
✅ **Comprehensive Logging** - All steps logged to `C:\Windows\Temp\`
✅ **Error Handling** - Graceful failure recovery

## Directory Structure

```
├── Autounattend.xml              # Windows unattended install configuration
├── Main-Orchestrator.ps1          # Main orchestrator script
├── AutoPilot/
│   ├── Setup-CopyFiles.ps1       # Copies auxiliary files
│   ├── AutoPilot-RegisterDevice.ps1 # Registers device with Azure AutoPilot
│   ├── Finalize-Sysprep.ps1      # Runs Sysprep and cleans up
│   ├── home.xml                  # WiFi profile (optional)
│   ├── Scripts/                  # Helper scripts
│   ├── PackageManagement/        # NuGet provider
│   └── WindowsPowerShell/        # PowerShell modules
├── Office/
│   ├── setup.exe                 # Office 365 installer
│   └── Configuration.xml         # Office install settings
├── Apps/                         # Third‑party installers
├── scripts/
│   ├── connectwifi.bat           # Legacy WiFi batch script
│   ├── thekingsmakers.bat        # Legacy provisioning script
│   └── kingsmakersactivator.bat  # Legacy activation script
└── sources/
  └── $OEM$/$$/
    ├── Panther/unattend.xml  # Additional unattended settings
    └── Setup/Scripts/
      ├── SetupComplete.cmd # Runs after Windows setup
      ├── Provisioning.ps1  # Legacy provisioning (fallback)
      └── Main-Orchestrator.ps1
```

---

## Usage

1. **Prerequisites** – See the [Prerequisites](#prerequisites) section.
2. **Configure the Project** – Edit the AutoPilot credentials and optionally export a WiFi profile.
3. **Create a Bootable USB** – Use Rufus, Media Creation Tool, or `dd`.
4. **Deploy** – Insert USB, boot with F12, and let the installation run.
5. **Logs & Troubleshooting** – Refer to the logs section for common issues.
6. **Advanced Customization** – Modify unattended settings, Office config, or add apps.

### 1. Azure AutoPilot Credentials

Edit `AutoPilot/AutoPilot-RegisterDevice.ps1` and set:

```powershell
$Tenant = "your-tenant-id"
$clientid = "your-app-id"
$clientSecret = "your-client-secret"
$grouptag = "TSUpload"
$teamsURI = "https://..."   # optional
$alerts = $false
```

### 2. WiFi Profile (Optional)

Export a WiFi profile from any Windows machine:

```powershell
netsh wlan export profile name="YourSSID" key=clear folder="C:\Temp"
cp C:\Temp\WiFi-YourSSID.xml C:\Path\To\AutoPilot\home.xml
```

If omitted, the installation will continue without WiFi.

### 3. Office 365 (Optional)

Download the Office Deployment Tool, extract `setup.exe` to `Office/`, and create a `Configuration.xml` in the same folder.

### 4. Application Installers

Place installers in the `Apps/` folder. The provisioning script will silently install them.

---

## Execution Flow

1. **Boot** from the USB drive.
2. Windows installer runs `Autounattend.xml`.
3. After installation, `SetupComplete.cmd` launches `Main-Orchestrator.ps1`.
4. The orchestrator performs:
  - WiFi auto‑connect (if `home.xml` present)
  - Copy auxiliary files
  - Register device with AutoPilot
  - Run Sysprep and reboot
5. Device reboots into a fresh OOBE ready for administrator provisioning.

---

## Logs & Troubleshooting

| Log File | Purpose |
|----------|---------|
| `C:\Windows\Temp\ProvisioningLog.txt` | Main provisioning log |
| `C:\Windows\Temp\Sysprep.log` | Sysprep finalization log |
| `C:\Windows\Panther\setuperr.log` | Windows setup errors |
| `C:\Windows\Panther\setupact.log` | Windows setup actions |

### Common Issues

- **WiFi not auto‑connecting** – Verify `home.xml` is valid and contains the correct SSID.
- **AutoPilot registration fails** – Check internet connectivity, credentials, and app registration permissions.
- **Sysprep fails** – Ensure sufficient disk space and that antivirus is disabled.
- **Office/Apps not installing** – Verify installer paths and `Configuration.xml`.

---

## Advanced Customization

- **Custom OOBE settings** – Edit `sources/$OEM$/$$/Panther/unattend.xml`.
- **Custom Office installation** – Modify `Office/Configuration.xml`.
- **Add more applications** – Edit `Provisioning.ps1` to include additional installers.

---

## Support & Documentation

- [Windows Unattend Reference](https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/)
- [AutoPilot Documentation](https://docs.microsoft.com/en-us/windows/deployment/windows-autopilot/)
- [Office Deployment Tool Guide](https://docs.microsoft.com/en-us/deployoffice/overview-office-deployment-tool/)

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

Download [Office Deployment Tool](https://www.microsoft.com/en-us/download/details.aspx?id=49117):

```
1. Extract setup.exe to Office/ folder
2. Create/place Configuration.xml in Office/ folder
```

---

**Created by**: thekingsmakers (Omar Osman Mahat)  
**Last Updated**: May 20, 2026

Place installers in `Apps/` folder:
- Adobe Acrobat Reader DC
- Google Chrome Enterprise (or any browser)
- WinRAR
- Notepad++
- Any other required applications

Applications are installed silently in `Provisioning.ps1`.

## Execution Flow

### Phase 1: Windows PE (Boot)
```
Boot with F12 → Select USB → Autounattend.xml runs
↓
Disk partitioning (EFI, MSR, C:)
↓
Windows installation to C: drive
```

### Phase 2: Windows Setup (Specialize)
```
Windows setup phase
↓
SkipMachineOOBE = true → Skip machine setup
SkipUserOOBE = true → Skip user setup
↓
No OOBE screens shown
```

### Phase 3: First Logon (OOBE System)
```
Windows first logon
↓
SetupComplete.cmd runs
↓
AutoPilot-Final.ps1 launches
```

### Phase 4: AutoPilot Provisioning (Orchestrator)
```
AutoPilot-Final.ps1 starts
↓
Step 1: WiFi Auto-Connect (if home.xml present)
Step 2: Script1.ps1 → Copy auxiliary files to ProgramFiles
Step 3: Script2.ps1 → AutoPilot registration & hash upload
Step 4: Script6final.ps1 → Sysprep with /oobe /reboot
↓
Device reboots and awaits administrator provisioning
```

## Script Details

### AutoPilot-Final.ps1 (Main Orchestrator)
- **Purpose**: Coordinates all provisioning steps
- **Features**: WiFi auto-connect, error handling, comprehensive logging
- **Location**: `C:\Setup\Scripts\AutoPilot-Final.ps1` (during Windows setup)
- **Logs**: `C:\Windows\Temp\ProvisioningLog.txt`

### Script1.ps1 (Setup)
- **Purpose**: Prepares environment by copying auxiliary files
- **Actions**:
  - Copies `Scripts/` → `%ProgramFiles%\Scripts\`
  - Copies `PackageManagement/` → `%ProgramFiles%\PackageManagement\`
  - Copies `WindowsPowerShell/` → `%ProgramFiles%\WindowsPowerShell\`

### Script2.ps1 (Registration) ⚠️ REQUIRES INTERNET
- **Purpose**: Registers device with Azure AutoPilot
- **Requirements**:
  - Active internet connection (WiFi auto-connects first)
  - Valid Azure AD credentials configured
  - App registration with appropriate permissions
- **Actions**:
  - Time synchronization with NTP
  - Device serial number collection
  - AutoPilot hash upload
  - (Optional) Teams notification
- **Logs**: Output to console + `C:\Windows\Temp\`

### Script6final.ps1 (Finalization)
- **Purpose**: Cleans up and prepares device for administrator provisioning
- **Actions**:
  - Removes DeviceManageabilityCSP registry key
  - Runs Sysprep with `/oobe /reboot /quiet`
  - Device reboots into fresh OOBE
- **Logs**: `C:\Windows\Temp\Sysprep.log`

## Creating Bootable USB

### Method 1: Rufus (Windows)
1. Download [Rufus](https://rufus.ie/)
2. Download Windows 10/11 ISO
3. Open Rufus:
   - Select USB drive
   - Select Windows ISO
   - Partition scheme: MBR or GPT (both work)
   - Click START
4. When complete, copy entire `USBBOOT-main` folder to USB root

### Method 2: Media Creation Tool
1. Download [Windows Media Creation Tool](https://www.microsoft.com/en-us/software-download/windows10)
2. Create bootable USB
3. Copy entire `USBBOOT-main` folder to USB root

### Method 3: Linux/macOS
```bash
# Identify USB device
diskutil list

# Unmount USB
diskutil unmountDisk /dev/diskX

# Write ISO
sudo dd if=windows.iso of=/dev/rdiskX bs=4m
sudo diskutil eject /dev/diskX

# Copy USBBOOT-main folder to USB root
```

## Deployment

1. **Insert USB** into target machine
2. **Boot with F12** (varies by manufacturer: F2, DEL, ESC, etc.)
3. **Select USB Boot** from boot menu
4. **Walk away** ☕ (20-30 minutes depending on hardware)

Device automatically:
- Partitions disk
- Installs Windows
- Connects to WiFi
- Registers with AutoPilot
- Prepares for administrator provisioning

## Logs & Troubleshooting

### Important Log Files

```
C:\Windows\Temp\ProvisioningLog.txt      # Main provisioning log
C:\Windows\Temp\Sysprep.log              # Sysprep finalization log
C:\Windows\Panther\setuperr.log          # Windows setup errors
C:\Windows\Panther\setupact.log          # Windows setup actions
```

### Common Issues

**❌ WiFi Not Auto-Connecting**
- Verify `AutoPilot/home.xml` exists and is valid XML
- Check WiFi SSID and password in profile
- Review `ProvisioningLog.txt` for WiFi errors

**❌ AutoPilot Registration Fails**
- Verify internet connectivity (WiFi should auto-connect)
- Check credentials in `Script2.ps1`
- Verify app registration has **Write** permissions in Azure AD
- Check device serial number appears in logs
- Verify tenant ID matches your organization

**❌ Sysprep Fails During Finalization**
- Antivirus software interference → disable temporarily
- Insufficient disk space → requires min 10GB free
- Registry corruption → check `Sysprep.log`
- Run as System account required

**❌ Office/Apps Not Installing**
- Verify installers are in `Apps/` and `Office/` folders
- Check `Provisioning.ps1` for app paths
- Review `ProvisioningLog.txt` for installation errors

## Advanced Customization

### Custom OOBE Settings
Edit `sources/$OEM$/$$/Panther/unattend.xml` to customize:
- Language, locale, keyboard layout
- Product key (optional)
- User accounts
- Network settings

### Custom Office Installation
Modify `Office/Configuration.xml` to specify:
- Language packages
- Component exclusions (Teams, Groove, Lync, etc.)
- Update channels (Monthly, Semi-Annual, etc.)

### Add More Applications
Edit `sources/$OEM$/$$/Setup/Scripts/Provisioning.ps1` to add app installation logic:

```powershell
# Add your app installer
Start-Process "C:\Apps\YourApp.exe" -ArgumentList "/silent /norestart" -Wait
```

## Notes & Best Practices

- ✅ All scripts run with `-ExecutionPolicy Bypass` for automation
- ✅ Comprehensive error handling ensures installation continues despite minor failures
- ✅ WiFi profile is optional; installation continues without it
- ✅ Logs are preserved for troubleshooting
- ✅ No user interaction required after boot
- ⚠️ Device requires internet for AutoPilot registration
- ⚠️ Azure AD app registration must have appropriate permissions
- ⚠️ First device provisioning may take 20-30 minutes

## Support & Documentation

- [Windows Unattend Reference](https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/)
- [AutoPilot Documentation](https://docs.microsoft.com/en-us/windows/deployment/windows-autopilot/)
- [Office Deployment Tool Guide](https://docs.microsoft.com/en-us/deployoffice/overview-office-deployment-tool)

---

**Created By**: thekingsmakers (Omar Osman Mahat)  
**Last Updated**: May 20, 2026  
**Status**: Production Ready
