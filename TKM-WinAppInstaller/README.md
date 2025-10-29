# THE KINGSMAKERS WINAPP TOOL

## Overview
THE KINGSMAKERS WINAPP TOOL (TKM WINAPP TOOL) is a comprehensive Windows package management solution featuring advanced installation, uninstallation, upgrading, searching, and listing capabilities using multiple package managers with intelligent fallbacks.

Created by thekingsmakers | Website: thekingsmaker.org | Twitter: thekingsmakers

## Quick Start (GitHub Bootstrap)

### 1. Download the Bootstrap Script
Download `bootstrap.ps1` from this repository - it's the only file you need!

### 2. Run the Tool
```powershell
# List installed packages (downloads only required modules)
.\bootstrap.ps1 -List

# Install Visual Studio Code (downloads Install + related modules)
.\bootstrap.ps1 -Install vscode

# Uninstall Chrome with advanced cleanup (downloads Uninstall modules)
.\bootstrap.ps1 -Uninstall chrome

# Search for browsers (downloads Search modules)
.\bootstrap.ps1 -Search "browser"

# Upgrade Git and Node.js (downloads Upgrade modules)
.\bootstrap.ps1 -Upgrade "git,nodejs"
```

### 3. How It Works
- The bootstrap script downloads **only the modules needed** for your specific operation
- **First run** downloads core modules (Utils, Aliases)
- **Operation-specific** modules download as needed (Install, Uninstall, etc.)
- **Caching** prevents re-downloading modules you've already used
- All downloads happen automatically in the background

### 4. Example Workflow
```powershell
# First time - downloads Utils + Aliases modules
.\bootstrap.ps1 -List

# Downloads Install + Detection + PackageManagers + Winget + Chocolatey modules
.\bootstrap.ps1 -Install vscode

# Reuses cached modules, no new downloads needed
.\bootstrap.ps1 -Install git
```

## Features

### Core Operations
- ✅ **Install Software**: Install packages using multiple methods with automatic fallbacks (winget → choco → direct → PowerShell)
- ✅ **Advanced Uninstallation**: Intelligent package detection, multi-method uninstall (winget → choco → PowerShell advanced), registry cleanup, and file removal
- ✅ **Upgrade Software**: Upgrade existing packages to their latest versions with multiple fallbacks
- ✅ **Search Packages**: Search for available packages across all supported managers
- ✅ **List Installed**: Display currently installed packages from all managers
- ✅ **Package Information**: Get detailed information about specific packages

### Advanced Features
- ✅ **Multiple Package Managers**: Winget (Windows Package Manager), Chocolatey, PowerShell-native
- ✅ **Intelligent Fallbacks**: Automatic progression through alternative methods when primary fails
- ✅ **Package Detection**: Cross-manager package discovery with detailed information gathering
- ✅ **Registry Cleanup**: Automatic removal of leftover registry entries from multiple locations
- ✅ **File System Cleanup**: Smart removal of leftover directories and files
- ✅ **Parallel Processing**: Concurrent installation and upgrade operations
- ✅ **Package Aliases**: Friendly name mapping (e.g., "chrome" → "Google.Chrome")
- ✅ **Comprehensive Logging**: Configurable logging levels with file output
- ✅ **Elevation Handling**: Automatic admin privilege detection and requests

## Requirements

### System Requirements
- **Windows 7 SP1 or later**
- **PowerShell 3.0 or later** (included in Windows 7+)
- **Internet connection** (for downloading modules on first run)

### Optional Dependencies
- **Winget** (Windows Package Manager) - Recommended for best experience
- **Chocolatey** - Alternative package manager for additional packages

## Installation Options

### Option 1: Bootstrap Script (Recommended)
1. Download `bootstrap.ps1` from the releases
2. Run: `.\bootstrap.ps1 -List`
3. Script automatically downloads and loads all modules

### Option 2: Monolithic Script
1. Download `THEKINGSMAKERS-WINAPP-TOOL-MONOLITHIC.ps1`
2. Run directly: `.\THEKINGSMAKERS-WINAPP-TOOL-MONOLITHIC.ps1 -List`
3. All functionality included in single file

### Option 3: Directory Installation
1. Download ZIP from releases
2. Extract all files to a folder
3. Run `THEKINGSMAKERS-WINAPP-TOOL.exe`

## Usage Examples

### Basic Operations
```powershell
# List all installed packages
.\bootstrap.ps1 -List

# Search for available packages
.\bootstrap.ps1 -Search "vscode"

# Get package information
.\bootstrap.ps1 -Info "Google.Chrome"
```

### Installation
```powershell
# Install single package
.\bootstrap.ps1 -Install vscode

# Install multiple packages
.\bootstrap.ps1 -Install "git,nodejs,python" -Parallel

# Install with specific manager
.\bootstrap.ps1 -Install firefox -Manager winget

# Dry run (see what would be installed)
.\bootstrap.ps1 -Install chrome -DryRun
```

### Advanced Uninstallation
```powershell
# Smart uninstall with detection
.\bootstrap.ps1 -Uninstall chrome

# Force uninstall
.\bootstrap.ps1 -Uninstall vlc -Force

# Silent uninstall
.\bootstrap.ps1 -Uninstall notepad++ -Silent
```

### Upgrades
```powershell
# Upgrade single package
.\bootstrap.ps1 -Upgrade vscode

# Upgrade multiple packages
.\bootstrap.ps1 -Upgrade "git,nodejs"

# Upgrade all packages containing "visual"
.\bootstrap.ps1 -Upgrade visual
```

## Command Line Parameters

### Core Parameters
- `-Install <packages>`: Install one or more packages (comma-separated)
- `-Uninstall <packages>`: Uninstall packages with advanced cleanup
- `-Upgrade <packages>`: Upgrade packages to latest versions
- `-Search <query>`: Search for available packages
- `-List`: List installed packages
- `-Info <package>`: Get detailed package information

### Advanced Parameters
- `-Manager <winget|choco|auto>`: Specify package manager (default: auto)
- `-Silent`: Run in silent mode
- `-Force`: Force operations without confirmation
- `-DryRun`: Preview operations without executing
- `-Parallel`: Enable parallel processing for multiple packages
- `-MaxConcurrency <n>`: Maximum concurrent operations (default: 3)
- `-LogLevel <Error|Warning|Info|Debug|Trace>`: Set logging verbosity
- `-LogFile <path>`: Custom log file path

## Architecture

### Bootstrap Architecture
```
bootstrap.ps1 (Single Download)
├── Downloads modules from GitHub
├── Loads Utils.ps1, Aliases.ps1, PackageManagers.ps1
├── Loads Detection.ps1, Winget.ps1, Chocolatey.ps1
├── Loads Install.ps1, Uninstall.ps1, Upgrade.ps1
└── Executes requested operation
```

### Module Dependencies
- **Utils.ps1**: Logging, elevation, caching functions
- **Aliases.ps1**: Package name mappings and aliases
- **PackageManagers.ps1**: Core functions for winget/choco interaction
- **Detection.ps1**: Package discovery and information gathering
- **Winget.ps1**: Winget-specific operations
- **Chocolatey.ps1**: Chocolatey-specific operations
- **Install.ps1**: Installation logic with fallbacks
- **Uninstall.ps1**: Advanced uninstallation with cleanup
- **Upgrade.ps1**: Update logic with version checking

## Troubleshooting

### Common Issues

#### "Execution Policy" Error
```powershell
# Run with execution policy bypass
powershell -ExecutionPolicy Bypass -File bootstrap.ps1 -List
```

#### "Cannot Download" Error
- Check internet connection
- Verify GitHub repository is accessible
- Try again (may be temporary network issue)

#### "Module Loading Failed" Error
- Check file permissions in temp directory
- Ensure PowerShell has write access to %TEMP%
- Try running as administrator

#### "Package Manager Not Found" Warning
- Install Winget (recommended): https://github.com/microsoft/winget-cli
- Or install Chocolatey: https://chocolatey.org/install
- Tool will still work with available managers

### Debug Mode
```powershell
# Enable detailed logging
.\bootstrap.ps1 -List -LogLevel Debug
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

Created by thekingsmakers - All rights reserved.

## Support

- **Website**: thekingsmaker.org
- **Twitter**: thekingsmakers
- **Issues**: GitHub Issues (for bug reports and feature requests)

---

## Repository Structure

```
WinAppInstaller/
├── bootstrap.ps1                 # Main bootstrap script (download this!)
├── THEKINGSMAKERS-WINAPP-TOOL-MONOLITHIC.ps1  # Single-file version
├── Utils.ps1                     # Utility functions
├── Aliases.ps1                   # Package aliases
├── PackageManagers.ps1           # Core manager functions
├── Detection.ps1                 # Package detection
├── Winget.ps1                    # Winget operations
├── Chocolatey.ps1                # Chocolatey operations
├── Install.ps1                   # Installation logic
├── Uninstall.ps1                 # Uninstallation logic
├── Upgrade.ps1                   # Upgrade logic
├── package-aliases.json          # Alias definitions
├── README.md                     # This file
└── docs/                         # Additional documentation
```

**For users: Just download `bootstrap.ps1` and run it! Everything else downloads automatically.**

---

*THE KINGSMAKERS WINAPP TOOL - Advanced Windows Package Management Made Simple*
