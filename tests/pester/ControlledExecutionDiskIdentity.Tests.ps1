Describe "Controlled execution disk identity fixtures" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitControlledExecutionReport.ps1")
    }

    It "passes the matched disk identity fixture" {
        $input = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\disk-identity\matched.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $plan = ConvertTo-KitDiskIdentityPlan -InputObject $input

        Assert-KitEqual $plan.status "matched"
        Assert-KitEqual $plan.mismatchCount 0
        Assert-KitEqual $plan.target.serial "SAMPLE-DISK-SERIAL-001"
    }

    It "blocks disk serial, size, and number mismatches" {
        foreach ($path in @(
            "tests\fixtures\controlled-execution\disk-identity\serial-mismatch.json",
            "tests\fixtures\controlled-execution\disk-identity\size-mismatch.json",
            "tests\fixtures\controlled-execution\disk-identity\disk-number-mismatch.json"
        )) {
            $input = Get-Content -LiteralPath (Join-Path $script:RepoRoot $path) -Raw -Encoding UTF8 | ConvertFrom-Json
            $plan = ConvertTo-KitDiskIdentityPlan -InputObject $input

            Assert-KitEqual $plan.status "blocked"
            if ($plan.mismatchCount -lt 1) {
                throw "Expected disk identity mismatch for $path."
            }
        }
    }
}
