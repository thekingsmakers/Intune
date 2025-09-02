## Intune Script Compliance Validator

PowerShell WinForms tool to validate Microsoft Intune PowerShell scripts, Proactive Remediations (PR) detection/remediation scripts, and Custom Compliance discovery scripts. It highlights common pitfalls and offers optional auto-fixes where safe.

### Features
- Responsive UI with DPI-safe layout (no overlapping controls)
- Single-file and whole-folder validation
- Live folder watcher to validate new/changed scripts
- Microsoft-guided checks with actionable messages


### Validations (summary)
- No reboots or shutdowns (`Restart-Computer`, `Stop-Computer`, `shutdown.exe`)
- No interactive prompts (`Read-Host`, `Out-GridView`, `Pause`, host prompts)
- Discourages `Write-Host` (prefer `Write-Output`/`Write-Verbose`)
- Rejects `Set-ExecutionPolicy`
- Rejects elevation via `Start-Process -Verb RunAs`
- Recommends `$ErrorActionPreference = "Stop"` and try/catch
- For web calls, recommends TLS 1.2+ (set `[Net.ServicePointManager]::SecurityProtocol`)
- Warns on large script size (>200 KB)
- Detects UTF-8 BOM and offers removal
- PR Detection requires explicit exit code (`exit 0` or `exit 1`)
- Custom Compliance discovery should output single-line JSON (`ConvertTo-Json -Compress`)

### Requirements
- Windows PowerShell 5.1 or PowerShell 7+
- .NET WindowsDesktop features available (WinForms)

### Getting Started
1. Download/clone this folder to a local path.
2. Launch from PowerShell:
```powershell
cd "D:\scripts\Intune Script Validator"
.exe
```

### Using the App
- Select a script or a folder containing `.ps1` files.
- Choose the Validation Type:
  - Intune PowerShell Script
  - PR Detection Script
  - PR Remediation Script
  - Custom Compliance Discovery
- Click "Check Compliance" for a single script or "Validate" for a folder.
- Review Issues/Infos in the results pane. If auto-fix was applied, a `.fixed.ps1` file is written next to the original.
- Optional: enable "Watch folder" to validate files created or modified in the target folder.

### Notes from Microsoft Guidance (high level)
- Do not require user interaction. Scripts must run unattended.
- Avoid reboot/shutdown in Intune and PR contexts.
- Use UTF-8 (without BOM) encoding.
- Prefer TLS 1.2+ for network traffic.
- Use robust error handling; consider `$ErrorActionPreference = "Stop"` and try/catch.
- Prefer `Write-Output`/`Write-Verbose` over `Write-Host` for logging.
- Do not change execution policy or attempt elevation inside scripts; choose the correct run context in Intune settings.
- PR detection: `exit 0` = compliant; non-zero = not compliant (triggers remediation).
- Custom compliance discovery: output a single JSON line (`ConvertTo-Json -Compress`).

### Auto-fix Behavior
- Removes UTF-8 BOM if present.
- Appends default `exit 0` (commented rationale) for PR Detection scripts missing explicit exit.
- Adds discovery JSON guidance as commented examples for Custom Compliance.

### Troubleshooting
- Controls too small/thin: This build uses Font autoscaling with layout panels. If display scaling is unusual, ensure you run on a standard Windows desktop session.
- Execution policy blocks script: Run the validator from a context where execution policy permits running local scripts, or use a signed copy according to your organization policy. The validator itself flags scripts that attempt to change execution policy.
- No output for large folders: Ensure you have read permissions to all files; errors per file are reported in the results pane.

### Security
- The validator reads and analyzes `.ps1` content and may create `.fixed.ps1` next to originals.
- It does not execute your target scripts.

### License
Provided as-is, without warranty. Review outputs before applying changes to production scripts.



