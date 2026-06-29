Describe "Issue 18 manual closure handoff" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-18\64-issue18-manual-closure-handoff.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
    }

    It "records a manual handoff without becoming a completion summary" {
        Assert-KitEqual (Test-Path -LiteralPath $script:DocPath) $true
        Assert-KitMatch $script:Doc 'Status:\s*`manual-closure-handoff`'
        Assert-KitMatch $script:Doc "not an Issue #18 completion summary"
        Assert-KitMatch $script:Doc "does not automatically close Issue #18"
        Assert-KitMatch $script:Doc "maintainer manual closure review"
        Assert-KitMatch $script:Doc "post-PR #96"
        Assert-KitMatch $script:Doc "28285895794"
    }

    It "keeps the closure note draft safe and non-mutating" {
        Assert-KitMatch $script:Doc "Safe Closure Note Draft"
        Assert-KitMatch $script:Doc "Real UX restore execution remains future authorized work"
        Assert-KitMatch $script:Doc "not real UX restore evidence"
        Assert-KitMatch $script:Doc "Refs #18"
        Assert-KitNotMatch $script:Doc "(?i)\b(fixes|closes|resolves)\s+#18\b"
    }

    It "keeps Issue 18 completion summary absent" {
        $issue18Docs = @(Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "docs") -Filter "*issue18*.md")
        Assert-KitEqual (@($issue18Docs | Where-Object { $_.Name -match "completion-summary" }).Count) 0
    }

    It "wires handoff documents into Quality Gates and Build Lock" {
        $qualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $gateIds = @($qualityGates.gates.id)
        Assert-KitEqual ($gateIds -contains "issue18-manual-closure-handoff") $true
        Assert-KitEqual ($gateIds -contains "future-true-ux-restore-split") $true

        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $paths = @($buildLock.entries.path)
        Assert-KitEqual ($paths -contains "docs/archive/completed-roadmap/issue-18/64-issue18-manual-closure-handoff.md") $true
        Assert-KitEqual ($paths -contains "docs/archive/future-true-ux-restore/00-governance/65-future-true-ux-restore-execution-split.md") $true
        Assert-KitEqual ($paths -contains "tests/pester/Issue18ManualClosureHandoff.Tests.ps1") $true
        Assert-KitEqual ($paths -contains "tests/pester/Issue18FutureTrueUxRestoreSplit.Tests.ps1") $true
        Assert-KitEqual ($paths -contains "manifests/paths.local.json") $false
    }
}
