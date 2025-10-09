Preparing a Win32 `.intunewin` package for TKM-Store-Apps-Update

1. Place these files in a folder (e.g., TKM-Store-Apps-Update-1.0):
   - TKM-Store-Apps-Update.ps1
   - TKM-Store-Apps-Update.psm1
   - TKM-Store-App-Map.json (optional)
   - README.md

2. Create an install wrapper (example):

```powershell
# Install.cmd wrapper that Intune will call
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "TKM-Store-Apps-Update.ps1" -All
```

3. Create detection script that verifies package versions or presence of a marker file created by the script.

4. Use the Microsoft Win32 Content Prep Tool to create `.intunewin`:

- Run: IntuneWinAppUtil.exe -c <source_folder> -s Install.cmd -o <output_folder>

5. Intune settings recommendations:
- Install command: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\TKM-Store-Apps-Update.ps1 -All`
- Uninstall: (not applicable)
- Detection: use the detection script that checks installed package version or the presence of a log/marker file
- Return codes: 0 = success, 1 = partial failure, 2 = blocked/permissions, 3 = bad params
- Retry behavior: set to 3 attempts with 15 minute intervals (recommended)

Notes:
- Ensure script signing policies and execution policies in your tenant permit this script or sign the script.
- For remediation scripts in Intune, non-interactive runs are expected to be elevated already.
