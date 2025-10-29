# THE KINGSMAKERS WINAPP TOOL - Usage Examples

## Overview
THE KINGSMAKERS WINAPP TOOL (TKM WINAPP TOOL) provides comprehensive Windows package management with intelligent fallbacks and advanced features.

**Created by thekingsmakers | Website: thekingsmaker.org | Twitter: thekingsmakers**

---

## Installation Examples

### Install Single Package (with Fallbacks)
```powershell
.\MainInstaller.ps1 -Install "vscode"
```
**What it does:**
- Tries winget first, then choco, then direct download
- Shows progress with colored output and timestamps
- Automatically handles elevation if needed

### Install Multiple Packages
```powershell
.\MainInstaller.ps1 -Install "git,nodejs,python"
```
**Features:**
- Sequential installation with individual progress tracking
- Shared elevation handling
- Comprehensive error reporting

### Parallel Installation
```powershell
.\MainInstaller.ps1 -Install "vscode,git,nodejs" -Parallel -MaxConcurrency 3
```
**Advanced Features:**
- Concurrent package installation
- Configurable concurrency limits
- Individual job monitoring and results

### Dry Run (Safe Testing)
```powershell
.\MainInstaller.ps1 -Install "firefox" -DryRun
```
**Safety Features:**
- Shows what would be installed without making changes
- Validates package availability
- Tests system compatibility

---

## Advanced Uninstallation Examples

### Intelligent Package Detection & Uninstall
```powershell
.\MainInstaller.ps1 -Uninstall "chrome"
```
**Smart Process:**
1. **Detects** all installed packages matching "chrome"
2. **Shows** detailed information about found packages
3. **Uninstalls** using multiple methods with fallbacks
4. **Cleans** registry entries and leftover files
5. **Reports** comprehensive success/failure summary

### Force Uninstall (Skip Confirmations)
```powershell
.\MainInstaller.ps1 -Uninstall "vlc" -Force -Silent
```
**Enterprise Features:**
- No user interaction required
- Silent operation for automation
- Comprehensive cleanup

---

## Upgrade Examples

### Upgrade by Partial Name
```powershell
.\MainInstaller.ps1 -Upgrade "chrome"
```
**Intelligent Matching:**
- Finds all packages containing "chrome"
- Checks current vs latest versions
- Only upgrades packages that need updating
- Reports packages already up-to-date

### Upgrade Multiple Packages
```powershell
.\MainInstaller.ps1 -Upgrade "vscode,git,python" -Parallel
```
**Batch Operations:**
- Concurrent upgrades where possible
- Individual progress tracking
- Comprehensive results summary

---

## Discovery & Information

### Search Available Packages
```powershell
.\MainInstaller.ps1 -Search "chrome"
```
**Cross-Manager Search:**
- Searches winget and choco repositories
- Shows package details and versions
- Helps identify correct package names

### List Installed Packages
```powershell
.\MainInstaller.ps1 -List
```
**Comprehensive Inventory:**
- Shows all installed packages from all managers
- Clean table formatting with proper encoding
- Package manager attribution

### Get Package Information
```powershell
.\MainInstaller.ps1 -Info "vscode"
```
**Detailed Package Info:**
- Installation status and details
- Version information
- Manager-specific data

---

## Advanced Usage Scenarios

### Silent Automation
```powershell
.\MainInstaller.ps1 -Install "notepad++" -Silent -Force -LogLevel Error
```
**Automation Features:**
- No user interaction
- Minimal logging output
- Error-only reporting for scripts

### Custom Manager Selection
```powershell
.\MainInstaller.ps1 -Install "firefox" -Manager winget
```
**Manager Control:**
- Force specific package manager
- Bypass automatic detection
- Override default preferences

### Debug Mode
```powershell
.\MainInstaller.ps1 -List -LogLevel Debug
```
**Troubleshooting:**
- Detailed logging output
- Function call tracing
- Comprehensive error information

---

## Error Recovery Examples

### Handling Failed Installations
```powershell
# If winget fails, automatically tries choco
.\MainInstaller.ps1 -Install "package-name"
```
**Automatic Fallbacks:**
- Method progression: winget → choco → direct → PowerShell
- Detailed error reporting for each attempt
- Success tracking and reporting

### Registry Cleanup After Manual Uninstall
```powershell
# Advanced uninstall finds and cleans leftovers
.\MainInstaller.ps1 -Uninstall "old-app"
```
**Cleanup Features:**
- Registry key removal (HKLM, HKCU, WOW6432Node)
- Leftover file detection and removal
- Program Files directory cleanup

---

## Professional Branding Output

All commands display the professional THE KINGSMAKERS branding:

```
==================================================================
               THE KINGSMAKERS WINAPP TOOL
                    (TKM WINAPP TOOL)

            Created by thekingsmakers
            Website: thekingsmaker.org
            Twitter: thekingsmakers
==================================================================
```

---

## Command Line Reference

### Core Parameters
- `-Install <packages>`: Install one or more packages
- `-Uninstall <packages>`: Advanced uninstall with detection and cleanup
- `-Upgrade <packages>`: Upgrade existing packages
- `-Search <query>`: Search for available packages
- `-List`: List installed packages
- `-Info <package>`: Get detailed package information

### Advanced Parameters
- `-Manager <winget|choco|auto>`: Force specific package manager
- `-Parallel`: Enable parallel processing
- `-MaxConcurrency <n>`: Set concurrent operation limit
- `-Silent`: Quiet operation (alias: `-Quiet`)
- `-Force`: Skip confirmations
- `-DryRun`: Preview operations without execution
- `-LogLevel <Error|Warning|Info|Debug|Trace>`: Set logging verbosity

### Output Control
- `-LogFile <path>`: Custom log file location
- All commands support colored output with fallback to plain text

---

## Best Practices

### For Administrators
1. Use `-DryRun` first to validate operations
2. Enable parallel processing for multiple packages: `-Parallel`
3. Set appropriate log levels: `-LogLevel Info`
4. Use specific managers when needed: `-Manager winget`

### For Automation
1. Use `-Silent -Force` for unattended operations
2. Redirect output for logging: `> output.log 2>&1`
3. Check exit codes for success/failure detection
4. Use explicit manager selection to avoid surprises

### For Troubleshooting
1. Start with `-DryRun` to see what would happen
2. Use `-LogLevel Debug` for detailed tracing
3. Check `installer.log` for comprehensive operation logs
4. Use `-List` to verify package states

---

**THE KINGSMAKERS WINAPP TOOL provides enterprise-grade package management with intelligent automation and comprehensive error recovery.**

**Created by thekingsmakers | Website: thekingsmaker.org | Twitter: thekingsmakers**
