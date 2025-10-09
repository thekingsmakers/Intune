## TKM-Store-Apps-Update — Usage and management guide

This document explains how to use the TKM Store updater provided in this repository. It covers both using the module interactively (importing the `.psm1`) and running the packaged script entrypoint (`TKM-Store-Apps-Update.ps1`). It also shows example workflows for Intune packaging, recommended logging, troubleshooting, and safe test commands.
## TKM-Store-Apps-Update — Usage and management guide

This document explains how to use the TKM Store updater provided in this repository. It covers both using the module interactively (importing the `.psm1`) and running the packaged script entrypoint (`TKM-Store-Apps-Update.ps1`). It also shows example workflows for Intune packaging, recommended logging, troubleshooting, and safe test commands.

Notes / assumptions
- The repository contains two primary artifacts used here: `TKM-Store-Apps-Update.psm1` (module) and `TKM-Store-Apps-Update.ps1` (runnable entry script).
- Reasonable defaults are assumed where the script does not provide an explicit default. When instructing a command, the `-LogPath` parameter is recommended to capture structured logs (example: `C:\ProgramData\TKM\logs\tkm-store-update.log`).

## Quick start

1. Open an elevated PowerShell session (required for many Store operations).
2. Import the module for interactive use, or run the script for one-off operations.

Import the module (interactive):

```powershell
Import-Module 'C:\Users\oosman\Pictures\Microsoft Store Update backend\TKM-Store-Apps-Update.psm1' -Force
# show exported helpers
Get-Command -Module (Get-Module -Name TKM -ListAvailable | Select-Object -First 1).Name
```

Run the packaged entry script (example DryRun for all apps):

```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "C:\Users\oosman\Pictures\Microsoft Store Update backend\TKM-Store-Apps-Update.ps1" -All -DryRun -LogPath "C:\ProgramData\TKM\logs\tkm-store-update.log"
```

> Tip: use `-DryRun` to show what the tool would do without making changes. Use `-Force` to bypass interactive checks where the script supports it.

## Module usage (recommended for automation / integration)

The module exports a small set of helpers you can call directly. Example workflows below assume the module is already imported.

- List installed Store apps (all users):

```powershell
Get-TKMInstalledStoreApps -AllUsers | Format-Table -AutoSize
```

- Check if a specific package has an update candidate via winget fallback:

```powershell
Get-TKMPackageUpdateCandidate -PackageFamilyName 'Microsoft.MSPaint_8wekyb3d8bbwe' -LogPath 'C:\ProgramData\TKM\logs\candidate.log'
```

- Do a DryRun update for a single app (safe to test):

```powershell
$app = Get-TKMInstalledStoreApps | Where-Object PackageFamilyName -EQ 'Microsoft.MSPaint_8wekyb3d8bbwe'
Invoke-TKMUpdateStoreApp -App $app -DryRun -LogPath 'C:\ProgramData\TKM\logs\dryrun.log'
```

- Update all installed Store apps (DryRun first):

```powershell
Invoke-TKMUpdateAllStoreApps -DryRun -LogPath 'C:\ProgramData\TKM\logs\all-dryrun.log'
# When satisfied, run without -DryRun
Invoke-TKMUpdateAllStoreApps -LogPath 'C:\ProgramData\TKM\logs\all-update.log'
```

- Check pre-requisites (useful in automation to gate an update job):

```powershell
Test-TKMStoreAppUpdatePrereqs | Format-Table -AutoSize
```

## Running the standalone script (`TKM-Store-Apps-Update.ps1`)

The entry script provides a convenient entry point for manual runs and Win32 packaging. Common parameters (the script accepts these patterns):
- `-AppId` : target single PackageFamilyName (string)
- `-All` : update all installed apps
- `-DryRun` : perform a dry-run only
- `-Force` : force behaviour where supported
- `-RetryCount`, `-RetryDelaySeconds`, `-TimeoutSeconds` : tuning
- `-LogPath` : write structured logs to this file
- `-SkipReboot` : skip reboot attempts
- `-TelemetryEndpoint` : optional HTTP endpoint to send summary telemetry

Example: update a single app with verbose output and log file

```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\TKM-Store-Apps-Update.ps1 -AppId 'Microsoft.MSPaint_8wekyb3d8bbwe' -LogPath 'C:\ProgramData\TKM\logs\mspaint-update.log' -Verbose
```

Example: update everything (careful) with retries and a log file

```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\TKM-Store-Apps-Update.ps1 -All -RetryCount 3 -RetryDelaySeconds 10 -LogPath 'C:\ProgramData\TKM\logs\all-update.log'
```

## Intune packaging & detection/remediation

This repo includes `Intune-Remediation-Detection-Snippets.ps1` as an example detection script for Win32 packaging. Key points:

- Intune detection scripts should return **exit code 0** when the device is compliant and **non-zero** when remediation is required.
- The remediation payload (the `.intunewin` package) should contain `TKM-Store-Apps-Update.ps1` (or a wrapper) and use the detection script above as the detection method.
- A simple packaging workflow:
  1. Put `TKM-Store-Apps-Update.ps1`, your wrapper, and the detection script in a folder.
  2. Use the Microsoft Win32 Content Prep Tool to create an `.intunewin` file (see the `pack-intunewin.ps1` helper below).
  3. In Intune, configure the detection script to run (packaged detection), and configure the remediation to run the packaged script.

Example Intune detection snippet (presence or version check):

```powershell
# returns 0 when present at desired version
# See file Intune-Remediation-Detection-Snippets.ps1 for a parameterized example
```

Exit codes for remediation (recommended):
- `0` — success (remediation completed)
- `1` — failure (Intune should retry according to your retry policy)

## Packaging helper: `pack-intunewin.ps1`

This repository contains `pack-intunewin.ps1` — a convenience wrapper around the Microsoft Win32 Content Prep Tool (`IntuneWinAppUtil.exe`). It:

- Validates the presence of the tool on PATH or at a provided `-ToolPath`.
- Validates the `-SourceFolder` and `-SetupFile` exist.
- Runs the tool and places the resulting `.intunewin` in `-OutputDir`.

Usage example:

```powershell
.\pack-intunewin.ps1 -SourceFolder '.\payload' -SetupFile 'TKM-Store-Apps-Update.ps1' -OutputDir '.\out'
```

Notes:
- Download `IntuneWinAppUtil.exe` from Microsoft and place it on PATH or alongside this script, or pass `-ToolPath`.
- The helper does not upload to Intune; it only creates the package.

## Logging and diagnostics

- Always pass `-LogPath` when running in production to collect a structured log file. Example path: `C:\ProgramData\TKM\logs\tkm-store-update.log`.
- Logs are written as single-line JSON when structured logging is enabled; human-readable lines are written otherwise.
- Use `-Verbose` / `-Debug` when running manually to get more console output.

## Troubleshooting

- "winget not available": the module prefers `winget` as a fallback update mechanism. If `winget` is not present, the module will emit a warning and leave the app unchanged. Consider packaging a runner that includes a controlled update mechanism or ensure `winget` is available on target devices.

- Permissions errors: many Appx/Store operations require elevation. Run the script in an elevated session or let your management solution run as SYSTEM or an account with appropriate privileges.

- "Get-AppxPackage failed": this often occurs if the current user profile is not available or if the environment prevents enumerating all users. Use `-All` or run as SYSTEM/administrator for machine-wide checks.

- Analyzer stale warnings (in editor): If a stale linter/IDE diagnostic appears after editing files, reload the editor window or restart the PowerShell language server to clear cached diagnostics.

## Safety & best practices

- Always test with `-DryRun` before an actual update.
- Run large-scale updates during maintenance windows and target pilot groups first.
- Capture logs centrally (Event Forwarding, SIEM, or an HTTP telemetry endpoint) to audit runs.
- For enterprise deployments, replace the `winget` fallback with your signed enterprise feed or a secure MSIX repository; validate signatures before applying updates.

## Examples — scripts you can run now

List installed packages and show a candidate check for MS Paint:

```powershell
Import-Module 'C:\Users\oosman\Pictures\Microsoft Store Update backend\TKM-Store-Apps-Update.psm1' -Force
Get-TKMInstalledStoreApps -AllUsers | Where-Object PackageFamilyName -Match 'MSPaint' | Format-Table -AutoSize
Get-TKMPackageUpdateCandidate -PackageFamilyName 'Microsoft.MSPaint_8wekyb3d8bbwe' -LogPath 'C:\ProgramData\TKM\logs\candidate.log'
```

Dry-run update all apps and write to a log file:

```powershell
Invoke-TKMUpdateAllStoreApps -DryRun -LogPath 'C:\ProgramData\TKM\logs\all-dryrun.log'
```

## Next steps and recommended improvements

- Add Pester tests that mock `Start-Process`/`winget` to simulate upgrade flows.
- Add an enterprise MSIX feed integration with authenticated downloads and signature verification.
- Add optional retry/exponential backoff and more granular error codes for telemetry/Intune mapping.

- If you want, I can:
- Run the existing Pester tests and report results.
- Add a couple of mocked Pester cases for the update flow (DryRun + winget unavailable).
- Add a small `packaging` script to build a sample `.intunewin` (requires the Win32 Content Prep Tool binary).

---
File created: `usage.md` — let me know which next step above you want me to run (run tests, add Pester mocks, or create packaging script).