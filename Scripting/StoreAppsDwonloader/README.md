## TheKingsmaker Store Downloader v1.5

Modern Windows Forms GUI for downloading Microsoft Store packages without changing the original download logic.

### Requirements
- Windows 10/11 with desktop environment
- Windows PowerShell 5.1+
- Internet access to `store.rg-adguard.net`

### Getting Started
1. Download or clone this folder to a local path (no admin required to run UI).
2. Right-click `Downloader.ps1` → Run with PowerShell, or run from a PowerShell 5.1 prompt:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File .\Downloader.ps1
   ```

### Usage
- Package: Select a Microsoft Store package from the list, or enter a Product ID.
- Arch: Choose one of `x64`, `x86`, `arm64`, or `arm`.
- Ring: Choose `Fast`, `Slow`, `Preview`, or `Retail`.
- Download Dependencies: When checked, will fetch required dependencies alongside the selected app(s).
- Show All Versions: When unchecked, shows latest version per major release; when checked, shows all versions.
- Install Packages (Admin only): Shown when PowerShell is running elevated; optional post-download install.
- OK: Starts the normal flow (versions window appears, select the package(s) to download).
- Cancel: Closes the UI without making changes.

### What Happens Next
- After OK, a versions picker appears (Out-GridView). Select one or more entries and click OK.
- Files download into per-app folders in the script directory.
- If Download Dependencies is enabled, required framework packages are merged into the download list.

### Progress & Status
- The header and status bar provide quick visual feedback.
- A progress indicator shows “Starting…” just before the flow continues to the versions window.

### Troubleshooting
- Nothing happens after OK:
  - Ensure you’re using Windows PowerShell 5.1 (not PowerShell 7) in a desktop session.
  - The versions picker relies on Out-GridView, which requires Windows GUI.
- No results returned:
  - Try switching Ring or Arch; ensure the Product ID/Package is valid for that ring/arch.
- Downloads fail or are slow:
  - Check internet connectivity and retry later; large packages may take time.
- Install Packages checkbox missing:
  - Run PowerShell “As Administrator” to see install options.

### Security Note
- This tool queries `store.rg-adguard.net` to discover Microsoft Store package URLs. Review your network policies if needed.

### Credits
- Built by Omar Osman — thekingsmakers
- Website: https://thekingsmakers.org

### License
- © 2025 TheKingsmakers.org - All rights reserved
