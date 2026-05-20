# Usage Guide

## Overview

The **USBBOOT** project provides a fully automated Windows 10/11 installation solution that uses Azure AutoPilot for device provisioning. The entire process is zero‑interaction after booting from a USB drive.

This guide walks you through the steps required to use the project.

## 1. Prerequisites

| Item | Description |
|------|-------------|
| Windows ISO | Windows 10 or 11 ISO file (64‑bit) |
| USB Drive | Minimum 8 GB, USB 3.0 preferred |
| Azure AD Tenant | Azure Active Directory tenant ID |
| Azure AD App | App registration with **DeviceManagementService** permissions |
| Office 365 Deployment Tool | Optional, for Office installation |
| WiFi Profile | Optional, for auto‑connect during installation |
| Application Installers | Adobe Acrobat, Chrome Enterprise, WinRAR, Notepad++, etc. |

## 2. Configure the Project

1. **Edit AutoPilot credentials**
   ```powershell
   # AutoPilot-RegisterDevice.ps1
   $Tenant = "your-tenant-id"
   $clientid = "your-app-id"
   $clientSecret = "your-client-secret"
   $grouptag = "TSUpload"
   $teamsURI = "https://..."   # optional
   $alerts = $false
   ```

2. **Export WiFi profile** (optional)
   ```powershell
   netsh wlan export profile name="YourSSID" key=clear folder="C:\Temp"
   cp C:\Temp\WiFi-YourSSID.xml C:\Path\To\AutoPilot\home.xml
   ```

3. **Prepare Office 365** (optional)
   - Download the Office Deployment Tool.
   - Extract `setup.exe` to `Office/`.
   - Create `Configuration.xml` in `Office/`.

4. **Add application installers** to `Apps/`.

## 3. Create a Bootable USB

### Using Rufus (Windows)
1. Download and run Rufus.
2. Select your USB drive.
3. Choose the Windows ISO.
4. Click **START**.
5. After Rufus finishes, copy the entire `USBBOOT-main` folder to the USB root.

### Using Media Creation Tool (Windows)
1. Run the Media Creation Tool.
2. Create a bootable USB.
3. Copy the entire `USBBOOT-main` folder to the USB root.

### Using `dd` (Linux/macOS)
```bash
diskutil list
# Identify USB device (e.g., /dev/disk2)
# Unmount
diskutil unmountDisk /dev/disk2
# Write ISO
sudo dd if=windows.iso of=/dev/rdisk2 bs=4m
sudo diskutil eject /dev/disk2
# Copy project folder to USB root
```

## 4. Deploy

1. Insert the USB into the target machine.
2. Boot and press **F12** (or the appropriate key) to open the boot menu.
3. Select the USB drive.
4. The Windows installer will start automatically.
5. The installation proceeds with no user interaction.
6. After the first reboot, the device will be registered with Azure AutoPilot and ready for administrator provisioning.

## 5. Logs & Troubleshooting

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

## 6. Advanced Customization

- **Custom OOBE settings** – Edit `sources/$OEM$/$$/Panther/unattend.xml`.
- **Custom Office installation** – Modify `Office/Configuration.xml`.
- **Add more applications** – Edit `Provisioning.ps1` to include additional installers.

## 7. Support & Documentation

- [Windows Unattend Reference](https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/)
- [AutoPilot Documentation](https://docs.microsoft.com/en-us/windows/deployment/windows-autopilot/)
- [Office Deployment Tool Guide](https://docs.microsoft.com/en-us/deployoffice/overview-office-deployment-tool/)

---

**Created by**: thekingsmakers (Omar Osman Mahat)
**Last Updated**: May 20, 2026
