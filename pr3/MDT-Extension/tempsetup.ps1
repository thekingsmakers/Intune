# setup.ps1
# PowerShell script for initial MDT Extension configuration

[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[System.Reflection.Assembly]::LoadWithPartialName("System.Xml")

# --- Company Information ---
$CompanyName = "Thekingsmakers"
$GithubLink = "https://github.com/thekingsmakers/OSDeploy"
$TwitterLink = "https://x.com/thekingsmakers"

#region Software List
$AvailableSoftwareList = @(
    @{ Name = "ChromeEnterprise"; DisplayName = "Chrome Enterprise" }
    @{ Name = "AdobeAcrobat"; DisplayName = "Adobe Acrobat Reader DC" }
    @{ Name = "Wireshark"; DisplayName = "Wireshark" }
    @{ Name = "WinRAR"; DisplayName = "WinRAR 64-bit" }
    @{ Name = "7-Zip"; DisplayName = "7-Zip 64-bit" }
    # Add more software here as needed, keep Name consistent with SoftwareInstaller.ps1
)
#endregion

#region GUI Elements
$form = New-Object System.Windows.Forms.Form
$form.Text = "MDT Extension Initial Configuration - $($CompanyName)"
$form.Size = New-Object System.Drawing.Size(600, 750) # Increased form height
$form.StartPosition = "CenterScreen"

# --- Header Panel ---
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size = New-Object System.Drawing.Size(600, 50)
$headerPanel.BackColor = [System.Drawing.SystemColors]::ControlLight
$companyLabel = New-Object System.Windows.Forms.Label
$companyLabel.Location = New-Object System.Drawing.Point(20, 15)
$companyLabel.Size = New-Object System.Drawing.Size(560, 20)
$companyLabel.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
$companyLabel.Text = $CompanyName
$headerPanel.Controls.Add($companyLabel)
$form.Controls.Add($headerPanel)


# --- Device Naming ---
$groupBoxDeviceNaming = New-Object System.Windows.Forms.GroupBox
$groupBoxDeviceNaming.Text = "Device Naming"
$groupBoxDeviceNaming.Location = New-Object System.Drawing.Point(20, 60) # Adjusted Y position
$groupBoxDeviceNaming.Size = New-Object System.Drawing.Size(540, 60)


$labelPrefix = New-Object System.Windows.Forms.Label
$labelPrefix.Location = New-Object System.Drawing.Point(10, 25)
$labelPrefix.Size = New-Object System.Drawing.Size(100, 20)
$labelPrefix.Text = "Device Prefix:"
$groupBoxDeviceNaming.Controls.Add($labelPrefix)

$textBoxPrefix = New-Object System.Windows.Forms.TextBox
$textBoxPrefix.Location = New-Object System.Drawing.Point(120, 25)
$textBoxPrefix.Size = New-Object System.Drawing.Size(150, 20)
$groupBoxDeviceNaming.Controls.Add($textBoxPrefix)

$form.Controls.Add($groupBoxDeviceNaming)

# --- Domain Join ---
$groupBoxDomainJoin = New-Object System.Windows.Forms.GroupBox
$groupBoxDomainJoin.Text = "Domain Join Configuration"
$groupBoxDomainJoin.Location = New-Object System.Drawing.Point(20, 130) # Adjusted Y position
$groupBoxDomainJoin.Size = New-Object System.Drawing.Size(540, 180)
# ... (Rest of Domain Join GroupBox controls - same as before)
# (Copy from previous script - Domain Join GroupBox controls)
$checkBoxDomainJoinEnabled = New-Object System.Windows.Forms.CheckBox
$checkBoxDomainJoinEnabled.Location = New-Object System.Drawing.Point(10, 25)
$checkBoxDomainJoinEnabled.Size = New-Object System.Drawing.Size(100, 20)
$checkBoxDomainJoinEnabled.Text = "Enabled"
$groupBoxDomainJoin.Controls.Add($checkBoxDomainJoinEnabled)

$labelDomainName = New-Object System.Windows.Forms.Label
$labelDomainName.Location = New-Object System.Drawing.Point(10, 50)
$labelDomainName.Size = New-Object System.Drawing.Size(100, 20)
$labelDomainName.Text = "Domain Name:"
$groupBoxDomainJoin.Controls.Add($labelDomainName)

$textBoxDomainName = New-Object System.Windows.Forms.TextBox
$textBoxDomainName.Location = New-Object System.Drawing.Point(120, 50)
$textBoxDomainName.Size = New-Object System.Drawing.Size(200, 20)
$groupBoxDomainJoin.Controls.Add($textBoxDomainName)

$labelDomainIP = New-Object System.Windows.Forms.Label
$labelDomainIP.Location = New-Object System.Drawing.Point(10, 80)
$labelDomainIP.Size = New-Object System.Drawing.Size(100, 20)
$labelDomainIP.Text = "Domain IP:"
$groupBoxDomainJoin.Controls.Add($labelDomainIP)

$textBoxDomainIP = New-Object System.Windows.Forms.TextBox
$textBoxDomainIP.Location = New-Object System.Drawing.Point(120, 80)
$textBoxDomainIP.Size = New-Object System.Drawing.Size(200, 20)
$groupBoxDomainJoin.Controls.Add($textBoxDomainIP)

$labelOUPath = New-Object System.Windows.Forms.Label
$labelOUPath.Location = New-Object System.Drawing.Point(10, 110)
$labelOUPath.Size = New-Object System.Drawing.Size(100, 20)
$labelOUPath.Text = "OU Path:"
$groupBoxDomainJoin.Controls.Add($labelOUPath)

$textBoxOUPath = New-Object System.Windows.Forms.TextBox
$textBoxOUPath.Location = New-Object System.Drawing.Point(120, 110)
$textBoxOUPath.Size = New-Object System.Drawing.Size(300, 20) # Wider textbox for OU Path
$groupBoxDomainJoin.Controls.Add($textBoxOUPath)

$labelUsername = New-Object System.Windows.Forms.Label
$labelUsername.Location = New-Object System.Drawing.Point(10, 140)
$labelUsername.Size = New-Object System.Drawing.Size(100, 20)
$labelUsername.Text = "Username:"
$groupBoxDomainJoin.Controls.Add($labelUsername)

$textBoxUsername = New-Object System.Windows.Forms.TextBox
$textBoxUsername.Location = New-Object System.Drawing.Point(120, 140)
$textBoxUsername.Size = New-Object System.Drawing.Size(200, 20)
$groupBoxDomainJoin.Controls.Add($textBoxUsername)

$labelPassword = New-Object System.Windows.Forms.Label
$labelPassword.Location = New-Object System.Drawing.Point(330, 140)
$labelPassword.Size = New-Object System.Drawing.Size(100, 20)
$labelPassword.Text = "Password:"
$groupBoxDomainJoin.Controls.Add($labelPassword)

$textBoxPassword = New-Object System.Windows.Forms.TextBox
$textBoxPassword.Location = New-Object System.Drawing.Point(440, 140)
$textBoxPassword.Size = New-Object System.Drawing.Size(90, 20)
$textBoxPassword.UseSystemPasswordChar = $true
$groupBoxDomainJoin.Controls.Add($textBoxPassword)


$form.Controls.Add($groupBoxDomainJoin)


# --- Windows Activation ---
$groupBoxWindowsActivation = New-Object System.Windows.Forms.GroupBox
$groupBoxWindowsActivation.Text = "Windows Activation"
$groupBoxWindowsActivation.Location = New-Object System.Drawing.Point(20, 320) # Adjusted Y position
$groupBoxWindowsActivation.Size = New-Object System.Drawing.Size(540, 80)

$labelProductKey = New-Object System.Windows.Forms.Label
$labelProductKey.Location = New-Object System.Drawing.Point(10, 30)
$labelProductKey.Size = New-Object System.Drawing.Size(100, 20)
$labelProductKey.Text = "Product Key:"
$groupBoxWindowsActivation.Controls.Add($labelProductKey)

$textBoxProductKey = New-Object System.Windows.Forms.TextBox
$textBoxProductKey.Location = New-Object System.Drawing.Point(120, 30)
$textBoxProductKey.Size = New-Object System.Drawing.Size(300, 20) # Wider textbox for Product Key
$groupBoxWindowsActivation.Controls.Add($textBoxProductKey)

$form.Controls.Add($groupBoxWindowsActivation)


# --- Software Installation ---
$groupBoxSoftwareInstallation = New-Object System.Windows.Forms.GroupBox
$groupBoxSoftwareInstallation.Text = "Software Installation"
$groupBoxSoftwareInstallation.Location = New-Object System.Drawing.Point(20, 410) # Adjusted Y position
$groupBoxSoftwareInstallation.Size = New-Object System.Drawing.Size(540, 250)

$checkedListBoxSoftware = New-Object System.Windows.Forms.CheckedListBox
$checkedListBoxSoftware.Location = New-Object System.Drawing.Point(10, 25)
$checkedListBoxSoftware.Size = New-Object System.Drawing.Size(520, 210)
# Populate Checkbox List with Software
foreach ($Software in $AvailableSoftwareList) {
    $checkedListBoxSoftware.Items.Add($Software.DisplayName)
}
$groupBoxSoftwareInstallation.Controls.Add($checkedListBoxSoftware)

$form.Controls.Add($groupBoxSoftwareInstallation)


# --- Buttons ---
$buttonSaveConfig = New-Object System.Windows.Forms.Button
$buttonSaveConfig.Location = New-Object System.Drawing.Point(250, 670) # Adjusted button position
$buttonSaveConfig.Size = New-Object System.Drawing.Size(100, 30)
$buttonSaveConfig.Text = "Save Config"
$form.Controls.Add($buttonSaveConfig)


# --- Footer Panel ---
$footerPanel = New-Object System.Windows.Forms.Panel
$footerPanel.Location = New-Object System.Drawing.Point(0, 710) # Adjusted Y position
$footerPanel.Size = New-Object System.Drawing.Size(600, 40)
$footerPanel.BackColor = [System.Drawing.SystemColors]::ControlLight
$footerLabel = New-Object System.Windows.Forms.Label
$footerLabel.Location = New-Object System.Drawing.Point(20, 10)
$footerLabel.Size = New-Object System.Drawing.Size(560, 20)
$footerLabel.Text = "GitHub: $($GithubLink) | Twitter: $($TwitterLink)"
$footerLabel.TextAlign = "MiddleCenter"
$footerPanel.Controls.Add($footerLabel)
$form.Controls.Add($footerPanel)


#endregion

# Load Existing Configuration (rest of the script remains the same from here)
# ... (Load Configuration, Button Click Event Handler, Display Form, Setup Script Finished)
# Load Existing Configuration
$configFilePath = "MDT-Extension/Configuration/config.xml"
if (Test-Path $configFilePath) {
    try {
        $xmlConfig = [xml](Get-Content $configFilePath)

        # Debugging output after loading XML
        Write-Host "--- After Loading XML ---"
        Write-Host "xmlConfig: $($xmlConfig)"
        Write-Host "xmlConfig.Configuration: $($xmlConfig.Configuration)"
        if ($xmlConfig.Configuration) {
            Write-Host "xmlConfig.Configuration.SoftwareInstallation: $($xmlConfig.Configuration.SoftwareInstallation)"
            if ($xmlConfig.Configuration.SoftwareInstallation) {
                # Ensure Packages node exists after loading
                if (-not $xmlConfig.Configuration.SoftwareInstallation.Packages) {
                    Write-Warning "Packages node is missing after loading, creating it..."
                    $packagesElement = $xmlConfig.CreateElement("Packages")
                    $xmlConfig.Configuration.SoftwareInstallation.AppendChild($packagesElement)
                }
                Write-Host "Packages Node Type After Load: $($xmlConfig.Configuration.SoftwareInstallation.Packages.GetType().FullName)"
                Write-Host "xmlConfig.Configuration.SoftwareInstallation.Packages: $($xmlConfig.Configuration.SoftwareInstallation.Packages)"
            } else {
                Write-Error "xmlConfig.Configuration.SoftwareInstallation is NULL after load"
            }
        } else {
            Write-Error "xmlConfig.Configuration is NULL after load"
        }


        $textBoxPrefix.Text = $xmlConfig.Configuration.DeviceNaming.Prefix
        if (-not [string]::IsNullOrEmpty($xmlConfig.Configuration.DomainJoin.Enabled)) {
            $checkBoxDomainJoinEnabled.Checked = [System.Convert]::ToBoolean($xmlConfig.Configuration.DomainJoin.Enabled)
        } else {
            $checkBoxDomainJoinEnabled.Checked = $false
        }
        $textBoxDomainName.Text = $xmlConfig.Configuration.DomainJoin.DomainName
        $textBoxDomainIP.Text = $xmlConfig.Configuration.DomainJoin.DomainIP
        $textBoxOUPath.Text = $xmlConfig.Configuration.DomainJoin.OUPath
        $textBoxUsername.Text = $xmlConfig.Configuration.DomainJoin.Credentials.Username
        # Password intentionally not loaded for security
        $textBoxProductKey.Text = $xmlConfig.Configuration.WindowsActivation.ProductKey

        # Load selected software from config
        if ($xmlConfig.Configuration.SoftwareInstallation.Packages -and $xmlConfig.Configuration.SoftwareInstallation.Packages.Package) {
            $selectedPackages = @($xmlConfig.Configuration.SoftwareInstallation.Packages.Package)
            foreach ($package in $selectedPackages) {
                $softwareDisplayName = ($AvailableSoftwareList | Where-Object {$_.Name -eq $package.InnerText}).DisplayName
                $index = $checkedListBoxSoftware.Items.IndexOf($softwareDisplayName)
                if ($index -ge 0) {
                    $checkedListBoxSoftware.SetItemChecked($index, $true)
                }
            }
        }
    }
    catch {
        Write-Warning "Error loading existing configuration: $_"
        [System.Windows.Forms.MessageBox]::Show("Error loading existing configuration: $($_.Exception.Message)", "Configuration Load Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
}
else
{
    # Create default config file programmatically if it doesn't exist
    $xmlConfig = New-Object System.Xml.XmlDocument

    $configurationElement = $xmlConfig.CreateElement("Configuration")
    $xmlConfig.AppendChild($configurationElement)

    $deviceNamingElement = $xmlConfig.CreateElement("DeviceNaming")
    $prefixElement = $xmlConfig.CreateElement("Prefix")
    $deviceNamingElement.AppendChild($prefixElement)
    $configurationElement.AppendChild($deviceNamingElement)

    $domainJoinElement = $xmlConfig.CreateElement("DomainJoin")
    $enabledElement = $xmlConfig.CreateElement("Enabled")
    $enabledElement.InnerText = "false"
    $domainJoinElement.AppendChild($enabledElement)
    $domainNameElement = $xmlConfig.CreateElement("DomainName")
    $domainJoinElement.AppendChild($domainNameElement)
    $domainIPElement = $xmlConfig.CreateElement("DomainIP")
    $domainJoinElement.AppendChild($domainIPElement)
    $ouPathElement = $xmlConfig.CreateElement("OUPath")
    $domainJoinElement.AppendChild($ouPathElement)
    $credentialsElement = $xmlConfig.CreateElement("Credentials")
    $usernameElement = $xmlConfig.CreateElement("Username")
    $credentialsElement.AppendChild($usernameElement)
    $passwordElement = $xmlConfig.CreateElement("Password")
    $credentialsElement.AppendChild($passwordElement)
    $domainJoinElement.AppendChild($credentialsElement)
    $configurationElement.AppendChild($domainJoinElement)

    $windowsActivationElement = $xmlConfig.CreateElement("WindowsActivation")
    $productKeyElement = $xmlConfig.CreateElement("ProductKey")
    $windowsActivationElement.AppendChild($productKeyElement)
    $configurationElement.AppendChild($windowsActivationElement)

    $softwareInstallationElement = $xmlConfig.CreateElement("SoftwareInstallation")
    # Ensure SoftwareInstallation and Packages nodes are created
    $packagesElement = $xmlConfig.CreateElement("Packages")
    $softwareInstallationElement.AppendChild($packagesElement)
    $configurationElement.AppendChild($softwareInstallationElement)

    $xmlConfig.Save($configFilePath)
}


# Button Click Event Handler
$buttonSaveConfig.Add_Click({
    try {
        # Update Configuration XML with GUI values
        $xmlConfig.Configuration.DeviceNaming.Prefix = $textBoxPrefix.Text
        $xmlConfig.Configuration.DomainJoin.Enabled = $checkBoxDomainJoinEnabled.Checked.ToString()
        $xmlConfig.Configuration.DomainJoin.DomainName = $textBoxDomainName.Text
        $xmlConfig.Configuration.DomainJoin.DomainIP = $textBoxDomainIP.Text
        $xmlConfig.Configuration.DomainJoin.OUPath = $textBoxOUPath.Text
        $xmlConfig.Configuration.DomainJoin.Credentials.Username = $textBoxUsername.Text
        $xmlConfig.Configuration.DomainJoin.Credentials.Password = $textBoxPassword.Text
        $xmlConfig.Configuration.WindowsActivation.ProductKey = $textBoxProductKey.Text

        # Ensure SoftwareInstallation node exists
        $softwareInstallationNode = $xmlConfig.Configuration.SoftwareInstallation
        if (-not $softwareInstallationNode) {
            $softwareInstallationNode = $xmlConfig.CreateElement("SoftwareInstallation")
            $xmlConfig.Configuration.AppendChild($softwareInstallationNode)
        }

        # Ensure Packages node exists
        $packagesNode = $softwareInstallationNode.SelectSingleNode("Packages")
        if (-not $packagesNode) {
            $packagesNode = $xmlConfig.CreateElement("Packages")
            $softwareInstallationNode.AppendChild($packagesNode)
        }

        # Clear existing packages
        while ($packagesNode.HasChildNodes) {
            $packagesNode.RemoveChild($packagesNode.FirstChild)
        }

        # Add selected software packages
        foreach ($checkedItem in $checkedListBoxSoftware.CheckedItems) {
            $softwareName = ($AvailableSoftwareList | Where-Object {$_.DisplayName -eq $checkedItem}).Name
            $packageElement = $xmlConfig.CreateElement("Package")
            $packageElement.InnerText = $softwareName
            $packagesNode.AppendChild($packageElement)
        }

        # Save XML Configuration
        if (-not (Test-Path "MDT-Extension/Configuration")) {
            New-Item -ItemType Directory -Path "MDT-Extension/Configuration" -Force
        }
        $xmlConfig.Save($configFilePath)
        
        [System.Windows.Forms.MessageBox]::Show("Configuration saved successfully to $($configFilePath)", "Configuration Saved", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
    catch {
        Write-Error "Error saving configuration: $_"
        [System.Windows.Forms.MessageBox]::Show("Error saving configuration: $($_.Exception.Message)", "Configuration Save Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# Load selected software from config.xml
[void]$form.ShowDialog()

Write-Host "Setup script finished."
