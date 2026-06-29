Describe "Future true UX restore mock decision ledger" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreMockReviewDrillReport.ps1")
    }

    It "documents required mock ledger states and frozen execution flags" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\01-mock-review\82-future-true-ux-restore-mock-decision-ledger.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc 'Status:\s*`mock-decision-ledger`'
        foreach ($stage in @("received", "packet-complete", "authorization-review-ready", "execute-ready-blocked", "true-execution-blocked")) {
            Assert-KitMatch $doc ([regex]::Escape($stage))
        }
        Assert-KitMatch $doc "AuthorizationApproved=false"
        Assert-KitMatch $doc "ExecutionApproved=false"
        Assert-KitMatch $doc "ExecuteReady=false"
        Assert-KitMatch $doc "trueExecution=false"
        Assert-KitMatch $doc "mutationCount=0"
    }

    It "emits execute-ready-blocked without allowing execution" {
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
