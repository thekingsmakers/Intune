# URLs to the raw scripts on GitHub
$script1Url = "https://raw.githubusercontent.com/user/repo/branch/script1.ps1"
$script2Url = "https://raw.githubusercontent.com/user/repo/branch/script2.ps1"

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
