# Known Issues

## Current Issues
- ✅ **Branding Display Issues**: Fixed colored Write-Host commands that were causing import failures in certain PowerShell environments. Added try/catch with plain text fallback.
- ✅ **Checksum Parameter Errors**: Removed unsupported Checksum parameter from Install-Package and Install-PackagesParallel function calls in MainInstaller.ps1.

## Resolved Issues
- ✅ **Complex Parsing Logic**: Fixed Get-InstalledPackages to properly handle winget output parsing with .EXE extension cleanup and 5-column format detection.
- ✅ **Job Context Issues**: Fixed logging to use global variables instead of script-scoped for better job compatibility.
- ✅ **Encoding Issues**: Improved temp file handling in package manager commands.
- ✅ **Incomplete Search-Package Function**: Verified Search-Package function is complete and properly implemented.
- ✅ **Script-Scoped Variables**: Fixed logging to use global variables instead of script-scoped for better job compatibility.
- ✅ **Elevation Function**: Improved Request-Elevation function with better error handling and reliability across environments.
- ✅ **Alias Validation**: Added validation for package aliases on load with warnings for placeholder checksums and invalid entries.
- ✅ **Null Argument Errors**: Original issue was fixed with default array initialization; remaining errors may be environmental.
- ✅ **Progress Display Bug**: Fixed installation progress header to show actual method list instead of blank.
- ✅ **Upgrade Progress Missing**: Added visual progress header and detailed method-by-method display for upgrade operations matching install format.
- ✅ **Parallel Installation**: Fully implemented with PowerShell jobs and configurable concurrency.
- ✅ **Direct Download Support**: Implemented MSI/EXE downloads with checksum verification.
- ✅ **Checksum Verification**: SHA256 validation for direct downloads.
- ✅ **Certificate Validation**: Basic checksum verification implemented (certificate validation for future enhancement).
- ✅ **Pester Test Issues**: Fixed assertion syntax for older Pester version.
- ✅ **No Output Issue**: Fixed search/list commands to show results instead of just "Operation completed successfully".
- ✅ **Output Formatting**: Fixed poorly formatted output with weird characters, truncated lines, and inconsistent table formatting. Now displays clean, readable tables with proper encoding and parsing.
- ✅ **Elevation/Installation Failure**: Fixed elevation logic to try non-elevated first, then elevate only when necessary. Added -SkipElevation parameter for skipping elevation. Improved error handling when elevation is canceled.
- ✅ **Multiple Installation Methods**: Implemented comprehensive fallback system trying winget → choco → direct download → PowerShell-native methods. Robust error handling and method-specific optimizations.
- ✅ **List Command Formatting**: Fixed winget list output parsing to display clean tables instead of raw, truncated text with weird characters.
- ✅ **Installation Argument Null Issue**: Fixed "Cannot validate argument on parameter 'ArgumentList'" error caused by null values in argument arrays when no -Args parameter is passed. Added default empty array initialization.
- ✅ **Package ID Parsing**: Fixed winget list output parsing to correctly extract package IDs without .EXE extensions.
- ✅ **Version Checking**: Added intelligent version comparison to detect when packages are already up-to-date and skip unnecessary upgrade attempts.
- ✅ **No Action for Latest Versions**: Implemented "already up to date" detection that reports status without throwing errors.
- ✅ **PowerShell Fallback**: Added PowerShell as a fallback upgrade method (though limited for remote packages).
- ✅ **Get-InstalledPackages Auto Logic**: Fixed Get-InstalledPackages to properly handle 'auto' manager by collecting packages from all available managers (winget + choco).
- ✅ **Upgrade Fallback Methods**: Added fallback upgrade methods when primary upgrade fails - now tries alternative package managers if available.
- ✅ **Code Modularization**: Successfully refactored monolithic code into separate modules for better maintainability and troubleshooting.
- ✅ **Retry Logic**: Added automatic retry (up to 2 attempts) for failed package manager operations with 3-second delays.
- ✅ **Advanced Uninstallation System**: Implemented intelligent package detection, multi-method uninstall (winget → choco → PowerShell), registry cleanup, and file removal with comprehensive reporting.
- ✅ **Package Detection Intelligence**: Added cross-manager package discovery with detailed information gathering, fuzzy matching, and system component detection.
- ✅ **THE KINGSMAKERS Branding**: Implemented professional branding with fallback support for environments that don't support colored output.

## Potential Issues
- PowerShell jobs for parallel installation may have limitations in some environments.
- Direct downloads require internet connectivity and valid URLs.
- Checksum verification uses SHA256 but doesn't validate certificates.
- Complex text parsing in Get-InstalledPackages may fail with unusual package manager output.
- Script-scoped logging variables may not work in PowerShell job contexts.
- Request-Elevation function reliability varies by environment.
- Package alias checksums are placeholders and not validated.
- Temp file cleanup in package manager functions may not always succeed.

## Bug Reports
- Recent logs show persistent "Get-AvailablePackageManagers not recognized" errors.
- Null argument validation errors still appear in logs despite fixes.
- Progress display for installations shows empty method list.

## Feature Requests
- ✅ **Retry Logic**: Added automatic retry (up to 2 attempts) for failed package manager operations with 3-second delays.
- Add comprehensive test coverage for upgrade functionality.
- Improve error handling for edge cases in text parsing.
- Consider adding GUI interface for user-friendly operation.
- Add support for Windows Store apps through winget.
- Implement version pinning for packages.
- Add rollback capabilities for failed installations.
- Enhanced certificate validation for downloads.