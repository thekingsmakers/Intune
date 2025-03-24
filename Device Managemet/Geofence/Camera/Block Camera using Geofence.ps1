<#
.SYNOPSIS
    This script checks if you are in a certain Geocordinate and blocks camera based on the required cordinates
    Add it as remeediation to run everytime to get precise functionality
.DESCRIPTION
    The script performs 
    - checks your current location
    - blocks camera is you are in the mentioned cordinates
    - enables camera if you are not in the mentioned cordinates

.NOTES
    Author: Omar Osman Mahat
    Twitter: https://x.com/thekingsmakers

.PARAMETER None
    This script does not accept any parameters.

.EXAMPLE
    Run the script to enable/Disable Camera based on the mentioned Cordinates:
    
    ```powershell
    .\Block Camera using Geofence.ps1
    ```
#>

 
 
 # Define the target coordinates
$targetLatitude = 21.2855
$targetLongitude = 21.5310

# Define the API endpoint to get your current location
$apiUrl = "https://ipinfo.io/json"

# Function to disable the camera
function Disable-Camera {
    $camera = Get-PnpDevice | Where-Object { $_.FriendlyName -like "*Camera*" -and $_.Status -eq "OK" }
    if ($camera) {
        foreach ($device in $camera) {
            try {
                $device | Disable-PnpDevice -Confirm:$false -ErrorAction Stop
                Write-Output "Camera '$($device.FriendlyName)' has been disabled."
            } catch {
                Write-Output "Failed to disable camera '$($device.FriendlyName)': $_"
            }
        }
    } else {
        Write-Output "No active camera found to disable."
    }
}

# Function to enable the camera
function Enable-Camera {
    # Enable the camera explicitly
    $camera = Get-PnpDevice | Where-Object { $_.FriendlyName -like "*Camera*" }
    if ($camera) {
        $camera | Enable-PnpDevice -Confirm:$false
        Write-Output "Camera has been enabled."
    } else {
        Write-Output "Camera device not found."
    }
}

# Get the current location data
try {
    $response = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
    $currentLocation = $response.loc
    $currentLatitude, $currentLongitude = $currentLocation -split ','
    
    # Convert coordinates to numbers
    $currentLatitude = [double]$currentLatitude
    $currentLongitude = [double]$currentLongitude
    
    # Calculate the difference between current location and target location
    $latitudeDifference = [math]::Abs($currentLatitude - $targetLatitude)
    $longitudeDifference = [math]::Abs($currentLongitude - $targetLongitude)
    
    # Set a threshold distance (in degrees, example: 0.01 degrees ~ 1 km)
    $threshold = 0.01

    # Check if the current location is within the specified range
    if ($latitudeDifference -le $threshold -and $longitudeDifference -le $threshold) {
        Write-Output "You are within the specified coordinates. Disabling the camera."
        Disable-Camera
    } else {
        Write-Output "You are outside the specified coordinates. Enabling the camera."
        Enable-Camera
    }
} catch {
    Write-Output "Failed to get location: $_"
    Write-Output "Defaulting to enabling the camera."
    Enable-Camera
}
