# TKM-Uninstaller

Command-line software detector and uninstaller for Windows automation (e.g., Intune).

- Safe detection via registry (no Win32_Product)
- Uninstall using official uninstall strings (prefers QuietUninstall when available)
- Dry-run support with `-WhatIf`
- Verbose/debug logging and rotating log files

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Execution policy permitting script execution (e.g., run PowerShell as Admin):
  - `Set-ExecutionPolicy RemoteSigned -Scope Process`

## File locations

- Script: `TKM-Uninstaller.ps1`
- Logs: `C:\ProgramData\TKM\uninstaller\logs\TKM-Uninstaller-<timestamp>.log`
- Flag file: `C:\ProgramData\TKM\uninstaller\flag` (contains `Success` or `Failed`)

## Actions

You can use the new native switches or the legacy `-Action` parameter.

### Native switches (recommended)

- `-List` (alias: `-l`) — List all installed software (from HKLM/HKCU, includes WOW6432Node)
- `-Detect <name>[,<name>...]` — Detect matching software
- `-Info <name>[,<name>...]` — Show detailed info (scope, arch, size, paths, uninstall strings)
- `-Uninstall <name>[,<name>...]` — Uninstall matching software

### Legacy `-Action` forms

- `-Action "-l"`
- `-Action "-detect" -Software <name>[,<name>...]`
- `-Action "-info" -Software <name>[,<name>...]`
- `-Action "-uninstall" -Software <name>[,<name>...]`

## Common flags

 - `-Silent` (aliases: `-silent`, `-quiet`) — Try to make uninstalls non-interactive by appending quiet flags if missing
- `-WhatIf` — Dry-run; show what would happen without making changes
- `-Verbosity normal|verbose|debug` — Controls debug logging (default: `normal`)

## Examples

List all installed software:

```powershell
.\TKM-Uninstaller.ps1 -List
.\TKM-Uninstaller.ps1 -l
```

Detect software (wildcards supported):

```powershell
.\TKM-Uninstaller.ps1 -Detect "wireshark"
.\TKM-Uninstaller.ps1 -Detect "wireshark","cursor"
```

Show detailed information:

```powershell
.\TKM-Uninstaller.ps1 -Info "wireshark"
```

Uninstall (dry-run first, then real):

```powershell
# Dry-run (no changes)
.\TKM-Uninstaller.ps1 -Uninstall "wireshark" -WhatIf -Verbosity debug

# Real uninstall, attempt silent
.\TKM-Uninstaller.ps1 -Uninstall "wireshark" -Silent
```

Multiple targets:

```powershell
.\TKM-Uninstaller.ps1 -Uninstall "zoom","wireshark" -WhatIf
```

## Behavior and notes

- Detection and listing read registry hives:
  - `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*`
  - `HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*`
  - `HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*`
- Uninstall prefers `QuietUninstallString` and falls back to `UninstallString`.
- If `-Silent` is provided and no quiet flag is present, a generic `/quiet` is appended.
- With `-WhatIf`, the script shows intended actions without executing them, including flag file writes.

## Exit codes

- `0` — All requested actions succeeded
- `1` — One or more requested actions failed

## Troubleshooting

- If an action appears to do nothing, re-run with debug logs:

```powershell
.\TKM-Uninstaller.ps1 -Uninstall "<name>" -WhatIf -Verbosity debug
```

- Check the newest log file:

```powershell
$log = Get-ChildItem "C:\ProgramData\TKM\uninstaller\logs" | Sort-Object LastWriteTime -Desc | Select-Object -First 1
Get-Content $log.FullName -Tail 300
```

- If detection finds an app but uninstall fails, try using the exact `DisplayName` shown by `-Action "-info"`.

## Code Signing (Optional)

To avoid PowerShell execution policy prompts and build trust:

### Quick signing setup
```powershell
# Option 1: Use built-in auto-signing
.\TKM-Uninstaller.ps1 -AutoSign -Verbosity debug

# Option 2: Use separate Sign.ps1 helper
.\Sign.ps1 -CreateCert -Sign -Export
```

### Manual signing steps
```powershell
# 1. Create self-signed certificate
$cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=TKM Uninstaller" -CertStoreLocation "Cert:\CurrentUser\My" -KeyExportPolicy Exportable -KeyLength 2048 -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" -HashAlgorithm SHA256

# 2. Sign the script
Set-AuthenticodeSignature -FilePath .\TKM-Uninstaller.ps1 -Certificate $cert -TimestampServer "http://timestamp.digicert.com"

# 3. Verify signature
(Get-AuthenticodeSignature .\TKM-Uninstaller.ps1).Status
```

### Trusting the certificate on other machines
```powershell
# Run as Administrator on target machines
Import-Certificate -FilePath "TKM-Uninstaller.cer" -CertStoreLocation Cert:\LocalMachine\TrustedPublisher
Import-Certificate -FilePath "TKM-Uninstaller.cer" -CertStoreLocation Cert:\LocalMachine\Root
```

**Note:** Self-signed certificates only help with PowerShell execution policy. They do NOT remove SmartScreen or antivirus warnings. For that, you need a paid certificate from a trusted CA.

## Limitations

- Some installers use custom uninstallers or require additional flags. The script appends a generic quiet switch when `-Silent` is used, but vendor-specific flags may still be required.
- Applications installed for other user profiles may appear only under that user's `HKCU` hive.
- Self-signed certificates don't prevent SmartScreen or antivirus warnings (requires paid CA certificate).


