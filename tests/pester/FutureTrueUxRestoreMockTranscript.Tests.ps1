Describe "Future true UX restore mock transcript" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreMockReviewDrillReport.ps1")
    }

    It "keeps mock transcript archive docs pruned from the resident worktree" {
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\01-mock-review")) $false
    }

    It "emits a transcript with complete checklist and not-approved execution decision" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $request = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\mock-review\current-user-complete-packet.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $report = New-FutureTrueUxRestoreMockReviewDrillReport -Manifest $manifest -Request $request -RepoRoot $script:RepoRoot

        Assert-KitEqual $report.transcript.reviewerRole "maintainer-reviewer-fixture"
        Assert-KitEqual $report.transcript.reviewDecision "authorization-review-ready"
        Assert-KitEqual $report.transcript.executionDecision "not-approved"
        Assert-KitMatch $report.transcript.warning "not execution approval"
        Assert-KitEqual $report.transcript.checklist.oneScopeOnly $true
        Assert-KitEqual $report.transcript.checklist.evidencePacketComplete $true
        Assert-KitEqual $report.transcript.checklist.noExecuteReady $true
    }
}
