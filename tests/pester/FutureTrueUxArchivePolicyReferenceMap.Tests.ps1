Describe "Future True UX archive policy reference map" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\110-future-true-ux-archive-policy-reference-map.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
        $script:QualityGatePolicy = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\109-future-true-ux-quality-gate-governance.md") -Raw -Encoding UTF8
    }

    It "records the post-move archive policy and required categories" {
        Assert-KitEqual (Test-Path -LiteralPath $script:DocPath) $true
        Assert-KitMatch $script:Doc 'Status:\s*`future-true-ux-archive-policy-reference-map`'
        foreach ($term in @(
            "Canonical active",
            "Active safety guardrail",
            "Archived historical stage evidence",
            "Delete candidates",
            "Current Archive Maintenance Procedure"
        )) {
            Assert-KitMatch $script:Doc ([regex]::Escape($term))
        }
    }

    It "covers every Future True UX quality gate ID from the governance policy" {
        $gateIds = @([regex]::Matches($script:QualityGatePolicy, '`(future-true-ux[^`]+)`') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -ne "future-true-ux-quality-gate-governance" -and $_ -notmatch '[*<>]' } | Sort-Object -Unique)
        Assert-KitEqual ($gateIds.Count -gt 0) $true
        foreach ($gateId in $gateIds) {
            Assert-KitMatch $script:Doc ([regex]::Escape('`' + $gateId + '`'))
        }
    }

    It "keeps Issue 19 and true execution boundaries closed" {
        Assert-KitMatch $script:Doc "Refs #19"
        Assert-KitNotMatch $script:Doc "(?i)\b(fixes|closes|resolves)\s+#19\b"
        Assert-KitMatch $script:Doc '\| `authorizationApproved` \| `false` \|'
        Assert-KitMatch $script:Doc '\| `executionApproved` \| `false` \|'
        Assert-KitMatch $script:Doc '\| `executeReady` \| `false` \|'
        Assert-KitMatch $script:Doc '\| `trueExecution` \| `false` \|'
        Assert-KitMatch $script:Doc '\| `mutationCount` \| `0` \|'
        Assert-KitNotMatch $script:Doc "authorizationApproved\s*=\s*true"
        Assert-KitNotMatch $script:Doc "executionApproved\s*=\s*true"
        Assert-KitNotMatch $script:Doc "executeReady\s*=\s*true"
        Assert-KitNotMatch $script:Doc "trueExecution\s*=\s*true"
    }

    It "documents archived stage paths and former root paths" {
        foreach ($path in @(
            "docs/archive/future-true-ux-restore/01-mock-review/80-future-true-ux-restore-mock-review-packet-drill.md",
            "docs/archive/future-true-ux-restore/01-mock-review/82-future-true-ux-restore-mock-decision-ledger.md",
            "docs/archive/future-true-ux-restore/04-packet-preview/92-future-true-ux-restore-integrated-authorization-packet-preview.md",
            "docs/archive/future-true-ux-restore/05-human-handoff/97-future-true-ux-restore-human-authorization-handoff.md",
            "docs/archive/future-true-ux-restore/06-no-execution-audit/102-future-true-ux-restore-end-to-end-no-execution-readiness-audit.md",
            "docs/archive/future-true-ux-restore/06-no-execution-audit/105-future-true-ux-restore-no-execution-stop-line.md"
        )) {
            Assert-KitMatch $script:Doc ([regex]::Escape('`' + $path + '`'))
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot ($path -replace '/', '\'))) $true
        }

        Assert-KitMatch $script:Doc ([regex]::Escape('`docs/80-future-true-ux-restore-mock-review-packet-drill.md`'))
        Assert-KitMatch $script:Doc ([regex]::Escape('`docs/105-future-true-ux-restore-no-execution-stop-line.md`'))
        Assert-KitMatch $script:Doc '\| Delete candidates \| None \|'
    }
}
