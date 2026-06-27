Describe "Issue 18 future true UX restore split" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\65-future-true-ux-restore-execution-split.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
    }

    It "requires explicit authorization and a real evidence model" {
        Assert-KitEqual (Test-Path -LiteralPath $script:DocPath) $true
        Assert-KitMatch $script:Doc 'Status:\s*`future-split`'
        Assert-KitMatch $script:Doc "explicit human authorization"
        Assert-KitMatch $script:Doc "target scope"
        Assert-KitMatch $script:Doc "rollback or backup"
        Assert-KitMatch $script:Doc "before state"
        Assert-KitMatch $script:Doc "after state"
        Assert-KitMatch $script:Doc "independent verification"
        Assert-KitMatch $script:Doc "Command exit code alone is not UX success evidence"
    }

    It "keeps true mutation disallowed until authorized" {
        foreach ($term in @(
            "registry writes",
            "profile writes",
            "Default User hive changes",
            "current-user default app mutation",
            "default app association import",
            "Start menu import",
            "taskbar mutation",
            "DISM default app import",
            "AppX query or mutation as success evidence",
            "network package lookup or download"
        )) {
            Assert-KitMatch $script:Doc ([regex]::Escape($term))
        }
    }

    It "keeps ready state scoped to report-only handoff" {
        Assert-KitMatch $script:Doc "current Issue #18 ready state must not be expanded into true mutation"
        Assert-KitMatch $script:Doc "Default User state is not current-user state"
        Assert-KitMatch $script:Doc "offline image is not the current machine"
        Assert-KitNotMatch $script:Doc "(?i)\b(fixes|closes|resolves)\s+#18\b"
    }

    It "keeps future current-user gate as dry-run only" {
        $docPath = Join-Path $script:RepoRoot "docs\69-future-true-ux-restore-current-user-dry-run-gate.md"
        $doc = Get-Content -LiteralPath $docPath -Raw -Encoding UTF8

        Assert-KitMatch $doc 'Status:\s*`current-user-dry-run-gate`'
        Assert-KitMatch $doc "AuthorizationApproved=false"
        Assert-KitMatch $doc "ExecutionApproved=false"
        Assert-KitMatch $doc "dry-run-ready"
        Assert-KitMatch $doc "cannot execute mutation"
    }

    It "keeps remaining scope gates as dry-run only" {
        $docs = @(
            @{ Path = "docs\72-future-true-ux-restore-default-user-dry-run-gate.md"; Status = "default-user-dry-run-gate"; Scope = "default-user" },
            @{ Path = "docs\73-future-true-ux-restore-offline-image-dry-run-gate.md"; Status = "offline-image-dry-run-gate"; Scope = "offline-image" },
            @{ Path = "docs\74-future-true-ux-restore-machine-dry-run-gate.md"; Status = "machine-dry-run-gate"; Scope = "machine" },
            @{ Path = "docs\75-future-true-ux-restore-scope-guard-matrix.md"; Status = "scope-guard-matrix"; Scope = "scope" }
        )

        foreach ($docInfo in $docs) {
            $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot $docInfo.Path) -Raw -Encoding UTF8
            Assert-KitMatch $doc ('Status:\s*`{0}`' -f [regex]::Escape($docInfo.Status))
            Assert-KitMatch $doc "AuthorizationApproved=false"
            Assert-KitMatch $doc "ExecutionApproved=false"
            Assert-KitNotMatch $doc "(?i)\b(fixes|closes|resolves)\s+#18\b"
        }
    }

    It "keeps authorization review workflow separate from Issue 18 closure" {
        $docs = @(
            @{ Path = "docs\76-future-true-ux-restore-unified-authorization-request.md"; Status = "authorization-request-draft" },
            @{ Path = "docs\77-future-true-ux-restore-maintainer-review-checkpoint.md"; Status = "review-checkpoint-draft" },
            @{ Path = "docs\78-future-true-ux-restore-evidence-packet-contract.md"; Status = "evidence-packet-draft" },
            @{ Path = "docs\79-future-true-ux-restore-authorization-state-machine.md"; Status = "authorization-state-machine" }
        )

        foreach ($docInfo in $docs) {
            $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot $docInfo.Path) -Raw -Encoding UTF8
            Assert-KitMatch $doc ('Status:\s*`{0}`' -f [regex]::Escape($docInfo.Status))
            Assert-KitMatch $doc "Refs #18"
            Assert-KitMatch $doc "AuthorizationApproved=false"
            Assert-KitMatch $doc "ExecutionApproved=false"
            Assert-KitNotMatch $doc "(?i)\b(fixes|closes|resolves)\s+#18\b"
        }
    }
}
