<#
.SYNOPSIS
    Builds and packages the Windows deployment tool
.DESCRIPTION
    Compiles the solution, organizes files, and creates a distributable package
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Configuration = "Release",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\Dist"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Write-Status {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    $name = [System.IO.Path]::GetRandomFileName()
    return New-Item -ItemType Directory -Path (Join-Path $parent $name)
}

function Test-DotNetSDK {
    try {
        # Execute dotnet --version directly since we only need the version
        $version = & dotnet --version
        Write-Status "Found .NET SDK version $version"
        return $true
    }
    catch {
        Write-Error ".NET SDK not found. Please install the .NET SDK"
        return $false
    }
}

function Build-Solution {
    Write-Status "Building solution..."
    
    try {
        dotnet restore $projectRoot\ImageDeployer.sln
        if ($LASTEXITCODE -ne 0) { throw "Restore failed" }
        
        dotnet build $projectRoot\ImageDeployer.sln --configuration $Configuration
        if ($LASTEXITCODE -ne 0) { throw "Build failed" }
        
        Write-Status "Build completed successfully" -ForegroundColor Green
    }
    catch {
        throw "Build failed: $_"
    }
}

function Copy-RequiredFiles {
    param([string]$TempDir)
    
    Write-Status "Copying files to staging directory..."
    
    # Create directory structure
    $dirs = @(
        "Deployment\Config",
        "Deployment\Scripts",
        "Deployment\Logs",
        "Deployment\Installers",
        "SetupGUI",
        "Tools"
    )
    
    foreach ($dir in $dirs) {
        New-Item -ItemType Directory -Path (Join-Path $TempDir $dir) -Force | Out-Null
    }
    
    # Copy deployment files
    Copy-Item "$projectRoot\Deployment\Scripts\*" "$TempDir\Deployment\Scripts"
    Copy-Item "$projectRoot\Deployment\Config\deploy-config.xml" "$TempDir\Deployment\Config"
    
    # Copy tools
    Copy-Item "$projectRoot\Tools\*.ps1" "$TempDir\Tools"
    
    # Copy GUI applications
    Copy-Item "$projectRoot\SetupGUI\bin\$Configuration\net6.0-windows\*" "$TempDir\SetupGUI" -Recurse
    
    # Copy documentation
    Copy-Item "$projectRoot\README.md" "$TempDir"
    
    # Copy autorun and configuration
    Copy-Item "$projectRoot\autorun.inf" "$TempDir"
}

function New-DistributionPackage {
    param([string]$TempDir)
    
    Write-Status "Creating distribution package..."
    
    # Create output directory if it doesn't exist
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    # Create version info file
    $versionInfo = @{
        Version = "1.0.0"
        BuildTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Configuration = $Configuration
    }
    
    $versionInfo | ConvertTo-Json | Set-Content (Join-Path $TempDir "version.json")
    
    # Create ZIP package
    $packagePath = Join-Path $OutputPath "WindowsDeploymentTool.zip"
    if (Test-Path $packagePath) {
        Remove-Item $packagePath -Force
    }
    
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($TempDir, $packagePath)
    
    return $packagePath
}

function Test-Package {
    param([string]$PackagePath)
    
    Write-Status "Verifying package..."
    
    $tempExtractPath = New-TemporaryDirectory
    
    try {
        # Extract package
        [System.IO.Compression.ZipFile]::ExtractToDirectory($PackagePath, $tempExtractPath)
        
        # Verify required files
        $requiredFiles = @(
            "autorun.inf",
            "README.md",
            "version.json",
            "Deployment\Config\deploy-config.xml",
            "Deployment\Scripts\Deploy-Windows.ps1",
            "SetupGUI\SetupGUI.exe",
            "Tools\Prepare-USB.ps1",
            "Tools\Monitor-Deployment.ps1",
            "Tools\Test-Requirements.ps1",
            "Tools\Rollback-Deployment.ps1"
        )
        
        $missingFiles = @()
        foreach ($file in $requiredFiles) {
            $path = Join-Path $tempExtractPath $file
            if (-not (Test-Path $path)) {
                $missingFiles += $file
            }
        }
        
        if ($missingFiles.Count -gt 0) {
            throw "Package verification failed. Missing files:`n" + ($missingFiles -join "`n")
        }
        
        Write-Status "Package verified successfully" -ForegroundColor Green
    }
    finally {
        Remove-Item -Path $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

try {
    Write-Host "Windows Deployment Tool - Build Package" -ForegroundColor Green
    Write-Host "====================================" -ForegroundColor Green
    
    # Check prerequisites
    if (-not (Test-DotNetSDK)) {
        exit 1
    }
    
    # Create temp directory
    $tempDir = New-TemporaryDirectory
    
    # Build solution
    Build-Solution
    
    # Copy files to temp directory
    Copy-RequiredFiles -TempDir $tempDir
    
    # Create package
    $packagePath = New-DistributionPackage -TempDir $tempDir
    
    # Test package
    Test-Package -PackagePath $packagePath
    
    Write-Host "`nPackage created successfully at: $packagePath" -ForegroundColor Green
    Write-Host "Size: $([math]::Round((Get-Item $packagePath).Length / 1MB, 2)) MB" -ForegroundColor Green
}
catch {
    Write-Error "Package creation failed: $_"
    exit 1
}
finally {
    if ($tempDir -and (Test-Path $tempDir)) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}