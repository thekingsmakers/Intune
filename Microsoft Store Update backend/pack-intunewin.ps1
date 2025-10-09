<#
pack-intunewin.ps1
Helper to create a .intunewin package using the Microsoft Win32 Content Prep Tool.
Usage:
  .\pack-intunewin.ps1 -SourceFolder .\payload -SetupFile 'TKM-Store-Apps-Update.ps1' -OutputDir .\out

Requirements:
- Microsoft Win32 Content Prep Tool (IntuneWinAppUtil.exe) must be on PATH or in the same folder as this script.
- Run in an elevated session when packaging for system-level install.

This script does not upload to Intune — it only creates the .intunewin file.
#>

param(
    [Parameter(Mandatory=$true)] [string] $SourceFolder,
    [Parameter(Mandatory=$true)] [string] $SetupFile,
    [string] $OutputDir = ".\out",
    [string] $ToolPath = ''
)

function Find-IntuneWinTool {
    param([string] $ToolPath)
    if ($ToolPath -and (Test-Path $ToolPath)) { return (Resolve-Path $ToolPath).Path }
    $exe = 'IntuneWinAppUtil.exe'
    $local = Join-Path -Path (Get-Location) -ChildPath $exe
    if (Test-Path $local) { return $local }
    $p = Get-Command $exe -ErrorAction SilentlyContinue
    if ($p) { return $p.Source }
    return $null
}

$tool = Find-IntuneWinTool -ToolPath $ToolPath
if (-not $tool) {
    Write-Error "Intune Win32 Content Prep Tool (IntuneWinAppUtil.exe) not found. Download from https://learn.microsoft.com/mem/intune/apps/apps-win32-app-management and place on PATH or next to this script."
    exit 2
}

if (-not (Test-Path $SourceFolder)) { Write-Error "Source folder '$SourceFolder' not found"; exit 3 }
if (-not (Test-Path (Join-Path $SourceFolder $SetupFile))) { Write-Error "Setup file '$SetupFile' not found inside source folder"; exit 4 }

if (-not (Test-Path $OutputDir)) { New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null }

# Build the command line
$cmd = "`"$tool`" -c `"$SourceFolder`" -s `"$SetupFile`" -o `"$OutputDir`""
Write-Output "Running: $cmd"
& $tool -c $SourceFolder -s $SetupFile -o $OutputDir

if ($LASTEXITCODE -eq 0) { Write-Output "Packaging succeeded. Check $OutputDir for the .intunewin file."; exit 0 } else { Write-Error "Packaging failed with exit code $LASTEXITCODE"; exit $LASTEXITCODE }
