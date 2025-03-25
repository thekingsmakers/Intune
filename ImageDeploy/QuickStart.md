# Windows Deployment Tool - Quick Start Guide

## Overview
This tool automates Windows deployment tasks including software installation, system configuration, and domain joining.

## Prerequisites
- Windows 10 or later
- Administrator privileges
- .NET 6.0 Runtime
- PowerShell 5.0 or later
- Internet connection (for downloading dependencies)
- USB drive (8GB or larger)

## Quick Setup

### 1. Prepare USB Drive
```powershell
.\Deploy.ps1 -Action Prepare
```
- Select your USB drive
- Provide Windows ISO path
- Wait for completion

### 2. Configure Deployment Settings
```powershell
.\Deploy.ps1 -Action Setup
```
Configure:
- Computer hostname
- Software packages
- WiFi settings
- Windows activation key
- Domain join details
- Windows features

### 3. Start Deployment
1. Boot from USB
2. Install Windows
3. After installation completes:
```powershell
.\Deploy.ps1 -Action Deploy
```

### 4. Monitor Progress
```powershell
.\Deploy.ps1 -Action Monitor
```

## Common Tasks

### Test System Requirements
```powershell
.\Deploy.ps1 -Action Test
```

### Build Distribution Package
```powershell
.\Deploy.ps1 -Action Build
```

### Rollback Changes
```powershell
.\Deploy.ps1 -Action Rollback
```

## Interactive Menu
Launch without parameters to use the menu interface:
```powershell
.\Deploy.ps1
```

## Directory Structure
```
DeploymentTool/
├── Deployment/
│   ├── Config/          # Configuration files
│   ├── Scripts/         # Deployment scripts
│   ├── Logs/           # Operation logs
│   └── Installers/     # Software packages
├── SetupGUI/           # Configuration interface
├── Tools/              # Utility scripts
└── Deploy.ps1          # Main launcher
```

## Troubleshooting

### Common Issues

1. **Setup GUI won't launch**
   - Verify .NET 6.0 Runtime is installed
   - Run as administrator
   - Check event logs for errors

2. **Software installation fails**
   - Verify installer files in Deployment/Installers/
   - Check software prerequisites
   - Review logs in Deployment/Logs/

3. **Network configuration fails**
   - Verify WiFi adapter is present
   - Check WiFi credentials
   - Ensure network coverage

4. **Domain join fails**
   - Verify domain connectivity
   - Check domain credentials
   - Ensure computer name is unique

### Log Locations
- Deployment logs: `Deployment/Logs/Deployment.log`
- Rollback logs: `Deployment/Logs/Rollback-*.log`
- Test results: `Tests/test_results.log`

### Getting Help
1. Check detailed logs in the Logs directory
2. Run requirements test: `.\Deploy.ps1 -Action Test`
3. Review README.md for detailed documentation

## Best Practices
1. Always run system requirements test before deployment
2. Keep software installers up to date
3. Test deployment in a virtual machine first
4. Maintain backups before domain joining
5. Monitor deployment progress in real-time

## Security Notes
- Run all scripts as Administrator
- Secure domain credentials
- Remove deployment tools after completion
- Keep Windows activation keys secure
- Clean up logs containing sensitive data