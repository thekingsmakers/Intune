# THE KINGSMAKERS WINAPP TOOL - Complete Functionality Documentation

## Overview
THE KINGSMAKERS WINAPP TOOL (TKM WINAPP TOOL) is a comprehensive Windows package management solution that provides advanced installation, uninstallation, upgrading, searching, and listing capabilities using multiple package managers with intelligent fallbacks.

Created by thekingsmakers | Website: thekingsmaker.org | Twitter: thekingsmakers

---

## Architecture Overview

### Core Components
```
MainInstaller.ps1 (Main Entry Point)
├── Utils.ps1 (Logging, Elevation, Caching)
├── Aliases.ps1 (Package Alias System)
├── PackageManagers.ps1 (Core Package Manager Functions)
├── Detection.ps1 (Package Detection & Info)
├── Winget.ps1 (Winget-Specific Operations)
├── Chocolatey.ps1 (Chocolatey-Specific Operations)
├── Install.ps1 (Installation Logic)
├── Uninstall.ps1 (Uninstallation Logic)
├── Upgrade.ps1 (Upgrade Logic)
└── package-aliases.json (Alias Definitions)
```

---

## Function Call Flow

### Main Entry Point: MainInstaller.ps1

#### Parameter Processing
```
MainInstaller.ps1
├── ParameterSet Selection (Install/Upgrade/Uninstall/Search/List/Info)
├── Branding Display (with fallback error handling)
├── Module Imports (dot-sourcing all .ps1 files)
├── Logging Initialization
├── Alias Loading
├── Elevation Check
└── Operation Dispatch
```

### Install Operation Flow
```
MainInstaller.ps1:Install
├── Resolve-Packages() → Load aliases and resolve package names
├── Manager Selection ('auto' → try all managers)
├── Parallel Check
│   ├── If Parallel: Install-PackagesParallel()
│   │   ├── Job Creation (Start-Job)
│   │   ├── Job Monitoring
│   │   └── Result Collection (Receive-Job)
│   └── If Sequential: foreach → Install-Package()
│       ├── Install-Package() [Install.ps1]
│       │   ├── Get-AvailablePackageManagers() [PackageManagers.ps1]
│       │   ├── Method Selection Logic
│       │   ├── foreach method → Install-PackageWithMethod()
│       │   │   ├── Install-PackageWithMethod() [Install.ps1]
│       │   │   │   ├── switch(method)
│       │   │   │   │   ├── 'winget' → Install-PackageWithWinget() [Winget.ps1]
│       │   │   │   │   │   ├── Invoke-WingetCommand() [PackageManagers.ps1]
│       │   │   │   │   │   │   ├── Start-Process (winget.exe)
│       │   │   │   │   │   │   ├── Temp file I/O
│       │   │   │   │   │   │   └── Process monitoring with timeout
│       │   │   │   │   ├── 'choco' → Update-PackageWithChoco() [Chocolatey.ps1]
│       │   │   │   │   │   └── Invoke-ChocoCommand() [PackageManagers.ps1]
│       │   │   │   │   └── 'direct'/'powershell' → Not implemented
│       │   │   └── Return success/failure
│       │   └── Break on first success
│       └── Throw on all failures
```

### Uninstall Operation Flow
```
MainInstaller.ps1:Uninstall
├── Resolve-Packages()
├── Manager Selection ('auto')
├── foreach package → Uninstall-Package()
    ├── Uninstall-Package() [Uninstall.ps1]
    │   ├── DETECTION PHASE: Get-PackageInfo() [Detection.ps1]
    │   │   ├── Get-AvailablePackageManagers() [PackageManagers.ps1]
    │   │   ├── foreach manager → Get-InstalledPackages() [Detection.ps1]
    │   │   │   ├── Invoke-WingetCommand() or Invoke-ChocoCommand()
    │   │   │   └── Parse output into objects
    │   │   └── Fuzzy matching for partial names
    │   ├── If no packages found → throw error
    │   ├── Display detected packages
    │   ├── UNINSTALL PHASE: foreach detected package
    │   │   ├── Get-AvailablePackageManagers()
    │   │   ├── Method selection ('auto' → winget,choco,powershell)
    │   │   ├── foreach method → Uninstall-PackageWithMethod()
    │   │   │   ├── Uninstall-PackageWithMethod() [Uninstall.ps1]
    │   │   │   │   ├── switch(method)
    │   │   │   │   │   ├── 'winget' → Uninstall-PackageWithWinget() [Winget.ps1]
    │   │   │   │   │   │   └── Invoke-WingetCommand()
    │   │   │   │   │   ├── 'choco' → Uninstall-PackageWithChoco() [Chocolatey.ps1]
    │   │   │   │   │   │   └── Invoke-ChocoCommand()
    │   │   │   │   │   └── 'powershell' → Uninstall-PackageWithPowerShell()
    │   │   │   │   │       ├── MSI: Uninstall-PackageWithMSI()
    │   │   │   │   │       │   ├── Get-WmiObject (Win32_Product)
    │   │   │   │   │       │   ├── Start-Process (msiexec.exe)
    │   │   │   │   │       │   └── Clean-RegistryEntries()
    │   │   │   │   │       ├── Registry: Uninstall-PackageWithRegistry()
    │   │   │   │   │       │   ├── Registry key enumeration
    │   │   │   │   │       │   ├── Start-Process (uninstall strings)
    │   │   │   │   │       │   └── Clean-RegistryEntries()
    │   │   │   │   │       └── Files: Uninstall-PackageWithFiles()
    │   │   │   │   │           ├── File system scanning
    │   │   │   │   │           ├── Start-Process (uninstallers)
    │   │   │   │   │           └── Clean-RegistryEntries() + Clean-LeftoverFiles()
    │   │   │   └── Clean-RegistryEntries() + Clean-LeftoverFiles()
    │   │   └── Break on first success per package
    │   └── Summary reporting
```

### Upgrade Operation Flow
```
MainInstaller.ps1:Upgrade
├── Resolve-Packages()
├── Manager Selection ('auto')
├── Parallel Check
│   ├── If Parallel: Update-PackagesParallel()
│   └── If Sequential: foreach → Update-Package()
    ├── Update-Package() [Upgrade.ps1]
    │   ├── Get-AvailablePackageManagers()
    │   ├── Method selection ('auto' → winget,choco,powershell)
    │   ├── foreach method → Update-PackageWithMethod()
    │   │   ├── switch(method)
    │   │   │   ├── 'winget' → Update-PackageWithWinget() [Winget.ps1]
    │   │   │   │   └── Invoke-WingetCommand()
    │   │   │   ├── 'choco' → Update-PackageWithChoco() [Chocolatey.ps1]
    │   │   │   │   └── Invoke-ChocoCommand()
    │   │   │   └── 'powershell' → Not implemented
    │   │   └── Return success/failure
    │   └── Break on first success
    └── Throw on all failures
```

### Search Operation Flow
```
MainInstaller.ps1:Search
├── Manager Selection (first available)
├── Search-Package() [Detection.ps1]
    ├── switch(manager)
    │   ├── 'winget' → Invoke-WingetCommand('search')
    │   └── 'choco' → Invoke-ChocoCommand('search')
    └── Parse and format results
└── Display results
```

### List Operation Flow
```
MainInstaller.ps1:List
├── Manager Selection (first available)
├── Get-InstalledPackages() [Detection.ps1]
    ├── Get-AvailablePackageManagers()
    ├── switch(manager)
    │   ├── 'winget' → Invoke-WingetCommand('list')
    │   └── 'choco' → Invoke-ChocoCommand('list')
    └── Parse output into objects
└── Format-Table display
```

### Info Operation Flow
```
MainInstaller.ps1:Info
├── Manager Selection (first available)
├── Search-Package() [Detection.ps1]
└── Format-List display
```

---

## Key Function Dependencies

### Core Functions Called by Multiple Modules:

#### PackageManagers.ps1 (Core Utilities)
- `Get-AvailablePackageManagers()` - Called by: Install, Uninstall, Upgrade, Search, List, Info operations
- `Invoke-WingetCommand()` - Called by: Winget operations, Get-InstalledPackages, Search-Package
- `Invoke-ChocoCommand()` - Called by: Chocolatey operations, Get-InstalledPackages, Search-Package

#### Detection.ps1 (Package Discovery)
- `Get-InstalledPackages()` - Called by: List operation, Get-PackageInfo
- `Search-Package()` - Called by: Search operation, Info operation
- `Get-PackageInfo()` - Called by: Uninstall operation (detection phase)
- `Get-DetailedPackageInfo()` - Called by: Get-PackageInfo
- `Test-PackageInstalled()` - Not currently used in main flow

#### Utils.ps1 (Infrastructure)
- `Initialize-Logging()` - Called by: MainInstaller.ps1 (once)
- `Write-Log()` - Called by: All operations throughout the system
- `Test-Elevation()` - Called by: MainInstaller.ps1
- `Get-DefaultCacheDirectory()` - Called by: MainInstaller.ps1

#### Aliases.ps1 (Package Mapping)
- `Load-PackageAliases()` - Called by: MainInstaller.ps1
- `Get-PackageFromAlias()` - Called by: Resolve-Packages()

---

## Data Flow

### Package Resolution Flow
```
User Input → Resolve-Packages() → Get-PackageFromAlias() → Alias Resolution → Final Package List
```

### Manager Selection Flow
```
'auto' → Get-AvailablePackageManagers() → Order: winget, choco, powershell/direct
Specific Manager → Direct selection (bypass availability check)
```

### Error Handling Flow
```
Operation → Try → Catch → Log Error → Try Next Method → All Failed → Throw
```

### Logging Flow
```
Initialize-Logging() → Write-Log() calls throughout → installer.log file
```

---

## Critical Integration Points

### 1. Import Order (Must be maintained)
```
Utils.ps1 → Aliases.ps1 → PackageManagers.ps1 → Detection.ps1 → Winget.ps1 → Chocolatey.ps1 → Install.ps1 → Uninstall.ps1 → Upgrade.ps1
```

### 2. Function Availability Dependencies
- All functions must be loaded before MainInstaller.ps1 execution
- Detection functions require PackageManagers functions
- Install/Uninstall/Upgrade functions require all manager-specific functions
- Logging functions must be available before any Write-Log calls

### 3. Parameter Consistency
- All manager functions follow consistent parameter patterns
- Error objects use consistent structure: `@{ Success = $bool; Error = $string }`
- AdditionalArgs arrays are consistently handled across all functions

### 4. State Management
- Global logging variables set once in MainInstaller.ps1
- Alias data loaded once and reused
- No persistent state between operations

---

## Error Recovery Mechanisms

### 1. Method Fallback
```
winget fails → choco → powershell → throw error
```

### 2. Retry Logic
```
Command fails → retry up to 2 times → final failure
```

### 3. Elevation Handling
```
Non-elevated first → fail → elevate → retry
```

### 4. Timeout Protection
```
Process monitoring → 300s timeout → kill process → error
```

---

## Performance Characteristics

### Parallel Processing
- Install/Upgrade support parallel execution
- Max concurrency: 3 (configurable)
- Job-based execution with result collection

### Sequential Processing
- Uninstall processes packages sequentially (one at a time)
- Search/List operations are naturally sequential

### Memory Usage
- Minimal memory footprint
- Temp files for command I/O
- Job cleanup prevents memory leaks

---

## Failure Points & Recovery

### Common Failure Scenarios:

1. **Import Failures**: Branding code errors → Fixed with try/catch
2. **Parameter Errors**: Missing Checksum parameter → Fixed by removal
3. **Function Availability**: Import order issues → Maintain strict order
4. **Process Timeouts**: Long-running commands → Timeout handling
5. **Permission Issues**: Elevation required → Automatic elevation attempts

### Recovery Strategies:
- **Branding**: Fallback to plain text
- **Parameters**: Remove unsupported parameters
- **Imports**: Strict ordering with error checking
- **Processes**: Timeout + kill + retry
- **Permissions**: Elevation detection + automatic retry

---

## Testing Coverage

### Pester Tests (MainInstaller.Tests.ps1)
- Parameter validation
- Import verification
- Basic function availability
- Error handling paths

### Manual Testing Required
- Actual package operations (winget/choco availability)
- Parallel processing
- Elevation scenarios
- Error recovery

---

## Maintenance Notes

### Code Organization
- Each .ps1 file = one responsibility
- Functions follow consistent naming: `Verb-Noun`
- Error objects use consistent structure
- Parameter validation on all public functions

### Update Process
1. Modify individual .ps1 files
2. Test imports work: `Get-ChildItem *.ps1 | %{. $_.FullName}`
3. Run Pester tests
4. Manual testing of operations
5. Update this documentation

### Debugging
- Enable verbose logging: `-LogLevel Debug`
- Check installer.log for detailed traces
- Test individual functions: `.\script.ps1; Function-Name`
- Use dry-run mode for safe testing

---

## Future Enhancements

### Planned Features
- Direct download support (MSI/EXE with checksums)
- Certificate validation for downloads
- GUI interface
- Version pinning
- Rollback capabilities
- Enhanced certificate validation

### Extension Points
- Add new package managers by creating new .ps1 files
- Extend detection logic in Detection.ps1
- Add new operation types in MainInstaller.ps1
- Enhance error recovery in Utils.ps1

---

**This documentation serves as the comprehensive reference for understanding how THE KINGSMAKERS WINAPP TOOL functions. Use this when debugging or extending the system.**

Created by thekingsmakers | Website: thekingsmaker.org | Twitter: thekingsmakers
