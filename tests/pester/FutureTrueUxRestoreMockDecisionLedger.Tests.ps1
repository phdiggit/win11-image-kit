Describe "Future true UX restore mock decision ledger prune" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "keeps the mock decision ledger out of resident gates, docs, and helpers" {
        $qualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual (@($qualityGates.gates.id) -contains "future-true-ux-mock-decision-ledger") $false
        Assert-KitEqual (@($qualityGates.gates.id) -contains "future-true-ux-mock-review-drill") $false
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\01-mock-review")) $false
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreMockReviewDrillReport.ps1")) $false
    }

    It "keeps no mock-review fixture family resident" {
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\mock-review")) $false
    }
}
