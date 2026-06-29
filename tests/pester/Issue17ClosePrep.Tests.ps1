Describe "Issue 17 close-prep candidate" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-17\56-issue17-close-preparation.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
    }

    It "keeps docs/56 ready for manual closure of the planning stage" {
        Assert-KitMatch $script:Doc 'Status:\s*`ready-for-manual-closure`'
        foreach ($term in @(
            "## Final Scope Candidate",
            "## Accepted Report-only / Fixture / Simulation Capabilities",
            "## Explicit Non-goals",
            "## Validation Policy",
            "## Manual Closure Checklist",
            "## True Execution Split",
            "## Local Private / Build Lock Policy",
            "## Closure Note Draft",
            "## Related Documents"
        )) {
            Assert-KitMatch $script:Doc ([regex]::Escape($term))
        }

        Assert-KitMatch $script:Doc "ready for maintainer manual closure review"
        Assert-KitMatch $script:Doc "post-PR #89.*Full Validate success"
        Assert-KitMatch $script:Doc "automatic.*Issue #17 closure"
        Assert-KitMatch $script:Doc "PR Fast CI is not main/workflow evidence"
        Assert-KitMatch $script:Doc "Simulation is not real execution evidence"
        Assert-KitNotMatch $script:Doc "(?i)\b(fixes|closes|resolves)\s+#17\b"
    }

    It "keeps real lifecycle actions out of the candidate scope" {
        foreach ($pattern in @(
            "No real WinPE",
            "No real disk query",
            "No real disk partition",
            "No real WIM",
            'No `diskpart`, DISM, `bcdboot`, `bcdedit`, or `reagentc` execution',
            "No registry, profile, hive, service, AppX, Defender, Junction, Sysprep",
            "No Issue #17 completion summary"
        )) {
            Assert-KitMatch $script:Doc ([regex]::Escape($pattern))
        }
    }

    It "keeps Issue 6 through 16 closure documents archived without auto-close drift" {
        foreach ($issue in 6..16) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-$issue")) $true
        }

        $docs = @(Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap") -Filter "*.md" -Recurse | Where-Object { $_.FullName -match 'issue-(6|7|8|9|10|11|12|13|14|15|16)' })
        foreach ($doc in $docs) {
            $text = Get-Content -LiteralPath $doc.FullName -Raw -Encoding UTF8
            Assert-KitNotMatch $text "(?i)\b(fixes|closes|resolves)\s+#(6|7|8|9|10|11|12|13|14|15|16)\b"
        }
    }

    It "keeps Issue 17 completion summary absent" {
        $issue17Docs = @(Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "docs") -Filter "*issue17*.md" -Recurse)
        Assert-KitEqual (@($issue17Docs | Where-Object { $_.Name -match "completion-summary" }).Count) 0
    }

    It "keeps Quality Gates and Build Lock wired to the candidate scaffolds" {
        $qualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $gateIds = @($qualityGates.gates.id)
        Assert-KitEqual ($gateIds -contains "issue17-close-prep") $true
        Assert-KitEqual ($gateIds -contains "issue17-main-evidence-scaffold") $true

        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $paths = @($buildLock.entries.path)
        foreach ($path in @(
            "docs/archive/completed-roadmap/issue-17/56-issue17-close-preparation.md",
            "docs/archive/completed-roadmap/issue-17/57-issue17-main-validation-evidence.md",
            "tests/pester/Issue17ClosePrep.Tests.ps1",
            "tests/pester/Issue17MainValidationEvidence.Tests.ps1"
        )) {
            Assert-KitEqual ($paths -contains $path) $true
        }

        Assert-KitEqual ($paths -contains "manifests/paths.local.json") $false
    }
}
