# Windows Unattended Installation & AutoPilot Setup Guide

## Overview
This USB boot image provides a fully automated Windows 10/11 installation with AutoPilot provisioning using three integrated scripts. No user interaction required after F12 boot.

## Structure

```
USBBOOT-main/
├── Autounattend.xml          # Unattended Windows install config
├── AutoPilot-Final.ps1       # Main orchestrator (WiFi + all 3 scripts)
├── AutoPilot/
│   ├── Script1.ps1           # Setup: Copy auxiliary files
│   ├── Script2.ps1           # Registration: AutoPilot hash upload
│   ├── Script6final.ps1      # Finalize: Sysprep + OOBE
│   ├── home.xml              # WiFi profile (optional)
│   ├── Scripts/              # AutoPilot helper scripts
│   ├── PackageManagement/    # NuGet provider
│   └── WindowsPowerShell/    # PowerShell modules
├── Office/
│   ├── setup.exe             # Office 365 installer
│   └── Configuration.xml     # Office install config
├── Apps/                     # Third-party app installers
├── scripts/
│   ├── connectwifi.bat       # WiFi connection (legacy)
│   ├── kingsmakersactivator.bat
│   ├── thekingsmakers.bat
│   └── home.xml              # WiFi profile
└── sources/
    └── $OEM$/
        └── $$/
            ├── Panther/
            │   └── unattend.xml
            └── Setup/
                └── Scripts/
                    ├── SetupComplete.cmd
                    └── Provisioning.ps1
```

## Before You Start

### 1. Configure AutoPilot Credentials
Edit `/AutoPilot/Script2.ps1` and fill in:
- `$Tenant` - Your Azure AD Tenant ID
- `$clientid` - App Registration Client ID
- `$clientSecret` - App Registration Client Secret
- `$teamsURI` - (Optional) Teams webhook for alerts

### 2. Export WiFi Profile (Optional but Recommended)
If you want automatic WiFi connection during installation:

```powershell
# Run on admin PowerShell on any Windows machine
netsh wlan export profile name="YourSSID" key=clear folder="C:\Temp"
```

Place the exported XML file as `/AutoPilot/home.xml`

### 3. Prepare Office 365
- Download Office 365 using [Office Deployment Tool](https://www.microsoft.com/en-us/download/details.aspx?id=49117)
- Extract `setup.exe` to `/Office/`
- Place/create `Configuration.xml` in `/Office/`

### 4. Add Application Installers
Place installers in `/Apps/`:
- Adobe Reader DC
- Google Chrome Enterprise
- WinRAR
- Notepad++
- Any other required applications

## Execution Flow

### Boot Flow
1. **Boot from USB with F12**
2. **Windows PE** - Autounattend.xml runs:
   - Partitions disk (EFI, MSR, C:)
   - Installs Windows image to C: drive
3. **Windows Setup** - Applies settings:
   - Skips OOBE screens (SkipMachineOOBE, SkipUserOOBE)
   - Sets locale/language
4. **First Logon** - Runs PowerShell scripts:
   - AutoPilot-Final.ps1 is executed
   - **Calls Script1.ps1** → Copies auxiliary files
   - **Calls Script2.ps1** → AutoPilot registration & hash upload
   - **Calls Script6final.ps1** → Sysprep + OOBE reset

### Script Details

**AutoPilot-Final.ps1** (Main Orchestrator)
- Auto-connects to WiFi (if home.xml present)
- Runs Script1, Script2, and Script6final in sequence
- Comprehensive error handling and logging

**Script1.ps1** (Setup)
- Copies Scripts, PackageManagement, WindowsPowerShell to ProgramFiles
- Prepares environment for AutoPilot registration

**Script2.ps1** (Registration)
- Requires internet connection (WiFi auto-connects first)
- Uploads device hash to AutoPilot
- Sends Teams notification (if configured)
- Registers device with Azure AD

**Script6final.ps1** (Finalization)
- Removes DeviceManageabilityCSP registry key
- Runs Sysprep with /oobe /reboot /quiet
- Device boots into fresh OOBE for normal provisioning

## Creating the Bootable USB

### Option 1: Rufus
1. Download Windows 10/11 ISO
2. Use Rufus with MBR/UEFI settings
3. Copy entire USBBOOT-main folder to USB root

### Option 2: Windows Media Creation Tool
1. Create bootable USB with Windows ISO
2. Copy entire USBBOOT-main folder to USB root

## Deployment

1. Insert USB into target machine
2. Boot with F12/F2/DEL (depends on manufacturer)
3. Select USB boot
4. **Walk away** - Installation is fully automated

## Logs & Troubleshooting

**Provisioning Log**
```
C:\Windows\Temp\ProvisioningLog.txt
```

**Sysprep Log**
```
C:\Windows\Temp\Sysprep.log
```

**AutoPilot Registration Log**
```
C:\Windows\Temp\AutoPilotRegistration.log
```

## Common Issues

**WiFi Not Auto-Connecting**
- Ensure `home.xml` is present in `/AutoPilot/`
- Check WiFi credentials in the XML file
- Verify SSID is correctly extracted

**AutoPilot Registration Fails**
- Verify credentials in Script2.ps1
- Check internet connectivity (WiFi should auto-connect first)
- Verify app registration has correct permissions in Azure AD

**Sysprep Fails**
- Check for antivirus interference
- Ensure sufficient disk space (min 10GB)
- Check registry permissions

## Notes

- All scripts run with `-ExecutionPolicy Bypass`
- Logging is enabled for all phases
- Error handling ensures installation continues despite minor failures
- WiFi profile is optional; installation continues without it
- No user interaction required after F12 boot

## Support

For issues with specific components:
- **Windows Setup**: Check `Autounattend.xml` syntax
- **AutoPilot**: Verify Azure AD configuration
- **Scripts**: Check individual script logs in C:\Windows\Temp\
