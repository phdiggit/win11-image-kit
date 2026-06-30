Describe "Future true UX restore authorization state machine" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "documents request, review, evidence packet, and state machine drafts" {
        $docs = @(
            @{ Path = "docs\archive\future-true-ux-restore\00-governance\76-future-true-ux-restore-unified-authorization-request.md"; Status = "authorization-request-draft" },
            @{ Path = "docs\archive\future-true-ux-restore\00-governance\77-future-true-ux-restore-maintainer-review-checkpoint.md"; Status = "review-checkpoint-draft" },
            @{ Path = "docs\archive\future-true-ux-restore\00-governance\78-future-true-ux-restore-evidence-packet-contract.md"; Status = "evidence-packet-draft" },
            @{ Path = "docs\archive\future-true-ux-restore\00-governance\79-future-true-ux-restore-authorization-state-machine.md"; Status = "authorization-state-machine" }
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

    It "keeps mock review drill pruned from current manifest and schema" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $schema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\future-true-ux-restore-authorization.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual ($manifest.PSObject.Properties.Name -contains "mockReviewDrill") $false
        Assert-KitEqual ($schema.'$defs'.PSObject.Properties.Name -contains "mockReviewDrill") $false
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "scripts\validate\Test-FutureTrueUxRestoreMockReviewDrill.ps1")) $true
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreMockReviewDrillReport.ps1")) $false
    }
}
