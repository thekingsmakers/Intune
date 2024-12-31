# Author: Omar Osman Mahat (@thekingsmakers)
# Title: Omar Osman Mahat Software Installer
# Twitter: @thekingsmakers

# Load Windows Forms and Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Check for upgrade argument
$upgradeMode = $args -contains "/upgrade"

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Omar Osman Mahat Software Installer"
$form.Size = New-Object System.Drawing.Size(600, 500)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30) # Dark background
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# Gradient Background Panel
$panel = New-Object System.Windows.Forms.Panel
$panel.Size = $form.ClientSize
$panel.Paint += {
    $gradientBrush = New-Object Drawing.Drawing2D.LinearGradientBrush(
        $panel.ClientRectangle,
        [System.Drawing.Color]::FromArgb(20, 20, 20),
        [System.Drawing.Color]::FromArgb(40, 40, 40),
        [Drawing.Drawing2D.LinearGradientMode]::Vertical
    )
    $_.Graphics.FillRectangle($gradientBrush, $panel.ClientRectangle)
}
$form.Controls.Add($panel)

# Title Label
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Omar Osman Mahat Software Installer"
$titleLabel.AutoSize = $true
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$titleLabel.Location = New-Object System.Drawing.Point(20, 20)
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 150, 255) # Futuristic blue
$panel.Controls.Add($titleLabel)

# Countdown Label
$countdownLabel = New-Object System.Windows.Forms.Label
$countdownLabel.Text = "Time remaining: 10 seconds"
$countdownLabel.AutoSize = $true
$countdownLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$countdownLabel.Location = New-Object System.Drawing.Point(20, 70)
$countdownLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 200, 200) # Cyan
$panel.Controls.Add($countdownLabel)

# Software ListBox
$softwareListBox = New-Object System.Windows.Forms.CheckedListBox
$softwareListBox.Location = New-Object System.Drawing.Point(20, 120)
$softwareListBox.Size = New-Object System.Drawing.Size(550, 200)
$softwareListBox.CheckOnClick = $true
$softwareListBox.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
$softwareListBox.ForeColor = [System.Drawing.Color]::White
$softwareListBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$softwareListBox.Items.Add("Google Chrome Enterprise")
$softwareListBox.Items.Add("Microsoft Office 365 Enterprise")
$softwareListBox.Items.Add("Adobe Reader")
$softwareListBox.Items.Add("WinRAR")
$softwareListBox.Items.Add("7-Zip")
$panel.Controls.Add($softwareListBox)

# Progress Bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 350)
$progressBar.Size = New-Object System.Drawing.Size(550, 20)
$progressBar.Style = "Continuous"
$progressBar.ForeColor = [System.Drawing.Color]::FromArgb(0, 150, 255) # Futuristic blue
$progressBar.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
$panel.Controls.Add($progressBar)

# Install Button
$installButton = New-Object System.Windows.Forms.Button
$installButton.Text = "Install Selected"
$installButton.Location = New-Object System.Drawing.Point(20, 400)
$installButton.Size = New-Object System.Drawing.Size(150, 40)
$installButton.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 255) # Futuristic blue
$installButton.ForeColor = [System.Drawing.Color]::White
$installButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$installButton.FlatStyle = "Flat"
$installButton.FlatAppearance.BorderSize = 0
$installButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$installButton.Add_Click({
    Start-Installation
})
$panel.Controls.Add($installButton)

# Countdown Timer
$countdown = 10
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000 # 1 second
$timer.Add_Tick({
    $countdown--
    $countdownLabel.Text = "Time remaining: $countdown seconds"
    if ($countdown -le 0) {
        $timer.Stop()
        Start-Installation -All
    }
})

# Function to start installation
function Start-Installation {
    param (
        [switch]$All = $false
    )

    $timer.Stop() # Stop the countdown
    $selectedSoftware = if ($All) { $softwareListBox.Items } else { $softwareListBox.CheckedItems }

    if ($selectedSoftware.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No software selected. Installing all software.", "Info")
        $selectedSoftware = $softwareListBox.Items
    }

    $progressBar.Maximum = $selectedSoftware.Count
    $progressBar.Value = 0

    foreach ($software in $selectedSoftware) {
        Install-Software -Name $software
        $progressBar.Value++

        # Prompt to continue after each installation
        $result = [System.Windows.Forms.MessageBox]::Show("$software has been installed. Do you want to continue?", "Continue?", [System.Windows.Forms.MessageBoxButtons]::YesNo)
        if ($result -eq "No") {
            break
        }
    }

    [System.Windows.Forms.MessageBox]::Show("Installation completed!", "Info")
    $form.Close()
}

# Function to install or upgrade software
function Install-Software {
    param (
        [string]$Name
    )

    switch ($Name) {
        "Google Chrome Enterprise" {
            $url = "https://dl.google.com/tag/s/dl/chrome/install/latest/chrome_installer.exe"
            $installer = "$env:TEMP\chrome_installer.exe"
            Invoke-WebRequest -Uri $url -OutFile $installer
            Start-Process -FilePath $installer -ArgumentList "/silent /install" -Wait
        }
        "Microsoft Office 365 Enterprise" {
            $url = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_16227-20246.exe"
            $installer = "$env:TEMP\officedeploymenttool.exe"
            $config = "$env:TEMP\configuration.xml"
            Invoke-WebRequest -Uri $url -OutFile $installer
            @"
<Configuration ID="9ff14b38-ee71-4d99-8811-94238b2211bb">
  <Info Description="" />
  <Add OfficeClientEdition="64" Channel="SemiAnnual">
    <Product ID="O365ProPlusRetail">
      <Language ID="MatchOS" />
      <Language ID="ar-sa" />
      <ExcludeApp ID="Groove" />
      <ExcludeApp ID="Lync" />
    </Product>
  </Add>
  <Property Name="SharedComputerLicensing" Value="0" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
  <Property Name="DeviceBasedLicensing" Value="0" />
  <Property Name="SCLCacheOverride" Value="0" />
  <Updates Enabled="TRUE" />
  <RemoveMSI>
    <IgnoreProduct ID="PrjPro" />
    <IgnoreProduct ID="PrjStd" />
    <IgnoreProduct ID="VisPro" />
    <IgnoreProduct ID="VisStd" />
  </RemoveMSI>
  <Display Level="Full" AcceptEULA="TRUE" />
</Configuration>
"@ | Out-File -FilePath $config -Encoding ASCII
            Start-Process -FilePath $installer -ArgumentList "/configure $config" -Wait
        }
        "Adobe Reader" {
            $url = "https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/2200120141/AcroRdrDC2200120141_MUI.exe"
            $installer = "$env:TEMP\AcroRdrDC2200120141_MUI.exe"
            Invoke-WebRequest -Uri $url -OutFile $installer
            Start-Process -FilePath $installer -ArgumentList "/sAll /rs /rps /msi /norestart /quiet EULA_ACCEPT=YES" -Wait
        }
        "WinRAR" {
            $url = "https://www.win-rar.com/fileadmin/winrar-versions/winrar/winrar-x64-623.exe"
            $installer = "$env:TEMP\winrar-x64-623.exe"
            Invoke-WebRequest -Uri $url -OutFile $installer
            Start-Process -FilePath $installer -ArgumentList "/s" -Wait
        }
        "7-Zip" {
            $url = "https://www.7-zip.org/a/7z2201-x64.exe"
            $installer = "$env:TEMP\7z2201-x64.exe"
            Invoke-WebRequest -Uri $url -OutFile $installer
            Start-Process -FilePath $installer -ArgumentList "/S" -Wait
        }
    }
}

# Start the countdown timer
$timer.Start()

# Show the form
$form.ShowDialog()
