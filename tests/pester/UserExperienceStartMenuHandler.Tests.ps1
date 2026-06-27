Describe "User experience Start menu handler" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitUserExperienceHandlerReport.ps1")
        $script:ReadJson = {
            param([string]$Path)
            Get-Content -LiteralPath (Join-Path $script:RepoRoot $Path) -Raw -Encoding UTF8 | ConvertFrom-Json
        }
    }

    It "plans default-user layout without claiming current-user success" {
        $plan = ConvertTo-KitStartMenuLayoutPlan -InputObject (& $script:ReadJson "tests\fixtures\user-experience\handlers\start-menu\default-user-layout-planned.json")

        Assert-KitEqual $plan.status "planned"
        Assert-KitEqual $plan.scope "default-user"
        Assert-KitEqual $plan.executed $false
    }

    It "keeps current-user layout as manual checklist" {
        $plan = ConvertTo-KitStartMenuLayoutPlan -InputObject (& $script:ReadJson "tests\fixtures\user-experience\handlers\start-menu\current-user-manual-checklist.json")

        Assert-KitEqual $plan.status "manual"
        Assert-KitEqual $plan.scope "current-user"
        Assert-KitEqual $plan.executed $false
    }

    It "blocks profile writes and requested apply" {
        foreach ($path in @(
            "tests\fixtures\user-experience\handlers\start-menu\profile-write-blocked.json",
            "tests\fixtures\user-experience\handlers\start-menu\requested-apply-blocked.json"
        )) {
            $plan = ConvertTo-KitStartMenuLayoutPlan -InputObject (& $script:ReadJson $path)
            Assert-KitEqual $plan.status "blocked"
            Assert-KitEqual $plan.executed $false
        }
    }
}
