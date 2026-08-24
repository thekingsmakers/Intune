#Requires -Version 5.1
#Requires -Modules Microsoft.PowerShell.Utility

############
# DATA
############

$PackageList = ConvertFrom-Csv @'
    Identity, Family
    Clipchamp.Clipchamp, Clipchamp.Clipchamp_yxz26nhyzhsrt
    Microsoft.AV1VideoExtension, Microsoft.AV1VideoExtension_8wekyb3d8bbwe
    Microsoft.BingNews, Microsoft.BingNews_8wekyb3d8bbwe
    Microsoft.BingTranslator, Microsoft.BingTranslator_8wekyb3d8bbwe
    Microsoft.BingWeather, Microsoft.BingWeather_8wekyb3d8bbwe
    Microsoft.Cortana, Microsoft.549981C3F5F10_8wekyb3d8bbwe
    Microsoft.DesktopAppInstaller, Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
    Microsoft.DirectXRuntime, Microsoft.DirectXRuntime_8wekyb3d8bbwe
    Microsoft.GamingApp, Microsoft.GamingApp_8wekyb3d8bbwe
    Microsoft.GamingServices, Microsoft.GamingServices_8wekyb3d8bbwe
    Microsoft.GetHelp, Microsoft.GetHelp_8wekyb3d8bbwe
    Microsoft.Getstarted, Microsoft.Getstarted_8wekyb3d8bbwe
    Microsoft.HEIFImageExtension, Microsoft.HEIFImageExtension_8wekyb3d8bbwe
    Microsoft.HEVCVideoExtension, Microsoft.HEVCVideoExtension_8wekyb3d8bbwe
    Microsoft.Microsoft3DViewer, Microsoft.Microsoft3DViewer_8wekyb3d8bbwe
    Microsoft.MicrosoftFamily, MicrosoftCorporationII.MicrosoftFamily_8wekyb3d8bbwe
    Microsoft.MicrosoftHoloLens, Microsoft.MicrosoftHoloLens_8wekyb3d8bbwe
    Microsoft.MicrosoftJournal, Microsoft.MicrosoftJournal_8wekyb3d8bbwe
    Microsoft.MicrosoftOfficeHub, Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe
    Microsoft.MicrosoftOneDrive, Microsoft.MicrosoftSkyDrive_8wekyb3d8bbwe
    Microsoft.MicrosoftSolitaireCollection, Microsoft.MicrosoftSolitaireCollection_8wekyb3d8bbwe
    Microsoft.MicrosoftStickyNotes, Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe
    Microsoft.Minecraft, Microsoft.MinecraftEducationEdition_8wekyb3d8bbwe
    Microsoft.MixedReality.Portal, Microsoft.MixedReality.Portal_8wekyb3d8bbwe
    Microsoft.MPEG2VideoExtension, Microsoft.MPEG2VideoExtension_8wekyb3d8bbwe
    Microsoft.MSPaint, Microsoft.MSPaint_8wekyb3d8bbwe
    Microsoft.Office.Excel, Microsoft.Office.Excel_8wekyb3d8bbwe
    Microsoft.Office.OneNote, Microsoft.Office.OneNote_8wekyb3d8bbwe
    Microsoft.Office.PowerPoint, Microsoft.Office.PowerPoint_8wekyb3d8bbwe
    Microsoft.Office.Word, Microsoft.Office.Word_8wekyb3d8bbwe
    Microsoft.OutlookForWindows, Microsoft.OutlookForWindows_8wekyb3d8bbwe
    Microsoft.Paint, Microsoft.Paint_8wekyb3d8bbwe
    Microsoft.People, Microsoft.People_8wekyb3d8bbwe
    Microsoft.PowerAutomateDesktop, Microsoft.PowerAutomateDesktop_8wekyb3d8bbwe
    Microsoft.PowerShell, Microsoft.PowerShell_8wekyb3d8bbwe
    Microsoft.QuickAssist, MicrosoftCorporationII.QuickAssist_8wekyb3d8bbwe
    Microsoft.RawImageExtension, Microsoft.RawImageExtension_8wekyb3d8bbwe
    Microsoft.RemoteDesktop, Microsoft.RemoteDesktop_8wekyb3d8bbwe
    Microsoft.ScreenSketch, Microsoft.ScreenSketch_8wekyb3d8bbwe
    Microsoft.Services.Store.Engagement, Microsoft.Services.Store.Engagement_8wekyb3d8bbwe
    Microsoft.SkypeApp, Microsoft.SkypeApp_kzf8qxf38zg5c
    Microsoft.StorePurchaseApp, Microsoft.StorePurchaseApp_8wekyb3d8bbwe
    Microsoft.SysinternalsSuite, Microsoft.SysinternalsSuite_8wekyb3d8bbwe
    Microsoft.Todos, Microsoft.Todos_8wekyb3d8bbwe
    Microsoft.VP9VideoExtensions, Microsoft.VP9VideoExtensions_8wekyb3d8bbwe
    Microsoft.WebMediaExtensions, Microsoft.WebMediaExtensions_8wekyb3d8bbwe
    Microsoft.WebpImageExtension, Microsoft.WebpImageExtension_8wekyb3d8bbwe
    Microsoft.Whiteboard, Microsoft.Whiteboard_8wekyb3d8bbwe
    Microsoft.WinDbg, Microsoft.WinDbg_8wekyb3d8bbwe
    Microsoft.WindowsAlarms, Microsoft.WindowsAlarms_8wekyb3d8bbwe
    Microsoft.WindowsCalculator, Microsoft.WindowsCalculator_8wekyb3d8bbwe
    Microsoft.WindowsCamera, Microsoft.WindowsCamera_8wekyb3d8bbwe
    MicrosoftWindows.Client.WebExperience, MicrosoftWindows.Client.WebExperience_cw5n1h2txyewy
    Microsoft.WindowsCommunicationsApps, microsoft.windowscommunicationsapps_8wekyb3d8bbwe
    Microsoft.WindowsDefenderApplicationGuard, Microsoft.WindowsDefenderApplicationGuard_8wekyb3d8bbwe
    Microsoft.WindowsFeedbackHub, Microsoft.WindowsFeedbackHub_8wekyb3d8bbwe
    Microsoft.WindowsHDRCalibration, MicrosoftCorporationII.WindowsHDRCalibration_8wekyb3d8bbwe
    Microsoft.WindowsMaps, Microsoft.WindowsMaps_8wekyb3d8bbwe
    Microsoft.WindowsNotepad, Microsoft.WindowsNotepad_8wekyb3d8bbwe
    Microsoft.Windows.Photos, Microsoft.Windows.Photos_8wekyb3d8bbwe
    Microsoft.Windows.PhotosLegacy, Microsoft.PhotosLegacy_8wekyb3d8bbwe
    Microsoft.WindowsScan, Microsoft.WindowsScan_8wekyb3d8bbwe
    Microsoft.WindowsSoundRecorder, Microsoft.WindowsSoundRecorder_8wekyb3d8bbwe
    Microsoft.WindowsStore, Microsoft.WindowsStore_8wekyb3d8bbwe
    Microsoft.WindowsSubsystemForAndroid, MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe
    Microsoft.WindowsSubsystemforLinux, MicrosoftCorporationII.WindowsSubsystemforLinux_8wekyb3d8bbwe
    Microsoft.WindowsTerminal, Microsoft.WindowsTerminal_8wekyb3d8bbwe
    Microsoft.XboxApp, Microsoft.XboxApp_8wekyb3d8bbwe
    Microsoft.XboxDevices, Microsoft.XboxDevices_8wekyb3d8bbwe
    Microsoft.XboxGameOverlay, Microsoft.XboxGameOverlay_8wekyb3d8bbwe
    Microsoft.XboxGamingOverlay, Microsoft.XboxGamingOverlay_8wekyb3d8bbwe
    Microsoft.XboxIdentityProvider, Microsoft.XboxIdentityProvider_8wekyb3d8bbwe
    Microsoft.XboxSpeechToTextOverlay, Microsoft.XboxSpeechToTextOverlay_8wekyb3d8bbwe
    Microsoft.Xbox.TCUI, Microsoft.Xbox.TCUI_8wekyb3d8bbwe
    Microsoft.YourPhone, Microsoft.YourPhone_8wekyb3d8bbwe
    Microsoft.ZuneMusic, Microsoft.ZuneMusic_8wekyb3d8bbwe
    Microsoft.ZuneVideo, Microsoft.ZuneVideo_8wekyb3d8bbwe
    Amazon.AmazonAppstore, Amazon.comServicesLLC.AmazonAppstore_bvztej1py64t8
    AMD.AMDRadeonSoftware, AdvancedMicroDevicesInc-2.AMDRadeonSoftware_0a9344xs7nr4m
    Canonical.Ubuntu, CanonicalGroupLimited.Ubuntu_79rhkp1fndgsc
    Canonical.Ubuntu18.04, CanonicalGroupLimited.Ubuntu18.04onWindows_79rhkp1fndgsc
    Canonical.Ubuntu20.04LTS, CanonicalGroupLimited.Ubuntu20.04LTS_79rhkp1fndgsc
    Canonical.Ubuntu22.04LTS, CanonicalGroupLimited.Ubuntu22.04LTS_79rhkp1fndgsc
    Debian.DebianGNULinux, TheDebianProject.DebianGNULinux_76v4gfsz19hv4
    Intel.IntelGraphicsExperience, AppUp.IntelGraphicsExperience_8j3eq9eme6ctt
    NVIDIA.NVIDIAControlPanel, NVIDIACorp.NVIDIAControlPanel_56jybvy8sckqj
'@

$DependencyNames = @(
    'Microsoft.Advertising.Xaml',
    'Microsoft.NET.Native.Framework',
    'Microsoft.NET.Native.Runtime',
    'Microsoft.Services.Store.Engagement',
    'Microsoft.UI.Xaml',
    'UWPDesktop',
    'Microsoft.VCLibs',
    'Microsoft.WinJS'
)

$RingMap = @{
    'Fast'    = 'WIF'
    'Slow'    = 'WIS'
    'Preview' = 'RP'
    'Retail'  = 'Retail'
}

############
# SETUP
############

$CurrentUser = New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())
$Elevated = $CurrentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[System.Windows.Forms.Application]::EnableVisualStyles()

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
$WebHeaders = @{
    "Referer" = "https://store.rg-adguard.net/"
    "Origin"  = "https://store.rg-adguard.net"
}

if (([System.Environment]::OSVersion.Version).Major -gt 6) { $FS = 10 } else { $FS = 8 }
$FontNormal = [System.Drawing.Font]::new('Segoe UI', $FS)
$FontBold   = [System.Drawing.Font]::new('Segoe UI', $FS, [System.Drawing.FontStyle]::Bold)
$FontSmall  = [System.Drawing.Font]::new('Segoe UI', ($FS - 1))
$FontLog    = [System.Drawing.Font]::new('Consolas', ($FS - 1))

# Script-level state
$script:AllLinks = $null
$script:FetchedApps = $null
$script:FetchedDeps = $null

############
# HELPER: Log to RichTextBox
############

function Write-Log {
    param(
        [string]$Message,
        [System.Drawing.Color]$Color = [System.Drawing.Color]::White
    )
    $LogBox.SelectionStart = $LogBox.TextLength
    $LogBox.SelectionLength = 0
    $LogBox.SelectionColor = $Color
    $LogBox.AppendText("$Message`r`n")
    $LogBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-StatusText {
    param([string]$Text)
    $StatusLabel.Text = $Text
    [System.Windows.Forms.Application]::DoEvents()
}

############
# BUILD MAIN FORM
############

$MainForm = New-Object System.Windows.Forms.Form
$MainForm.Text = 'Thekingsmaker - Store Downloader - V3.0'
$MainForm.Size = New-Object System.Drawing.Size(960, 780)
$MainForm.StartPosition = 'CenterScreen'
$MainForm.FormBorderStyle = 'FixedDialog'
$MainForm.MaximizeBox = $false
$MainForm.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$MainForm.ForeColor = [System.Drawing.Color]::White

if ($PSVersionTable.PSVersion.Major -le 5) {
    $MainForm.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($PSHOME + '\powershell.exe')
} else {
    $MainForm.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($PSHOME + '\pwsh.exe')
}

# ============================================================
# ROW 1: Package List (left) + Arch & Ring (right)
# ============================================================

# --- Package Label + ListBox ---
$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = 'Package'
$lbl.Font = $FontBold
$lbl.Location = New-Object System.Drawing.Point(15, 10)
$lbl.Size = New-Object System.Drawing.Size(400, 20)
$lbl.ForeColor = [System.Drawing.Color]::FromArgb(100, 180, 255)
$MainForm.Controls.Add($lbl)

$Package_ListBox = New-Object System.Windows.Forms.ListBox
$Package_ListBox.Location = New-Object System.Drawing.Point(15, 32)
$Package_ListBox.Size = New-Object System.Drawing.Size(420, 175)
$Package_ListBox.Font = $FontNormal
$Package_ListBox.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
$Package_ListBox.ForeColor = [System.Drawing.Color]::White
$Package_ListBox.BorderStyle = 'FixedSingle'
$Package_ListBox.add_SelectedIndexChanged({ $ProductID_TextBox.Clear() })
foreach ($item in $PackageList.Identity) { [void]$Package_ListBox.Items.Add($item) }
$MainForm.Controls.Add($Package_ListBox)

# --- Product ID ---
$lbl2 = New-Object System.Windows.Forms.Label
$lbl2.Text = 'Or enter Product ID:'
$lbl2.Font = $FontBold
$lbl2.Location = New-Object System.Drawing.Point(15, 212)
$lbl2.Size = New-Object System.Drawing.Size(160, 20)
$lbl2.ForeColor = [System.Drawing.Color]::FromArgb(100, 180, 255)
$MainForm.Controls.Add($lbl2)

$ProductID_TextBox = New-Object System.Windows.Forms.TextBox
$ProductID_TextBox.Location = New-Object System.Drawing.Point(180, 210)
$ProductID_TextBox.Size = New-Object System.Drawing.Size(255, 25)
$ProductID_TextBox.Font = $FontNormal
$ProductID_TextBox.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
$ProductID_TextBox.ForeColor = [System.Drawing.Color]::White
$ProductID_TextBox.BorderStyle = 'FixedSingle'
$ProductID_TextBox.Add_TextChanged({ $Package_ListBox.ClearSelected() })
$MainForm.Controls.Add($ProductID_TextBox)

# --- Architecture GroupBox ---
$ArchGroup = New-Object System.Windows.Forms.GroupBox
$ArchGroup.Text = 'Architecture'
$ArchGroup.Font = $FontBold
$ArchGroup.ForeColor = [System.Drawing.Color]::FromArgb(100, 180, 255)
$ArchGroup.Location = New-Object System.Drawing.Point(455, 10)
$ArchGroup.Size = New-Object System.Drawing.Size(230, 105)
$MainForm.Controls.Add($ArchGroup)

$archCheckboxes = @{}
$archNames = @('x64', 'x86', 'arm64', 'arm')
$archPositions = @(
    (New-Object System.Drawing.Point(15, 22)),
    (New-Object System.Drawing.Point(15, 47)),
    (New-Object System.Drawing.Point(110, 22)),
    (New-Object System.Drawing.Point(110, 47))
)

for ($i = 0; $i -lt $archNames.Count; $i++) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $archNames[$i]
    $cb.Font = $FontNormal
    $cb.ForeColor = [System.Drawing.Color]::White
    $cb.Location = $archPositions[$i]
    $cb.Size = New-Object System.Drawing.Size(85, 22)
    if ($archNames[$i] -eq 'x64') { $cb.Checked = $true }
    $ArchGroup.Controls.Add($cb)
    $archCheckboxes[$archNames[$i]] = $cb
}

$Arch_All = New-Object System.Windows.Forms.CheckBox
$Arch_All.Text = 'Select All'
$Arch_All.Font = $FontSmall
$Arch_All.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$Arch_All.Location = New-Object System.Drawing.Point(15, 75)
$Arch_All.Size = New-Object System.Drawing.Size(100, 22)
$Arch_All.Add_CheckedChanged({
    foreach ($k in $archCheckboxes.Keys) { $archCheckboxes[$k].Checked = $Arch_All.Checked }
})
$ArchGroup.Controls.Add($Arch_All)

# --- Ring GroupBox (checkboxes) ---
$RingGroup = New-Object System.Windows.Forms.GroupBox
$RingGroup.Text = 'Ring'
$RingGroup.Font = $FontBold
$RingGroup.ForeColor = [System.Drawing.Color]::FromArgb(100, 180, 255)
$RingGroup.Location = New-Object System.Drawing.Point(700, 10)
$RingGroup.Size = New-Object System.Drawing.Size(235, 105)
$MainForm.Controls.Add($RingGroup)

$ringCheckboxes = @{}
$ringNames = @('Retail', 'Preview', 'Slow', 'Fast')
$ringPositions = @(
    (New-Object System.Drawing.Point(15, 22)),
    (New-Object System.Drawing.Point(15, 47)),
    (New-Object System.Drawing.Point(120, 22)),
    (New-Object System.Drawing.Point(120, 47))
)

for ($i = 0; $i -lt $ringNames.Count; $i++) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $ringNames[$i]
    $cb.Font = $FontNormal
    $cb.ForeColor = [System.Drawing.Color]::White
    $cb.Location = $ringPositions[$i]
    $cb.Size = New-Object System.Drawing.Size(100, 22)
    if ($ringNames[$i] -eq 'Retail') { $cb.Checked = $true }
    $RingGroup.Controls.Add($cb)
    $ringCheckboxes[$ringNames[$i]] = $cb
}

$Ring_All = New-Object System.Windows.Forms.CheckBox
$Ring_All.Text = 'Select All'
$Ring_All.Font = $FontSmall
$Ring_All.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$Ring_All.Location = New-Object System.Drawing.Point(15, 75)
$Ring_All.Size = New-Object System.Drawing.Size(100, 22)
$Ring_All.Add_CheckedChanged({
    foreach ($k in $ringCheckboxes.Keys) { $ringCheckboxes[$k].Checked = $Ring_All.Checked }
})
$RingGroup.Controls.Add($Ring_All)

# ============================================================
# ROW 2: Download Location + Options
# ============================================================

$lbl3 = New-Object System.Windows.Forms.Label
$lbl3.Text = 'Download Location:'
$lbl3.Font = $FontBold
$lbl3.Location = New-Object System.Drawing.Point(15, 245)
$lbl3.Size = New-Object System.Drawing.Size(150, 20)
$lbl3.ForeColor = [System.Drawing.Color]::FromArgb(100, 180, 255)
$MainForm.Controls.Add($lbl3)

$defaultDir = if (-not [string]::IsNullOrEmpty($PSScriptRoot)) { $PSScriptRoot } else { $PWD.Path }

$DownloadPath_TextBox = New-Object System.Windows.Forms.TextBox
$DownloadPath_TextBox.Location = New-Object System.Drawing.Point(170, 243)
$DownloadPath_TextBox.Size = New-Object System.Drawing.Size(670, 25)
$DownloadPath_TextBox.Font = $FontNormal
$DownloadPath_TextBox.Text = $defaultDir
$DownloadPath_TextBox.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
$DownloadPath_TextBox.ForeColor = [System.Drawing.Color]::White
$DownloadPath_TextBox.BorderStyle = 'FixedSingle'
$DownloadPath_TextBox.ReadOnly = $true
$MainForm.Controls.Add($DownloadPath_TextBox)

$BrowseButton = New-Object System.Windows.Forms.Button
$BrowseButton.Text = 'Browse...'
$BrowseButton.Font = $FontNormal
$BrowseButton.Location = New-Object System.Drawing.Point(848, 241)
$BrowseButton.Size = New-Object System.Drawing.Size(85, 26)
$BrowseButton.FlatStyle = 'Flat'
$BrowseButton.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
$BrowseButton.ForeColor = [System.Drawing.Color]::White
$BrowseButton.Add_Click({
    $folderDlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDlg.Description = 'Select download folder'
    $folderDlg.SelectedPath = $DownloadPath_TextBox.Text
    if ($folderDlg.ShowDialog() -eq 'OK') {
        $DownloadPath_TextBox.Text = $folderDlg.SelectedPath
    }
})
$MainForm.Controls.Add($BrowseButton)

# --- Options row ---
$Opt_Deps = New-Object System.Windows.Forms.CheckBox
$Opt_Deps.Text = 'Include Dependencies'
$Opt_Deps.Font = $FontNormal
$Opt_Deps.ForeColor = [System.Drawing.Color]::White
$Opt_Deps.Location = New-Object System.Drawing.Point(15, 275)
$Opt_Deps.Size = New-Object System.Drawing.Size(180, 22)
$Opt_Deps.Checked = $true
$MainForm.Controls.Add($Opt_Deps)

$Opt_AllVer = New-Object System.Windows.Forms.CheckBox
$Opt_AllVer.Text = 'Show All Versions'
$Opt_AllVer.Font = $FontNormal
$Opt_AllVer.ForeColor = [System.Drawing.Color]::White
$Opt_AllVer.Location = New-Object System.Drawing.Point(210, 275)
$Opt_AllVer.Size = New-Object System.Drawing.Size(170, 22)
$Opt_AllVer.Checked = $false
$MainForm.Controls.Add($Opt_AllVer)

$Opt_Install = $null
if ($Elevated) {
    $Opt_Install = New-Object System.Windows.Forms.CheckBox
    $Opt_Install.Text = 'Install After Download'
    $Opt_Install.Font = $FontNormal
    $Opt_Install.ForeColor = [System.Drawing.Color]::FromArgb(255, 200, 80)
    $Opt_Install.Location = New-Object System.Drawing.Point(400, 275)
    $Opt_Install.Size = New-Object System.Drawing.Size(200, 22)
    $Opt_Install.Checked = $false
    $MainForm.Controls.Add($Opt_Install)
}

# ============================================================
# ROW 3: DataGridView for fetched packages
# ============================================================

$lbl4 = New-Object System.Windows.Forms.Label
$lbl4.Text = 'Fetched Packages (check rows to download):'
$lbl4.Font = $FontBold
$lbl4.Location = New-Object System.Drawing.Point(15, 305)
$lbl4.Size = New-Object System.Drawing.Size(400, 20)
$lbl4.ForeColor = [System.Drawing.Color]::FromArgb(100, 180, 255)
$MainForm.Controls.Add($lbl4)

$Grid = New-Object System.Windows.Forms.DataGridView
$Grid.Location = New-Object System.Drawing.Point(15, 328)
$Grid.Size = New-Object System.Drawing.Size(918, 200)
$Grid.AllowUserToAddRows = $false
$Grid.AllowUserToDeleteRows = $false
$Grid.AllowUserToResizeRows = $false
$Grid.ReadOnly = $false
$Grid.SelectionMode = 'FullRowSelect'
$Grid.RowHeadersVisible = $false
$Grid.AutoSizeColumnsMode = 'Fill'
$Grid.BackgroundColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
$Grid.GridColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
$Grid.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
$Grid.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
$Grid.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(60, 90, 130)
$Grid.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
$Grid.DefaultCellStyle.Font = $FontSmall
$Grid.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
$Grid.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(100, 180, 255)
$Grid.ColumnHeadersDefaultCellStyle.Font = $FontBold
$Grid.EnableHeadersVisualStyles = $false
$Grid.BorderStyle = 'FixedSingle'

# Define columns
$colCheck = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
$colCheck.Name = 'Selected'
$colCheck.HeaderText = ''
$colCheck.Width = 35
$colCheck.FillWeight = 5
$colCheck.ReadOnly = $false
[void]$Grid.Columns.Add($colCheck)

foreach ($colDef in @(
    @{Name='Family';  Header='Family';  Weight=30},
    @{Name='Version'; Header='Version'; Weight=15},
    @{Name='Arch';    Header='Arch';    Weight=8},
    @{Name='Ring';    Header='Ring';    Weight=8},
    @{Name='Date';    Header='Last Modified'; Weight=18},
    @{Name='Size';    Header='Size';    Weight=10},
    @{Name='Package'; Header='Package (filename)'; Weight=35}
)) {
    $c = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $c.Name = $colDef.Name
    $c.HeaderText = $colDef.Header
    $c.FillWeight = $colDef.Weight
    $c.ReadOnly = $true
    [void]$Grid.Columns.Add($c)
}

$MainForm.Controls.Add($Grid)

# --- Select All / None buttons for grid ---
$SelectAllBtn = New-Object System.Windows.Forms.Button
$SelectAllBtn.Text = 'Select All'
$SelectAllBtn.Font = $FontSmall
$SelectAllBtn.Location = New-Object System.Drawing.Point(700, 305)
$SelectAllBtn.Size = New-Object System.Drawing.Size(75, 20)
$SelectAllBtn.FlatStyle = 'Flat'
$SelectAllBtn.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
$SelectAllBtn.ForeColor = [System.Drawing.Color]::White
$SelectAllBtn.Add_Click({
    foreach ($row in $Grid.Rows) { $row.Cells['Selected'].Value = $true }
})
$MainForm.Controls.Add($SelectAllBtn)

$SelectNoneBtn = New-Object System.Windows.Forms.Button
$SelectNoneBtn.Text = 'Select None'
$SelectNoneBtn.Font = $FontSmall
$SelectNoneBtn.Location = New-Object System.Drawing.Point(782, 305)
$SelectNoneBtn.Size = New-Object System.Drawing.Size(80, 20)
$SelectNoneBtn.FlatStyle = 'Flat'
$SelectNoneBtn.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
$SelectNoneBtn.ForeColor = [System.Drawing.Color]::White
$SelectNoneBtn.Add_Click({
    foreach ($row in $Grid.Rows) { $row.Cells['Selected'].Value = $false }
})
$MainForm.Controls.Add($SelectNoneBtn)

$LatestOnlyBtn = New-Object System.Windows.Forms.Button
$LatestOnlyBtn.Text = 'Latest Only'
$LatestOnlyBtn.Font = $FontSmall
$LatestOnlyBtn.Location = New-Object System.Drawing.Point(870, 305)
$LatestOnlyBtn.Size = New-Object System.Drawing.Size(80, 20)
$LatestOnlyBtn.FlatStyle = 'Flat'
$LatestOnlyBtn.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
$LatestOnlyBtn.ForeColor = [System.Drawing.Color]::White
$LatestOnlyBtn.Add_Click({
    # Uncheck all first
    foreach ($row in $Grid.Rows) { $row.Cells['Selected'].Value = $false }
    # Group by Arch, pick latest version per arch
    $grouped = @{}
    foreach ($row in $Grid.Rows) {
        $arch = $row.Cells['Arch'].Value
        $ver  = [Version]$row.Cells['Version'].Value
        if (-not $grouped.ContainsKey($arch) -or $ver -gt $grouped[$arch].Version) {
            $grouped[$arch] = @{ Index = $row.Index; Version = $ver }
        }
    }
    foreach ($entry in $grouped.Values) {
        $Grid.Rows[$entry.Index].Cells['Selected'].Value = $true
    }
})
$MainForm.Controls.Add($LatestOnlyBtn)

# ============================================================
# ROW 4: Log area
# ============================================================

$lbl5 = New-Object System.Windows.Forms.Label
$lbl5.Text = 'Log:'
$lbl5.Font = $FontBold
$lbl5.Location = New-Object System.Drawing.Point(15, 535)
$lbl5.Size = New-Object System.Drawing.Size(60, 20)
$lbl5.ForeColor = [System.Drawing.Color]::FromArgb(100, 180, 255)
$MainForm.Controls.Add($lbl5)

$LogBox = New-Object System.Windows.Forms.RichTextBox
$LogBox.Location = New-Object System.Drawing.Point(15, 558)
$LogBox.Size = New-Object System.Drawing.Size(918, 120)
$LogBox.Font = $FontLog
$LogBox.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 20)
$LogBox.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
$LogBox.ReadOnly = $true
$LogBox.BorderStyle = 'FixedSingle'
$LogBox.ScrollBars = 'ForcedVertical'
$MainForm.Controls.Add($LogBox)

# --- Progress Bar ---
$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.Location = New-Object System.Drawing.Point(15, 683)
$ProgressBar.Size = New-Object System.Drawing.Size(650, 22)
$ProgressBar.Style = 'Continuous'
$ProgressBar.ForeColor = [System.Drawing.Color]::FromArgb(0, 180, 80)
$MainForm.Controls.Add($ProgressBar)

$StatusLabel = New-Object System.Windows.Forms.Label
$StatusLabel.Location = New-Object System.Drawing.Point(15, 708)
$StatusLabel.Size = New-Object System.Drawing.Size(650, 20)
$StatusLabel.Font = $FontSmall
$StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$StatusLabel.Text = 'Ready.'
$MainForm.Controls.Add($StatusLabel)

# ============================================================
# ACTION BUTTONS
# ============================================================

$FetchButton = New-Object System.Windows.Forms.Button
$FetchButton.Text = 'Fetch Packages'
$FetchButton.Font = $FontBold
$FetchButton.Location = New-Object System.Drawing.Point(680, 683)
$FetchButton.Size = New-Object System.Drawing.Size(120, 32)
$FetchButton.FlatStyle = 'Flat'
$FetchButton.BackColor = [System.Drawing.Color]::FromArgb(0, 100, 180)
$FetchButton.ForeColor = [System.Drawing.Color]::White
$MainForm.Controls.Add($FetchButton)

$DownloadButton = New-Object System.Windows.Forms.Button
$DownloadButton.Text = 'Download'
$DownloadButton.Font = $FontBold
$DownloadButton.Location = New-Object System.Drawing.Point(810, 683)
$DownloadButton.Size = New-Object System.Drawing.Size(120, 32)
$DownloadButton.FlatStyle = 'Flat'
$DownloadButton.BackColor = [System.Drawing.Color]::FromArgb(0, 140, 60)
$DownloadButton.ForeColor = [System.Drawing.Color]::White
$DownloadButton.Enabled = $false
$MainForm.Controls.Add($DownloadButton)

# ============================================================
# FETCH LOGIC
# ============================================================

$FetchButton.Add_Click({
    # Validate inputs
    $selectedArchs = @()
    foreach ($k in $archCheckboxes.Keys) {
        if ($archCheckboxes[$k].Checked) { $selectedArchs += $k }
    }
    if ($selectedArchs.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Select at least one architecture.', 'Error', 'OK', 'Error')
        return
    }

    $selectedRings = @()
    foreach ($k in $ringCheckboxes.Keys) {
        if ($ringCheckboxes[$k].Checked) { $selectedRings += $k }
    }
    if ($selectedRings.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Select at least one ring.', 'Error', 'OK', 'Error')
        return
    }

    if ($Package_ListBox.SelectedIndex -eq -1 -and [string]::IsNullOrWhiteSpace($ProductID_TextBox.Text)) {
        [System.Windows.Forms.MessageBox]::Show('Select a package or enter a Product ID.', 'Error', 'OK', 'Error')
        return
    }

    # Determine request type
    if (-not [string]::IsNullOrWhiteSpace($ProductID_TextBox.Text)) {
        $reqType = 'ProductId'
        $reqUrl  = $ProductID_TextBox.Text.Trim()
    }
    else {
        $reqType = 'PackageFamilyName'
        $reqUrl  = ($PackageList | Where-Object { $_.Identity -eq $Package_ListBox.SelectedItem }).Family
    }

    # Clear grid
    $Grid.Rows.Clear()
    $LogBox.Clear()
    $script:AllLinks = @()
    $script:FetchedDeps = New-Object System.Collections.ArrayList

    $FetchButton.Enabled = $false
    $DownloadButton.Enabled = $false

    $archPattern = ($selectedArchs | ForEach-Object { [regex]::Escape($_) }) -join '|'

    $totalApps = New-Object System.Collections.ArrayList

    foreach ($ringName in $selectedRings) {
        $ringValue = $RingMap[$ringName]
        Set-StatusText "Fetching $ringName ring..."
        Write-Log "Fetching from API: ring=$ringName ($ringValue), type=$reqType" ([System.Drawing.Color]::Cyan)

        try {
            $resp = Invoke-WebRequest -UseBasicParsing -UserAgent $UserAgent -Headers $WebHeaders `
                -ContentType "application/x-www-form-urlencoded" -Method 'POST' `
                -Uri 'https://store.rg-adguard.net/api/GetFiles' `
                -Body "type=$reqType&url=$reqUrl&ring=$ringValue&lang=en-US"
        }
        catch {
            Write-Log "ERROR fetching $ringName ring: $($_.Exception.Message)" ([System.Drawing.Color]::Red)
            continue
        }

        $links = $resp.Links.outerHTML | Where-Object {
            $_ -notmatch 'BlockMap' -and
            $_ -notmatch '\.eappx' -and
            $_ -notmatch '\.emsix' -and
            ($_ -match "($archPattern)" -or $_ -match '_neutral_')
        }

        if ($null -eq $links -or @($links).Count -eq 0) {
            Write-Log "  No packages found for $ringName." ([System.Drawing.Color]::Yellow)
            continue
        }

        $script:AllLinks += @($links)

        foreach ($link in @($links)) {
            $pkgName = $link.Split('>')[1].Split('<')[0]
            $parts = $pkgName.Split('_')
            $family = $parts[0]
            $verStr = $parts[1]
            $archField = $parts[2]

            # Check if dependency
            $isDep = $false
            foreach ($depName in $DependencyNames) {
                if ($family -match $depName) {
                    $isDep = $true
                    # Track dependency (keep latest per family+arch)
                    $existIdx = -1
                    for ($i = 0; $i -lt $script:FetchedDeps.Count; $i++) {
                        if ($script:FetchedDeps[$i].Family -eq $family -and $script:FetchedDeps[$i].Arch -eq $archField) {
                            $existIdx = $i
                            break
                        }
                    }
                    $depObj = [PSCustomObject]@{
                        Package = $pkgName; Family = $family;
                        Version = [Version]$verStr; Arch = $archField; Ring = $ringName
                    }
                    if ($existIdx -ge 0 -and [Version]$verStr -gt $script:FetchedDeps[$existIdx].Version) {
                        $script:FetchedDeps[$existIdx] = $depObj
                    }
                    elseif ($existIdx -lt 0) {
                        [void]$script:FetchedDeps.Add($depObj)
                    }
                    break
                }
            }

            if (-not $isDep) {
                [void]$totalApps.Add([PSCustomObject]@{
                    Package = $pkgName; Family = $family;
                    Version = [Version]$verStr; Arch = $archField; Ring = $ringName
                })
            }
        }

        Write-Log "  Found $(@($links).Count) files in $ringName ring." ([System.Drawing.Color]::Green)
    }

    # Deduplicate apps (same package across rings)
    $uniqueApps = $totalApps | Sort-Object -Property Package -Unique

    if ($uniqueApps.Count -eq 0) {
        Write-Log "No application packages found." ([System.Drawing.Color]::Yellow)
        $FetchButton.Enabled = $true
        Set-StatusText 'No packages found.'
        return
    }

    # Filter versions if "Show All Versions" is unchecked
    if (-not $Opt_AllVer.Checked) {
        $filtered = @()
        $groups = $uniqueApps | Group-Object -Property { "$($_.Family)_$($_.Arch)_$($_.Ring)" }
        foreach ($g in $groups) {
            $filtered += ($g.Group | Sort-Object -Property Version -Descending | Select-Object -First 1)
        }
        $uniqueApps = $filtered
    }

    Set-StatusText 'Fetching file metadata...'
    $counter = 0

    foreach ($app in ($uniqueApps | Sort-Object Arch, Family, Version)) {
        $counter++
        Set-StatusText "Metadata $counter / $($uniqueApps.Count): $($app.Family)"

        $matchedLink = @($script:AllLinks | Where-Object { $_ -match [regex]::Escape($app.Package) })
        if ($matchedLink.Count -eq 0) { continue }

        $url = $matchedLink[0].Split('"')[1]

        $lastMod = ''
        $sizeStr = ''

        try {
            $headResp = Invoke-WebRequest -UseBasicParsing -UserAgent $UserAgent -Headers $WebHeaders -Method 'HEAD' -Uri $url
            $lastMod = ([DateTime][string]$headResp.Headers['Last-Modified']).ToString('yyyy-MM-dd HH:mm')
            $len = [uint64][string]$headResp.Headers['Content-Length']
            if ($len -ge 1GB)     { $sizeStr = '{0:N2} GB' -f ($len / 1GB) }
            elseif ($len -ge 1MB) { $sizeStr = '{0:N2} MB' -f ($len / 1MB) }
            else                  { $sizeStr = '{0:N2} KB' -f ($len / 1KB) }
        }
        catch {
            $lastMod = '?'
            $sizeStr = '?'
        }

        [void]$Grid.Rows.Add($true, $app.Family, $app.Version.ToString(), $app.Arch, $app.Ring, $lastMod, $sizeStr, $app.Package)
    }

    Write-Log "Loaded $($Grid.Rows.Count) packages into grid. Dependencies tracked: $($script:FetchedDeps.Count)" ([System.Drawing.Color]::Green)
    Set-StatusText "Fetched $($Grid.Rows.Count) packages. Select rows and click Download."
    $FetchButton.Enabled = $true
    $DownloadButton.Enabled = $true
})

# ============================================================
# DOWNLOAD LOGIC
# ============================================================

$DownloadButton.Add_Click({
    $baseDir = $DownloadPath_TextBox.Text
    if (-not (Test-Path $baseDir)) {
        [System.Windows.Forms.MessageBox]::Show("Download path does not exist: $baseDir", 'Error', 'OK', 'Error')
        return
    }

    # Collect checked rows
    $selectedPackages = @()
    foreach ($row in $Grid.Rows) {
        if ($row.Cells['Selected'].Value -eq $true) {
            $selectedPackages += $row.Cells['Package'].Value
        }
    }

    if ($selectedPackages.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('No packages selected. Check the boxes in the grid.', 'Info', 'OK', 'Information')
        return
    }

    # Build full download list with dependencies
    $downloadList = [System.Collections.ArrayList]@($selectedPackages)

    if ($Opt_Deps.Checked -and $script:FetchedDeps.Count -gt 0) {
        Write-Log '' ([System.Drawing.Color]::White)
        Write-Log '--- Dependencies ---' ([System.Drawing.Color]::Cyan)

        foreach ($dep in $script:FetchedDeps) {
            if ($downloadList -notcontains $dep.Package) {
                [void]$downloadList.Add($dep.Package)
                Write-Log "  + $($dep.Package)" ([System.Drawing.Color]::DarkCyan)
            }
        }
    }

    $total = $downloadList.Count
    $ProgressBar.Minimum = 0
    $ProgressBar.Maximum = $total
    $ProgressBar.Value = 0

    $FetchButton.Enabled = $false
    $DownloadButton.Enabled = $false
    $downloaded = 0
    $skipped = 0
    $failed = 0

    Write-Log '' ([System.Drawing.Color]::White)
    Write-Log "=== Starting download of $total file(s) to: $baseDir ===" ([System.Drawing.Color]::Green)

    foreach ($filename in $downloadList) {
        $downloaded++
        $ProgressBar.Value = $downloaded
        Set-StatusText "[$downloaded / $total] $filename"

        $escapedName = [regex]::Escape($filename)
        $matchedLink = @($script:AllLinks | Where-Object { $_ -match $escapedName })

        if ($matchedLink.Count -eq 0) {
            Write-Log "  SKIP (no link): $filename" ([System.Drawing.Color]::Yellow)
            $failed++
            continue
        }

        $url = $matchedLink[0].Split('"')[1]

        # Create subfolder by identity
        $identity = $filename.Split('_')[0]
        $folderName = $identity -replace '[^\w\-\.]', '_'
        $dirPath = Join-Path -Path $baseDir -ChildPath $folderName

        try {
            if (-not (Test-Path $dirPath)) {
                New-Item -Path $dirPath -ItemType Directory -Force | Out-Null
            }
        }
        catch {
            Write-Log "  FAIL (dir): $filename - $_" ([System.Drawing.Color]::Red)
            $failed++
            continue
        }

        $filePath = Join-Path -Path $dirPath -ChildPath $filename

        if (Test-Path $filePath) {
            Write-Log "  EXISTS: $filename" ([System.Drawing.Color]::DarkGray)
            $skipped++
            continue
        }

        try {
            Write-Log "  Downloading: $filename" ([System.Drawing.Color]::White)
            Invoke-WebRequest -Uri $url -UserAgent $UserAgent -Headers $WebHeaders -OutFile $filePath -ErrorAction Stop
            Write-Log "  OK -> $folderName\" ([System.Drawing.Color]::Green)
        }
        catch {
            Write-Log "  FAIL: $filename - $($_.Exception.Message)" ([System.Drawing.Color]::Red)
            $failed++
        }
    }

    # Install if requested
    if ($Elevated -and $null -ne $Opt_Install -and $Opt_Install.Checked) {
        Write-Log '' ([System.Drawing.Color]::White)
        Write-Log '=== Installing selected packages ===' ([System.Drawing.Color]::Cyan)
        foreach ($filename in $selectedPackages) {
            $identity = $filename.Split('_')[0]
            $folderName = $identity -replace '[^\w\-\.]', '_'
            $filePath = Join-Path -Path (Join-Path -Path $baseDir -ChildPath $folderName) -ChildPath $filename

            if (Test-Path $filePath) {
                Write-Log "  Installing: $filename" ([System.Drawing.Color]::White)
                try {
                    Add-AppxPackage -Path $filePath -ErrorAction Stop
                    Write-Log "  Installed OK." ([System.Drawing.Color]::Green)
                }
                catch {
                    Write-Log "  Install FAIL: $($_.Exception.Message)" ([System.Drawing.Color]::Red)
                }
            }
        }
    }

    $summary = "Done! Downloaded: $($downloaded - $skipped - $failed) | Skipped: $skipped | Failed: $failed"
    Write-Log '' ([System.Drawing.Color]::White)
    Write-Log "=== $summary ===" ([System.Drawing.Color]::FromArgb(100, 255, 100))
    Set-StatusText $summary

    $ProgressBar.Value = $ProgressBar.Maximum
    $FetchButton.Enabled = $true
    $DownloadButton.Enabled = $true
})

# ============================================================
# SHOW FORM (stays open until user closes)
# ============================================================

$MainForm.Topmost = $false
$MainForm.Add_Shown({ $MainForm.Activate() })
[void]$MainForm.ShowDialog()
