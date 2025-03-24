# Create the registry key for disabling Microsoft Store (current user)
New-Item -Path "HKCU:\Software\Policies\Microsoft\Windows\CloudStore" -Force

# Set the DisableStoreApps value to 1 (current user)
Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\CloudStore" -Name "DisableStoreApps" -Value 1

# Create the registry key for disabling Microsoft Store (all users - requires admin rights)
New-Item -Path "HKLM:\Software\Policies\Microsoft\Windows\CloudStore" -Force

# Set the DisableStoreApps value to 1 (all users - requires admin rights)
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\CloudStore" -Name "DisableStoreApps" -Value 1
