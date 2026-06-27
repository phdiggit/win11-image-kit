Describe "User experience taskbar handler" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitUserExperienceHandlerReport.ps1")
        $script:ReadJson = {
            param([string]$Path)
            Get-Content -LiteralPath (Join-Path $script:RepoRoot $Path) -Raw -Encoding UTF8 | ConvertFrom-Json
        }
    }

    It "keeps taskbar current-user restore as manual checklist" {
        $plan = ConvertTo-KitTaskbarPlan -InputObject (& $script:ReadJson "tests\fixtures\user-experience\handlers\taskbar\current-user-manual-checklist.json")

        Assert-KitEqual $plan.status "manual"
        Assert-KitEqual $plan.executed $false
    }

    It "blocks registry writes and requested apply" {
        foreach ($path in @(
            "tests\fixtures\user-experience\handlers\taskbar\registry-write-blocked.json",
            "tests\fixtures\user-experience\handlers\taskbar\requested-apply-blocked.json"
        )) {
            $plan = ConvertTo-KitTaskbarPlan -InputObject (& $script:ReadJson $path)
            Assert-KitEqual $plan.status "blocked"
            Assert-KitEqual $plan.executed $false
        }
    }
}
