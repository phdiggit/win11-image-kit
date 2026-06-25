Describe "Issue 11 main validation evidence" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "keeps main validation evidence pending until real accepted evidence is recorded" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\31-issue11-main-validation-evidence.md") -Raw -Encoding UTF8

        foreach ($term in @(
            'Status: `pending-main-validation`',
            "## Evidence Sources",
            "## Current Evidence",
            '| Status | `pending` |',
            '| Main commit SHA | `pending` |',
            '| Workflow trigger | `pending` |',
            '| Workflow URL | `pending` |',
            '| Validate result | `pending` |',
            'Status: `not-run`',
            "Manual Closure Readiness",
            'Status: `pending`'
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }
    }

    It "requires main or workflow-dispatch evidence instead of PR Fast CI" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\31-issue11-main-validation-evidence.md") -Raw -Encoding UTF8

        foreach ($term in @(
            'push` workflow on `main`',
            'workflow_dispatch` workflow targeting `main`',
            "Pull request-only Fast CI",
            "is not a substitute",
            "40-character commit SHA",
            "workflow URL",
            'successful `Validate` result'
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }
    }

    It "documents optional real VM smoke without implying it ran" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\31-issue11-main-validation-evidence.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc "Real VM or administrator smoke validation is optional"
        Assert-KitMatch $doc "must not be implied from PR Fast CI"
        Assert-KitNotMatch $doc "(?i)\b(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+#11\b"
    }

    It "links main-evidence scaffold from README and PR Fast CI" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8

        Assert-KitMatch $readme "docs/31-issue11-main-validation-evidence\.md"
        Assert-KitMatch $workflow ([regex]::Escape("tests/pester/Issue11MainValidationEvidence.Tests.ps1"))
    }
}
