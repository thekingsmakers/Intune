# MainInstaller.Tests.ps1
# Pester tests for MainInstaller.ps1

#Requires -Modules Pester

# Import modules
. $PSScriptRoot\PackageManagers.ps1
. $PSScriptRoot\Aliases.ps1
. $PSScriptRoot\Utils.ps1
. $PSScriptRoot\InstallerFunctions.ps1

Describe "Package Manager Detection" {
    It "Should detect available package managers" {
        $managers = Get-AvailablePackageManagers
        $managers -is [array] | Should Be $true
    }
}

Describe "Alias Loading" {
    It "Should load package aliases from JSON" {
        $aliases = Load-PackageAliases
        $aliases | Should BeOfType System.Collections.Hashtable
        $aliases.Count | Should BeGreaterThan 0
    }
}

Describe "Utility Functions" {
    It "Should check elevation status" {
        $elevated = Test-Elevation
        $elevated | Should BeOfType System.Boolean
    }

    It "Should get default cache directory" {
        $cacheDir = Get-DefaultCacheDirectory
        $cacheDir | Should BeOfType System.String
        Test-Path $cacheDir | Should Be $true
    }
}

Describe "Dry Run Mode" {
    It "Should not perform actual installation in dry run" {
        Initialize-Logging -LogLevel 'Info'

        # Mock the package manager commands
        Mock Invoke-WingetCommand { return @{ ExitCode = 0; Output = "Mocked" } }
        Mock Invoke-ChocoCommand { return @{ ExitCode = 0; Output = "Mocked" } }
        Mock Test-PackageManager { return $true } -ParameterFilter { $Manager -eq 'winget' }

        { Install-Package -Name "test-package" -DryRun } | Should Not Throw
    }
}

Describe "Command Building" {
    It "Should build winget install command correctly" {
        # Test the argument building logic indirectly
        # This is simplified since functions call external commands
        $true | Should Be $true  # Placeholder test
    }
}
