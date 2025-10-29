# Test Bootstrap with Local Files
# Temporarily modify URLs to point to local files for testing

param(
    [string]$TestCommand = "help"
)

# Temporarily modify bootstrap for local testing
$bootstrapContent = Get-Content "bootstrap.ps1" -Raw
$bootstrapContent = $bootstrapContent -replace 'https://raw\.githubusercontent\.com/[^/]+/[^/]+/[^/]+/', 'file:///d:/Projects/WinAppInstaller/'

# Save modified version for testing
$testBootstrap = "test-bootstrap.ps1"
$bootstrapContent | Out-File -FilePath $testBootstrap -Encoding UTF8

Write-Host "Created test bootstrap: $testBootstrap"
Write-Host "Run: .\test-bootstrap.ps1 -$TestCommand"
