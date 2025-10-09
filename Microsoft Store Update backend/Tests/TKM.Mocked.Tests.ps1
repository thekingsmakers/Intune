## Requires Pester

Import-Module 'c:\Users\oosman\Pictures\Microsoft Store Update backend\TKM-Store-Apps-Update.psm1' -Force

Describe 'TKM mocked behaviors' {
    Context 'DryRun path (mocking Start-Process)' {
        It 'DryRun returns success and does not call Start-Process' {
            $dummy = [PSCustomObject]@{ PackageFamilyName = 'Contoso.App_8wekyb3d8bbwe' }

            # Mock Start-Process so it would throw if called
            Mock -CommandName Start-Process { throw 'Start-Process should not be called during DryRun' }

            $res = Invoke-TKMUpdateStoreApp -App $dummy -DryRun
            $res.Success | Should Be $true
            Assert-MockCalled -CommandName Start-Process -Times 0
        }
    }

    Context 'winget missing fallback' {
        It 'When winget is missing, function returns message about no mechanism' {
            $dummy = [PSCustomObject]@{ PackageFamilyName = 'Contoso.App_8wekyb3d8bbwe' }

            # Mock Get-Command to simulate missing winget
            Mock -CommandName Get-Command { return $null }

            $res = Invoke-TKMUpdateStoreApp -App $dummy
            $res.Success | Should Be $false
            $res.Message | Should Match 'No update mechanism'
        }
    }
}
