Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# -------------------------------------------------------
# CONNECT GRAPH
# -------------------------------------------------------
Write-Host "Connecting to Microsoft Graph..."
Connect-MgGraph -Scopes "Device.Read.All","Directory.Read.All" -NoWelcome
Write-Host "Connected."

# -------------------------------------------------------
# XAML
# -------------------------------------------------------
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Azure Device Export Tool"
        Height="700" Width="1250"
        WindowStartupLocation="CenterScreen"
        Background="#F3F6FB">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <Border Background="#0078D4" Padding="12" CornerRadius="6">
            <TextBlock Text="Azure Device Export Tool" Foreground="White"
                       FontSize="20" FontWeight="Bold"/>
        </Border>

        <StackPanel Grid.Row="1" Margin="0,10,0,10">
            <TextBox Name="FileBox" Height="30" AllowDrop="True"
                     Text="Drag and Drop Excel File Here..."/>
            <StackPanel Orientation="Horizontal" Margin="0,8,0,0">
                <Button Name="BrowseBtn" Content="Browse" Width="100" Margin="0,0,8,0"/>
                <Button Name="StartBtn" Content="Start Export" Width="130" Margin="0,0,8,0"/>
                <Button Name="DownloadBtn" Content="Download Results" Width="150" IsEnabled="False"/>
                <TextBox Name="SearchBox" Width="280" Margin="30,0,0,0" Height="30" Text="Search..."/>
            </StackPanel>
            <ProgressBar Name="ProgressBar" Height="22" Margin="0,12,0,0" Minimum="0" Maximum="100"/>
            <TextBlock Name="StatusText" Text="Ready..." Margin="0,6,0,0" FontWeight="Medium"/>
        </StackPanel>

        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="3*"/>
                <ColumnDefinition Width="1.2*"/>
            </Grid.ColumnDefinitions>
            <DataGrid Name="ResultGrid" AutoGenerateColumns="True" IsReadOnly="True" 
                      GridLinesVisibility="None" AlternatingRowBackground="#F9F9F9"/>
            <TextBox Name="LogBox" Grid.Column="1" TextWrapping="Wrap" 
                     VerticalScrollBarVisibility="Auto" IsReadOnly="True" Margin="8,0,0,0"/>
        </Grid>
    </Grid>
</Window>
"@

# Load UI
[xml]$xml = $xaml
$reader = New-Object System.Xml.XmlNodeReader $xml
$window = [Windows.Markup.XamlReader]::Load($reader)

$fileBox     = $window.FindName("FileBox")
$browseBtn   = $window.FindName("BrowseBtn")
$startBtn    = $window.FindName("StartBtn")
$downloadBtn = $window.FindName("DownloadBtn")
$progress    = $window.FindName("ProgressBar")
$status      = $window.FindName("StatusText")
$dataGrid    = $window.FindName("ResultGrid")
$logBox      = $window.FindName("LogBox")
$searchBox   = $window.FindName("SearchBox")

$script:sync = $null

# Timer with extra force refresh
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(400)
$timer.Add_Tick({
    $s = $script:sync
    if ($null -eq $s -or -not $s.Running) { return }

    $msg = $null
    while ($s.Messages.TryDequeue([ref]$msg)) {
        if ($msg -like "LOG:*") {
            $logBox.AppendText(($msg -replace "^LOG:", "") + "`n")
            $logBox.ScrollToEnd()
        }
        elseif ($msg -like "PROGRESS:*") {
            $pct = [int]($msg -replace "^PROGRESS:", "")
            $progress.Value = $pct
            $status.Text = "$pct% complete"
        }
    }

    if ($s.Done) {
        $s.Running = $false

        $items = [System.Collections.ObjectModel.ObservableCollection[object]]::new($s.Results)
        $dataGrid.ItemsSource = $items

        # Force UI refresh
        $dataGrid.UpdateLayout()
        [System.Windows.Data.CollectionViewSource]::GetDefaultView($dataGrid.ItemsSource).Refresh()

        $progress.Value = 100
        $status.Text = "Done - $($items.Count) device(s) found"

        $logBox.AppendText("Export complete. $($items.Count) record(s) loaded.`n")
        $logBox.ScrollToEnd()

        $startBtn.IsEnabled = $true
        
        # Reliable enable for Download button
        $downloadBtn.IsEnabled = ($items.Count -gt 0)
        if ($items.Count -gt 0) {
            $logBox.AppendText("Download button enabled.`n")
        }
    }
})
$timer.Start()

# Drag & Drop + Browse
$fileBox.Add_PreviewDragOver({ param($s, $e) $e.Effects = [System.Windows.DragDropEffects]::Copy; $e.Handled = $true })
$fileBox.Add_Drop({
    param($s, $e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $dropped = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
        if ($dropped.Count -gt 0) { $fileBox.Text = $dropped[0] }
    }
})
$browseBtn.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = "Excel (*.xlsx)|*.xlsx"
    if ($dlg.ShowDialog()) { $fileBox.Text = $dlg.FileName }
})

# Search across all columns
$searchBox.Add_TextChanged({
    if (-not $dataGrid.ItemsSource) { return }
    $text = $searchBox.Text.Trim().ToLower()
    $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($dataGrid.ItemsSource)

    if ([string]::IsNullOrWhiteSpace($text)) {
        $view.Filter = $null
    } else {
        $view.Filter = { param($item) ($item.PSObject.Properties.Value -join " ").ToLower().Contains($text) }
    }
    $view.Refresh()
})

# Download Button (exports visible rows)
$downloadBtn.Add_Click({
    if (-not $dataGrid.ItemsSource -or $dataGrid.ItemsSource.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No results to download.", "Nothing to Export", "OK", "Information")
        return
    }

    $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($dataGrid.ItemsSource)
    $dataToExport = if ($view -and $view.Count -gt 0) { @($view) } else { @($dataGrid.ItemsSource) }

    if ($dataToExport.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No visible rows to export.", "Nothing to Export", "OK", "Information")
        return
    }

    $saveDlg = New-Object Microsoft.Win32.SaveFileDialog
    $saveDlg.Filter = "Excel Workbook (*.xlsx)|*.xlsx"
    $saveDlg.Title = "Save Device Export"
    $saveDlg.FileName = "Azure_Devices_Export_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

    if ($saveDlg.ShowDialog() -eq $true) {
        try {
            $dataToExport | Export-Excel -Path $saveDlg.FileName `
                                         -AutoSize `
                                         -TableName "Devices" `
                                         -TableStyle "Medium2" `
                                         -BoldTopRow `
                                         -WorksheetName "Azure Devices"

            $logBox.AppendText("Exported $($dataToExport.Count) rows successfully to:`n$($saveDlg.FileName)`n")
            $logBox.ScrollToEnd()
            [System.Windows.MessageBox]::Show("Export successful!`n$($dataToExport.Count) rows saved.", "Success", "OK", "Information")
        }
        catch {
            $logBox.AppendText("Export failed: $($_.Exception.Message)`n")
            $logBox.ScrollToEnd()
            [System.Windows.MessageBox]::Show("Export failed: $($_.Exception.Message)", "Error", "OK", "Error")
        }
    }
})

# START EXPORT
$startBtn.Add_Click({
    $file = $fileBox.Text
    if (-not (Test-Path $file)) {
        $logBox.AppendText("ERROR: File not found - $file`n")
        $logBox.ScrollToEnd()
        return
    }

    $startBtn.IsEnabled = $false
    $downloadBtn.IsEnabled = $false
    $dataGrid.ItemsSource = $null
    $progress.Value = 0
    $status.Text = "Running..."
    $logBox.AppendText("Starting export...`n")
    $logBox.ScrollToEnd()

    $script:sync = [hashtable]::Synchronized(@{
        Running  = $true
        Done     = $false
        Messages = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
        Results  = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
        File     = $file
    })

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable("sync", $script:sync)

    $ps = [powershell]::Create()
    $ps.Runspace = $runspace

    $ps.AddScript({
        function Log([string]$msg) { $sync.Messages.Enqueue("LOG:$msg") }
        function Prog([int]$pct)   { $sync.Messages.Enqueue("PROGRESS:$pct") }

        try {
            Import-Module ImportExcel -ErrorAction Stop

            Log "Reading Excel file..."
            $rows = @(Import-Excel $sync.File)
            $total = $rows.Count
            Log "Found $total rows."

            $counter = 0
            foreach ($row in $rows) {
                $counter++
                if (-not $row.DeviceName) { continue }

                $name = $row.DeviceName.Trim()
                try {
                    $resp = Invoke-MgGraphRequest -Method GET `
                        -Uri "https://graph.microsoft.com/v1.0/devices?`$filter=startswith(displayName,'$([Uri]::EscapeDataString($name))')"

                    foreach ($dev in $resp.value) {
                        $sync.Results.Add([pscustomobject]@{
                            DeviceName            = $dev.displayName
                            ObjectId              = $dev.id
                            DeviceId              = $dev.deviceId
                            OS                    = $dev.operatingSystem
                            OSVersion             = $dev.operatingSystemVersion
                            ApproximateLastSignIn = $dev.approximateLastSignInDateTime
                        })
                    }
                }
                catch {
                    Log "Error on '$name': $($_.Exception.Message)"
                }

                if ($counter % 10 -eq 0 -or $counter -eq $total) {
                    $pct = [int](($counter / $total) * 100)
                    Prog $pct
                    Log "Processed $counter / $total"
                }
            }
            Log "All rows processed successfully."
        }
        catch {
            Log "FATAL ERROR: $($_.Exception.Message)"
        }
        finally {
            $sync.Done = $true
        }
    }) | Out-Null

    $ps.BeginInvoke() | Out-Null
})

$window.ShowDialog() | Out-Null
