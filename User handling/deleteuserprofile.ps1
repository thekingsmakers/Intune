# Set the number of days
$Days = 30  # Change this to your desired number

# Get today's date
$CutOffDate = (Get-Date).AddDays(-$Days)

# Get all local profiles except system profiles
$Profiles = Get-CimInstance Win32_UserProfile | Where-Object {
    $_.LocalPath -and
    ($_.Special -eq $false) -and
    ($_.LastUseTime -ne $null) -and
    ([Management.ManagementDateTimeConverter]::ToDateTime($_.LastUseTime) -lt $CutOffDate)
}

foreach ($Profile in $Profiles) {
    try {
        $LastUsed = [Management.ManagementDateTimeConverter]::ToDateTime($Profile.LastUseTime)
        Write-Host "Deleting profile: $($Profile.LocalPath) - Last used: $LastUsed" -ForegroundColor Yellow
        
        # Delete the profile (removes files and registry entries)
        $Profile | Remove-CimInstance -ErrorAction Stop
        
        Write-Host "Deleted successfully: $($Profile.LocalPath)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to delete $($Profile.LocalPath): $_" -ForegroundColor Red
    }
}