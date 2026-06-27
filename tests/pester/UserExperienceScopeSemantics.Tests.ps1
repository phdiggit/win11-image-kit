Describe "User experience scope semantics" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitUserExperienceRestoreReport.ps1")

        $script:ReadJson = {
            param([string]$Path)
            Get-Content -LiteralPath (Join-Path $script:RepoRoot $Path) -Raw -Encoding UTF8 | ConvertFrom-Json
        }
    }

    It "keeps default-user, current-user, offline-image, and machine scopes distinct" {
        foreach ($path in @(
            "tests\fixtures\user-experience\scope-semantics\default-user-vs-current-user.json",
            "tests\fixtures\user-experience\scope-semantics\offline-image-vs-current-machine.json"
        )) {
            $result = Test-KitUserExperienceScopeSemantics -InputObject (& $script:ReadJson $path)
            Assert-KitEqual $result.status "passed"
            Assert-KitEqual $result.scopeMismatchCount 0
            Assert-KitEqual $result.userConfigurationConfirmed $false
        }
    }

    It "blocks Default Profile claims that current user changed" {
        $result = Test-KitUserExperienceScopeSemantics -InputObject (& $script:ReadJson "tests\fixtures\user-experience\scope-semantics\default-profile-claims-current-user.json")

        Assert-KitEqual $result.status "failed"
        if ($result.scopeMismatchCount -lt 1) {
            throw "Expected scopeMismatchCount to be greater than zero."
        }
    }
}
