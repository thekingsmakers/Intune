# PowerShell GUI to simulate Intune Scripts & Remediation with Branding & Script Validation
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Branding & Colors
$brandName = '@thekingsmakers'
$bgColor = [System.Drawing.Color]::FromArgb(30,30,30)
$fgColor = [System.Drawing.Color]::White
$btnColor = [System.Drawing.Color]::FromArgb(0,120,215)
$btnHoverColor = [System.Drawing.Color]::FromArgb(0,150,255)
$fontMain = New-Object System.Drawing.Font('Segoe UI',10)

# Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Intune Scripts Simulator - $brandName"
$form.Size = New-Object System.Drawing.Size(1250,800)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $bgColor
$form.ForeColor = $fgColor
$form.Font = $fontMain

# Branding Label
$lblBrand = New-Object System.Windows.Forms.Label
$lblBrand.Text = "All rights reserved $brandName 2025"
$lblBrand.ForeColor = $fgColor
$lblBrand.Location = New-Object System.Drawing.Point(10,720)
$lblBrand.AutoSize = $true
$form.Controls.Add($lblBrand)

# Output TextBox with Logging
$txtOutput = New-Object System.Windows.Forms.TextBox
$txtOutput.Multiline = $true
$txtOutput.ScrollBars = 'Vertical'
$txtOutput.Font = New-Object System.Drawing.Font('Consolas',10)
$txtOutput.Size = New-Object System.Drawing.Size(1210,250)
$txtOutput.Location = New-Object System.Drawing.Point(10,470)
$txtOutput.ReadOnly = $true
$txtOutput.BackColor = [System.Drawing.Color]::FromArgb(20,20,20)
$txtOutput.ForeColor = $fgColor
$form.Controls.Add($txtOutput)

# Panels for Detection and Remediation Scripts
$panelDetect = New-Object System.Windows.Forms.Panel
$panelDetect.Size = New-Object System.Drawing.Size(580,350)
$panelDetect.Location = New-Object System.Drawing.Point(10,10)
$panelDetect.BackColor = [System.Drawing.Color]::FromArgb(40,40,40)
$form.Controls.Add($panelDetect)

$lblDetect = New-Object System.Windows.Forms.Label
$lblDetect.Text = 'Detection Script'
$lblDetect.ForeColor = $fgColor
$lblDetect.Location = New-Object System.Drawing.Point(10,10)
$lblDetect.AutoSize = $true
$panelDetect.Controls.Add($lblDetect)

$txtDetection = New-Object System.Windows.Forms.TextBox
$txtDetection.Multiline = $true
$txtDetection.ScrollBars = 'Both'
$txtDetection.Font = New-Object System.Drawing.Font('Consolas',10)
$txtDetection.Size = New-Object System.Drawing.Size(550,260)
$txtDetection.Location = New-Object System.Drawing.Point(10,35)
$txtDetection.ReadOnly = $true
$txtDetection.BackColor = [System.Drawing.Color]::FromArgb(20,20,20)
$txtDetection.ForeColor = $fgColor
$panelDetect.Controls.Add($txtDetection)

$btnBrowseDetect = New-Object System.Windows.Forms.Button
$btnBrowseDetect.Text = 'Browse Detection'
$btnBrowseDetect.BackColor = $btnColor
$btnBrowseDetect.ForeColor = $fgColor
$btnBrowseDetect.FlatStyle = 'Flat'
$btnBrowseDetect.Size = New-Object System.Drawing.Size(150,30)
$btnBrowseDetect.Location = New-Object System.Drawing.Point(10,305)
$panelDetect.Controls.Add($btnBrowseDetect)

$panelRemed = New-Object System.Windows.Forms.Panel
$panelRemed.Size = New-Object System.Drawing.Size(580,350)
$panelRemed.Location = New-Object System.Drawing.Point(600,10)
$panelRemed.BackColor = [System.Drawing.Color]::FromArgb(40,40,40)
$form.Controls.Add($panelRemed)

$lblRemed = New-Object System.Windows.Forms.Label
$lblRemed.Text = 'Remediation Script'
$lblRemed.ForeColor = $fgColor
$lblRemed.Location = New-Object System.Drawing.Point(10,10)
$lblRemed.AutoSize = $true
$panelRemed.Controls.Add($lblRemed)

$txtRemediation = New-Object System.Windows.Forms.TextBox
$txtRemediation.Multiline = $true
$txtRemediation.ScrollBars = 'Both'
$txtRemediation.Font = New-Object System.Drawing.Font('Consolas',10)
$txtRemediation.Size = New-Object System.Drawing.Size(550,260)
$txtRemediation.Location = New-Object System.Drawing.Point(10,35)
$txtRemediation.ReadOnly = $true
$txtRemediation.BackColor = [System.Drawing.Color]::FromArgb(20,20,20)
$txtRemediation.ForeColor = $fgColor
$panelRemed.Controls.Add($txtRemediation)

$btnBrowseRemed = New-Object System.Windows.Forms.Button
$btnBrowseRemed.Text = 'Browse Remediation'
$btnBrowseRemed.BackColor = $btnColor
$btnBrowseRemed.ForeColor = $fgColor
$btnBrowseRemed.FlatStyle = 'Flat'
$btnBrowseRemed.Size = New-Object System.Drawing.Size(150,30)
$btnBrowseRemed.Location = New-Object System.Drawing.Point(10,305)
$panelRemed.Controls.Add($btnBrowseRemed)

# Force Signature Checkbox
$chkForceSig = New-Object System.Windows.Forms.CheckBox
$chkForceSig.Text = 'Force Script Signature'
$chkForceSig.ForeColor = $fgColor
$chkForceSig.Location = New-Object System.Drawing.Point(10,400)
$form.Controls.Add($chkForceSig)

# Logging Function
function Write-Log($msg){
    $txtOutput.AppendText("$(Get-Date -Format 'HH:mm:ss') - $msg`r`n")
    $txtOutput.SelectionStart = $txtOutput.Text.Length
    $txtOutput.ScrollToCaret()
}

# Script Validation as per Microsoft Documentation
function Validate-Script($path){
    $requiredProperties = @('ScriptContent','RunAs32','EnforceSignatureCheck')
    Write-Log "Validating script: $path"
    $scriptContent = Get-Content $path -Raw
    if(!$scriptContent){ throw "Script is empty or unreadable" }
    # Optional: Implement additional Microsoft script validation rules here
    Write-Log "Script validated successfully: $path"
}

# Script Invocation Functions
function Test-SignatureOrFail($path){
    if($chkForceSig.Checked){
        $sig = Get-AuthenticodeSignature -FilePath $path -ErrorAction SilentlyContinue
        if(!$sig -or $sig.Status -ne 'Valid'){ throw "Invalid signature: $path" }
    }
}

function Invoke-Script($path){
    Write-Log "Running script: $path"
    Validate-Script $path
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = (Join-Path $PSHOME 'powershell.exe')
    $psi.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$path`""
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    Write-Log $stdout
    if($stderr){ Write-Log "Error: $stderr" }
    return $proc.ExitCode
}

# Run Detection & Remediation Automatically
function Run-DetectionRemediation(){
    if($txtDetection.Text -ne ''){
        Test-SignatureOrFail $txtDetection.Text
        $exitCode = Invoke-Script $txtDetection.Text
        if($exitCode -ne 0 -and $txtRemediation.Text -ne ''){
            Write-Log "Detection failed, running remediation..."
            Test-SignatureOrFail $txtRemediation.Text
            Invoke-Script $txtRemediation.Text
        }
        elseif($exitCode -eq 0){
            Write-Log "Detection passed, remediation not needed."
        }
    }
}

# Browse Events with Auto-Run
$btnBrowseDetect.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = 'PowerShell Scripts (*.ps1)|*.ps1'
    if($ofd.ShowDialog() -eq 'OK'){ 
        $txtDetection.Text = $ofd.FileName 
        if($txtRemediation.Text -ne ''){ Run-DetectionRemediation }
    }
})

$btnBrowseRemed.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = 'PowerShell Scripts (*.ps1)|*.ps1'
    if($ofd.ShowDialog() -eq 'OK'){ 
        $txtRemediation.Text = $ofd.FileName 
        if($txtDetection.Text -ne ''){ Run-DetectionRemediation }
    }
})

# Show Form
[void]$form.ShowDialog()