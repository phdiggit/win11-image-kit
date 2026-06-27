Describe "User experience verification plan" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitUserExperienceRestoreReport.ps1")

        $script:ReadJson = {
            param([string]$Path)
            Get-Content -LiteralPath (Join-Path $script:RepoRoot $Path) -Raw -Encoding UTF8 | ConvertFrom-Json
        }
    }

    It "keeps baseline verification planned and not confirmed" {
        foreach ($path in @(
            "tests\fixtures\user-experience\verification\default-apps-planned.json",
            "tests\fixtures\user-experience\verification\start-menu-planned.json"
        )) {
            $result = New-KitUserExperienceVerificationPlan -InputObject (& $script:ReadJson $path)
            Assert-KitEqual $result.status "planned"
            Assert-KitEqual $result.commandExitCodeSufficient $false
            Assert-KitEqual $result.userConfigurationConfirmed $false
            Assert-KitEqual $result.trueExecution $false
        }
    }

    It "blocks exit-code-only and false user configuration success claims" {
        $cases = @(
            @{ Path = "tests\fixtures\user-experience\verification\exit-code-claims-success.json"; Count = "exitCodeOnlySuccessClaimCount" },
            @{ Path = "tests\fixtures\user-experience\verification\user-config-confirmed-without-real-evidence.json"; Count = "userConfigurationFalseClaimCount" }
        )

        foreach ($case in $cases) {
            $result = New-KitUserExperienceVerificationPlan -InputObject (& $script:ReadJson $case.Path)
            Assert-KitEqual $result.status "blocked"
            if ($result.($case.Count) -lt 1) {
                throw "Expected $($case.Count) to be greater than zero."
            }
        }
    }
}
