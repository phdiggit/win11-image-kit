Describe "Issue 14 quality gates" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "documents the quality gate bus and safety boundaries" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-14\40-issue14-quality-gates.md") -Raw -Encoding UTF8

        foreach ($term in @(
            'Status: `in-progress`',
            "## Scope",
            "## Non-goals",
            "## Quality Gate Inventory",
            "## PR Fast CI",
            "## Full Validate",
            "## Schema / JSON Policy",
            "## Pester Inventory Policy",
            "## PSScriptAnalyzer Policy",
            "## Build Lock Coverage",
            "## Safety Boundaries",
            "## Acceptance Checklist"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        foreach ($term in @(
            "PR Fast CI is not main/workflow evidence",
            "separate task or issue",
            'Full Validate` being skipped on pull requests is expected'
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }
    }

    It "links README and Build Lock to Issue 14 docs and tests" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $paths = @($buildLock.entries.path)

        Assert-KitMatch $readme "docs/archive/completed-roadmap/issue-14/40-issue14-quality-gates\.md"

        foreach ($path in @(
            "docs/archive/completed-roadmap/issue-14/40-issue14-quality-gates.md",
            "tests/pester/Issue14QualityGates.Tests.ps1",
            "tests/pester/Issue14CiPolicy.Tests.ps1",
            "tests/pester/Issue14PesterInventory.Tests.ps1",
            "tests/pester/Issue14AnalyzerPolicy.Tests.ps1",
            "PSScriptAnalyzerSettings.psd1",
            ".github/workflows/ci.yml",
            "README.md"
        )) {
            Assert-KitEqual ($paths -contains $path) $true
        }
    }

    It "does not introduce Issue 14 auto-close wording" {
        $text = @(
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-14\40-issue14-quality-gates.md") -Raw -Encoding UTF8
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        ) -join "`n"

        Assert-KitNotMatch $text "(?i)\b(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+#14\b"
    }
}
