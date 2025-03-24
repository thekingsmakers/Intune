<#
Version: 1.1
Author: Omar Osman(thekingsmakers.github.io), Modified
Script: Remove-PrimaryUserFromIntuneDevices
Description:
Remove the primary user from devices listed in a CSV file
Release notes:
Version 1.0: Init
Version 1.1: Modified to use CSV input file
#> 
function Get-AuthToken {
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        $User
    )

    $userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $User
    $tenant = $userUpn.Host
    $AadModule = Get-Module -Name "AzureAD" -ListAvailable
    if ($AadModule -eq $null) {
        Write-Host "AzureAD PowerShell module not found, looking for AzureADPreview"
        $AadModule = Get-Module -Name "AzureADPreview" -ListAvailable
    }

    $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
    $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"

    Add-Type -Path $adal
    Add-Type -Path $adalforms
    # [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    # [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
    $clientId = "-16e1-4764-894d-b6c0ad0267ef" #application name can be found in your azure tenant 
    $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
    $resourceAppIdURI = "https://graph.microsoft.com"
    $authority = "https://login.microsoftonline.com/$Tenant"

    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
    $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"
    $userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($User, "OptionalDisplayableId")
    $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI,$clientId,$redirectUri,$platformParameters,$userId).Result

      
    $authHeader = @{
        'Content-Type'='application/json'
        'Authorization'="Bearer " + $authResult.AccessToken
        'ExpiresOn'=$authResult.ExpiresOn
        }

    return $authHeader
}

####################################################

function Get-Win10IntuneManagedDevices {

<#
.SYNOPSIS
This gets information on Intune managed devices
.DESCRIPTION
This gets information on Intune managed devices
.EXAMPLE
Get-Win10IntuneManagedDevices
.NOTES
NAME: Get-Win10IntuneManagedDevices
#>

[cmdletbinding()]

param
(
[parameter(Mandatory=$false)]
[ValidateNotNullOrEmpty()]
[string]$deviceName
)

    $devices = @()
    $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"
    if($deviceName) {
        $uri = "$uri?" + '$filter' + "=deviceName eq '$deviceName'"
        $response = Invoke-RestMethod -Uri $uri -Headers $authToken -Method "GET"
        $devices += $response.value
    }else{
        while($uri)
        {
            $response = Invoke-RestMethod -Uri $uri -Headers $authToken -Method "GET"
            $devices += $response.value
            $uri = $response.'@odata.nextLink'
        }
    }
    return $devices
}

####################################################

function Get-IntuneDevicePrimaryUser {

<#
.SYNOPSIS
This lists the Intune device primary user
.DESCRIPTION
This lists the Intune device primary user
.EXAMPLE
Get-IntuneDevicePrimaryUser
.NOTES
NAME: Get-IntuneDevicePrimaryUser
#>

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)]
    [string] $deviceId
)
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/managedDevices"
	$uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)" + "/" + $deviceId + "/users"

    try {
        
        $primaryUser = Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get

        return $primaryUser.value."id"
        
	} catch {
		$ex = $_.Exception
		$errorResponse = $ex.Response.GetResponseStream()
		$reader = New-Object System.IO.StreamReader($errorResponse)
		$reader.BaseStream.Position = 0
		$reader.DiscardBufferedData()
		$responseBody = $reader.ReadToEnd();
		Write-Host "Response content:`n$responseBody" -f Red
		Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
		throw "Get-IntuneDevicePrimaryUser error"
	}
}

####################################################

function Delete-IntuneDevicePrimaryUser {

<#
.SYNOPSIS
This deletes the Intune device primary user
.DESCRIPTION
This deletes the Intune device primary user
.EXAMPLE
Delete-IntuneDevicePrimaryUser
.NOTES
NAME: Delete-IntuneDevicePrimaryUser
#>

[cmdletbinding()]

param
(
[parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
$IntuneDeviceId
)
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/managedDevices('$IntuneDeviceId')/users/`$ref"

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"

        Invoke-RestMethod -Uri $uri -Headers $authToken -Method Delete

	}

    catch {

		$ex = $_.Exception
		$errorResponse = $ex.Response.GetResponseStream()
		$reader = New-Object System.IO.StreamReader($errorResponse)
		$reader.BaseStream.Position = 0
		$reader.DiscardBufferedData()
		$responseBody = $reader.ReadToEnd();
		Write-Host "Response content:`n$responseBody" -f Red
		Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
		throw "Delete-IntuneDevicePrimaryUser error"
	
    }

}

# CSV File Path
$csvFilePath = "delete.csv"

# Check if the CSV file exists
if (-not (Test-Path $csvFilePath)) {
    Write-Host "CSV file not found: $csvFilePath" -ForegroundColor Red
    exit
}

# Read device names from CSV
try {
    $devicesToProcess = Import-Csv -Path $csvFilePath
    Write-Host "Successfully loaded CSV file with $($devicesToProcess.Count) devices" -ForegroundColor Green
} catch {
    Write-Host "Error reading CSV file: $_" -ForegroundColor Red
    exit
}

# Check CSV format - assuming it has a column named "DeviceName"
if (-not ($devicesToProcess | Get-Member -Name "DeviceName" -MemberType NoteProperty)) {
    Write-Host "CSV file must contain a column named 'DeviceName'" -ForegroundColor Red
    exit
}

# Auth
if(-not $global:authToken){
    if($User -eq $null -or $User -eq ""){
    $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
    Write-Host
    }
    $global:authToken = Get-AuthToken -User $User
}

# Get all Intune managed devices
$allDevices = Get-Win10IntuneManagedDevices

# Process each device in the CSV
foreach ($deviceEntry in $devicesToProcess) {
    $deviceName = $deviceEntry.DeviceName
    $matchingDevices = $allDevices | Where-Object {$_.deviceName -eq $deviceName}
    
    if ($matchingDevices.Count -eq 0) {
        Write-Host "Device '$deviceName' not found in Intune" -ForegroundColor Yellow
    } elseif ($matchingDevices.Count -gt 1) {
        Write-Host "Multiple devices found with name '$deviceName'. Processing all matches..." -ForegroundColor Yellow
        foreach ($device in $matchingDevices) {
            Write-Host "Removing primary user from device: $($device.deviceName) (ID: $($device.id))" -ForegroundColor Cyan
            Delete-IntuneDevicePrimaryUser -IntuneDeviceId $device.id -ErrorAction Continue
        }
    } else {
        $device = $matchingDevices[0]
        Write-Host "Removing primary user from device: $($device.deviceName) (ID: $($device.id))" -ForegroundColor Cyan
        Delete-IntuneDevicePrimaryUser -IntuneDeviceId $device.id -ErrorAction Continue
    }
}

Write-Host "Script completed. Primary users removed from devices listed in $csvFilePath" -ForegroundColor Green
