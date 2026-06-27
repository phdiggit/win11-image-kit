Describe "User experience default app handler" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitUserExperienceHandlerReport.ps1")
        $script:ReadJson = {
            param([string]$Path)
            Get-Content -LiteralPath (Join-Path $script:RepoRoot $Path) -Raw -Encoding UTF8 | ConvertFrom-Json
        }
    }

    It "plans default-user and offline-image handlers without execution" {
        foreach ($path in @(
            "tests\fixtures\user-experience\handlers\default-apps\default-user-planned.json",
            "tests\fixtures\user-experience\handlers\default-apps\offline-image-planned.json"
        )) {
            $plan = ConvertTo-KitDefaultAppAssociationPlan -InputObject (& $script:ReadJson $path)

            Assert-KitEqual $plan.status "planned"
            Assert-KitEqual $plan.executed $false
            Assert-KitEqual $plan.requestedApply $false
        }
    }

    It "keeps current-user default apps manual and not success evidence" {
        $plan = ConvertTo-KitDefaultAppAssociationPlan -InputObject (& $script:ReadJson "tests\fixtures\user-experience\handlers\default-apps\current-user-manual.json")

        Assert-KitEqual $plan.status "manual"
        Assert-KitEqual $plan.scope "current-user"
        Assert-KitEqual $plan.executed $false
    }

    It "blocks requested apply, missing ProgId, and false current-user claims" {
        $cases = @(
            @{ Path = "tests\fixtures\user-experience\handlers\default-apps\requested-apply-blocked.json"; Count = "requestedApplyBlockedCount" },
            @{ Path = "tests\fixtures\user-experience\handlers\default-apps\missing-required-progid.json"; Count = "missingCapabilityCount" },
            @{ Path = "tests\fixtures\user-experience\handlers\default-apps\scope-mismatch.json"; Count = "userConfigurationFalseClaimCount" }
        )

        foreach ($case in $cases) {
            $plan = ConvertTo-KitDefaultAppAssociationPlan -InputObject (& $script:ReadJson $case.Path)
            Assert-KitEqual $plan.status "blocked"
            if ([int]$plan.($case.Count) -lt 1) {
                throw "Expected $($case.Count) to be greater than zero."
            }
            Assert-KitEqual $plan.executed $false
        }
    }
}
