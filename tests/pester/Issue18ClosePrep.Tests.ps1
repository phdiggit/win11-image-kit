Describe "Issue 18 close-prep candidate" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-18\62-issue18-close-preparation.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
    }

    It "keeps docs/62 ready for manual closure of the current stage" {
        Assert-KitMatch $script:Doc 'Status:\s*`ready-for-manual-closure`'
        foreach ($term in @(
            "## Final Scope Candidate",
            "## Accepted Report-only / Fixture / Handler Capabilities",
            "## Explicit Non-goals",
            "## Validation Policy",
            "## Manual Closure Checklist",
            "## True UX Restore Split",
            "## Template Metadata / Config Policy",
            "## Local Private / Build Lock Policy",
            "## Closure Note Draft",
            "## Related Documents"
        )) {
            Assert-KitMatch $script:Doc ([regex]::Escape($term))
        }

        Assert-KitMatch $script:Doc "manual closure readiness"
        Assert-KitMatch $script:Doc "must not be automatically closed"
        Assert-KitNotMatch $script:Doc "(?i)\b(fixes|closes|resolves)\s+#18\b"
    }

    It "keeps fake UX evidence out of the candidate scope" {
        foreach ($pattern in @(
            "PR Fast CI is not main/workflow evidence",
            "Fixture validation is not real UX restore evidence",
            "handler reports are not real UX restore evidence",
            "Manual checklist rows are not success evidence",
            "No Issue #18 completion summary",
            "No registry write",
            "No profile write",
            "No default app import",
            "No Start menu import",
            "No taskbar mutation"
        )) {
            Assert-KitMatch $script:Doc ([regex]::Escape($pattern))
        }
    }

    It "keeps Issue 6 through 17 closure documents archived without changing closure semantics" {
        foreach ($issue in 6..17) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-$issue")) $true
        }

        $archivedDocs = @(Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap") -Filter "*.md" -Recurse)
        $issue6To17Docs = @($archivedDocs | Where-Object { $_.FullName -match 'issue-(6|7|8|9|10|11|12|13|14|15|16|17)' })
        Assert-KitEqual ($issue6To17Docs.Count -gt 0) $true

        foreach ($doc in $issue6To17Docs) {
            $text = Get-Content -LiteralPath $doc.FullName -Raw -Encoding UTF8
            Assert-KitNotMatch $text "(?i)\b(fixes|closes|resolves)\s+#(6|7|8|9|10|11|12|13|14|15|16|17)\b"
        }
    }

    It "keeps Issue 18 completion summary absent and auto-close keywords out" {
        $issue18Docs = @(Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "docs") -Filter "*issue18*.md" -Recurse)
        Assert-KitEqual (@($issue18Docs | Where-Object { $_.Name -match "completion-summary" }).Count) 0

        foreach ($doc in $issue18Docs) {
            $text = Get-Content -LiteralPath $doc.FullName -Raw -Encoding UTF8
            Assert-KitNotMatch $text "(?i)\b(fixes|closes|resolves)\s+#18\b"
        }
    }

    It "keeps Quality Gates and Build Lock wired to Issue 18 scaffolds" {
        $qualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $gateIds = @($qualityGates.gates.id)
        Assert-KitEqual ($gateIds -contains "issue18-close-prep") $true
        Assert-KitEqual ($gateIds -contains "issue18-main-evidence-scaffold") $true

        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $paths = @($buildLock.entries.path)
        foreach ($path in @(
            "docs/archive/completed-roadmap/issue-18/62-issue18-close-preparation.md",
            "docs/archive/completed-roadmap/issue-18/63-issue18-main-validation-evidence.md",
            "tests/pester/Issue18ClosePrep.Tests.ps1",
            "tests/pester/Issue18MainValidationEvidence.Tests.ps1"
        )) {
            Assert-KitEqual ($paths -contains $path) $true
        }

        Assert-KitEqual ($paths -contains "manifests/paths.local.json") $false
    }
}
