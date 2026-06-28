Describe "Future true UX restore mock transcript" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreMockReviewDrillReport.ps1")
    }

    It "documents mock maintainer review without execution approval" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\81-future-true-ux-restore-mock-maintainer-review-transcript.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc 'Status:\s*`mock-review-transcript`'
        Assert-KitMatch $doc "maintainer-reviewer-fixture"
        Assert-KitMatch $doc "authorization-review-ready"
        Assert-KitMatch $doc "not-approved"
        Assert-KitMatch $doc "Review-ready is not execution approval"
        Assert-KitNotMatch $doc "(?i)\b(fixes|closes|resolves)\s+#18\b"
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
