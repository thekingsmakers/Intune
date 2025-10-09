## Requires Pester

Import-Module 'c:\Users\oosman\Pictures\Microsoft Store Update backend\TKM-Store-Apps-Update.psm1' -Force

Describe 'TKM-Store-Apps-Update basic tests' {
    Context 'Discovery' {
        It 'Get-TKMInstalledStoreApps returns array or empty array' {
            $r = Get-TKMInstalledStoreApps
            $r | Should BeOfType 'System.Object'
        }
    }

    Context 'DryRun behavior' {
        It 'Invoke-TKMUpdateStoreApp DryRun does not throw and returns success' {
            $dummy = [PSCustomObject]@{ PackageFamilyName = 'Microsoft.MSPaint_8wekyb3d8bbwe' }
            $res = Invoke-TKMUpdateStoreApp -App $dummy -DryRun
            $res.Success | Should Be $true
        }
    }

    Context 'Module prereqs test' {
        It 'Test-TKMStoreAppUpdatePrereqs returns checks' {
            $checks = Test-TKMStoreAppUpdatePrereqs
            $checks | Should Not BeNullOrEmpty
        }
    }
}
