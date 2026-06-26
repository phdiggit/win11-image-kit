Describe "Controlled execution image metadata fixtures" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitControlledExecutionReport.ps1")
    }

    It "passes matched fixture image metadata" {
        $input = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\wim-image\matched.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $plan = ConvertTo-KitWimImagePlan -InputObject $input

        Assert-KitEqual $plan.status "matched"
        Assert-KitEqual $plan.failureCount 0
        Assert-KitEqual $plan.imagePath "fixture://install.wim"
    }

    It "blocks hash, index, and local path failures" {
        foreach ($path in @(
            "tests\fixtures\controlled-execution\wim-image\hash-mismatch.json",
            "tests\fixtures\controlled-execution\wim-image\index-mismatch.json",
            "tests\fixtures\controlled-execution\wim-image\local-private-path.json"
        )) {
            $input = Get-Content -LiteralPath (Join-Path $script:RepoRoot $path) -Raw -Encoding UTF8 | ConvertFrom-Json
            $plan = ConvertTo-KitWimImagePlan -InputObject $input

            Assert-KitEqual $plan.status "blocked"
            if ($plan.failureCount -lt 1) {
                throw "Expected image metadata failure for $path."
            }
        }
    }
}
