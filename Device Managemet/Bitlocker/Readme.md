# BitLocker Readiness Audit Script

## Overview

This PowerShell script collects device security and BitLocker readiness information from Windows endpoints and sends the results to a Microsoft Power Automate Flow via HTTP POST.

The script is useful for:

* BitLocker deployment readiness audits
* Security compliance checks
* TPM and Secure Boot validation
* PCR7 readiness validation
* Enterprise inventory reporting

The collected data is transmitted as JSON to a configured Power Automate Flow endpoint and can be stored in a SharePoint List.

---

# Solution Architecture

```text
Windows Device
      │
      ▼
PowerShell Script
      │
      ▼
Power Automate Flow (HTTP Trigger)
      │
      ▼
SharePoint List
```

---

# Features

The script checks and reports:

| Feature                              | Description                                    |
| ------------------------------------ | ---------------------------------------------- |
| TPM Presence                         | Detects whether TPM is installed               |
| TPM Version                          | Retrieves TPM specification version            |
| UEFI Mode                            | Checks if system uses UEFI or Legacy BIOS      |
| Secure Boot                          | Determines whether Secure Boot is enabled      |
| Kernel DMA Protection                | Detects DMA protection support/status          |
| PCR7 Configuration                   | Validates BitLocker PCR7 binding readiness     |
| Windows Recovery Environment (WinRE) | Checks if WinRE is enabled                     |
| BitLocker Status                     | Reports encryption status for C: and D: drives |
| Device Name                          | Captures hostname                              |
| Timestamp                            | Logs execution timestamp                       |

---

# Requirements

## Supported OS

* Windows 10
* Windows 11
* Windows Server (with BitLocker modules installed)

## PowerShell

* PowerShell 5.1 or later

## Required Permissions

Run the script with:

* Local Administrator privileges
* PowerShell execution policy allowing script execution

Example:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope Process
```

---

# Step 1 — Create SharePoint List

Create a SharePoint list to store the device audit results.

## Suggested List Name

```text
BitLockerAudit
```

---

## Create the List

1. Open SharePoint Site
2. Click **New**
3. Select **List**
4. Choose **Blank List**
5. Name the list:

```text
BitLockerAudit
```

6. Click **Create**

---

## Create Columns

Create the following columns in SharePoint:

| Column Name | Type                |
| ----------- | ------------------- |
| DeviceName  | Single line of text |
| TPM_Present | Single line of text |
| TPM_Version | Single line of text |
| UEFI_Mode   | Single line of text |
| SecureBoot  | Single line of text |
| KernelDMA   | Single line of text |
| PCR7        | Single line of text |
| WinRE       | Single line of text |
| BitLocker_C | Single line of text |
| BitLocker_D | Single line of text |
| Timestamp   | Date and Time       |

---

# Step 2 — Create Power Automate Flow

## Create Instant Cloud Flow

1. Open Power Automate
2. Click **Create**
3. Select **Instant Cloud Flow**
4. Name the flow:

```text
BitLocker Device Audit
```

5. Choose trigger:

```text
When an HTTP request is received
```

6. Click **Create**

---

# Step 3 — Configure HTTP Trigger

## Request Body JSON Schema

Click **Use sample payload to generate schema** and paste:

```json
{
  "DeviceName": "PC-001",
  "TPM_Present": "Yes",
  "TPM_Version": "2.0",
  "UEFI_Mode": "UEFI",
  "SecureBoot": "Enabled",
  "KernelDMA": "On",
  "PCR7": "Ready",
  "WinRE": "Enabled",
  "BitLocker_C": "Encrypted",
  "BitLocker_D": "Not Encrypted",
  "Timestamp": "2026-05-20T14:32:11"
}
```

Power Automate will auto-generate the schema.

---

# Step 4 — Add SharePoint Action

Add a new action:

```text
Create item
```

Connector:

```text
SharePoint
```

---

## Configure Create Item Action

Select:

| Setting      | Value                |
| ------------ | -------------------- |
| Site Address | Your SharePoint Site |
| List Name    | BitLockerAudit       |

---

## Map Fields

Map the HTTP request values to SharePoint columns:

| SharePoint Column | Dynamic Content |
| ----------------- | --------------- |
| DeviceName        | DeviceName      |
| TPM_Present       | TPM_Present     |
| TPM_Version       | TPM_Version     |
| UEFI_Mode         | UEFI_Mode       |
| SecureBoot        | SecureBoot      |
| KernelDMA         | KernelDMA       |
| PCR7              | PCR7            |
| WinRE             | WinRE           |
| BitLocker_C       | BitLocker_C     |
| BitLocker_D       | BitLocker_D     |
| Timestamp         | Timestamp       |

---

# Step 5 — Save and Copy Flow URL

1. Save the flow
2. Copy the generated HTTP POST URL

Example:

```text
https://prod-xx.westeurope.logic.azure.com:443/workflows/xxxxxxxx
```

---

# Step 6 — Update PowerShell Script

Update the following variable:

```powershell
$FlowUrl = "YOUR_FLOW_HTTP_TRIGGER_URL"
```

---

# Script Functions

## `Get-TPMInfo`

Retrieves:

* TPM availability
* TPM specification version

Uses:

```powershell
Win32_Tpm
```

---

## `Get-UEFI`

Checks firmware mode:

* UEFI
* Legacy BIOS

---

## `Get-SecureBoot`

Determines Secure Boot state using:

```powershell
Confirm-SecureBootUEFI
```

---

## `Get-KernelDMA`

Checks Kernel DMA protection support/status using:

```powershell
NtQuerySystemInformation
```

---

## `Get-PCR7`

Uses `msinfo32` report parsing to determine PCR7 readiness.

Possible outputs:

* Ready
* Not Ready
* Unknown

---

## `Get-WinRE`

Checks Windows Recovery Environment status using:

```powershell
reagentc /info
```

---

## `Get-BitLockerStatus`

Checks BitLocker encryption state for:

* C:
* D:

Possible outputs:

* Encrypted
* Not Encrypted
* Drive Not Found
* Unknown

---

# Running the Script

## Option 1 — Run Manually

```powershell
.\BitLockerAudit.ps1
```

---

## Option 2 — Deploy via Intune

Recommended settings:

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run this script using logged on credentials | No    |
| Enforce script signature check              | No    |
| Run script in 64-bit PowerShell             | Yes   |

---

## Option 3 — Deploy via SCCM / MECM

Deploy as:

* Package
* Configuration Baseline
* Compliance Script

---

# Output Example

Example JSON payload sent to Power Automate:

```json
{
  "DeviceName": "PC-001",
  "TPM_Present": "Yes",
  "TPM_Version": "2.0",
  "UEFI_Mode": "UEFI",
  "SecureBoot": "Enabled",
  "KernelDMA": "On",
  "PCR7": "Ready",
  "WinRE": "Enabled",
  "BitLocker_C": "Encrypted",
  "BitLocker_D": "Not Encrypted",
  "Timestamp": "2026-05-20T14:32:11"
}
```

---

# Success & Error Handling

## Success

```text
SUCCESS: HOSTNAME sent to Flow
```

Exit code:

```text
0
```

---

## Failure

```text
ERROR: <message>
```

Exit code:

```text
1
```

---

# Security Considerations

* The Power Automate Flow URL contains authentication tokens.
* Store the script securely.
* Avoid publishing the Flow URL publicly.
* Consider rotating Flow URLs periodically.
* Restrict access to the SharePoint list.

---

# Recommended Enhancements

Possible future improvements:

* Add device serial number
* Add Azure AD / Entra ID device ID
* Add OS build/version
* Add Intune compliance status
* Add CSV local logging
* Retry logic for failed uploads
* TLS validation handling
* Proxy support

---

# Troubleshooting

## `Get-BitLockerVolume` Not Found

Install BitLocker feature/tools:

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName BitLocker
```

---

## Secure Boot Returns "Not Supported"

Possible causes:

* Device using Legacy BIOS
* Unsupported firmware
* Virtual machine limitations

---

## PCR7 Shows Unknown

Possible causes:

* `msinfo32` report generation failure
* Device hardware limitations
* Unsupported TPM configuration

---

# Author

TheKingsMakers

---

# License

This script is provided as-is without warranty. Use at your own risk.
