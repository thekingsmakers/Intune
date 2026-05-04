# Intune Device Owners Fetcher

**Built by teh kingsmakers**

A stylized Windows PowerShell GUI application that reads a list of device hostnames from a CSV file, connects to your Microsoft Intune environment using the Microsoft Graph API, and retrieves the assigned Primary User for each device. The results are then exported to a new, clean CSV file.

## Features
- **Modern GUI**: A sleek dark-mode Windows Forms interface.
- **Intune Integration**: Connects directly to Microsoft Intune to fetch up-to-date Primary User assignments.
- **Live Logs**: Watch the execution process in real-time within the application's built-in log viewer.
- **Robust Authentication**: Supports standard interactive browser login and provides a Device Code fallback if the browser window fails to render.
- **Automated Module Installation**: Prompts you with exact instructions if you are missing the required PowerShell modules.

---

## Requirements & Prerequisites

Before using this tool, ensure your environment meets the following requirements:

1. **PowerShell**: Windows PowerShell 5.1 or PowerShell 7+.
2. **Microsoft Graph Module**: The `Microsoft.Graph.Authentication` module must be installed. 
   - *If you do not have it, open an elevated (Administrator) PowerShell console and run:*
     ```powershell
     Install-Module Microsoft.Graph -Force -Scope CurrentUser
     ```
3. **Permissions**: You must have an account with access to your Azure/Intune tenant. The script requires the following Microsoft Graph scopes:
   - `DeviceManagementManagedDevices.Read.All` (To read Intune device data)
   - `User.Read.All` (To translate the user IDs into Display Names)
   - *Note: Depending on your organization's Azure AD settings, you may need an Administrator to grant consent the first time you run the tool.*

---

## Input File Format

The tool requires an input CSV file containing a list of the devices you want to look up. 

**Critical Requirement:** The CSV file **must** contain a column header named `Hostname`, `DeviceName`, `Name`, or `Device`.

**Example `devices.csv`:**
```csv
Hostname,Location,Notes
DESKTOP-1234567,New York,Test Machine
LAPTOP-ABCDEFG,London,Deployed
```

---

## How to Use

1. **Launch the Tool**: 
   Right-click `Get-DeviceOwners.ps1` and select **Run with PowerShell**, or open a PowerShell console, navigate to the folder, and type:
   ```powershell
   .\Get-DeviceOwners.ps1
   ```
2. **Select Input**: In the GUI, click the **Browse** button next to "Input CSV" and select your `.csv` file containing the hostnames.
3. **Select Output**: Click the **Browse** button next to "Output CSV" and choose where you want to save the final report.
4. **Start**: Click the blue **Connect & Start** button.
5. **Authenticate**: A Microsoft login window will appear. Enter your credentials.
   - *Fallback*: If the login window fails to appear, a prompt will instruct you to look at the blue PowerShell console running behind the GUI. Follow the instructions there to complete a "Device Code" login.
6. **Review Logs**: Watch the "Execution Logs" box to see the tool query Intune for each device.
7. **Complete**: Once finished, a success message will appear, and your new CSV will be ready at your chosen output location!

---

## Troubleshooting

- **"Module Missing" Error**: You must install the Microsoft Graph PowerShell module. See the Prerequisites section.
- **"Device not found in Intune"**: Ensure the hostname exactly matches the `Device Name` in the Intune portal.
- **Login window doesn't appear**: Check the PowerShell console window running behind the application. You likely need to perform a Device Code authentication by visiting `https://microsoft.com/devicelogin`.
