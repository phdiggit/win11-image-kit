Describe "Future true UX restore mock transcript prune" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "keeps mock transcript archive docs pruned from the resident worktree" {
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\01-mock-review")) $false
    }

    It "keeps mock transcript fixtures and helper pruned" {
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\mock-review")) $false
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreMockReviewDrillReport.ps1")) $false
    }
}
