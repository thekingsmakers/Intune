#requires -Version 5.1
<# 
.SYNOPSIS
    The Kingsmaker – PowerShell Script Signer (WPF GUI)
.DESCRIPTION
    A modern WPF GUI to sign PowerShell scripts (.ps1) using a code-signing certificate
    from the CurrentUser or LocalMachine certificate store (My/Personal).
.NOTES
    Website: https://thekingsmaker.org
    Created by: The Kingsmaker
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\ScriptSignerGUI.ps1
#>

[CmdletBinding()]
param()

# Ensure STA for WPF
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    $psi = New-Object System.Diagnostics.ProcessStartInfo -Property @{
        FileName         = (Get-Process -Id $PID).Path
        Arguments        = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        UseShellExecute  = $true
    }
    [void][System.Diagnostics.Process]::Start($psi)
    return
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
Add-Type -AssemblyName System.Security

function Write-LogUI {
    param(
        [Parameter(Mandatory)][System.Windows.Controls.TextBox]$LogBox,
        [string]$Message
    )
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $LogBox.Dispatcher.Invoke([action]{
        $LogBox.AppendText("[$timestamp] $Message`r`n")
        $LogBox.ScrollToEnd()
    })
}

function Get-CodeSigningCerts {
    $ekuOid = '1.3.6.1.5.5.7.3.3'
    $stores  = 'Cert:\CurrentUser\My', 'Cert:\LocalMachine\My'
    $now     = Get-Date
    $certs   = foreach ($store in $stores) {
        try {
            Get-ChildItem -Path $store -ErrorAction Stop |
                Where-Object {
                    $_.HasPrivateKey -and $_.NotAfter -gt $now -and
                    ($_.EnhancedKeyUsageList.FriendlyName -contains 'Code Signing' -or
                     $_.EnhancedKeyUsageList.ObjectId -contains $ekuOid)
                }
        } catch {
            Write-Warning "Could not access store: $store"
        }
    }
    $certs | Sort-Object NotBefore -Descending
}

function Import-CodeSigningPfx {
    param(
        [Parameter(Mandatory)][string]$PfxPath,
        [string]$Password,
        [ValidateSet('CurrentUser','LocalMachine')][string]$StoreScope = 'CurrentUser'
    )
    if (-not (Test-Path $PfxPath)) { throw "PFX not found: $PfxPath" }

    $secure = if ($Password) {
        ConvertTo-SecureString $Password -AsPlainText -Force
    } else {
        (Get-Credential -Message 'PFX password (user name ignored)' -UserName 'ignore').Password
    }

    $storeLoc = if ($StoreScope -eq 'LocalMachine') { 'Cert:\LocalMachine\My' } else { 'Cert:\CurrentUser\My' }
    Import-PfxCertificate -FilePath $PfxPath -CertStoreLocation $storeLoc -Password $secure -Exportable -ErrorAction Stop
}

function Sign-PsFile {
    param(
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)][System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        [Parameter(Mandatory)][string]$OutputPath,
        [switch]$Overwrite,
        [switch]$UseTimestamp,
        [string]$TimestampUrl = 'http://timestamp.digicert.com'
    )
    if (-not (Test-Path $File)) { throw "Input script not found: $File" }
    if (-not (Test-Path $OutputPath)) { throw "Output path not found: $OutputPath" }

    $outFile = Join-Path $OutputPath (Split-Path $File -Leaf)
    if (-not $Overwrite -and (Test-Path $outFile)) {
        $base  = [IO.Path]::GetFileNameWithoutExtension($outFile)
        $dir   = [IO.Path]::GetDirectoryName($outFile)
        $ext   = [IO.Path]::GetExtension($outFile)
        $i     = 1
        do {
            $outFile = Join-Path $dir "${base}.signed$(if($i -gt 1){ "-$i" })$ext"
            $i++
        } while (Test-Path $outFile)
    }

    Copy-Item -Path $File -Destination $outFile -Force

    $sig = Set-AuthenticodeSignature -FilePath $outFile -Certificate $Certificate -HashAlgorithm SHA256 -ErrorAction Stop `
        -TimestampServer $(if ($UseTimestamp) { $TimestampUrl })
    [PSCustomObject]@{
        OutputFile        = $outFile
        Status            = $sig.Status
        StatusMessage     = $sig.StatusMessage
        SignerCertificate = $sig.SignerCertificate.Subject
        TimeStamp         = if ($sig.TimeStamperCertificate) { $sig.TimeStamperCertificate.Subject } else { 'Not timestamped' }
    }
}

# ---------- CLEAN XAML ----------
$xaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="The Kingsmaker - PS Script Signer"
    Height="600"
    Width="900"
    WindowStartupLocation="CenterScreen"
    Background="#FAFAFA"
    FontFamily="Segoe UI">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#0078D4"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="Margin" Value="4"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#106EBE"/>
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background" Value="#005A9E"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style TargetType="TextBox">
            <Setter Property="Background" Value="White"/>
            <Setter Property="Foreground" Value="#202020"/>
            <Setter Property="BorderBrush" Value="#DEDEDE"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8"/>
            <Setter Property="Margin" Value="4"/>
        </Style>

        <Style TargetType="ComboBox">
            <Setter Property="Background" Value="White"/>
            <Setter Property="Foreground" Value="#202020"/>
            <Setter Property="BorderBrush" Value="#DEDEDE"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8"/>
            <Setter Property="Margin" Value="4"/>
            <Setter Property="Height" Value="32"/>
        </Style>

        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#202020"/>
            <Setter Property="Margin" Value="4"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
        </Style>

        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="#202020"/>
            <Setter Property="Margin" Value="4"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
        </Style>

        <Style TargetType="TabItem">
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>
    </Window.Resources>

    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border CornerRadius="8" Padding="16" Margin="0,0,0,12" Background="#0078D4">
            <StackPanel>
                <TextBlock Text="The Kingsmaker - PowerShell Script Signer" FontSize="22" FontWeight="Bold" Foreground="White"/>
                <TextBlock Text="thekingsmaker.org  -  Created by The Kingsmaker" FontSize="12" Foreground="#CCFFFFFF" Margin="0,6,0,0"/>
            </StackPanel>
        </Border>

        <!-- Tabs -->
        <TabControl Grid.Row="1" Background="Transparent" BorderThickness="0" Padding="0">
            <TabItem Header="Sign Script">
                <Grid Margin="8">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <!-- Script file -->
                    <TextBlock Grid.Row="0" Grid.Column="0" Text="Script (.ps1):" VerticalAlignment="Center" Margin="4"/>
                    <TextBox Grid.Row="0" Grid.Column="1" x:Name="TxtScript" Height="34"/>
                    <Button Grid.Row="0" Grid.Column="2" x:Name="BtnBrowseScript" Content="Browse..." Width="80"/>

                    <!-- Output -->
                    <TextBlock Grid.Row="1" Grid.Column="0" Text="Output folder:" Margin="4,12,4,4"/>
                    <TextBox Grid.Row="1" Grid.Column="1" x:Name="TxtOutput" Height="34" Margin="0,8,0,0"/>
                    <Button Grid.Row="1" Grid.Column="2" x:Name="BtnBrowseFolder" Content="Choose..." Width="80" Margin="0,8,0,0"/>

                    <!-- Certificate -->
                    <TextBlock Grid.Row="2" Grid.Column="0" Text="Certificate:" Margin="4,12,4,4"/>
                    <ComboBox Grid.Row="2" Grid.Column="1" x:Name="CmbCert" Margin="0,8,0,0"/>
                    <StackPanel Grid.Row="2" Grid.Column="2" Orientation="Horizontal" Margin="0,8,0,0">
                        <Button x:Name="BtnRefreshCerts" Content="Refresh" Width="80" Margin="0,0,4,0"/>
                        <Button x:Name="BtnImportPfx" Content="Import PFX" Width="80"/>
                    </StackPanel>

                    <!-- Options -->
                    <StackPanel Grid.Row="3" Grid.Column="0" Grid.ColumnSpan="3" Orientation="Horizontal" Margin="0,16,0,0">
                        <CheckBox x:Name="ChkOverwrite" Content="Overwrite original file" Margin="8,0,16,0"/>
                        <CheckBox x:Name="ChkTimestamp" Content="Add timestamp" IsChecked="True" Margin="0,0,8,0"/>
                        <TextBox x:Name="TxtTimestamp" Width="260" Height="28" Text="http://timestamp.digicert.com" VerticalAlignment="Center"/>
                        <Button x:Name="BtnSign" Content="Sign Script" Width="100" Height="36" Margin="12,0,0,0" FontSize="14"/>
                    </StackPanel>

                    <!-- Log -->
                    <Border Grid.Row="4" Grid.Column="0" Grid.ColumnSpan="3" CornerRadius="4" Background="#F5F5F5" BorderBrush="#E0E0E0" BorderThickness="1" Padding="10" Margin="0,12,0,0">
                        <ScrollViewer VerticalScrollBarVisibility="Auto">
                            <TextBox x:Name="TxtLog" Background="Transparent" Foreground="#202020" BorderThickness="0" IsReadOnly="True" TextWrapping="Wrap" AcceptsReturn="True" FontFamily="Consolas" FontSize="12"/>
                        </ScrollViewer>
                    </Border>
                </Grid>
            </TabItem>

            <TabItem Header="About &amp; Usage">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="8">
                    <StackPanel>
                        <TextBlock Text="About The Kingsmaker PowerShell Script Signer" FontSize="18" FontWeight="Bold" Margin="0,0,0,12"/>
                        <TextBlock Text="Use this tool to sign PowerShell scripts with a valid code-signing certificate." TextWrapping="Wrap" Margin="0,0,0,12"/>

                        <TextBlock Text="How to Use:" FontSize="14" FontWeight="Bold" Margin="0,16,0,8"/>
                        <TextBlock Text="1. Select a PowerShell script (.ps1) to sign" TextWrapping="Wrap" Margin="16,0,0,4"/>
                        <TextBlock Text="2. Choose an output folder for the signed script" TextWrapping="Wrap" Margin="16,0,0,4"/>
                        <TextBlock Text="3. Select a code-signing certificate from the dropdown" TextWrapping="Wrap" Margin="16,0,0,4"/>
                        <TextBlock Text="4. Optionally import a PFX certificate if needed" TextWrapping="Wrap" Margin="16,0,0,4"/>
                        <TextBlock Text="5. Configure signing options (timestamp, overwrite)" TextWrapping="Wrap" Margin="16,0,0,4"/>
                        <TextBlock Text="6. Click 'Sign Script' to sign your PowerShell script" TextWrapping="Wrap" Margin="16,0,0,12"/>

                        <TextBlock Text="Certificate Requirements:" FontSize="14" FontWeight="Bold" Margin="0,16,0,8"/>
                        <TextBlock Text="- Must have code-signing extended key usage (EKU)" TextWrapping="Wrap" Margin="16,0,0,4"/>
                        <TextBlock Text="- Must have an associated private key" TextWrapping="Wrap" Margin="16,0,0,4"/>
                        <TextBlock Text="- Must be valid (not expired)" TextWrapping="Wrap" Margin="16,0,0,4"/>
                        <TextBlock Text="- Can be from CurrentUser or LocalMachine store" TextWrapping="Wrap" Margin="16,0,0,12"/>

                        <TextBlock Text="Timestamp Servers:" FontSize="14" FontWeight="Bold" Margin="0,16,0,8"/>
                        <TextBlock Text="Common timestamp server URLs:" TextWrapping="Wrap" Margin="16,0,0,4"/>
                        <TextBlock Text="- http://timestamp.digicert.com" TextWrapping="Wrap" Margin="32,0,0,4"/>
                        <TextBlock Text="- http://timestamp.comodoca.com" TextWrapping="Wrap" Margin="32,0,0,4"/>
                        <TextBlock Text="- http://timestamp.sectigo.com" TextWrapping="Wrap" Margin="32,0,0,4"/>
                        <TextBlock Text="- http://rfc3161timestamp.globalsign.com/advanced" TextWrapping="Wrap" Margin="32,0,0,12"/>

                        <TextBlock Text="Note:" FontWeight="Bold" Margin="0,16,0,8"/>
                        <TextBlock Text="Administrator privileges may be required to access certificates in the LocalMachine store or to import PFX files to the LocalMachine store." TextWrapping="Wrap" Margin="16,0,0,0"/>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>
        </TabControl>

        <!-- Footer -->
        <DockPanel Grid.Row="2" Margin="0,12,0,0">
            <TextBlock DockPanel.Dock="Left" Text="(c) 2023 The Kingsmaker - thekingsmaker.org" Foreground="#666666"/>
            <TextBlock DockPanel.Dock="Right" Text="Built with PowerShell &amp; WPF" Foreground="#666666"/>
        </DockPanel>
    </Grid>
</Window>
'@

# ---------- END XAML ----------

# Parse XAML
try {
    $reader = [System.Xml.XmlNodeReader]::new([xml]$xaml)
    $Window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    Write-Host "Error parsing XAML: $($_.Exception.Message)"
    exit 1
}

# Control references
$TxtScript        = $Window.FindName('TxtScript')
$BtnBrowseScript  = $Window.FindName('BtnBrowseScript')
$TxtOutput        = $Window.FindName('TxtOutput')
$BtnBrowseFolder  = $Window.FindName('BtnBrowseFolder')
$CmbCert          = $Window.FindName('CmbCert')
$BtnRefreshCerts  = $Window.FindName('BtnRefreshCerts')
$BtnImportPfx     = $Window.FindName('BtnImportPfx')
$ChkOverwrite     = $Window.FindName('ChkOverwrite')
$ChkTimestamp     = $Window.FindName('ChkTimestamp')
$TxtTimestamp     = $Window.FindName('TxtTimestamp')
$BtnSign          = $Window.FindName('BtnSign')
$TxtLog           = $Window.FindName('TxtLog')

# Default output folder
$TxtOutput.Text = [Environment]::GetFolderPath('MyDocuments')

function Refresh-CertCombo {
    $CmbCert.Items.Clear()
    $certs = Get-CodeSigningCerts
    if (-not $certs) {
        $item = [System.Windows.Controls.ComboBoxItem]::new()
        $item.Content = '[No code-signing certificates found]'
        $item.IsEnabled = $false
        $CmbCert.Items.Add($item) | Out-Null
        $CmbCert.SelectedIndex = 0
        Write-LogUI $TxtLog "No code-signing certificates found in certificate stores."
        return
    }
    foreach ($c in $certs) {
        $store = if ($c.PSPath -like "*LocalMachine*") { "LocalMachine" } else { "CurrentUser" }
        $item  = [System.Windows.Controls.ComboBoxItem]::new()
        $item.Content = "$($c.Subject) | Store: $store | Expires: $($c.NotAfter.ToString('yyyy-MM-dd'))"
        $item.ToolTip = "Thumbprint: $($c.Thumbprint)`nIssuer: $($c.Issuer)"
        $item.Tag = $c
        $CmbCert.Items.Add($item) | Out-Null
    }
    $CmbCert.SelectedIndex = 0
    Write-LogUI $TxtLog "Loaded $($certs.Count) code-signing certificate(s)."
}

# ------------- Event Handlers -------------
$BtnRefreshCerts.Add_Click({
    Write-LogUI $TxtLog "Refreshing certificates..."
    Refresh-CertCombo
})

$BtnBrowseScript.Add_Click({
    $ofd = [System.Windows.Forms.OpenFileDialog]::new()
    $ofd.Filter = 'PowerShell (*.ps1)|*.ps1|All files (*.*)|*.*'
    $ofd.Title  = 'Select a PowerShell script to sign'
    if ($ofd.ShowDialog() -eq 'OK') {
        $TxtScript.Text = $ofd.FileName
        Write-LogUI $TxtLog "Selected script: $($ofd.FileName)"
    }
})

$BtnBrowseFolder.Add_Click({
    $fbd = [System.Windows.Forms.FolderBrowserDialog]::new()
    $fbd.Description = 'Select output folder for signed script'
    $fbd.SelectedPath = $TxtOutput.Text
    if ($fbd.ShowDialog() -eq 'OK') {
        $TxtOutput.Text = $fbd.SelectedPath
        Write-LogUI $TxtLog "Output folder: $($fbd.SelectedPath)"
    }
})

$BtnImportPfx.Add_Click({
    $ofd = [System.Windows.Forms.OpenFileDialog]::new()
    $ofd.Filter = 'PFX files (*.pfx, *.p12)|*.pfx;*.p12|All files (*.*)|*.*'
    $ofd.Title  = 'Select a PFX certificate to import'
    if ($ofd.ShowDialog() -eq 'OK') {
        try {
            $choice = [System.Windows.MessageBox]::Show(
                'Import to LocalMachine store (requires admin) or CurrentUser store?',
                'Certificate Store', 'YesNoCancel', 'Question', 'No')
            if ($choice -eq 'Cancel') { return }
            $scope  = if ($choice -eq 'Yes') { 'LocalMachine' } else { 'CurrentUser' }

            $cred = Get-Credential -Message 'PFX password (username ignored)' -UserName 'ignore'
            if (-not $cred) { Write-LogUI $TxtLog 'PFX import cancelled.'; return }

            Write-LogUI $TxtLog "Importing PFX certificate to $scope store..."
            $cert = Import-CodeSigningPfx -PfxPath $ofd.FileName -Password $cred.Password -StoreScope $scope
            Write-LogUI $TxtLog "Imported certificate: $($cert.Thumbprint)"
            Refresh-CertCombo
        } catch {
            Write-LogUI $TxtLog "Error importing PFX: $($_.Exception.Message)"
            [System.Windows.MessageBox]::Show("Failed to import PFX:`n$($_.Exception.Message)", 'Error', 'OK', 'Error') | Out-Null
        }
    }
})

$BtnSign.Add_Click({
    try {
        if (-not (Test-Path $TxtScript.Text))   { throw 'Please select a valid script file.' }
        if (-not (Test-Path $TxtOutput.Text))   { throw 'Please choose a valid output folder.' }
        if (-not ($CmbCert.SelectedItem -and $CmbCert.SelectedItem.Tag)) { throw 'Please select a valid certificate.' }

        $cert        = $CmbCert.SelectedItem.Tag
        $useStamp    = $ChkTimestamp.IsChecked
        $stampUrl    = if ($useStamp) { $TxtTimestamp.Text } else { $null }

        Write-LogUI $TxtLog "Signing script with certificate: $($cert.Subject)..."
        $result = Sign-PsFile -File $TxtScript.Text -Certificate $cert -OutputPath $TxtOutput.Text `
            -Overwrite:$($ChkOverwrite.IsChecked) -UseTimestamp:$useStamp -TimestampUrl $stampUrl

        Write-LogUI $TxtLog "Signature status: $($result.Status) - $($result.StatusMessage)"
        Write-LogUI $TxtLog "Signed file saved to: $($result.OutputFile)"

        if ($result.Status -eq 'Valid') {
            [System.Windows.MessageBox]::Show("Script signed successfully!`n`nOutput: $($result.OutputFile)", 'Success', 'OK', 'Information') | Out-Null
        } else {
            [System.Windows.MessageBox]::Show("Script signed with status: $($result.Status)`n`n$($result.StatusMessage)", 'Warning', 'OK', 'Warning') | Out-Null
        }
    } catch {
        $err = $_.Exception.Message
        Write-LogUI $TxtLog "Error: $err"
        [System.Windows.MessageBox]::Show("Signing failed:`n$err", 'Error', 'OK', 'Error') | Out-Null
    }
})

# ------------------  Run  ------------------
Refresh-CertCombo
Write-LogUI $TxtLog 'Script Signer initialized. Select a script and certificate to begin.'

$Window.Add_Closed({ Write-Host 'Script Signer closed.' })
$null = $Window.ShowDialog()
