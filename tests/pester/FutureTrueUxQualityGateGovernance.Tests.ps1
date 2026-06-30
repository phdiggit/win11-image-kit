Describe "Future True UX quality gate governance" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "tests\pester\FutureTrueUxPesterHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\109-future-true-ux-quality-gate-governance.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
        $script:QualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:ExpectedFutureGateIds = @(
            "future-true-ux-restore-split",
            "future-true-ux-restore-authorization",
            "future-true-ux-restore-evidence-model",
            "future-true-ux-current-user-dry-run",
            "future-true-ux-scope-dry-run",
            "future-true-ux-scope-guard-matrix",
            "future-true-ux-execute-gate",
            "future-true-ux-authorization-review",
            "future-true-ux-evidence-packet",
            "future-true-ux-mock-review-drill",
            "future-true-ux-mock-decision-ledger",
            "future-true-ux-end-to-end-no-execution-readiness-audit",
            "future-true-ux-final-stop-line-handoff"
        )
    }

    It "documents every Future True UX gate in the intended order" {
        Assert-KitEqual (Test-Path -LiteralPath $script:DocPath) $true
        Assert-KitMatch $script:Doc 'Status:\s*`future-true-ux-quality-gate-governance`'
        Assert-KitMatch $script:Doc 'Canonical group name: `Future True UX Restore quality gates`'

        $previousIndex = -1
        foreach ($id in $script:ExpectedFutureGateIds) {
            $needle = '`' + $id + '`'
            Assert-KitMatch $script:Doc ([regex]::Escape($needle))
            $currentIndex = $script:Doc.IndexOf($needle, [StringComparison]::Ordinal)
            Assert-KitEqual ($currentIndex -gt $previousIndex) $true
            $previousIndex = $currentIndex
        }
    }

    It "keeps Future True UX gates contiguous and ordered in the manifest" {
        $ids = @($script:QualityGates.gates.id)
        $futureIndexes = @()
        for ($i = 0; $i -lt $ids.Count; $i++) {
            if ($ids[$i] -like "future-true-ux*") {
                $futureIndexes += $i
            }
        }

        Assert-KitEqual @($futureIndexes).Count @($script:ExpectedFutureGateIds).Count
        for ($i = 0; $i -lt $futureIndexes.Count; $i++) {
            Assert-KitEqual $ids[$futureIndexes[$i]] $script:ExpectedFutureGateIds[$i]
            if ($i -gt 0) {
                Assert-KitEqual ($futureIndexes[$i] -eq ($futureIndexes[$i - 1] + 1)) $true
            }
        }
    }

    It "keeps every Future True UX gate report-only, required, blocking, and pull-request triggered" {
        $futureGates = @($script:QualityGates.gates | Where-Object { $_.id -like "future-true-ux*" })
        foreach ($gate in $futureGates) {
            Assert-FutureTrueUxQualityGateSemantics -Gate $gate
        }
    }

    It "keeps Issue 19 and true execution boundaries closed in the governance document" {
        Assert-FutureTrueUxGovernanceBoundary -DocumentText $script:Doc -IssueNumber 19
    }
}
