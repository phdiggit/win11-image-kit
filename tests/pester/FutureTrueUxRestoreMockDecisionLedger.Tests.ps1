Describe "Future true UX restore mock decision ledger" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreMockReviewDrillReport.ps1")
    }

    It "keeps the mock decision ledger out of quality gates and archived docs" {
        $qualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual (@($qualityGates.gates.id) -contains "future-true-ux-mock-decision-ledger") $false
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\01-mock-review")) $false
    }

    It "still emits execute-ready-blocked report data without allowing execution" {
        $ledger = @(New-FutureTrueUxRestoreMockDecisionLedger -Scope "current-user")

        Assert-KitEqual (@($ledger.stage) -contains "execute-ready-blocked") $true
        foreach ($entry in $ledger) {
            Assert-KitEqual $entry.executionFlags.authorizationApproved $false
            Assert-KitEqual $entry.executionFlags.executionApproved $false
            Assert-KitEqual $entry.executionFlags.executeReady $false
            Assert-KitEqual $entry.executionFlags.trueExecution $false
            Assert-KitEqual $entry.executionFlags.mutationCount 0
        }
    }
}
