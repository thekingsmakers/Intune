# Windows Image Deployment Tool

Automated deployment tool for Windows devices that runs after OS installation to configure system settings, install software, and join domains.

## Features

- Software package installation
- Hostname configuration
- Automatic WiFi setup
- Windows activation
- Optional Windows features installation
- Domain join capability
- Configuration GUI for easy setup
- Detailed logging and error handling

## Project Structure

```
ImageDeployer/
├── autorun.inf              # Autorun configuration for USB
├── Deployment/
│   ├── Config/
│   │   └── deploy-config.xml    # Deployment configuration
│   ├── Scripts/
│   │   └── Deploy-Windows.ps1   # Main deployment script
│   ├── Logs/                    # Deployment logs
│   └── Installers/             # Software packages
├── SetupGUI/                   # Configuration interface
│   ├── MainForm.cs
│   ├── Program.cs
│   ├── SetupGUI.csproj
│   └── app.manifest
└── ImageDeployer.sln          # Visual Studio solution
```

## Requirements

- Windows 10 or later
- .NET 6.0 Runtime
- Administrative privileges
- USB drive for deployment

## Setup Instructions

1. Build the Solution:
   ```bash
   dotnet build ImageDeployer.sln --configuration Release
   ```

2. Prepare USB Drive:
   - Copy all files to USB root
   - Place software installers in `Deployment/Installers/`
   - Run SetupGUI.exe to configure deployment settings
   - Save Windows image to USB root

3. Deployment Process:
   - Boot from USB to install Windows
   - After installation, automated deployment will:
     1. Install configured software packages
     2. Set computer hostname
     3. Configure WiFi connection
     4. Activate Windows
     5. Install selected Windows features
     6. Join domain (if configured)

## Configuration Options

### Software Installation
- Place installers in `Deployment/Installers/`
- Support for silent installation arguments
- Automatic retry on failure

### Network Configuration
- WiFi SSID and password
- Connection verification
- Retry mechanism for reliability

### Domain Join
- Domain name
- Admin credentials
- Automatic verification
- Error recovery

### Windows Features
- Telnet Client
- Microsoft Hyper-V
- Windows Subsystem for Linux
- .NET Framework 3.5
- Additional features configurable

## Error Handling

- Detailed logging in `Deployment/Logs/`
- Non-blocking errors for non-critical components
- Automatic retry mechanisms
- Clear error messages and status updates

## Security Considerations

- Runs with administrative privileges
- Secure credential handling
- Configuration file validation
- Error recovery mechanisms

## Development

### Building from Source
```bash
git clone [repository-url]
cd ImageDeployer
dotnet restore
dotnet build
```

### Adding Features
1. Update `deploy-config.xml` schema
2. Add GUI controls to `MainForm.cs`
3. Implement feature in `Deploy-Windows.ps1`
4. Test thoroughly before deployment

## Troubleshooting

1. Check `Deployment/Logs/` for detailed error information
2. Verify administrative privileges
3. Ensure all required files are present
4. Validate configuration in XML file

## License

MIT License - Feel free to modify and distribute

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request