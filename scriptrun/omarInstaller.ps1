# Temporarily set execution policy to allow script execution
$originalExecutionPolicy = Get-ExecutionPolicy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Author: Omar Osman Mahat (@thekingsmakers)
# Title: Omar Osman Mahat Software Installer
# Twitter: @thekingsmakers

# Load Windows Forms and Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Check for silent and upgrade arguments
$silentMode = $args -contains "/silent"
$upgradeMode = $args -contains "/upgrade"

# Function to install or upgrade software
function Install-Software {
    param (
        [string]$Name,
        [switch]$Upgrade = $false
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

# Function to create and show the GUI
function Show-GUI {
    param (
        [string[]]$SoftwareList,
        [switch]$Silent = $false
    )

    # Create the main form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Omar Osman Mahat Software Installer"
    $form.Size = New-Object System.Drawing.Size(600, 500)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30) # Dark background
    $form.ForeColor = [System.Drawing.Color]::White
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.TopMost = $true # Always on top

    # Gradient Background
    $gradientImage = New-Object System.Drawing.Bitmap($form.Width, $form.Height)
    $gradientGraphics = [System.Drawing.Graphics]::FromImage($gradientImage)
    $gradientBrush = New-Object Drawing.Drawing2D.LinearGradientBrush(
        $form.ClientRectangle,
        [System.Drawing.Color]::FromArgb(20, 20, 20),
        [System.Drawing.Color]::FromArgb(40, 40, 40),
        [Drawing.Drawing2D.LinearGradientMode]::Vertical
    )
    $gradientGraphics.FillRectangle($gradientBrush, $form.ClientRectangle)
    $form.BackgroundImage = $gradientImage

    # Title Label
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Omar Osman Software Installer"
    $titleLabel.AutoSize = $true
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 150, 255) # Futuristic blue
    $form.Controls.Add($titleLabel)

    # Credits Label
    $creditsLabel = New-Object System.Windows.Forms.Label
    $creditsLabel.Text = "Created by Omar Osman Mahat | Twitter: @thekingsmakers"
    $creditsLabel.AutoSize = $true
    $creditsLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $creditsLabel.Location = New-Object System.Drawing.Point(20, 60)
    $creditsLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 200, 200) # Cyan
    $form.Controls.Add($creditsLabel)

    # Progress Bar
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(20, 400)
    $progressBar.Size = New-Object System.Drawing.Size(550, 20)
    $progressBar.Style = "Continuous"
    $progressBar.ForeColor = [System.Drawing.Color]::FromArgb(0, 150, 255) # Futuristic blue
    $progressBar.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $form.Controls.Add($progressBar)

    # Software ListBox
    $softwareListBox = New-Object System.Windows.Forms.CheckedListBox
    $softwareListBox.Location = New-Object System.Drawing.Point(20, 120)
    $softwareListBox.Size = New-Object System.Drawing.Size(550, 200)
    $softwareListBox.CheckOnClick = $true
    $softwareListBox.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
    $softwareListBox.ForeColor = [System.Drawing.Color]::White
    $softwareListBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    foreach ($software in $SoftwareList) {
        $softwareListBox.Items.Add($software)
    }
    $form.Controls.Add($softwareListBox)

    # Install Button
    $installButton = New-Object System.Windows.Forms.Button
    $installButton.Text = "Install Selected"
    $installButton.Location = New-Object System.Drawing.Point(20, 350)
    $installButton.Size = New-Object System.Drawing.Size(150, 40)
    $installButton.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 255) # Futuristic blue
    $installButton.ForeColor = [System.Drawing.Color]::White
    $installButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $installButton.FlatStyle = "Flat"
    $installButton.FlatAppearance.BorderSize = 0
    $installButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    $installButton.Add_Click({
        $selectedSoftware = $softwareListBox.CheckedItems
        if ($selectedSoftware.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No software selected. Please select at least one software.", "Info")
        } else {
            $progressBar.Maximum = $selectedSoftware.Count
            $progressBar.Value = 0
            foreach ($software in $selectedSoftware) {
                Install-Software -Name $software
                $progressBar.Value++
                $softwareListBox.SetItemChecked($softwareListBox.Items.IndexOf($software), $false) # Uncheck after installation
            }
            [System.Windows.Forms.MessageBox]::Show("Installation completed!", "Info")
            $form.Close()
        }
    })
    $form.Controls.Add($installButton)

    # Silent Mode: Automatically install all software
    if ($Silent) {
        $progressBar.Maximum = $softwareListBox.Items.Count
        $progressBar.Value = 0
        foreach ($software in $softwareListBox.Items) {
            Install-Software -Name $software
            $progressBar.Value++
            $softwareListBox.SetItemChecked($softwareListBox.Items.IndexOf($software), $false) # Uncheck after installation
        }
        [System.Windows.Forms.MessageBox]::Show("Installation completed!", "Info")
        $form.Close()
    }

    # Show the form
    $form.ShowDialog()
}

# Main script logic
$softwareList = @("Google Chrome Enterprise", "Microsoft Office 365 Enterprise", "Adobe Reader", "WinRAR", "7-Zip")

if ($silentMode) {
    Show-GUI -SoftwareList $softwareList -Silent
} elseif ($upgradeMode) {
    foreach ($software in $softwareList) {
        Install-Software -Name $software -Upgrade
    }
} else {
    Show-GUI -SoftwareList $softwareList
}

# Restore the original execution policy
Set-ExecutionPolicy -ExecutionPolicy $originalExecutionPolicy -Scope Process -Force
