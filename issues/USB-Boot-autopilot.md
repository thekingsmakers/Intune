# Detailed Issues for USB Boot Autopilot Folder

### 1. Windows Crashes in WinPE
   - **Description**: Windows crashes during the WinPE phase, specifically caused by improper handling of dynamic disk partitioning.
   - **Severity**: Critical
   - **Workaround**: Edit the dynamic disk formatting script to fix this issue while a permanent solution is being developed.

---

### 2. Windows Installation Fails at 75%
   - **Description**: Installation halts at 75%, possibly due to triggers during the OS installation process. This might be linked to bypassing Windows 11 requirements.
   - **Severity**: High
   - **Status**: Investigation ongoing to identify causes of these triggers.

---

### 3. No Actions Triggered After OOBE
   - **Description**: Post-OOBE, no actions are being triggered as a result of a bug in the main orchestrator.
   - **Severity**: High
   - **Status**: Fix is in progress to address this issue in orchestration scripts.

---

### 4. Logging System Improvements
   - **Description**: Logging lacks robustness. Developing a solution to mirror Setup Panther logs directly to the console for better debugging.
   - **Severity**: Medium
