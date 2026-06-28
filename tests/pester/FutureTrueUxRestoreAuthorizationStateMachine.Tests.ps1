Describe "Future true UX restore authorization state machine" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "documents request, review, evidence packet, and state machine drafts" {
        $docs = @(
            @{ Path = "docs\76-future-true-ux-restore-unified-authorization-request.md"; Status = "authorization-request-draft" },
            @{ Path = "docs\77-future-true-ux-restore-maintainer-review-checkpoint.md"; Status = "review-checkpoint-draft" },
            @{ Path = "docs\78-future-true-ux-restore-evidence-packet-contract.md"; Status = "evidence-packet-draft" },
            @{ Path = "docs\79-future-true-ux-restore-authorization-state-machine.md"; Status = "authorization-state-machine" },
            @{ Path = "docs\80-future-true-ux-restore-mock-review-packet-drill.md"; Status = "mock-review-drill" },
            @{ Path = "docs\81-future-true-ux-restore-mock-maintainer-review-transcript.md"; Status = "mock-review-transcript" },
            @{ Path = "docs\82-future-true-ux-restore-mock-decision-ledger.md"; Status = "mock-decision-ledger" },
            @{ Path = "docs\83-future-true-ux-restore-mock-drill-lessons.md"; Status = "mock-drill-lessons" }
        )

        foreach ($docInfo in $docs) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $docInfo.Path) -Raw -Encoding UTF8
            Assert-KitMatch $text ('Status:\s*`{0}`' -f [regex]::Escape($docInfo.Status))
            Assert-KitMatch $text "AuthorizationApproved=false"
            Assert-KitMatch $text "ExecutionApproved=false"
            Assert-KitNotMatch $text "(?i)\b(fixes|closes|resolves)\s+#18\b"
        }
    }

    It "keeps execute-ready out of allowed review decisions" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $schema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\future-true-ux-restore-authorization.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $section = $manifest.authorizationReview

        Assert-KitEqual $section.enabled $true
        Assert-KitEqual $section.authorizationApproved $false
        Assert-KitEqual $section.executionApproved $false
        Assert-KitEqual $section.executeReady $false
        Assert-KitEqual (@($section.allowedReviewDecisions) -contains "authorization-review-ready") $true
        Assert-KitEqual (@($section.allowedReviewDecisions) -contains "execute-ready") $false
        Assert-KitEqual (@($section.forbiddenReviewDecisions) -contains "execute-ready") $true
        Assert-KitEqual (@($schema.'$defs'.reviewDecision.enum) -contains "authorization-review-ready") $true
        Assert-KitEqual (@($schema.'$defs'.reviewDecision.enum) -contains "execute-ready") $false
    }

    It "keeps mock review drill decisions blocked from execute-ready and completion" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $schema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\future-true-ux-restore-authorization.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $section = $manifest.mockReviewDrill

        Assert-KitEqual $section.enabled $true
        Assert-KitEqual $section.mode "mock-review-drill"
        Assert-KitEqual $section.defaultScope "current-user"
        Assert-KitEqual $section.authorizationApproved $false
        Assert-KitEqual $section.executionApproved $false
        Assert-KitEqual $section.executeReady $false
        Assert-KitEqual $section.trueExecution $false
        Assert-KitEqual $section.mutationCount 0
        foreach ($decision in @("execute-ready", "executed", "completed")) {
            Assert-KitEqual (@($section.allowedMockDecisions) -contains $decision) $false
            Assert-KitEqual (@($section.forbiddenMockDecisions) -contains $decision) $true
        }
        Assert-KitEqual ($null -ne $schema.'$defs'.mockReviewDrill) $true
    }
}
