<#
.SYNOPSIS
    GUI Application to get the primary user and their details for a list of devices from Microsoft Intune.

.DESCRIPTION
    This script provides a Windows Forms GUI to select a CSV file containing device hostnames.
    It connects to Microsoft Graph, queries Intune for each device, and outputs the results to a new CSV file.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create Main Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Azure Device Owners Tool"
$form.Size = New-Object System.Drawing.Size(600, 500)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#1E1E1E")
$form.ForeColor = [System.Drawing.Color]::White
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$fontRegular = New-Object System.Drawing.Font("Segoe UI", 10)
$fontBold = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$fontTitle = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)

# Title
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Azure Device Owners Fetcher"
$lblTitle.Font = $fontTitle
$lblTitle.AutoSize = $true
$lblTitle.Location = New-Object System.Drawing.Point(20, 20)
$form.Controls.Add($lblTitle)

# Input Group
$lblInput = New-Object System.Windows.Forms.Label
$lblInput.Text = "Input CSV:"
$lblInput.Font = $fontRegular
$lblInput.Location = New-Object System.Drawing.Point(20, 60)
$lblInput.AutoSize = $true
$form.Controls.Add($lblInput)

$txtInput = New-Object System.Windows.Forms.TextBox
$txtInput.Location = New-Object System.Drawing.Point(100, 58)
$txtInput.Size = New-Object System.Drawing.Size(350, 25)
$txtInput.Font = $fontRegular
$txtInput.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#333333")
$txtInput.ForeColor = [System.Drawing.Color]::White
$txtInput.BorderStyle = "FixedSingle"
$form.Controls.Add($txtInput)

$btnBrowseInput = New-Object System.Windows.Forms.Button
$btnBrowseInput.Text = "Browse"
$btnBrowseInput.Location = New-Object System.Drawing.Point(460, 57)
$btnBrowseInput.Size = New-Object System.Drawing.Size(100, 27)
$btnBrowseInput.Font = $fontRegular
$btnBrowseInput.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#444444")
$btnBrowseInput.FlatStyle = "Flat"
$btnBrowseInput.FlatAppearance.BorderSize = 0
$form.Controls.Add($btnBrowseInput)

# Output Group
$lblOutput = New-Object System.Windows.Forms.Label
$lblOutput.Text = "Output CSV:"
$lblOutput.Font = $fontRegular
$lblOutput.Location = New-Object System.Drawing.Point(20, 100)
$lblOutput.AutoSize = $true
$form.Controls.Add($lblOutput)

$txtOutput = New-Object System.Windows.Forms.TextBox
$txtOutput.Location = New-Object System.Drawing.Point(100, 98)
$txtOutput.Size = New-Object System.Drawing.Size(350, 25)
$txtOutput.Font = $fontRegular
$txtOutput.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#333333")
$txtOutput.ForeColor = [System.Drawing.Color]::White
$txtOutput.BorderStyle = "FixedSingle"
$form.Controls.Add($txtOutput)

$btnBrowseOutput = New-Object System.Windows.Forms.Button
$btnBrowseOutput.Text = "Browse"
$btnBrowseOutput.Location = New-Object System.Drawing.Point(460, 97)
$btnBrowseOutput.Size = New-Object System.Drawing.Size(100, 27)
$btnBrowseOutput.Font = $fontRegular
$btnBrowseOutput.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#444444")
$btnBrowseOutput.FlatStyle = "Flat"
$btnBrowseOutput.FlatAppearance.BorderSize = 0
$form.Controls.Add($btnBrowseOutput)

# Logs Group
$lblLogs = New-Object System.Windows.Forms.Label
$lblLogs.Text = "Execution Logs:"
$lblLogs.Font = $fontBold
$lblLogs.Location = New-Object System.Drawing.Point(20, 140)
$lblLogs.AutoSize = $true
$form.Controls.Add($lblLogs)

$txtLogs = New-Object System.Windows.Forms.TextBox
$txtLogs.Multiline = $true
$txtLogs.ScrollBars = "Vertical"
$txtLogs.Location = New-Object System.Drawing.Point(20, 165)
$txtLogs.Size = New-Object System.Drawing.Size(540, 200)
$txtLogs.Font = New-Object System.Drawing.Font("Consolas", 9)
$txtLogs.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#111111")
$txtLogs.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#00FF00")
$txtLogs.BorderStyle = "FixedSingle"
$txtLogs.ReadOnly = $true
$form.Controls.Add($txtLogs)

# Start Button
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Connect & Start"
$btnStart.Location = New-Object System.Drawing.Point(20, 380)
$btnStart.Size = New-Object System.Drawing.Size(150, 35)
$btnStart.Font = $fontBold
$btnStart.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0078D7")
$btnStart.FlatStyle = "Flat"
$btnStart.FlatAppearance.BorderSize = 0
$form.Controls.Add($btnStart)

# About Button
$btnAbout = New-Object System.Windows.Forms.Button
$btnAbout.Text = "About / Info"
$btnAbout.Location = New-Object System.Drawing.Point(410, 380)
$btnAbout.Size = New-Object System.Drawing.Size(150, 35)
$btnAbout.Font = $fontRegular
$btnAbout.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#444444")
$btnAbout.FlatStyle = "Flat"
$btnAbout.FlatAppearance.BorderSize = 0
$form.Controls.Add($btnAbout)

# Kingsmakers Label
$lblKings = New-Object System.Windows.Forms.Label
$lblKings.Text = "built by teh kingsmakers"
$lblKings.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$lblKings.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#888888")
$lblKings.AutoSize = $true
$lblKings.Location = New-Object System.Drawing.Point(20, 430)
$form.Controls.Add($lblKings)


# Helper function to append logs
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $txtLogs.AppendText("[$timestamp] $Message`r`n")
    # Auto-scroll to bottom
    $txtLogs.SelectionStart = $txtLogs.Text.Length
    $txtLogs.ScrollToCaret()
    # Keep GUI responsive
    [System.Windows.Forms.Application]::DoEvents()
}

# Button Click Events
$btnBrowseInput.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "CSV Files (*.csv)|*.csv|All Files (*.*)|*.*"
    $dialog.Title = "Select Input CSV File"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtInput.Text = $dialog.FileName
    }
})

$btnBrowseOutput.Add_Click({
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Filter = "CSV Files (*.csv)|*.csv|All Files (*.*)|*.*"
    $dialog.Title = "Select Output CSV File"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtOutput.Text = $dialog.FileName
    }
})

$btnAbout.Add_Click({
    [System.Windows.Forms.MessageBox]::Show(
        "Intune Device Owners Fetcher`n`nThis tool reads a list of hostnames from a CSV file, connects to your Intune environment using Microsoft Graph, and retrieves the primary user for each device.`n`nEnsure your input CSV has a column named 'Hostname'.`n`nBuilt by teh kingsmakers.",
        "About / Info",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
})

$btnStart.Add_Click({
    $inputPath = $txtInput.Text
    $outputPath = $txtOutput.Text

    # Validation
    if ([string]::IsNullOrWhiteSpace($inputPath) -or [string]::IsNullOrWhiteSpace($outputPath)) {
        [System.Windows.Forms.MessageBox]::Show("Please select both an input and output CSV file.", "Validation Error", 0, 16)
        return
    }

    if (-not (Test-Path $inputPath)) {
        [System.Windows.Forms.MessageBox]::Show("The selected input file does not exist.", "Validation Error", 0, 16)
        return
    }

    # Disable buttons during execution
    $btnStart.Enabled = $false
    $btnBrowseInput.Enabled = $false
    $btnBrowseOutput.Enabled = $false
    
    $txtLogs.Clear()
    Write-Log "Starting process..."

    try {
        if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
            Write-Log "ERROR: Microsoft.Graph module not found."
            [System.Windows.Forms.MessageBox]::Show("The Microsoft.Graph module is not installed. Please open a PowerShell console as Administrator and run:`n`nInstall-Module Microsoft.Graph -Force", "Module Missing", 0, 16)
            return
        }
        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

        Write-Log "Checking Graph Connection..."
        $context = Get-MgContext
        if (-not $context) {
            Write-Log "Connecting to Microsoft Graph..."
            try {
                Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All", "User.Read.All" -NoWelcome -ErrorAction Stop
            } catch {
                Write-Log "Interactive login error: $($_.Exception.Message)"
                Write-Log "Attempting Device Code login. PLEASE CHECK THE POWERSHELL CONSOLE BEHIND THIS WINDOW."
                [System.Windows.Forms.MessageBox]::Show("Interactive login failed. A Device Code login will now be attempted. Please check the blue PowerShell console window behind this app for instructions on how to authenticate.", "Authentication Fallback", 0, 64)
                Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All", "User.Read.All" -UseDeviceAuthentication -NoWelcome
            }
        }
        Write-Log "Connected successfully to: $((Get-MgContext).TenantId)"

        Write-Log "Reading input CSV: $inputPath"
        $devices = Import-Csv $inputPath
        $results = @()

        foreach ($row in $devices) {
            $hostname = $null
            if ($row.PSObject.Properties.Match('Hostname').Count) { $hostname = $row.Hostname }
            elseif ($row.PSObject.Properties.Match('DeviceName').Count) { $hostname = $row.DeviceName }
            elseif ($row.PSObject.Properties.Match('Name').Count) { $hostname = $row.Name }
            elseif ($row.PSObject.Properties.Match('Device').Count) { $hostname = $row.Device }

            if (-not $hostname) {
                Write-Log "ERROR: Row missing 'Hostname' column. Skipping..."
                continue
            }

            Write-Log "Querying Intune for device: $hostname"
            
            $deviceInfo = [ordered]@{
                Hostname = $hostname
                Username = $null
                Email    = $null
                DeviceId = $null
                Status   = "Not Found"
            }

            try {
                $device = Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$hostname'" -Top 1 -ErrorAction Stop

                if ($device) {
                    $deviceInfo.DeviceId = $device.Id
                    $deviceInfo.Status = "Device Found"
                    
                    if ($device.UserId) {
                        $ownerId = $device.UserId
                        $user = Get-MgUser -UserId $ownerId -ErrorAction Stop
                        
                        if ($user) {
                            $deviceInfo.Username = $user.DisplayName
                            $deviceInfo.Email = $user.UserPrincipalName
                            $deviceInfo.Status = "Success"
                            Write-Log "  -> Found Primary User: $($user.DisplayName) ($($user.UserPrincipalName))"
                        } else {
                            $deviceInfo.Email = $device.UserPrincipalName
                            $deviceInfo.Status = "User Details Not Found, using UPN"
                            Write-Log "  -> Found User ID, but failed to retrieve display name. Using UPN."
                        }
                    } elseif ($device.UserPrincipalName) {
                        $deviceInfo.Email = $device.UserPrincipalName
                        $deviceInfo.Status = "Primary User UPN Found, No UserID"
                        Write-Log "  -> Found Primary User UPN: $($device.UserPrincipalName)"
                    } else {
                        $deviceInfo.Status = "No Primary User Found"
                        Write-Log "  -> Device found, but has no primary user assigned in Intune."
                    }
                } else {
                    Write-Log "  -> Device not found in Intune."
                }
            } catch {
                Write-Log "  -> Error: $($_.Exception.Message)"
                $deviceInfo.Status = "Error: $($_.Exception.Message)"
            }

            $results += New-Object PSObject -Property $deviceInfo
        }

        Write-Log "Exporting results to $outputPath"
        $results | Export-Csv -Path $outputPath -NoTypeInformation
        Write-Log "Done!"
        [System.Windows.Forms.MessageBox]::Show("Process completed successfully! Results saved to:`n$outputPath", "Success", 0, 64)

    } catch {
        Write-Log "CRITICAL ERROR: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("An error occurred: $($_.Exception.Message)", "Error", 0, 16)
    } finally {
        $btnStart.Enabled = $true
        $btnBrowseInput.Enabled = $true
        $btnBrowseOutput.Enabled = $true
    }
})

# Show Form
Write-Host "Launching GUI..."
$form.ShowDialog() | Out-Null
