# Intune detection snippet - check presence of marker file or package version
param()

$marker = 'C:\ProgramData\TKM\TKM-Store-Apps-Update\last-success.txt'
if (Test-Path $marker) { exit 0 }

# Fallback check for a specific package
$pkg = Get-AppxPackage -Name *MSPaint* -ErrorAction SilentlyContinue
if ($pkg) { exit 0 } else { exit 1 }
