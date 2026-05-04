# Helpdesk Troubleshooting Guide: BGInfo

This document is intended for Helpdesk and IT Support technicians troubleshooting issues where BGInfo is not updating or displaying correctly on a user's machine.

## Expected Behavior
The BGInfo text should refresh automatically whenever the user:
1. Logs into the computer.
2. Locks the computer (Win + L).
3. Unlocks the computer.

It is deployed to a hidden local folder at `C:\ProgramData\BginfoRefresh` and executed via a Scheduled Task named **"BGInfo User Refresh"**.

---

## Basic Troubleshooting

### 1. Verify the Files Exist
Check if the application successfully deployed to the machine.
Navigate to: `C:\ProgramData\BginfoRefresh`
You should see three files:
- `Bginfo64.exe`
- `hostname.bgi`
- `bginforefresh.ps1`

*If the folder or files are missing, the Intune deployment failed. Sync the device in Company Portal.*

### 2. Check the Local Audit Log
Every time BGInfo successfully applies, it writes to a log file in the user's temporary folder.
Check the following file:
`%TEMP%\bginfo_apply.log` (Resolves to `C:\Users\<username>\AppData\Local\Temp\bginfo_apply.log`)

*If the file is missing or the timestamps are outdated, the script is not triggering.*

---

## Managing the Scheduled Task

If the files are present but BGInfo isn't updating, the Scheduled Task might be disabled, corrupted, or failing.

### How to trigger it manually via GUI (Task Scheduler)
1. Press **Win + R**, type `taskschd.msc`, and press Enter (Run as Administrator if prompted).
2. In the left pane, click on **Task Scheduler Library**.
3. In the middle pane, look for the task named **`BGInfo User Refresh`**.
4. Right-click the task and select **Run**.
5. Check the user's desktop to see if the BGInfo text updated.

### How to trigger it manually via PowerShell
You can force the refresh script to run by executing this command in an elevated PowerShell window:
```powershell
Start-ScheduledTask -TaskName "BGInfo User Refresh"
```

### Checking Task Failure Reasons
If running the task manually doesn't work:
1. Open **Task Scheduler**.
2. Locate **`BGInfo User Refresh`**.
3. Look at the **"Last Run Result"** column.
   - `0x0`: Success.
   - `0x1`: The script failed to execute (Check Execution Policies or Antivirus blocking PowerShell).
   - `0x8004131F`: An instance of this task is already running (Kill `Bginfo64.exe` in Task Manager).

### Quick Fix / Reinstallation
If the task is completely broken, you can re-register it by running the installation script manually from an elevated PowerShell prompt:
```powershell
# Run this as Administrator
C:\ProgramData\BginfoRefresh\bginforefresh.ps1
```
*(Note: To completely repair the task triggers, reinstall via Intune or run the `Install-Bginfo.ps1` script from the deployment package).*
