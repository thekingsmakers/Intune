#requires -Version 5.1
<#!
The Kingsmaker – PowerShell Script Signer (WPF GUI)
Website: https://thekingsmaker.org
Created by: The Kingsmakers

Description
-----------
A modern WPF GUI to sign PowerShell scripts (.ps1) using a code-signing certificate from the
CurrentUser or LocalMachine certificate store (My/Personal). You can browse/upload a script,
choose an output folder, select a certificate, and sign with optional timestamping. Includes an
About tab with usage help and project information.

How to run
----------
1) Save this file as: ScriptSignerGUI.ps1
2) Open Windows PowerShell (x86 or x64) **as your normal user** (admin not required unless importing to LocalMachine store).
3) Run: powershell -ExecutionPolicy Bypass -File .\ScriptSignerGUI.ps1

Notes
-----
- You need a valid Code Signing certificate installed (EKU 1.3.6.1.5.5.7.3.3). Use **Import PFX** to import one if needed.
- Timestamp server defaults to DigiCert; you can change/disable it.
- Output file will default to `<originalName>.signed.ps1` in the selected folder unless you choose overwrite.
- Hash algorithm: SHA256.
- Works on Windows PowerShell 5.1 and PowerShell 7+ with WPF available on Windows.

#>

[CmdletBinding()]
param()

# Ensure STA for WPF
if (![System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    $psi = New-Object System.Diagnostics.ProcessStartInfo -Property @{
        FileName = (Get-Process -Id $PID).Path
        Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        UseShellExecute = $true
    }
    [void][System.Diagnostics.Process]::Start($psi)
    return
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -AssemblyName System.Windows.Forms

function Write-LogUI {
    param(
        [Parameter(Mandatory)][System.Windows.Controls.TextBox]$LogBox,
        [string]$Message,
        [ConsoleColor]$Color
    )
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $LogBox.AppendText("[$timestamp] $Message`r`n")
    $LogBox.ScrollToEnd()
}

function Get-CodeSigningCerts {
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    param()
    $ekuOid = '1.3.6.1.5.5.7.3.3' # Code Signing
    $stores = @(
        'Cert:\CurrentUser\My',
        'Cert:\LocalMachine\My'
    )
    $now = Get-Date
    $certs = foreach ($store in $stores) {
        Get-ChildItem -Path $store -ErrorAction SilentlyContinue |
            Where-Object {
                $_.HasPrivateKey -and $_.NotAfter -gt $now -and (
                    $_.EnhancedKeyUsageList.FriendlyName -contains 'Code Signing' -or
                    $_.Extensions | Where-Object { $_.Oid.Value -eq $ekuOid }
                )
            }
    }
    $certs | Sort-Object NotBefore -Descending
}

function Import-CodeSigningPfx {
    [CmdletBinding()] param(
        [Parameter(Mandatory)] [string] $PfxPath,
        [Parameter()] [string] $Password,
        [ValidateSet('CurrentUser','LocalMachine')] [string] $StoreScope = 'CurrentUser'
    )
    if (-not (Test-Path $PfxPath)) { throw "PFX not found: $PfxPath" }
    $secure = if ($Password) { ConvertTo-SecureString $Password -AsPlainText -Force } else { Read-Host -AsSecureString 'PFX Password' }
    $store = if ($StoreScope -eq 'LocalMachine') { 'Cert:\LocalMachine\My' } else { 'Cert:\CurrentUser\My' }
    $result = Import-PfxCertificate -FilePath $PfxPath -CertStoreLocation $store -Password $secure -Exportable -ErrorAction Stop
    return $result
}

function Sign-PsFile {
    [CmdletBinding()] param(
        [Parameter(Mandatory)] [string] $File,
        [Parameter(Mandatory)] [System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate,
        [Parameter(Mandatory)] [string] $OutputPath,
        [Parameter()] [switch] $Overwrite,
        [Parameter()] [switch] $UseTimestamp,
        [Parameter()] [string] $TimestampUrl = 'http://timestamp.digicert.com'
    )
    if (-not (Test-Path $File)) { throw "Input script not found: $File" }
    $outFile = Join-Path $OutputPath (Split-Path $File -Leaf)
    if (-not $Overwrite) {
        $name = [IO.Path]::GetFileNameWithoutExtension($outFile)
        $dir = [IO.Path]::GetDirectoryName($outFile)
        $ext = [IO.Path]::GetExtension($outFile)
        $outFile = Join-Path $dir ("{0}.signed{1}" -f $name, $ext)
    }
    Copy-Item -Path $File -Destination $outFile -Force

    $sigParams = @{
        FilePath      = $outFile
        Certificate   = $Certificate
        HashAlgorithm = 'SHA256'
        ErrorAction   = 'Stop'
    }
    if ($UseTimestamp) { $sigParams['TimestampServer'] = $TimestampUrl }

    $signature = Set-AuthenticodeSignature @sigParams
    return [PSCustomObject]@{
        OutputFile = $outFile
        Status     = $signature.Status
        StatusMessage = $signature.StatusMessage
        SignerCertificate = $signature.SignerCertificate.Subject
        TimeStamp = $signature.TimeStamperCertificate.Subject
    }
}

# -------------------- XAML (Modern WPF UI) --------------------
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="The Kingsmaker – PS Script Signer" Height="540" Width="900" WindowStartupLocation="CenterScreen" Background="#0B1220" AllowsTransparency="False" ResizeMode="CanResizeWithGrip">
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border CornerRadius="18" Padding="18" Margin="0,0,0,12">
            <Border.Background>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                    <GradientStop Color="#3A7CFD" Offset="0"/>
                    <GradientStop Color="#6B5BFF" Offset="0.5"/>
                    <GradientStop Color="#C94BFF" Offset="1"/>
                </LinearGradientBrush>
            </Border.Background>
            <DockPanel>
                <StackPanel Orientation="Vertical" DockPanel.Dock="Left">
                    <TextBlock Text="The Kingsmaker – PowerShell Script Signer" FontSize="22" FontWeight="Bold" Foreground="White"/>
                    <TextBlock Text="thekingsmaker.org  •  Created by The Kingsmaker" FontSize="12" Foreground="#E6FFFFFF" Margin="0,6,0,0"/>
                </StackPanel>
            </DockPanel>
        </Border>

        <!-- Content -->
        <TabControl Grid.Row="1" Background="#0B1220" BorderBrush="#223" BorderThickness="1" Padding="8">
            <TabItem Header="Sign">
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

                    <!-- Script file picker -->
                    <TextBlock Grid.Row="0" Grid.Column="0" Text="Script (.ps1):" Foreground="#CFE1FF" VerticalAlignment="Center" Margin="0,0,8,0"/>
                    <TextBox   Grid.Row="0" Grid.Column="1" x:Name="TxtScript" Height="34" Background="#111827" Foreground="#E5E7EB" BorderBrush="#374151" BorderThickness="1" Padding="8"/>
                    <StackPanel Grid.Row="0" Grid.Column="2" Orientation="Horizontal" Margin="8,0,0,0">
                        <Button x:Name="BtnBrowseScript" Content="Browse…" Height="34" Padding="14,4" Margin="0,0,8,0"/>
                        <Border CornerRadius="8" Background="#111827" BorderBrush="#374151" BorderThickness="1" Padding="10" AllowDrop="True" x:Name="DropZone" ToolTip="Drag & drop a .ps1 file here">
                            <TextBlock Text="Drop file" Foreground="#9CA3AF"/>
                        </Border>
                    </StackPanel>

                    <!-- Output folder picker -->
                    <TextBlock Grid.Row="1" Grid.Column="0" Text="Output folder:" Foreground="#CFE1FF" VerticalAlignment="Center" Margin="0,8,8,0"/>
                    <TextBox   Grid.Row="1" Grid.Column="1" x:Name="TxtOutput" Height="34" Background="#111827" Foreground="#E5E7EB" BorderBrush="#374151" BorderThickness="1" Padding="8" Margin="0,8,0,0"/>
                    <Button    Grid.Row="1" Grid.Column="2" x:Name="BtnBrowseFolder" Content="Choose…" Height="34" Padding="14,4" Margin="8,8,0,0"/>

                    <!-- Certificate selection -->
                    <TextBlock Grid.Row="2" Grid.Column="0" Text="Certificate:" Foreground="#CFE1FF" VerticalAlignment="Center" Margin="0,8,8,0"/>
                    <ComboBox  Grid.Row="2" Grid.Column="1" x:Name="CmbCert" Height="34" Background="#111827" Foreground="#E5E7EB" BorderBrush="#374151" BorderThickness="1" Padding="4" Margin="0,8,0,0"/>
                    <StackPanel Grid.Row="2" Grid.Column="2" Orientation="Horizontal" Margin="8,8,0,0">
                        <Button x:Name="BtnRefreshCerts" Content="Refresh" Height="34" Padding="12,4" Margin="0,0,8,0"/>
                        <Button x:Name="BtnImportPfx" Content="Import PFX…" Height="34" Padding="12,4"/>
                    </StackPanel>

                    <!-- Options -->
                    <StackPanel Grid.Row="3" Grid.Column="0" Grid.ColumnSpan="3" Orientation="Horizontal" Margin="0,10,0,0">
                        <CheckBox x:Name="ChkOverwrite" Content="Overwrite original file" Foreground="#E5E7EB" Margin="0,0,16,0"/>
                        <CheckBox x:Name="ChkTimestamp" Content="Timestamp (recommended)" IsChecked="True" Foreground="#E5E7EB" Margin="0,0,8,0"/>
                        <TextBox x:Name="TxtTimestamp" Width="320" Height="28" Text="http://timestamp.digicert.com" Background="#111827" Foreground="#E5E7EB" BorderBrush="#374151" BorderThickness="1" Padding="6"/>
                        <Button x:Name="BtnSign" Content="Sign Script" Height="34" Padding="18,4" Margin="12,0,0,0"/>
                    </StackPanel>

                    <!-- Log -->
                    <Border Grid.Row="4" Grid.Column="0" Grid.ColumnSpan="3" CornerRadius="12" Background="#0F172A" BorderBrush="#1F2937" BorderThickness="1" Padding="10" Margin="0,12,0,0">
                        <ScrollViewer VerticalScrollBarVisibility="Auto">
                            <TextBox x:Name="TxtLog" Background="#0F172A" Foreground="#D1D5DB" BorderThickness="0" IsReadOnly="True" TextWrapping="Wrap" AcceptsReturn="True"/>
                        </ScrollViewer>
                    </Border>
                </Grid>
            </TabItem>

            <TabItem Header="About & Usage">
                <ScrollViewer>
                    <StackPanel Margin="16">
                        <TextBlock Text="The Kingsmaker – PowerShell Script Signer" FontSize="20" FontWeight="Bold" Foreground="#F3F4F6"/>
                        <TextBlock Text="Website: thekingsmaker.org" Foreground="#9CA3AF" Margin="0,6,0,0"/>
                        <TextBlock Text="Created by the Kingsmaker" Foreground="#9CA3AF" Margin="0,2,0,0"/>
                        <Separator Margin="0,12,0,12"/>
                        <TextBlock TextWrapping="Wrap" Foreground="#E5E7EB">
Use this tool to sign your PowerShell scripts using a valid code-signing certificate. Steps:
1) Choose or drag-drop the .ps1 file.
2) Choose an output folder.
3) Select your code-signing certificate. Use 'Import PFX…' to add one if needed.
4) Keep Timestamp enabled (recommended) to add a trusted time to your signature.
5) Click 'Sign Script'. Check the log below for results and the output file path.
                        </TextBlock>
                        <Separator Margin="0,12,0,12"/>
                        <TextBlock Text="Information about the code" FontSize="16" FontWeight="SemiBold" Foreground="#F3F4F6"/>
                        <TextBlock TextWrapping="Wrap" Foreground="#E5E7EB">
- Searches CurrentUser and LocalMachine Personal stores for certificates that have a Code Signing EKU and a private key.
- Uses SHA256 for signing via Set-AuthenticodeSignature.
- Optional timestamp server (default DigiCert) can be changed or turned off.
- Produces `<name>.signed.ps1` unless Overwrite is selected.
                        </TextBlock>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>
        </TabControl>

        <!-- Footer -->
        <DockPanel Grid.Row="2" Margin="0,12,0,0">
            <TextBlock DockPanel.Dock="Left" Text="© $(Get-Date).Year The Kingsmaker • thekingsmaker.org" Foreground="#7F8EA3"/>
            <TextBlock DockPanel.Dock="Right" Text="Built with PowerShell & WPF" Foreground="#7F8EA3"/>
        </DockPanel>
    </Grid>
</Window>
"@

# Parse XAML
$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$Window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$TxtScript      = $Window.FindName('TxtScript')
$BtnBrowseScript= $Window.FindName('BtnBrowseScript')
$DropZone       = $Window.FindName('DropZone')
$TxtOutput      = $Window.FindName('TxtOutput')
$BtnBrowseFolder= $Window.FindName('BtnBrowseFolder')
$CmbCert        = $Window.FindName('CmbCert')
$BtnRefreshCerts= $Window.FindName('BtnRefreshCerts')
$BtnImportPfx   = $Window.FindName('BtnImportPfx')
$ChkOverwrite   = $Window.FindName('ChkOverwrite')
$ChkTimestamp   = $Window.FindName('ChkTimestamp')
$TxtTimestamp   = $Window.FindName('TxtTimestamp')
$BtnSign        = $Window.FindName('BtnSign')
$TxtLog         = $Window.FindName('TxtLog')

# Populate / handlers
function Refresh-CertCombo {
    $CmbCert.Items.Clear()
    $certs = Get-CodeSigningCerts
    if (-not $certs) {
        [void]$CmbCert.Items.Add('[No code-signing certificates found]')
        $CmbCert.SelectedIndex = 0
        return
    }
    foreach ($c in $certs) {
        $disp = "{0}  |  Thumbprint: {1}  |  Store: {2}  |  Expires: {3}" -f $c.Subject, $c.Thumbprint, ($c.PSParentPath -replace '.*Cert:\\',''), $c.NotAfter.ToString('yyyy-MM-dd')
        $item = New-Object System.Windows.Controls.ComboBoxItem
        $item.Content = $disp
        $item.Tag = $c
        [void]$CmbCert.Items.Add($item)
    }
    $CmbCert.SelectedIndex = 0
}

Refresh-CertCombo

$BtnRefreshCerts.Add_Click({
    try {
        Refresh-CertCombo
        Write-LogUI -LogBox $TxtLog -Message 'Refreshed certificates.'
    } catch { Write-LogUI -LogBox $TxtLog -Message "Failed to refresh certificates: $_" }
})

$BtnImportPfx.Add_Click({
    try {
        $ofd = New-Object System.Windows.Forms.OpenFileDialog
        $ofd.Filter = 'PFX files (*.pfx)|*.pfx|All files (*.*)|*.*'
        if ($ofd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
        $pfx = $ofd.FileName
        $scope = [System.Windows.Forms.MessageBox]::Show('Import to CurrentUser? Click No for LocalMachine (requires admin).', 'Import scope', [System.Windows.Forms.MessageBoxButtons]::YesNo)
        $storeScope = if ($scope -eq [System.Windows.Forms.DialogResult]::Yes) { 'CurrentUser' } else { 'LocalMachine' }
        $pwd = Read-Host 'Enter PFX password (input is hidden)' -AsSecureString
        # Convert secure to plain for Import-PfxCertificate only if necessary
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwd)
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        try {
            $res = Import-CodeSigningPfx -PfxPath $pfx -Password $plain -StoreScope $storeScope
            Write-LogUI -LogBox $TxtLog -Message "Imported certificate(s) to $storeScope. Thumbprints: $($res.Thumbprint -join ', ')"
            Refresh-CertCombo
        } finally {
            if ($bstr) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        }
    } catch { Write-LogUI -LogBox $TxtLog -Message "Failed to import PFX: $_" }
})

$BtnBrowseScript.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = 'PowerShell (*.ps1)|*.ps1|All files (*.*)|*.*'
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $TxtScript.Text = $ofd.FileName
        Write-LogUI -LogBox $TxtLog -Message "Selected script: $($ofd.FileName)"
    }
})

$DropZone.Add_Drop({ param($sender,$e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $files = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
        if ($files -and $files[0].ToString().EndsWith('.ps1')) {
            $TxtScript.Text = $files[0]
            Write-LogUI -LogBox $TxtLog -Message "Dropped script: $($files[0])"
        } else {
            [System.Windows.MessageBox]::Show('Please drop a .ps1 file','Invalid file',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Warning) | Out-Null
        }
    }
})
$DropZone.Add_DragOver({ param($s,$e)
    $e.Effects = [System.Windows.DragDropEffects]::Copy
    $e.Handled = $true
})

$BtnBrowseFolder.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fbd.Description = 'Choose output folder for the signed script'
    if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $TxtOutput.Text = $fbd.SelectedPath
        Write-LogUI -LogBox $TxtLog -Message "Output folder: $($fbd.SelectedPath)"
    }
})

$BtnSign.Add_Click({
    try {
        if (-not (Test-Path $TxtScript.Text)) { throw 'Please select a valid script file.' }
        if (-not (Test-Path $TxtOutput.Text)) { throw 'Please choose a valid output folder.' }
        if (-not ($CmbCert.SelectedItem -and $CmbCert.SelectedItem -is [System.Windows.Controls.ComboBoxItem] -and $CmbCert.SelectedItem.Tag)) {
            throw 'Please select a code-signing certificate.'
        }
        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]$CmbCert.SelectedItem.Tag
        $useTs = $ChkTimestamp.IsChecked
        $tsUrl = $TxtTimestamp.Text
        Write-LogUI -LogBox $TxtLog -Message "Signing started…"
        $result = Sign-PsFile -File $TxtScript.Text -Certificate $cert -OutputPath $TxtOutput.Text -Overwrite:$($ChkOverwrite.IsChecked) -UseTimestamp:$useTs -TimestampUrl $tsUrl
        Write-LogUI -LogBox $TxtLog -Message "Signature Status: $($result.Status)"
        if ($result.StatusMessage) { Write-LogUI -LogBox $TxtLog -Message $result.StatusMessage }
        Write-LogUI -LogBox $TxtLog -Message "Signed file: $($result.OutputFile)"
        if ($result.TimeStamp) { Write-LogUI -LogBox $TxtLog -Message "Timestamped by: $($result.TimeStamp)" }
        [System.Windows.MessageBox]::Show("Signed successfully:\n$($result.OutputFile)", 'Done', 'OK', 'Information') | Out-Null
    } catch {
        Write-LogUI -LogBox $TxtLog -Message "❌ Error: $_"
        [System.Windows.MessageBox]::Show("Signing failed:\n$_", 'Error', 'OK', 'Error') | Out-Null
    }
})

# Show
$Window.Topmost = $false
[void]$Window.ShowDialog()
