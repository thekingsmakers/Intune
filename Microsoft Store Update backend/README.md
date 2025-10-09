# TKM-Store-Apps-Update

Enterprise-grade PowerShell script/module to discover and update Microsoft Store (Appx/MSIX/UWP) apps on Windows devices. Designed for use as a Win32 app or Intune remediation script.

See `TKM-Store-Apps-Update.ps1` (entry script) and `TKM-Store-Apps-Update.psm1` (module).

Quick start

1. Review the scripts and sign them with your code-signing certificate if required by policy.
2. Test discovery and dry-run on a test VM:

```powershell
.\TKM-Store-Apps-Update.ps1 -All -DryRun -LogPath C:\Temp\tkm-dryrun.log -ReturnJson
```

3. Package for Intune (see Packaging/IntunePackageInstructions.md).

Packaging helper

This repository includes a small helper script `pack-intunewin.ps1` which wraps the Microsoft Win32 Content Prep Tool (`IntuneWinAppUtil.exe`). It validates that the tool exists and calls it to create a `.intunewin` from a source folder.

Example:

```powershell
# from the repo root
.\pack-intunewin.ps1 -SourceFolder .\payload -SetupFile 'TKM-Store-Apps-Update.ps1' -OutputDir .\out
```

Notes:
- You must download `IntuneWinAppUtil.exe` (Win32 Content Prep Tool) from Microsoft and place it on PATH or alongside this script, or pass the `-ToolPath` parameter.
- The helper only creates the `.intunewin` file; uploading to Intune is out-of-scope and must be performed via the Intune admin center or graph API.

What this deliverable includes

- `TKM-Store-Apps-Update.ps1` - entry script with parameterized behavior and JSON output
- `TKM-Store-Apps-Update.psm1` - helper module with exported functions
- `TKM-Store-App-Map.json` - friendly-name to package family mapping (editable)
- `Intune-Remediation-Detection-Snippets.ps1` - example detection & remediation snippets
- `Tests/` - Pester tests (mocks used for non-destructive checks)
- `Packaging/IntunePackageInstructions.md` - step-by-step packaging guide
- `CHANGELOG.md` - initial version notes

Notes and limitations

- This initial implementation prefers `winget` for update operations where available.
- Store COM/API integration is not implemented here; for enterprise feeds, plug in your MSIX feed download & validation logic in `Get-TKMPackageUpdateCandidate` and `Invoke-TKMUpdateStoreApp`.
- The script attempts to elevate interactively; in non-interactive Intune contexts scripts run elevated already.

Troubleshooting

- If `Get-AppxPackage` returns no apps: ensure the script is running under the user context where apps are installed, or use `-All` to enumerate AllUsers.
- If updates fail due to AppLocker/WDAC: capture the error and consult security team to allow the signed MSIX/MSIX bundle.
- If winget is not present, either install the App Installer from Microsoft Store (not applicable in all enterprise environments) or configure an internal MSIX feed and extend `Invoke-TKMUpdateStoreApp`.

Signing the scripts

1. Obtain a code-signing certificate (PFX) from your PKI or vendor.
2. Sign the script: `Set-AuthenticodeSignature -FilePath .\TKM-Store-Apps-Update.ps1 -Certificate (Get-PfxCertificate -FilePath .\signing.pfx)`
3. Ensure Intune execution policies allow signed scripts or set execution policy via device configuration.
