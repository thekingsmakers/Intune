$Tenant = ""
$clientid = ""
$clientSecret = ""
$grouptag = "TSUpload"
$teamsURI = ''
$alerts = $false

Try {
  # Robust time synchronization
  Write-Host "Current system time: $(Get-Date)"
  Write-Host "Synchronizing system time with time.windows.com..."
  Start-Service -Name W32Time -ErrorAction SilentlyContinue 
  w32tm /config /manualpeerlist:"time.windows.com" /syncfromflags:manual /update
  $syncResult = w32tm /resync /force 2>&1
  Write-Host $syncResult

  # Fallback: Sync from web if time is still significantly off
  try {
      $webResponse = Invoke-WebRequest -Uri "https://login.microsoftonline.com" -Method Head -UseBasicParsing -ErrorAction Stop
      if ($webResponse -and $webResponse.Headers.Date) {
          $webTime = [DateTime]$webResponse.Headers.Date
          $localTime = Get-Date
          if ([Math]::Abs(($localTime - $webTime).TotalMinutes) -gt 2) {
              Write-Host "Time is still off by $([Math]::Round(($localTime - $webTime).TotalMinutes)) minutes. Manually correcting..."
              Set-Date -Date $webTime
          }
      }
  } catch {
      Write-Warning "Web time sync fallback failed: $($_.Exception.Message)"
  }
  Write-Host "System time after sync: $(Get-Date)"

  $serial = (Get-CimInstance win32_bios).SerialNumber
  Set-Location "$env:ProgramFiles\Scripts\"
  
  # Clean up any existing Graph sessions
  if (Get-Module -Name Microsoft.Graph.Authentication) { Disconnect-MgGraph -ErrorAction SilentlyContinue }
  
  ./Get-WindowsAutoPilotInfo.ps1 -Online -groupTag $grouptag -TenantId $tenant -AppId $clientid -AppSecret $clientSecret
   
  remove-item  $env:ProgramFiles\Scripts\ -force -Recurse
  
  
  if ($alerts -eq $true) {
    # Force TLS 1.2 protocol. Invoke-RestMethod uses 1.0 by default. Required for Teams notification to work
    Write-Verbose -Message ('{0} - Forcing TLS 1.2 protocol for invoking REST method.' -f $MyInvocation.MyCommand.Name)
    Set-Location "C:\"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
     
    $body = ConvertTo-Json -Depth 4 @{
      title    = "Hash Upload Status"
      text     = " "
      sections = @(
        @{
          activityTitle    = 'Succesful Upload of Hardware Hash'
          activitySubtitle = "Device with Serial $serial uploaded succesfully, with the group tag $grouptag"
          activityText     = ' '
          activityImage    = 'https://i.imgur.com/NtPeAoY.png' # this value would be a path to a nice image you would like to display in notifications
        }
      )
    }
    Invoke-RestMethod -uri $teamsURI -Method Post -body $body -ContentType 'application/json'
  }
}
catch {
        
  $errMsg = $_.Exception.Message
  write-host $errMsg
  if ($alerts -eq $true) {                
    # Force TLS 1.2 protocol. Invoke-RestMethod uses 1.0 by default. Required for Teams notification to work
    Write-Verbose -Message ('{0} - Forcing TLS 1.2 protocol for invoking REST method.' -f $MyInvocation.MyCommand.Name)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
     
    $body = ConvertTo-Json -Depth 4 @{
      title    = "Hash Upload Fail"
      text     = "$errMsg "
      sections = @(
        @{
          activityTitle    = 'Hash upload failure'
          activitySubtitle = "Review error message"
          activityText     = ' '
          activityImage    = 'https://i.imgur.com/N39eDrY.png' # this value would be a path to a nice image you would like to display in notifications
        }
      )
    }
    Invoke-RestMethod -uri $teamsURI -Method Post -body $body -ContentType 'application/json'
  }
}





