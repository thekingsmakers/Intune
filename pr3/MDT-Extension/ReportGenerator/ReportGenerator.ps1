# ReportGenerator.ps1
# PowerShell script for generating MDT deployment report in HTML

#region HTML Report Template
$HTMLReportTemplate = @"
<!DOCTYPE html>
<html>
<head>
    <title>MDT Deployment Report - {DeviceName}</title>
    <style>
        body { font-family: Arial, sans-serif; }
        h1 { color: #333; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>MDT Deployment Report</h1>
    <h2>Device Name: {DeviceName}</h2>
    <p>Report generated on: {ReportDate}</p>

    <h3>Deployment Summary</h3>
    <table>
        <tr><th>Item</th><th>Status</th></tr>
        <tr><td>Operating System Deployment</td><td>{OSDeploymentStatus}</td></tr>
        <tr><td>Domain Join</td><td>{DomainJoinStatus}</td></tr>
        <tr><td>Software Installation</td><td>{SoftwareInstallationStatus}</td></tr>
    </table>

    <h3>Software Inventory</h3>
    <table>
        <tr><th>Software Name</th><th>Version</th><th>Installation Status</th></tr>
        <!-- Software Inventory Items will be inserted here -->
        {SoftwareInventoryTableRows}
    </table>

    <h3>Deployment Logs</h3>
    <pre>{DeploymentLogs}</pre>

</body>
</html>
"@
#endregion

#region Data to be inserted into the report (Placeholder Data for now)
$DeviceName = "Computer-01"
$ReportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$OSDeploymentStatus = "Success"
$DomainJoinStatus = "Success"
$SoftwareInstallationStatus = "Success"
$DeploymentLogs = "Placeholder logs. Detailed logs will be added here in future versions."

$SoftwareInventory = @(
    @{ Name = "Software 1"; Version = "1.0"; Status = "Installed" }
    @{ Name = "Software 2"; Version = "2.1"; Status = "Installed" }
    @{ Name = "Software 3"; Version = "1.5"; Status = "Not Installed" }
)

# Generate Software Inventory Table Rows
$SoftwareInventoryTableRows = ""
foreach ($Software in $SoftwareInventory) {
    $SoftwareInventoryTableRows += "<tr><td>$($Software.Name)</td><td>$($Software.Version)</td><td>$($Software.Status)</td></tr>"
}
#endregion

#region Generate HTML Report Content
$HTMLContent = $HTMLReportTemplate -replace "{DeviceName}", $DeviceName
$HTMLContent = $HTMLContent -replace "{ReportDate}", $ReportDate
$HTMLContent = $HTMLContent -replace "{OSDeploymentStatus}", $OSDeploymentStatus
$HTMLContent = $HTMLContent -replace "{DomainJoinStatus}", $DomainJoinStatus
$HTMLContent = $HTMLContent -replace "{SoftwareInstallationStatus}", $SoftwareInstallationStatus
$HTMLContent = $HTMLContent -replace "{SoftwareInventoryTableRows}", $SoftwareInventoryTableRows
$HTMLContent = $HTMLContent -replace "{DeploymentLogs}", $DeploymentLogs
#endregion

# Output HTML Report to File (for now, just output to console)
# $ReportFilePath = "MDT-Extension/ReportGenerator/DeploymentReport-$DeviceName.html"
# $HTMLContent | Out-File -FilePath $ReportFilePath -Encoding UTF8
Write-Host $HTMLContent
Write-Host "HTML Report content generated (output to console for now)."