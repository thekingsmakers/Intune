<#
PowerShell WinForms tool to validate Microsoft Intune PowerShell scripts, Proactive Remediations (PR) detection/remediation scripts, and Custom Compliance discovery scripts. It highlights common pitfalls and offers optional auto-fixes where safe.

Features
Responsive UI with DPI-safe layout (no overlapping controls)
Single-file and whole-folder validation
Live folder watcher to validate new/changed scripts
Microsoft-guided checks with actionable messages

Author: Thekingsmakers

# Using the App

Select a script or a folder containing .ps1 files.
Choose the Validation Type:
Intune PowerShell Script
PR Detection Script
PR Remediation Script
Custom Compliance Discovery
Click "Check Compliance" for a single script or "Validate" for a folder.
Review Issues/Infos in the results pane. If auto-fix was applied, a .fixed.ps1 file is written next to the original.
Optional: enable "Watch folder" to validate files created or modified in the target folder.
Notes from Microsoft Guidance (high level)
Do not require user interaction. Scripts must run unattended.
Avoid reboot/shutdown in Intune and PR contexts.
Use UTF-8 (without BOM) encoding.
Prefer TLS 1.2+ for network traffic.
Use robust error handling; consider $ErrorActionPreference = "Stop" and try/catch.
Prefer Write-Output/Write-Verbose over Write-Host for logging.
Do not change execution policy or attempt elevation inside scripts; choose the correct run context in Intune settings.
PR detection: exit 0 = compliant; non-zero = not compliant (triggers remediation).
Custom compliance discovery: output a single JSON line (ConvertTo-Json -Compress).
Auto-fix Behavior
Removes UTF-8 BOM if present.
Appends default exit 0 (commented rationale) for PR Detection scripts missing explicit exit.
Adds discovery JSON guidance as commented examples for Custom Compliance.
Troubleshooting
Controls too small/thin: This build uses Font autoscaling with layout panels. If display scaling is unusual, ensure you run on a standard Windows desktop session.
Execution policy blocks script: Run the validator from a context where execution policy permits running local scripts, or use a signed copy according to your organization policy. The validator itself flags scripts that attempt to change execution policy.
No output for large folders: Ensure you have read permissions to all files; errors per file are reported in the results pane.


#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# === Form ===
$form = New-Object System.Windows.Forms.Form
$form.Text = "Intune Script Compliance Validator"
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(1000, 650)
$form.MinimumSize = New-Object System.Drawing.Size(900, 600)
$form.BackColor = [System.Drawing.Color]::WhiteSmoke
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Regular)
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Font

# === Root Layout (Table) ===
$root = New-Object System.Windows.Forms.TableLayoutPanel
$root.Dock = 'Fill'
$root.BackColor = [System.Drawing.Color]::WhiteSmoke
$root.Padding = New-Object System.Windows.Forms.Padding(16)
$root.ColumnCount = 3
$root.RowCount = 7
$root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
$root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
$root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null # Title
$root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null # Credits/Link/Help
$root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null # File
$root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null # Type
$root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null # Folder
$root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null # Results
$root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null # Bottom
$form.Controls.Add($root)

# === Title ===
$title = New-Object System.Windows.Forms.Label
$title.Text = 'Microsoft Intune Script  Remediation Validator'
$title.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::SteelBlue
$title.AutoSize = $true
$root.SetColumnSpan($title, 3)
$root.Controls.Add($title, 0, 0)

# === Credits / Link / Help (row as FlowPanel) ===
$rowInfo = New-Object System.Windows.Forms.TableLayoutPanel
$rowInfo.ColumnCount = 3
$rowInfo.Dock = 'Fill'
$rowInfo.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
$rowInfo.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
$rowInfo.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$root.SetColumnSpan($rowInfo, 3)
$root.Controls.Add($rowInfo, 0, 1)

$lblCredits = New-Object System.Windows.Forms.Label
$lblCredits.Text = 'Created by Omar Osman Mahat - Thekingsmakers'
$lblCredits.AutoSize = $true
$rowInfo.Controls.Add($lblCredits, 0, 0)

$linkSite = New-Object System.Windows.Forms.LinkLabel
$linkSite.Text = 'thekingsmaker.org'
$linkSite.AutoSize = $true
$linkSite.Margin = New-Object System.Windows.Forms.Padding(12, 0, 0, 0)
$rowInfo.Controls.Add($linkSite, 1, 0)

$helpPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$helpPanel.Dock = 'Right'
$helpPanel.FlowDirection = 'RightToLeft'
$helpPanel.WrapContents = $false
$helpPanel.AutoSize = $true
$rowInfo.Controls.Add($helpPanel, 2, 0)

$btnHelp = New-Object System.Windows.Forms.Button
$btnHelp.Text = 'Help'
$btnHelp.AutoSize = $true
$btnHelp.BackColor = [System.Drawing.Color]::Gainsboro
$btnHelp.FlatStyle = 'Flat'
$helpPanel.Controls.Add($btnHelp)

# === File Row ===
$lblFile = New-Object System.Windows.Forms.Label
$lblFile.Text = 'Select PowerShell Script:'
$lblFile.AutoSize = $true
$root.Controls.Add($lblFile, 0, 2)

$txtFile = New-Object System.Windows.Forms.TextBox
$txtFile.Dock = 'Fill'
$root.Controls.Add($txtFile, 1, 2)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = 'Browse'
$btnBrowse.AutoSize = $true
$btnBrowse.BackColor = [System.Drawing.Color]::LightSteelBlue
$btnBrowse.FlatStyle = 'Flat'
$root.Controls.Add($btnBrowse, 2, 2)

# === Validation Type Row ===
$lblType = New-Object System.Windows.Forms.Label
$lblType.Text = 'Validation Type:'
$lblType.AutoSize = $true
$root.Controls.Add($lblType, 0, 3)

$cmbType = New-Object System.Windows.Forms.ComboBox
$cmbType.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cmbType.Items.AddRange(@(
    'Intune PowerShell Script',
    'PR Detection Script',
    'PR Remediation Script',
    'Custom Compliance Discovery'
))
$cmbType.SelectedIndex = 0
$cmbType.Dock = 'Left'
$cmbType.Width = 260
$root.Controls.Add($cmbType, 1, 3)

$padType = New-Object System.Windows.Forms.Panel
$padType.Dock = 'Fill'
$root.Controls.Add($padType, 2, 3)

# === Folder Row ===
$lblFolder = New-Object System.Windows.Forms.Label
$lblFolder.Text = 'Validate All in Folder:'
$lblFolder.AutoSize = $true
$root.Controls.Add($lblFolder, 0, 4)

$txtFolder = New-Object System.Windows.Forms.TextBox
$txtFolder.Dock = 'Fill'
$root.Controls.Add($txtFolder, 1, 4)

$folderActionPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$folderActionPanel.FlowDirection = 'LeftToRight'
$folderActionPanel.WrapContents = $false
$folderActionPanel.AutoSize = $true
$folderActionPanel.Dock = 'Right'
$root.Controls.Add($folderActionPanel, 2, 4)

$btnBrowseFolder = New-Object System.Windows.Forms.Button
$btnBrowseFolder.Text = 'Browse'
$btnBrowseFolder.AutoSize = $true
$btnBrowseFolder.BackColor = [System.Drawing.Color]::LightSteelBlue
$btnBrowseFolder.FlatStyle = 'Flat'
$folderActionPanel.Controls.Add($btnBrowseFolder)

$btnValidateAll = New-Object System.Windows.Forms.Button
$btnValidateAll.Text = 'Validate'
$btnValidateAll.AutoSize = $true
$btnValidateAll.BackColor = [System.Drawing.Color]::SlateGray
$btnValidateAll.ForeColor = [System.Drawing.Color]::White
$btnValidateAll.FlatStyle = 'Flat'
$btnValidateAll.Margin = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)
$folderActionPanel.Controls.Add($btnValidateAll)

# === Results ===
$resultsBox = New-Object System.Windows.Forms.RichTextBox
$resultsBox.Font = New-Object System.Drawing.Font('Consolas', 10)
$resultsBox.ReadOnly = $true
$resultsBox.Dock = 'Fill'
$root.SetColumnSpan($resultsBox, 3)
$root.Controls.Add($resultsBox, 0, 5)

# === Bottom Row ===
$bottomPanel = New-Object System.Windows.Forms.TableLayoutPanel
$bottomPanel.ColumnCount = 3
$bottomPanel.Dock = 'Fill'
$bottomPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
$bottomPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
$bottomPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$root.SetColumnSpan($bottomPanel, 3)
$root.Controls.Add($bottomPanel, 0, 6)

$btnCheck = New-Object System.Windows.Forms.Button
$btnCheck.Text = 'Check Compliance'
$btnCheck.AutoSize = $true
$btnCheck.BackColor = [System.Drawing.Color]::MediumSeaGreen
$btnCheck.ForeColor = [System.Drawing.Color]::White
$btnCheck.FlatStyle = 'Flat'
$bottomPanel.Controls.Add($btnCheck, 0, 0)

$chkWatch = New-Object System.Windows.Forms.CheckBox
$chkWatch.Text = 'Watch folder for new/changed scripts'
$chkWatch.AutoSize = $true
$chkWatch.Margin = New-Object System.Windows.Forms.Padding(12, 6, 0, 6)
$bottomPanel.Controls.Add($chkWatch, 1, 0)

# === Actions ===
$btnHelp.Add_Click({
    $help = @(
        'How to use:',
        '',
        '1) Select a script or a folder.',
        '   - Choose Validation Type: Intune Script, PR Detection, PR Remediation, or Custom Compliance.',
        '2) Click Check Compliance (single file) or Validate (folder).',
        '3) Review issues and info in the results area.',
        '4) If fixes are prepared, a *.fixed.ps1 file is written next to the original.',
        '5) Optional: Enable "Watch folder" to validate new/changed scripts automatically.',
        '',
        'Notes:',
        '- Avoid reboot and interactive prompts.',
        '- Detection (PR) must exit 0 or 1.',
        '- Discovery should output single-line JSON via ConvertTo-Json -Compress.',
        '- Prefer UTF-8 without BOM (esp. with signature checks).'
    ) -join "`n"
    [System.Windows.Forms.MessageBox]::Show($help, 'Usage', 'OK', 'Information') | Out-Null
})

$linkSite.add_LinkClicked({ Start-Process 'https://thekingsmaker.org' })

$btnBrowse.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = 'PowerShell Scripts (*.ps1)|*.ps1'
    if ($dialog.ShowDialog() -eq 'OK') { $txtFile.Text = $dialog.FileName }
})

$btnBrowseFolder.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dialog.ShowDialog() -eq 'OK') { $txtFolder.Text = $dialog.SelectedPath }
})

# === Helpers ===
function Get-FileHasUtf8Bom {
    param([string]$Path)
    try {
        $bytes = Get-Content -Path $Path -Encoding Byte -TotalCount 3 -ErrorAction Stop
        return ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    } catch { return $false }
}

function Remove-Utf8BomFromString {
    param([string]$Content)
    if ($Content.Length -gt 0 -and [int]$Content[0] -eq 65279) { return $Content.Substring(1) }
    return $Content
}

function Save-FixedScript {
    param([string]$OriginalPath,[string]$FixedContent)
    $dir = Split-Path -Parent $OriginalPath
    $name = Split-Path -LeafBase $OriginalPath
    $fixedPath = Join-Path $dir ("$name.fixed.ps1")
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($fixedPath, $FixedContent, $utf8NoBom)
    return $fixedPath
}

function Test-IntuneScript {
    param(
        [string]$Path,
        [string]$Content,
        [string]$ValidationType
    )
    function Add-Unique([System.Collections.Generic.List[string]]$list,[string]$text){ if (-not $list.Contains($text)) { $null = $list.Add($text) } }
    $issues = New-Object System.Collections.Generic.List[string]
    $infos = New-Object System.Collections.Generic.List[string]
    $fixNotes = New-Object System.Collections.Generic.List[string]
    $fixed = $Content
    $fixedChanged = $false

    if ($Content -match '(?im)\b(Restart-Computer|Stop-Computer|shutdown.exe)\b') {
        Add-Unique $issues '❌ Contains reboot/shutdown commands – not allowed in Intune/PR scripts'
    } else { Add-Unique $infos '✅ No reboot/shutdown commands found' }

    if ($Content -match '(?im)\b(Read-Host|Out-GridView|Pause|\$host\.UI\.PromptFor)\b') {
        Add-Unique $issues '❌ Interactive prompts detected – not supported in Intune context'
    } else { Add-Unique $infos '✅ No interactive prompts detected' }

    if (Get-FileHasUtf8Bom -Path $Path) {
        Add-Unique $issues '❌ UTF-8 BOM detected – use UTF-8 without BOM'
        $fixed = Remove-Utf8BomFromString -Content $fixed
        $fixedChanged = $true
        Add-Unique $fixNotes 'Removed UTF-8 BOM'
    } else { Add-Unique $infos '✅ UTF-8 without BOM' }

    if ($ValidationType -eq 'PR Detection Script') {
        if ($Content -notmatch '(?im)^\s*exit\s+0\b' -and $Content -notmatch '(?im)^\s*exit\s+1\b') {
            Add-Unique $issues '❌ Detection script must exit 0 (compliant) or 1 (issue)'
            if ($fixed -notmatch '(?im)^\s*exit\s+[01]\b' -and $fixed -notmatch '(?im)# Added by validator: default compliant exit; replace with detection logic') {
                $fixed = $fixed.TrimEnd() + "`r`n`r`n# Added by validator: default compliant exit; replace with detection logic`r`nexit 0`r`n"
                $fixedChanged = $true
                Add-Unique $fixNotes 'Appended default exit 0'
            }
        } else { Add-Unique $infos '✅ Detection exit code found' }
    }

    if ($ValidationType -eq 'PR Remediation Script') { Add-Unique $infos 'ℹ️ Remediation runs only when detection exits 1' }

    if ($ValidationType -eq 'Custom Compliance Discovery') {
        if ($Content -notmatch '(?im)ConvertTo-Json\s*-Compress') {
            Add-Unique $issues '⚠️ Discovery should output single-line JSON via ConvertTo-Json -Compress'
            if ($fixed -notmatch '(?im)# Added by validator: ensure single-line JSON output for discovery') {
                $fixed = $fixed.TrimEnd() + "`r`n`r`n# Added by validator: ensure single-line JSON output for discovery`r`n# $result = @{ Example = 'value' }`r`n# return $result | ConvertTo-Json -Compress`r`n"
                $fixedChanged = $true
                Add-Unique $fixNotes 'Appended guidance for ConvertTo-Json -Compress'
            }
        } else { Add-Unique $infos '✅ Contains ConvertTo-Json -Compress' }
    }

    if ($ValidationType -like 'PR*') { Add-Unique $infos 'ℹ️ Keep PR script output <= 2048 characters' }

    $summarySet = New-Object System.Collections.Generic.HashSet[string]
    foreach ($i in $issues) { $summarySet.Add($i) | Out-Null }
    foreach ($i in $infos) { $summarySet.Add($i) | Out-Null }
    if ($fixNotes.Count -gt 0) { $summarySet.Add("Fixes prepared: " + ($fixNotes -join '; ')) | Out-Null }
    [PSCustomObject]@{ Issues=$issues; Infos=$infos; FixedContent=($(if($fixedChanged){$fixed}else{$null})); Summary=([string]::Join("`n", $summarySet)) }
}

# === Validate All in Folder ===
$btnValidateAll.Add_Click({
    $resultsBox.Clear()
    if (-not (Test-Path $txtFolder.Text)) { $resultsBox.AppendText("⚠️ Please select a valid folder.`n"); return }
    $type = $cmbType.SelectedItem.ToString()
    $files = Get-ChildItem -Path $txtFolder.Text -Filter *.ps1 -Recurse -File -ErrorAction SilentlyContinue
    if (-not $files) { $resultsBox.AppendText("No .ps1 files found.`n"); return }
    foreach ($f in $files) {
        try {
            $content = Get-Content -Path $f.FullName -Raw -ErrorAction Stop
            $res = Test-IntuneScript -Path $f.FullName -Content $content -ValidationType $type
            $resultsBox.AppendText("=== " + $f.FullName + " ===`n")
            $resultsBox.AppendText($res.Summary + "`n")
            if ($res.FixedContent) {
                $fixedPath = Save-FixedScript -OriginalPath $f.FullName -FixedContent $res.FixedContent
                $resultsBox.AppendText("💡 Wrote auto-fixed script: " + $fixedPath + "`n")
            }
            $resultsBox.AppendText("`n")
        } catch {
            $resultsBox.AppendText("❌ Failed to validate " + $f.FullName + ": " + $_.Exception.Message + "`n")
        }
    }
})

# === Single File Check ===
$btnCheck.Add_Click({
    $resultsBox.Clear()
    if (-not (Test-Path $txtFile.Text)) { $resultsBox.AppendText("⚠️ Please select a valid script file.`n"); return }
    $scriptContent = Get-Content -Path $txtFile.Text -Raw
    $type = $cmbType.SelectedItem.ToString()
    $res = Test-IntuneScript -Path $txtFile.Text -Content $scriptContent -ValidationType $type
    $resultsBox.AppendText($res.Summary + "`n")
    if ($res.FixedContent) {
        $fixedPath = Save-FixedScript -OriginalPath $txtFile.Text -FixedContent $res.FixedContent
        $resultsBox.AppendText("💡 Wrote auto-fixed script: " + $fixedPath + "`n")
    }
})

# === Folder Watcher ===
$global:fsw = $null
$chkWatch.Add_CheckedChanged({
    if ($chkWatch.Checked) {
        if (-not (Test-Path $txtFolder.Text)) { $resultsBox.AppendText("⚠️ Select a valid folder to watch.`n"); $chkWatch.Checked = $false; return }
        if ($global:fsw) { try { $global:fsw.EnableRaisingEvents = $false; $global:fsw.Dispose() } catch {} }
        $global:fsw = New-Object System.IO.FileSystemWatcher
        $global:fsw.Path = $txtFolder.Text
        $global:fsw.Filter = '*.ps1'
        $global:fsw.IncludeSubdirectories = $true
        $global:fsw.EnableRaisingEvents = $true
        Register-ObjectEvent -InputObject $global:fsw -EventName Created -Action {
            try {
                Start-Sleep -Milliseconds 350
                $path = $Event.SourceEventArgs.FullPath
                if (-not (Test-Path $path)) { return }
                $typeLocal = $cmbType.SelectedItem.ToString()
                $content = Get-Content -Path $path -Raw -ErrorAction Stop
                $res = Test-IntuneScript -Path $path -Content $content -ValidationType $typeLocal
                $form.Invoke([Action]{
                    $resultsBox.AppendText("[WATCH] " + $path + "`n")
                    $resultsBox.AppendText($res.Summary + "`n")
                    if ($res.FixedContent) {
                        $fixedPath = Save-FixedScript -OriginalPath $path -FixedContent $res.FixedContent
                        $resultsBox.AppendText("💡 Wrote auto-fixed script: " + $fixedPath + "`n")
                    }
                    $resultsBox.AppendText("`n")
                }) | Out-Null
            } catch {}
        } | Out-Null
        Register-ObjectEvent -InputObject $global:fsw -EventName Changed -Action {
            try {
                Start-Sleep -Milliseconds 350
                $path = $Event.SourceEventArgs.FullPath
                if (-not (Test-Path $path)) { return }
                $typeLocal = $cmbType.SelectedItem.ToString()
                $content = Get-Content -Path $path -Raw -ErrorAction Stop
                $res = Test-IntuneScript -Path $path -Content $content -ValidationType $typeLocal
                $form.Invoke([Action]{
                    $resultsBox.AppendText("[WATCH] " + $path + "`n")
                    $resultsBox.AppendText($res.Summary + "`n")
                    if ($res.FixedContent) {
                        $fixedPath = Save-FixedScript -OriginalPath $path -FixedContent $res.FixedContent
                        $resultsBox.AppendText("💡 Wrote auto-fixed script: " + $fixedPath + "`n")
                    }
                    $resultsBox.AppendText("`n")
                }) | Out-Null
            } catch {}
        } | Out-Null
        $resultsBox.AppendText("👀 Watching folder: $($txtFolder.Text)`n")
    } else {
        if ($global:fsw) { try { $global:fsw.EnableRaisingEvents = $false; $global:fsw.Dispose(); $global:fsw = $null } catch {} }
        Get-EventSubscriber | Where-Object { $_.SourceObject -is [System.IO.FileSystemWatcher] } | Unregister-Event -ErrorAction SilentlyContinue
        $resultsBox.AppendText("🛑 Stopped watching.`n")
    }
})

[void]$form.ShowDialog()
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# === GUI Setup ===
$form = New-Object System.Windows.Forms.Form
$form.Text = "Intune Script Compliance Validator"
$form.Size = New-Object System.Drawing.Size(900,600)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::WhiteSmoke
$form.MinimumSize = New-Object System.Drawing.Size(900,600)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Font

# Title
$title = New-Object System.Windows.Forms.Label
$title.Text = "Microsoft Intune Script & Remediation Validator"
$title.Font = New-Object System.Drawing.Font("Segoe UI",18,[System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::SteelBlue
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(20,20)
$title.MaximumSize = New-Object System.Drawing.Size(760,0)
$form.Controls.Add($title)

# Credits and website
$lblCredits = New-Object System.Windows.Forms.Label
$lblCredits.Text = "Created by Omar Osman Mahat - Thekingsmakers"
$lblCredits.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Regular)
$lblCredits.AutoSize = $true
$lblCredits.Location = New-Object System.Drawing.Point(20,55)
$form.Controls.Add($lblCredits)

$linkSite = New-Object System.Windows.Forms.LinkLabel
$linkSite.Text = "thekingsmaker.org"
$linkSite.Location = New-Object System.Drawing.Point(320,55)
$linkSite.AutoSize = $true
$form.Controls.Add($linkSite)

# File path box
$lblFile = New-Object System.Windows.Forms.Label
$lblFile.Text = "Select PowerShell Script:"
$lblFile.Font = New-Object System.Drawing.Font("Segoe UI",10)
$lblFile.Location = New-Object System.Drawing.Point(20,70)
$lblFile.AutoSize = $true
$form.Controls.Add($lblFile)

# Validation type selector
$lblType = New-Object System.Windows.Forms.Label
$lblType.Text = "Validation Type:"
$lblType.Font = New-Object System.Drawing.Font("Segoe UI",10)
$lblType.Location = New-Object System.Drawing.Point(400,70)
$lblType.AutoSize = $true
$form.Controls.Add($lblType)

$cmbType = New-Object System.Windows.Forms.ComboBox
$cmbType.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cmbType.Items.AddRange(@(
    'Intune PowerShell Script',
    'PR Detection Script',
    'PR Remediation Script',
    'Custom Compliance Discovery'
))
$cmbType.SelectedIndex = 0
$cmbType.Location = New-Object System.Drawing.Point(400,95)
$cmbType.Size = New-Object System.Drawing.Size(220,25)
$form.Controls.Add($cmbType)

$txtFile = New-Object System.Windows.Forms.TextBox
$txtFile.Size = New-Object System.Drawing.Size(360,25)
$txtFile.Location = New-Object System.Drawing.Point(20,95)
$txtFile.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($txtFile)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse"
$btnBrowse.Location = New-Object System.Drawing.Point(590,92)
$btnBrowse.BackColor = [System.Drawing.Color]::LightSteelBlue
$btnBrowse.FlatStyle = "Flat"
$form.Controls.Add($btnBrowse)

# Help button
$btnHelp = New-Object System.Windows.Forms.Button
$btnHelp.Text = "Help"
$btnHelp.Location = New-Object System.Drawing.Point(690,20)
$btnHelp.Size = New-Object System.Drawing.Size(70,25)
$btnHelp.BackColor = [System.Drawing.Color]::Gainsboro
$btnHelp.FlatStyle = "Flat"
$form.Controls.Add($btnHelp)

# Folder path controls
$lblFolder = New-Object System.Windows.Forms.Label
$lblFolder.Text = "Validate All in Folder:"
$lblFolder.Font = New-Object System.Drawing.Font("Segoe UI",10)
$lblFolder.Location = New-Object System.Drawing.Point(20,125)
$lblFolder.AutoSize = $true
$form.Controls.Add($lblFolder)

$txtFolder = New-Object System.Windows.Forms.TextBox
$txtFolder.Size = New-Object System.Drawing.Size(550,25)
$txtFolder.Location = New-Object System.Drawing.Point(20,150)
$txtFolder.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($txtFolder)

$btnBrowseFolder = New-Object System.Windows.Forms.Button
$btnBrowseFolder.Text = "Browse"
$btnBrowseFolder.Location = New-Object System.Drawing.Point(590,148)
$btnBrowseFolder.BackColor = [System.Drawing.Color]::LightSteelBlue
$btnBrowseFolder.FlatStyle = "Flat"
$form.Controls.Add($btnBrowseFolder)

$btnValidateAll = New-Object System.Windows.Forms.Button
$btnValidateAll.Text = "Validate"
$btnValidateAll.Location = New-Object System.Drawing.Point(670,148)
$btnValidateAll.Size = New-Object System.Drawing.Size(90,25)
$btnValidateAll.BackColor = [System.Drawing.Color]::SlateGray
$btnValidateAll.ForeColor = [System.Drawing.Color]::White
$btnValidateAll.FlatStyle = "Flat"
$form.Controls.Add($btnValidateAll)

# Results box
$resultsBox = New-Object System.Windows.Forms.RichTextBox
$resultsBox.Size = New-Object System.Drawing.Size(740,290)
$resultsBox.Location = New-Object System.Drawing.Point(20,190)
$resultsBox.Font = New-Object System.Drawing.Font("Consolas",10)
$resultsBox.ReadOnly = $true
$resultsBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$form.Controls.Add($resultsBox)

# Validate button
$btnCheck = New-Object System.Windows.Forms.Button
$btnCheck.Text = "Check Compliance"
$btnCheck.Location = New-Object System.Drawing.Point(20,500)
$btnCheck.Size = New-Object System.Drawing.Size(150,25)
$btnCheck.BackColor = [System.Drawing.Color]::MediumSeaGreen
$btnCheck.ForeColor = [System.Drawing.Color]::White
$btnCheck.FlatStyle = "Flat"
$btnCheck.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($btnCheck)

# Watcher toggle
$chkWatch = New-Object System.Windows.Forms.CheckBox
$chkWatch.Text = "Watch folder for new/changed scripts"
$chkWatch.Location = New-Object System.Drawing.Point(200,500)
$chkWatch.AutoSize = $true
$chkWatch.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($chkWatch)

# === Layout function to prevent overlap and handle resize ===
function Arrange-Layout {
    try {
        $margin = 20
        $gap = 10
        $clientW = $form.ClientSize.Width
        $clientH = $form.ClientSize.Height

        # Title
        $title.MaximumSize = New-Object System.Drawing.Size($clientW - 2*$margin, 0)
        $title.Location = New-Object System.Drawing.Point($margin, 20)

        # Credits and link
        $lblCredits.Location = New-Object System.Drawing.Point($margin, $title.Bottom + 5)
        $linkSite.Location = New-Object System.Drawing.Point([Math]::Min($lblCredits.Right + 10, $clientW - $margin - $linkSite.Width), $lblCredits.Top)

        # Row 1 fixed layout (with wrap if needed)
        $row1Y = $lblCredits.Bottom + 15
        $labelW = 170
        $lblFile.Location = New-Object System.Drawing.Point($margin, $row1Y)
        $lblFile.Size = New-Object System.Drawing.Size($labelW,20)

        $browseW = 80
        $btnBrowse.Size = New-Object System.Drawing.Size($browseW,25)
        $btnBrowse.Location = New-Object System.Drawing.Point($clientW - $margin - $btnBrowse.Width, $row1Y - 3)

        $typeRight = $btnBrowse.Left - $gap
        $lblTypeMin = 120
        $cmbMin = 180
        $txtMin = 180
        $txtFileX = $lblFile.Left + $labelW + 5
        $available = $typeRight - $txtFileX
        $typeNeeded = $lblTypeMin + 5 + $cmbMin
        $wrapTypeBelow = $false
        if ($available - $typeNeeded - $gap - $txtMin -lt 0) { $wrapTypeBelow = $true }

        if (-not $wrapTypeBelow) {
            $txtFileW = $available - $typeNeeded - $gap
            if ($txtFileW -lt $txtMin) { $txtFileW = $txtMin }
            $txtFile.Location = New-Object System.Drawing.Point($txtFileX, $row1Y)
            $txtFile.Size = New-Object System.Drawing.Size($txtFileW,25)

            $cmbW = [Math]::Max($cmbMin, $typeRight - ($txtFile.Right + $gap + $lblTypeMin + 5))
            if ($cmbW -lt $cmbMin) { $cmbW = $cmbMin }
            $cmbType.Size = New-Object System.Drawing.Size($cmbW,25)
            $lblType.Size = New-Object System.Drawing.Size($lblTypeMin,20)
            $lblType.Location = New-Object System.Drawing.Point($txtFile.Right + $gap, $row1Y)
            $cmbType.Location = New-Object System.Drawing.Point($lblType.Right + 5, $row1Y - 2)
            $row2Y = $row1Y + 35
        } else {
            # Put Validation Type on its own row below
            $txtFileW = [Math]::Max($txtMin, $available)
            $txtFile.Location = New-Object System.Drawing.Point($txtFileX, $row1Y)
            $txtFile.Size = New-Object System.Drawing.Size($txtFileW,25)

            $row1bY = $row1Y + 28
            $lblType.Size = New-Object System.Drawing.Size($lblTypeMin,20)
            $lblType.Location = New-Object System.Drawing.Point($txtFileX, $row1bY)
            $cmbType.Size = New-Object System.Drawing.Size([Math]::Max($cmbMin, $typeRight - ($lblType.Right + 5)),25)
            $cmbType.Location = New-Object System.Drawing.Point($lblType.Right + 5, $row1bY - 2)
            $row2Y = $row1bY + 30
        }

        # Row 2: folder
        $lblFolder.Location = New-Object System.Drawing.Point($margin, $row2Y)
        $lblFolder.Size = New-Object System.Drawing.Size($labelW,20)
        $btnValidateAll.Size = New-Object System.Drawing.Size(100,25)
        $btnValidateAll.Location = New-Object System.Drawing.Point($clientW - $margin - $btnValidateAll.Width, $row2Y - 2)
        $btnBrowseFolder.Size = New-Object System.Drawing.Size($browseW,25)
        $btnBrowseFolder.Location = New-Object System.Drawing.Point($btnValidateAll.Left - $gap - $btnBrowseFolder.Width, $row2Y - 2)
        $txtFolderX = $lblFolder.Left + $labelW + 5
        $txtFolderW = $btnBrowseFolder.Left - $gap - $txtFolderX
        if ($txtFolderW -lt 220) { $txtFolderW = 220 }
        $txtFolder.Location = New-Object System.Drawing.Point($txtFolderX, $row2Y)
        $txtFolder.Size = New-Object System.Drawing.Size($txtFolderW,25)

        # Results area
        $resultsTop = $row2Y + 35
        $bottomControlsH = 40
        $resultsHeight = $clientH - $resultsTop - $bottomControlsH
        if ($resultsHeight -lt 120) { $resultsHeight = 120 }
        $resultsBox.Location = New-Object System.Drawing.Point($margin, $resultsTop)
        $resultsBox.Size = New-Object System.Drawing.Size($clientW - 2*$margin, $resultsHeight)

        # Bottom row
        $btnCheck.Location = New-Object System.Drawing.Point($margin, $resultsBox.Bottom + 10)
        $chkWatch.Location = New-Object System.Drawing.Point($btnCheck.Right + 20, $btnCheck.Top + 4)
        $btnHelp.Location = New-Object System.Drawing.Point($clientW - $margin - $btnHelp.Width, $title.Top)
    } catch {
        # If anything fails, avoid crashing the form
    }
}

$form.Add_Load({ Arrange-Layout })
$form.Add_Shown({ Arrange-Layout })
$form.Add_SizeChanged({ Arrange-Layout })

# === Browse Button Action ===
$btnBrowse.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "PowerShell Scripts (*.ps1)|*.ps1"
    if ($dialog.ShowDialog() -eq "OK") {
        $txtFile.Text = $dialog.FileName
    }
})

# Help button action and link
$btnHelp.Add_Click({
    $help = @(
        'How to use:',
        '',
        '1) Select a script or a folder.',
        '   - Choose Validation Type: Intune Script, PR Detection, PR Remediation, or Custom Compliance.',
        '2) Click Check Compliance (single file) or Validate (folder).',
        '3) Review issues and info in the results area.',
        '4) If fixes are prepared, a *.fixed.ps1 file is written next to the original.',
        '5) Optional: Enable "Watch folder" to validate new/changed scripts automatically.',
        '',
        'Notes:',
        '- Avoid reboot and interactive prompts.',
        '- Detection (PR) must exit 0 or 1.',
        '- Discovery should output single-line JSON via ConvertTo-Json -Compress.',
        '- Prefer UTF-8 without BOM (esp. with signature checks).'
    ) -join "`n"
    [System.Windows.Forms.MessageBox]::Show($help, 'Usage', 'OK', 'Information') | Out-Null
})

$linkSite.add_LinkClicked({
    Start-Process 'https://thekingsmaker.org'
})

# === Browse Folder Action ===
$btnBrowseFolder.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dialog.ShowDialog() -eq "OK") {
        $txtFolder.Text = $dialog.SelectedPath
    }
})

# === Helpers ===
function Get-FileHasUtf8Bom {
    param([string]$Path)
    try {
        $bytes = Get-Content -Path $Path -Encoding Byte -TotalCount 3 -ErrorAction Stop
        return ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    } catch { return $false }
}

function Remove-Utf8BomFromString {
    param([string]$Content)
    if ($Content.Length -gt 0 -and [int]$Content[0] -eq 65279) { return $Content.Substring(1) }
    return $Content
}

function Save-FixedScript {
    param([string]$OriginalPath,[string]$FixedContent)
    $dir = Split-Path -Parent $OriginalPath
    $name = Split-Path -LeafBase $OriginalPath
    $fixedPath = Join-Path $dir ("$name.fixed.ps1")
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($fixedPath, $FixedContent, $utf8NoBom)
    return $fixedPath
}

function Test-IntuneScript {
    param(
        [string]$Path,
        [string]$Content,
        [string]$ValidationType
    )
    function Add-Unique([System.Collections.Generic.List[string]]$list,[string]$text){ if (-not $list.Contains($text)) { $null = $list.Add($text) } }
    $issues = New-Object System.Collections.Generic.List[string]
    $infos = New-Object System.Collections.Generic.List[string]
    $fixNotes = New-Object System.Collections.Generic.List[string]
    $fixed = $Content
    $fixedChanged = $false

    if ($Content -match '(?im)\b(Restart-Computer|Stop-Computer|shutdown.exe)\b') {
        Add-Unique $issues '❌ Contains reboot/shutdown commands – not allowed in Intune/PR scripts'
    } else { Add-Unique $infos '✅ No reboot/shutdown commands found' }

    if ($Content -match '(?im)\b(Read-Host|Out-GridView|Pause|\$host\.UI\.PromptFor)\b') {
        Add-Unique $issues '❌ Interactive prompts detected – not supported in Intune context'
    } else { Add-Unique $infos '✅ No interactive prompts detected' }

    if (Get-FileHasUtf8Bom -Path $Path) {
        Add-Unique $issues '❌ UTF-8 BOM detected – use UTF-8 without BOM'
        $fixed = Remove-Utf8BomFromString -Content $fixed
        $fixedChanged = $true
        Add-Unique $fixNotes 'Removed UTF-8 BOM'
    } else { Add-Unique $infos '✅ UTF-8 without BOM' }

    if ($ValidationType -eq 'PR Detection Script') {
        if ($Content -notmatch '(?im)^\s*exit\s+0\b' -and $Content -notmatch '(?im)^\s*exit\s+1\b') {
            Add-Unique $issues '❌ Detection script must exit 0 (compliant) or 1 (issue)'
            if ($fixed -notmatch '(?im)^\s*exit\s+[01]\b' -and $fixed -notmatch '(?im)# Added by validator: default compliant exit; replace with detection logic') {
                $fixed = $fixed.TrimEnd() + "`r`n`r`n# Added by validator: default compliant exit; replace with detection logic`r`nexit 0`r`n"
                $fixedChanged = $true
                Add-Unique $fixNotes 'Appended default exit 0'
            }
        } else { Add-Unique $infos '✅ Detection exit code found' }
    }

    if ($ValidationType -eq 'PR Remediation Script') { Add-Unique $infos 'ℹ️ Remediation runs only when detection exits 1' }

    if ($ValidationType -eq 'Custom Compliance Discovery') {
        if ($Content -notmatch '(?im)ConvertTo-Json\s*-Compress') {
            Add-Unique $issues '⚠️ Discovery should output single-line JSON via ConvertTo-Json -Compress'
            if ($fixed -notmatch '(?im)# Added by validator: ensure single-line JSON output for discovery') {
                $fixed = $fixed.TrimEnd() + "`r`n`r`n# Added by validator: ensure single-line JSON output for discovery`r`n# $result = @{ Example = 'value' }`r`n# return $result | ConvertTo-Json -Compress`r`n"
                $fixedChanged = $true
                Add-Unique $fixNotes 'Appended guidance for ConvertTo-Json -Compress'
            }
        } else { Add-Unique $infos '✅ Contains ConvertTo-Json -Compress' }
    }

    if ($ValidationType -like 'PR*') { Add-Unique $infos 'ℹ️ Keep PR script output <= 2048 characters' }

    $summarySet = New-Object System.Collections.Generic.HashSet[string]
    foreach ($i in $issues) { $summarySet.Add($i) | Out-Null }
    foreach ($i in $infos) { $summarySet.Add($i) | Out-Null }
    if ($fixNotes.Count -gt 0) { $summarySet.Add("Fixes prepared: " + ($fixNotes -join '; ')) | Out-Null }
    [PSCustomObject]@{ Issues=$issues; Infos=$infos; FixedContent=($(if($fixedChanged){$fixed}else{$null})); Summary=([string]::Join("`n", $summarySet)) }
}

# === Validate All in Folder ===
$btnValidateAll.Add_Click({
    $resultsBox.Clear()
    if (-not (Test-Path $txtFolder.Text)) { $resultsBox.AppendText("⚠️ Please select a valid folder.`n"); return }
    $type = $cmbType.SelectedItem.ToString()
    $files = Get-ChildItem -Path $txtFolder.Text -Filter *.ps1 -Recurse -File -ErrorAction SilentlyContinue
    if (-not $files) { $resultsBox.AppendText("No .ps1 files found.`n"); return }
    foreach ($f in $files) {
        try {
            $content = Get-Content -Path $f.FullName -Raw -ErrorAction Stop
            $res = Test-IntuneScript -Path $f.FullName -Content $content -ValidationType $type
            $resultsBox.AppendText("=== " + $f.FullName + " ===`n")
            $resultsBox.AppendText($res.Summary + "`n")
            if ($res.FixedContent) {
                $fixedPath = Save-FixedScript -OriginalPath $f.FullName -FixedContent $res.FixedContent
                $resultsBox.AppendText("💡 Wrote auto-fixed script: " + $fixedPath + "`n")
            }
            $resultsBox.AppendText("`n")
        } catch {
            $resultsBox.AppendText("❌ Failed to validate " + $f.FullName + ": " + $_.Exception.Message + "`n")
        }
    }
})

# === Check Compliance Action ===
$btnCheck.Add_Click({
    $resultsBox.Clear()
    if (-not (Test-Path $txtFile.Text)) {
        $resultsBox.AppendText("⚠️ Please select a valid script file.`n")
        return
    }

    $scriptContent = Get-Content -Path $txtFile.Text -Raw
    $type = $cmbType.SelectedItem.ToString()
    $res = Test-IntuneScript -Path $txtFile.Text -Content $scriptContent -ValidationType $type
    $resultsBox.AppendText($res.Summary + "`n")
    if ($res.FixedContent) {
        $fixedPath = Save-FixedScript -OriginalPath $txtFile.Text -FixedContent $res.FixedContent
        $resultsBox.AppendText("💡 Wrote auto-fixed script: " + $fixedPath + "`n")
    }
})

# === Folder Watcher ===
$global:fsw = $null
$chkWatch.Add_CheckedChanged({
    if ($chkWatch.Checked) {
        if (-not (Test-Path $txtFolder.Text)) { $resultsBox.AppendText("⚠️ Select a valid folder to watch.`n"); $chkWatch.Checked = $false; return }
        if ($global:fsw) { try { $global:fsw.EnableRaisingEvents = $false; $global:fsw.Dispose() } catch {} }
        $global:fsw = New-Object System.IO.FileSystemWatcher
        $global:fsw.Path = $txtFolder.Text
        $global:fsw.Filter = '*.ps1'
        $global:fsw.IncludeSubdirectories = $true
        $global:fsw.EnableRaisingEvents = $true
        Register-ObjectEvent -InputObject $global:fsw -EventName Created -Action {
            try {
                Start-Sleep -Milliseconds 350
                $path = $Event.SourceEventArgs.FullPath
                if (-not (Test-Path $path)) { return }
                $typeLocal = $cmbType.SelectedItem.ToString()
                $content = Get-Content -Path $path -Raw -ErrorAction Stop
                $res = Test-IntuneScript -Path $path -Content $content -ValidationType $typeLocal
                $form.Invoke([Action]{
                    $resultsBox.AppendText("[WATCH] " + $path + "`n")
                    $resultsBox.AppendText($res.Summary + "`n")
                    if ($res.FixedContent) {
                        $fixedPath = Save-FixedScript -OriginalPath $path -FixedContent $res.FixedContent
                        $resultsBox.AppendText("💡 Wrote auto-fixed script: " + $fixedPath + "`n")
                    }
                    $resultsBox.AppendText("`n")
                }) | Out-Null
            } catch {}
        } | Out-Null
        Register-ObjectEvent -InputObject $global:fsw -EventName Changed -Action {
            try {
                Start-Sleep -Milliseconds 350
                $path = $Event.SourceEventArgs.FullPath
                if (-not (Test-Path $path)) { return }
                $typeLocal = $cmbType.SelectedItem.ToString()
                $content = Get-Content -Path $path -Raw -ErrorAction Stop
                $res = Test-IntuneScript -Path $path -Content $content -ValidationType $typeLocal
                $form.Invoke([Action]{
                    $resultsBox.AppendText("[WATCH] " + $path + "`n")
                    $resultsBox.AppendText($res.Summary + "`n")
                    if ($res.FixedContent) {
                        $fixedPath = Save-FixedScript -OriginalPath $path -FixedContent $res.FixedContent
                        $resultsBox.AppendText("💡 Wrote auto-fixed script: " + $fixedPath + "`n")
                    }
                    $resultsBox.AppendText("`n")
                }) | Out-Null
            } catch {}
        } | Out-Null
        $resultsBox.AppendText("👀 Watching folder: $($txtFolder.Text)`n")
    } else {
        if ($global:fsw) { try { $global:fsw.EnableRaisingEvents = $false; $global:fsw.Dispose(); $global:fsw = $null } catch {} }
        Get-EventSubscriber | Where-Object { $_.SourceObject -is [System.IO.FileSystemWatcher] } | Unregister-Event -ErrorAction SilentlyContinue
        $resultsBox.AppendText("🛑 Stopped watching.`n")
    }
})

# Run the GUI
[void]$form.ShowDialog()
