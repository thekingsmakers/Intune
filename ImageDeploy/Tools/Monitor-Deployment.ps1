<#
.SYNOPSIS
    Monitors Windows deployment progress
.DESCRIPTION
    Provides real-time monitoring of deployment status, logs, and system changes
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "..\Deployment\Logs\Deployment.log"
)

$ErrorActionPreference = "Stop"
$script:lastLogSize = 0
$script:startTime = Get-Date
$progressStages = @{
    "Software" = @{
        Status = "Pending"
        StartTime = $null
        EndTime = $null
        Details = @()
    }
    "Hostname" = @{
        Status = "Pending"
        StartTime = $null
        EndTime = $null
        Details = @()
    }
    "Network" = @{
        Status = "Pending"
        StartTime = $null
        EndTime = $null
        Details = @()
    }
    "Windows" = @{
        Status = "Pending"
        StartTime = $null
        EndTime = $null
        Details = @()
    }
    "Features" = @{
        Status = "Pending"
        StartTime = $null
        EndTime = $null
        Details = @()
    }
    "Domain" = @{
        Status = "Pending"
        StartTime = $null
        EndTime = $null
        Details = @()
    }
}

function Write-ProgressBar {
    param(
        [int]$Completed,
        [int]$Total,
        [string]$Stage
    )
    
    $percentage = [math]::Min(100, [math]::Round(($Completed / $Total) * 100))
    $width = [Console]::WindowWidth - 20
    $filledWidth = [math]::Round(($width * $percentage) / 100)
    $emptyWidth = $width - $filledWidth
    
    $bar = "[" + ("=" * $filledWidth) + (" " * $emptyWidth) + "]"
    Write-Host ("`r{0}: {1} {2}%" -f $Stage, $bar, $percentage) -NoNewline
}

function Update-StageStatus {
    param(
        [string]$Stage,
        [string]$Status,
        [string]$Detail
    )
    
    $progressStages[$Stage].Status = $Status
    if ($Status -eq "Running" -and -not $progressStages[$Stage].StartTime) {
        $progressStages[$Stage].StartTime = Get-Date
    }
    elseif ($Status -eq "Complete") {
        $progressStages[$Stage].EndTime = Get-Date
    }
    
    if ($Detail) {
        $progressStages[$Stage].Details += $Detail
    }
}

function Show-DeploymentProgress {
    Clear-Host
    Write-Host "Windows Deployment Progress Monitor" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    
    $elapsedTime = [math]::Round(((Get-Date) - $script:startTime).TotalMinutes, 1)
    Write-Host "`nElapsed Time: $elapsedTime minutes`n"
    
    $completedStages = 0
    foreach ($stage in $progressStages.GetEnumerator()) {
        $stageName = $stage.Key
        $stageData = $stage.Value
        
        # Status color
        $color = switch ($stageData.Status) {
            "Complete" { "Green"; $completedStages++ }
            "Running" { "Yellow" }
            "Error" { "Red" }
            default { "Gray" }
        }
        
        Write-Host "$stageName : " -NoNewline
        Write-Host $stageData.Status -ForegroundColor $color
        
        if ($stageData.Details.Count -gt 0) {
            $stageData.Details | Select-Object -Last 3 | ForEach-Object {
                Write-Host "  - $_" -ForegroundColor DarkGray
            }
        }
        
        if ($stageData.StartTime -and $stageData.EndTime) {
            $duration = [math]::Round(($stageData.EndTime - $stageData.StartTime).TotalSeconds, 1)
            Write-Host "  Duration: $duration seconds" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
    
    Write-ProgressBar -Completed $completedStages -Total 6 -Stage "Overall Progress"
}

function Process-LogEntry {
    param([string]$Line)
    
    # Extract stage and status from log entry
    if ($Line -match "Installing software") {
        Update-StageStatus -Stage "Software" -Status "Running" -Detail $Line
    }
    elseif ($Line -match "Software installation complete") {
        Update-StageStatus -Stage "Software" -Status "Complete" -Detail $Line
    }
    elseif ($Line -match "Setting hostname") {
        Update-StageStatus -Stage "Hostname" -Status "Running" -Detail $Line
    }
    elseif ($Line -match "Hostname configured") {
        Update-StageStatus -Stage "Hostname" -Status "Complete" -Detail $Line
    }
    elseif ($Line -match "Configuring WiFi") {
        Update-StageStatus -Stage "Network" -Status "Running" -Detail $Line
    }
    elseif ($Line -match "WiFi connected") {
        Update-StageStatus -Stage "Network" -Status "Complete" -Detail $Line
    }
    elseif ($Line -match "Activating Windows") {
        Update-StageStatus -Stage "Windows" -Status "Running" -Detail $Line
    }
    elseif ($Line -match "Windows activated") {
        Update-StageStatus -Stage "Windows" -Status "Complete" -Detail $Line
    }
    elseif ($Line -match "Installing features") {
        Update-StageStatus -Stage "Features" -Status "Running" -Detail $Line
    }
    elseif ($Line -match "Features installation complete") {
        Update-StageStatus -Stage "Features" -Status "Complete" -Detail $Line
    }
    elseif ($Line -match "Joining domain") {
        Update-StageStatus -Stage "Domain" -Status "Running" -Detail $Line
    }
    elseif ($Line -match "Domain joined") {
        Update-StageStatus -Stage "Domain" -Status "Complete" -Detail $Line
    }
    
    # Error handling
    if ($Line -match "ERROR|Failed|Exception") {
        $stage = $progressStages.Keys | Where-Object { $Line -match $_ } | Select-Object -First 1
        if ($stage) {
            Update-StageStatus -Stage $stage -Status "Error" -Detail $Line
        }
    }
}

function Monitor-LogFile {
    try {
        while ($true) {
            if (Test-Path $LogPath) {
                $currentSize = (Get-Item $LogPath).Length
                if ($currentSize -gt $script:lastLogSize) {
                    $newContent = Get-Content $LogPath | Select-Object -Skip ($script:lastLogSize / 2)
                    foreach ($line in $newContent) {
                        Process-LogEntry $line
                    }
                    $script:lastLogSize = $currentSize
                }
            }
            
            Show-DeploymentProgress
            Start-Sleep -Seconds 1
        }
    }
    catch {
        Write-Error "Monitoring failed: $_"
    }
    finally {
        Write-Host "`n`nMonitoring ended. Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# Start monitoring
Write-Host "Starting deployment monitoring..."
Write-Host "Press Ctrl+C to stop monitoring`n"
Monitor-LogFile