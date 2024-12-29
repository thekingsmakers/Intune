# URLs to the raw scripts on GitHub
$script1Url = "https://github.com/thekingsmakers/Intune/blob/eb1fb857320d3c530b25efaa246480ce931129f8/Brave%20Browser/BraveDetection.ps1"
$script2Url = "https://github.com/thekingsmakers/Intune/blob/c5c7f5d1fe67627308750f1bda9d1c810bef7344/Brave%20Browser/BraveUninstall.ps1"

# Run the first script
Invoke-Expression (Invoke-WebRequest -Uri $script1Url).Content
$exitCode = $LASTEXITCODE

# Check the exit code and run the second script if necessary
if ($exitCode -eq 1) {
    Write-Output "Running second script..."
    Invoke-Expression (Invoke-WebRequest -Uri $script2Url).Content
} else {
    Write-Output "No traces found."
}
