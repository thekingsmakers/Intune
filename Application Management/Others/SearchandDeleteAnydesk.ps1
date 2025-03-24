# Define the file name
$fileName = "anydesk.exe"

# Function to search and delete the file
function DeleteFile ($path, $file) {
    # Search for the file in the directory and subdirectories
    $foundFiles = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Where-Object {$_.Name -eq $file}
    
    # Delete found files
    foreach ($foundFile in $foundFiles) {
        Remove-Item -Path $foundFile.FullName -Force
        Write-Host "Deleted $($foundFile.FullName)"
    }
}

# Loop through each user profile for C:\Users\
$userProfiles = Get-ChildItem -Path "C:\Users" -Directory

foreach ($userProfile in $userProfiles) {
    DeleteFile $userProfile.FullName $fileName
}

# Now search D:\ drive
DeleteFile "D:\" $fileName
