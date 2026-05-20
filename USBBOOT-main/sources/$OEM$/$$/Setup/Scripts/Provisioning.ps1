# Enable Logging
Start-Transcript -Path "C:\Windows\Temp\ProvisioningLog.txt" -Append

$branding  = "yourcompanyname"

# Display Progress UI
$progress = @{Activity="Provisioning Windows..."; Status="Initializing..."; PercentComplete=0}
Write-Progress @progress

# -------------------
# Step 1: Branding
# -------------------
$progress.Status = "Applying Branding..."
$progress.PercentComplete = 5
Write-Progress @progress

try {
    $brandImage = "C:\Branding\kingsmakers-logo.png"
    if (-not (Test-Path "C:\Branding")) {
        New-Item -Path "C:\Branding" -ItemType Directory -Force | Out-Null
    }
    
    $usbDrive = (Get-WmiObject Win32_Volume | Where-Object { $_.DriveType -eq 2 -and $_.Label -eq "WINSETUP" } | Select-Object -First 1).DriveLetter
    if ($usbDrive) {
        $brandSource = "$($usbDrive)\Branding\kingsmakers-logo.png"
        if (Test-Path $brandSource) {
            Copy-Item $brandSource -Destination $brandImage -Force -ErrorAction Stop
            Write-Host "Branding applied successfully."
        } else {
            Write-Host "Warning: Branding file not found at $brandSource"
        }
    } else {
        Write-Host "Warning: USB drive not found. Skipping branding."
    }
} catch {
    Write-Host "Error applying branding: $($_.Exception.Message)"
}

# -------------------
# Step 2: Create Local Admin User
# -------------------
$progress.Status = "Creating Local Admin User..."
$progress.PercentComplete = 10
Write-Progress @progress

try {
    $Username = "admin"
    $Password = ConvertTo-SecureString "" -AsPlainText -Force
    
    # Check if user already exists
    $userExists = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
    if (-not $userExists) {
        New-LocalUser -Name $Username -Password $Password -FullName "Admin Account" -Description "Local Admin" -ErrorAction Stop
        Add-LocalGroupMember -Group "Administrators" -Member $Username -ErrorAction Stop
        Write-Host "Local admin user created successfully."
    } else {
        Write-Host "Admin user already exists. Skipping creation."
    }
} catch {
    Write-Host "Error creating admin user: $($_.Exception.Message)"
}

# -------------------
# Step 3: Set Date, Time, Language, and Keyboard
# -------------------
$progress.Status = "Setting Date, Time, Language..."
$progress.PercentComplete = 20
Write-Progress @progress

try {
    Write-Host "Setting timezone to Arab Standard Time..."
    tzutil /s "Arab Standard Time"
    Write-Host "Setting language and keyboard to US..."
    Set-WinUserLanguageList -LanguageList en-US -Force -ErrorAction Stop
    Write-Host "Date, time, and language configured."
} catch {
    Write-Host "Warning: Error setting date/time/language: $($_.Exception.Message)"
}

# -------------------
# Step 4: Install Applications
# -------------------
$progress.Status = "Installing Applications..."
$progress.PercentComplete = 30
Write-Progress @progress

$apps = @(
    "C:\Apps\AdobeReader.exe",
    "C:\Apps\ChromeEnterprise.msi",
    "C:\Apps\WinRAR.exe"
)

foreach ($app in $apps) {
    if (Test-Path $app) {
        try {
            $progress.Status = "Installing $([System.IO.Path]::GetFileName($app))..."
            Write-Progress @progress
            
            if ($app -match "\.msi$") {
                Start-Process "msiexec.exe" -ArgumentList "/i `"$app`" /qn /norestart" -Wait -ErrorAction Stop
            } elseif ($app -match "\.exe$") {
                Start-Process $app -ArgumentList "/silent /norestart" -Wait -ErrorAction Stop
            }
            Write-Host "Installed: $app"
        } catch {
            Write-Host "Error installing $app : $($_.Exception.Message)"
        }
    } else {
        Write-Host "Warning: App not found at $app. Skipping."
    }
}
Write-Host "Application installation completed."

# -------------------
# Step 5: Install Microsoft Office
# -------------------
$progress.Status = "Installing Microsoft Office..."
$progress.PercentComplete = 50
Write-Progress @progress

try {
    $officePath = "C:\Office"
    if (!(Test-Path $officePath)) {
        New-Item -Path $officePath -ItemType Directory -Force | Out-Null
    }
    
    $usbDrive = (Get-WmiObject Win32_Volume | Where-Object { $_.DriveType -eq 2 } | Select-Object -First 1).DriveLetter
    if ($usbDrive -and (Test-Path "$($usbDrive)\Office")) {
        Copy-Item "$($usbDrive)\Office\*" -Destination $officePath -Recurse -Force -ErrorAction Stop
        
        if (Test-Path "$officePath\setup.exe" -and (Test-Path "$officePath\configuration.xml")) {
            Start-Process "$officePath\setup.exe" -ArgumentList "/configure `"$officePath\configuration.xml`"" -Wait -ErrorAction Stop
            Write-Host "Microsoft Office installed successfully."
        } else {
            Write-Host "Warning: Office setup.exe or configuration.xml not found. Skipping Office installation."
        }
    } else {
        Write-Host "Warning: USB drive or Office folder not found. Skipping Office installation."
    }
} catch {
    Write-Host "Error installing Office: $($_.Exception.Message)"
}

# -------------------
# Step 6: Apply Privacy Settings
# -------------------
$progress.Status = "Applying Privacy Settings..."
$progress.PercentComplete = 70
Write-Progress @progress

try {
    $privacyKeys = @(
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection",
        "HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
    )
    
    foreach ($key in $privacyKeys) {
        try {
            if (!(Test-Path $key)) { 
                New-Item -Path $key -Force | Out-Null
            }
            New-ItemProperty -Path $key -Name "Enabled" -Value 0 -PropertyType DWORD -Force | Out-Null
        } catch {
            Write-Host "Warning: Could not set $key : $($_.Exception.Message)"
        }
    }
    Write-Host "Privacy settings disabled."
} catch {
    Write-Host "Error applying privacy settings: $($_.Exception.Message)"
}

# -------------------
# Step 7: Finalizing Setup
# -------------------
$progress.Status = "Finalizing Setup..."
$progress.PercentComplete = 90
Write-Progress @progress

try {
    Write-Host "Applying group policies..."
    gpupdate /force 2>&1 | Out-Null
    Write-Host "Group policies updated."
} catch {
    Write-Host "Warning: Error updating group policies: $($_.Exception.Message)"
}

Write-Host "Provisioning Completed Successfully!"
$progress.Status = "Completed!"
$progress.PercentComplete = 100
Write-Progress @progress -Completed

Write-Host "Device is ready for deployment."
Stop-Transcript
