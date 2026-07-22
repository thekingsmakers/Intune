#requires -RunAsAdministrator

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#------------------------------------------------------------
# Windows Image Export Tool
# Supports:
#   - .WIM
#   - .ESD
#
# Exports selected image as:
#   install.wim
#
# Uses:
#   /Compress:Max
#   /CheckIntegrity
#------------------------------------------------------------

$form = New-Object System.Windows.Forms.Form
$form.Text = "Windows Image Export Tool"
$form.Size = New-Object System.Drawing.Size(760,560)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

#------------------------------------------------------------
# Source Image
#------------------------------------------------------------

$lblSource = New-Object System.Windows.Forms.Label
$lblSource.Location = New-Object System.Drawing.Point(10,15)
$lblSource.Size = New-Object System.Drawing.Size(100,20)
$lblSource.Text = "Source Image"

$txtSource = New-Object System.Windows.Forms.TextBox
$txtSource.Location = New-Object System.Drawing.Point(110,12)
$txtSource.Size = New-Object System.Drawing.Size(520,22)

$btnBrowseSource = New-Object System.Windows.Forms.Button
$btnBrowseSource.Location = New-Object System.Drawing.Point(640,10)
$btnBrowseSource.Size = New-Object System.Drawing.Size(90,26)
$btnBrowseSource.Text = "Browse"

#------------------------------------------------------------
# Image List
#------------------------------------------------------------

$lblImages = New-Object System.Windows.Forms.Label
$lblImages.Location = New-Object System.Drawing.Point(10,50)
$lblImages.Size = New-Object System.Drawing.Size(200,20)
$lblImages.Text = "Available Images"

$listImages = New-Object System.Windows.Forms.ListView
$listImages.Location = New-Object System.Drawing.Point(10,75)
$listImages.Size = New-Object System.Drawing.Size(720,280)
$listImages.View = "Details"
$listImages.FullRowSelect = $true
$listImages.GridLines = $true
$listImages.MultiSelect = $false

[void]$listImages.Columns.Add("Index",60)
[void]$listImages.Columns.Add("Name",250)
[void]$listImages.Columns.Add("Description",390)

#------------------------------------------------------------
# Output Folder
#------------------------------------------------------------

$lblOutput = New-Object System.Windows.Forms.Label
$lblOutput.Location = New-Object System.Drawing.Point(10,375)
$lblOutput.Size = New-Object System.Drawing.Size(100,20)
$lblOutput.Text = "Output Folder"

$txtOutput = New-Object System.Windows.Forms.TextBox
$txtOutput.Location = New-Object System.Drawing.Point(110,372)
$txtOutput.Size = New-Object System.Drawing.Size(520,22)

$btnBrowseOutput = New-Object System.Windows.Forms.Button
$btnBrowseOutput.Location = New-Object System.Drawing.Point(640,370)
$btnBrowseOutput.Size = New-Object System.Drawing.Size(90,26)
$btnBrowseOutput.Text = "Browse"

#------------------------------------------------------------
# Export Button
#------------------------------------------------------------

$btnExport = New-Object System.Windows.Forms.Button
$btnExport.Location = New-Object System.Drawing.Point(260,420)
$btnExport.Size = New-Object System.Drawing.Size(220,45)
$btnExport.Text = "Export install.wim"
$btnExport.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)

#------------------------------------------------------------
# Status
#------------------------------------------------------------

$status = New-Object System.Windows.Forms.Label
$status.Location = New-Object System.Drawing.Point(10,485)
$status.Size = New-Object System.Drawing.Size(720,30)
$status.Text = "Ready."

#------------------------------------------------------------
# Add Controls
#------------------------------------------------------------

$form.Controls.AddRange(@(
    $lblSource,
    $txtSource,
    $btnBrowseSource,
    $lblImages,
    $listImages,
    $lblOutput,
    $txtOutput,
    $btnBrowseOutput,
    $btnExport,
    $status
))

#------------------------------------------------------------
# Browse Source Image
#------------------------------------------------------------

$btnBrowseSource.Add_Click({

    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Select Windows Image"
    $dialog.Filter = "Windows Images (*.wim;*.esd)|*.wim;*.esd|WIM Files (*.wim)|*.wim|ESD Files (*.esd)|*.esd|All Files (*.*)|*.*"

    if($dialog.ShowDialog() -ne "OK"){
        return
    }

    $txtSource.Text = $dialog.FileName
    $listImages.Items.Clear()

    try{

        $images = Get-WindowsImage -ImagePath $dialog.FileName -ErrorAction Stop

        foreach($img in $images){

            $item = New-Object System.Windows.Forms.ListViewItem($img.ImageIndex.ToString())

            [void]$item.SubItems.Add($img.ImageName)

            if([string]::IsNullOrWhiteSpace($img.ImageDescription)){
                [void]$item.SubItems.Add("")
            }
            else{
                [void]$item.SubItems.Add($img.ImageDescription)
            }

            [void]$listImages.Items.Add($item)
        }

        $status.Text = "$($images.Count) image(s) found."

    }
    catch{

        [System.Windows.Forms.MessageBox]::Show(
            "Unable to read the selected image.`n`n$($_.Exception.Message)",
            "Error",
            "OK",
            "Error"
        )

        $status.Text = "Failed to read image."
    }

})

#------------------------------------------------------------
# Browse Output Folder
#------------------------------------------------------------

$btnBrowseOutput.Add_Click({

    $folder = New-Object System.Windows.Forms.FolderBrowserDialog
    $folder.Description = "Select output folder"

    if($folder.ShowDialog() -eq "OK"){
        $txtOutput.Text = $folder.SelectedPath
    }

})

#------------------------------------------------------------
# Export
#------------------------------------------------------------

$btnExport.Add_Click({

    if(!(Test-Path $txtSource.Text)){
        [System.Windows.Forms.MessageBox]::Show("Please select a valid WIM or ESD.")
        return
    }

    if($listImages.SelectedItems.Count -eq 0){
        [System.Windows.Forms.MessageBox]::Show("Please select an image index.")
        return
    }

    if(!(Test-Path $txtOutput.Text)){
        [System.Windows.Forms.MessageBox]::Show("Please select an output folder.")
        return
    }

    $index = $listImages.SelectedItems[0].Text

    $destination = Join-Path $txtOutput.Text "install.wim"

    if(Test-Path $destination){

        $answer = [System.Windows.Forms.MessageBox]::Show(
            "install.wim already exists.`n`nOverwrite it?",
            "Confirm",
            "YesNo",
            "Question"
        )

        if($answer -ne "Yes"){
            return
        }

        Remove-Item $destination -Force
    }

    $btnExport.Enabled = $false
    $status.Text = "Exporting image... Please wait."
    $form.Refresh()

    $arguments = @(
        "/Export-Image"
        "/SourceImageFile:`"$($txtSource.Text)`""
        "/SourceIndex:$index"
        "/DestinationImageFile:`"$destination`""
        "/Compress:Max"
        "/CheckIntegrity"
    ) -join " "

    $process = Start-Process `
        -FilePath dism.exe `
        -ArgumentList $arguments `
        -Wait `
        -NoNewWindow `
        -PassThru

    $btnExport.Enabled = $true

    if($process.ExitCode -eq 0){

        $status.Text = "Export completed successfully."

        [System.Windows.Forms.MessageBox]::Show(
            "Export completed successfully!`n`n$destination",
            "Finished",
            "OK",
            "Information"
        )

    }
    else{

        $status.Text = "Export failed."

        [System.Windows.Forms.MessageBox]::Show(
            "DISM failed.`nExit Code: $($process.ExitCode)",
            "Error",
            "OK",
            "Error"
        )
    }

})

#------------------------------------------------------------

[void]$form.ShowDialog()

