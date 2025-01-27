# SoftwareInstaller.ps1
# PowerShell script for software installation with GUI selection and silent install
# Software list and configuration are loaded from config.xml

Write-Host "Software Installer script started."

[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

# --- Configuration ---
$configFilePath = "MDT-Extension/Configuration/config.xml"
try {
    $xmlConfig = [xml](Get-Content $configFilePath)
    $SoftwarePackagesConfig = $xmlConfig.Configuration.SoftwareInstallation.Packages.Package
    if (-not $SoftwarePackagesConfig) {
        Write-Warning "No software packages configured in config.xml."
        $SoftwareList = @() # Initialize empty software list
    } else {
        # Convert XML Software Package nodes to PowerShell objects
        $SoftwareList = @()
        foreach ($PackageConfig in $SoftwarePackagesConfig) {
            $Software = [PSCustomObject]@{
                Name = $PackageConfig.Name
                DisplayName = $PackageConfig.DisplayName
                DownloadURL = $PackageConfig.DownloadURL
                SilentInstallArgs = $PackageConfig.SilentInstallArgs
            }
            $SoftwareList += $Software
        }
    }
}
catch {
    Write-Error "Error loading software installation configuration from $($configFilePath): $_"
    Write-Warning "Software Installer script may not function correctly."
    $SoftwareList = @() # Initialize empty software list in case of error
}

# --- GUI Elements ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Software Installation Selection"
$form.Size = New-Object System.Drawing.Size(500, 400)
$form.StartPosition = "CenterScreen"

$checkedListBoxSoftware = New-Object System.Windows.Forms.CheckedListBox
$checkedListBoxSoftware.Location = New-Object System.Drawing.Point(20, 20)
$checkedListBoxSoftware.Size = New-Object System.Drawing.Size(440, 250)

# Populate Checkbox List with Software from Config
foreach ($Software in $SoftwareList) {
    $checkedListBoxSoftware.Items.Add($Software.DisplayName)
}

$buttonInstall = New-Object System.Windows.Forms.Button
$buttonInstall.Location = New-Object System.Drawing.Point(200, 300)
$buttonInstall.Size = New-Object System.Drawing.Size(100, 30)
$buttonInstall.Text = "Install Selected"

$form.Controls.Add($checkedListBoxSoftware)
$form.Controls.Add($buttonInstall)
#endregion

# --- Button Click Event Handler ---
$buttonInstall.Add_Click({
    $selectedSoftware = @()
    foreach ($index in $checkedListBoxSoftware.CheckedIndices) {
        $selectedSoftware += $SoftwareList[$index]
    }

    if ($selectedSoftware.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No software selected for installation.", "Selection Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    Write-Host "Starting software installation..."

    foreach ($Software in $selectedSoftware) {
        Write-Host "Installing $($Software.DisplayName)..."
        Write-Host "Downloading from $($Software.DownloadURL)"

        $installerPath = Join-Path -Path $env:TEMP -ChildPath "$($Software.Name)Installer.exe"

        try {
            Invoke-WebRequest -Uri $Software.DownloadURL -OutFile $installerPath
            Write-Host "Installer downloaded to $($installerPath)"

            # Silent Install Command
            Write-Host "Executing silent install..."
            Start-Process -FilePath $installerPath -ArgumentList $Software.SilentInstallArgs -Wait -NoNewWindow

            Write-Host "$($Software.DisplayName) installed successfully."
            [System.Windows.Forms.MessageBox]::Show("$($Software.DisplayName) installed successfully.", "Installation Status", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

        }
        catch {
            Write-Error "Error installing $($Software.DisplayName): $_"
            [System.Windows.Forms.MessageBox]::Show("Error installing $($Software.DisplayName): $($_.Exception.Message)", "Installation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
        finally {
            # Cleanup installer file
            if (Test-Path $installerPath) {
                Remove-Item $installerPath -Force
                Write-Host "Installer file removed: $($installerPath)"
            }
        }
    }

    Write-Host "Software installation process finished."
    [System.Windows.Forms.MessageBox]::Show("Software installation process finished.", "Installation Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

# Display the Form
$form.ShowDialog() | Out-Null

Write-Host "Software Installer script finished."