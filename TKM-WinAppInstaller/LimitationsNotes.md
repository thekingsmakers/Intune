# Limitations & Notes

## Assumptions
- PowerShell 7+ is required for full functionality.
- Windows 10/11 environment with winget (Windows Package Manager) or Chocolatey installed.
- Internet connection available for package manager operations and direct downloads.
- User has appropriate permissions for software installation (elevation when required).

## Known Limitations
- Parallel installation is fully implemented with PowerShell jobs and configurable concurrency limits.
- Direct installer downloads (MSI/EXE from URL) are implemented with checksum verification.
- Checksum verification uses SHA256 with proper validation.
- Microsoft Store packages via winget have limited support due to API differences.
- Enterprise proxy configurations may require additional setup.
- Certificate validation for downloads is not implemented.
- Logging to external servers or advanced logging frameworks is not integrated.

## Recommended Next Steps
- Implement full parallel installation with proper job management.
- Add direct download support with checksum verification and certificate checking.
- Integrate with Microsoft Store APIs for better Store app handling.
- Add support for enterprise proxies and authentication.
- Implement centralized logging with log aggregation servers.
- Add package version pinning and rollback capabilities.
- Integrate with Windows Update for system updates.
- Add GUI interface using Windows Forms or WPF.
- Implement configuration profiles for different environments.
- Add telemetry and usage analytics (with opt-in).
