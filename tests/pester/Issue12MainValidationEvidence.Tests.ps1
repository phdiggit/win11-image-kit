Describe "Issue 12 main validation evidence" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "keeps the default evidence state pending" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\35-issue12-main-validation-evidence.md") -Raw -Encoding UTF8
        $statusMatch = [regex]::Match($doc, '(?m)^Status: `([^`]+)`')

        Assert-KitEqual $statusMatch.Success $true
        Assert-KitEqual (@("pending-main-validation", "ready-for-manual-closure") -contains $statusMatch.Groups[1].Value) $true
        Assert-KitEqual $statusMatch.Groups[1].Value "pending-main-validation"
        foreach ($term in @(
            "## Evidence Sources",
            "## Current Evidence",
            "## Real VM/Admin Smoke",
            "## Manual Closure Readiness",
            "## Copyable Manual Closure Comment Draft"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }
    }

    It "does not present pending evidence as ready" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\35-issue12-main-validation-evidence.md") -Raw -Encoding UTF8

        foreach ($term in @(
            '| Trigger source | `pending` |',
            '| Main SHA | `pending` |',
            '| Workflow run | `pending` |',
            '| Result | `pending` |',
            '| Current readiness | `pending-main-validation` |'
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        Assert-KitNotMatch $doc '\| Result \| `success` \|'
        Assert-KitNotMatch $doc '\| Current readiness \| `ready-for-manual-closure` \|'
    }

    It "documents ready-state rules for future main evidence" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\35-issue12-main-validation-evidence.md") -Raw -Encoding UTF8

        foreach ($term in @(
            'Trigger source is `main push` or `workflow_dispatch`',
            "Main SHA is a 40-character Git SHA",
            "Workflow run is a GitHub Actions URL",
            'Result is `success`',
            'Current readiness is `ready-for-manual-closure`'
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }
    }

    It "keeps PR Fast CI separate from main validation evidence and smoke optional" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\35-issue12-main-validation-evidence.md") -Raw -Encoding UTF8

        foreach ($term in @(
            "Pull request-only Fast CI is not a substitute",
            "Real VM/admin smoke is optional manual evidence",
            "not-run",
            "not-provided",
            'PR Fast CI substitute allowed | `false`'
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        Assert-KitNotMatch $doc "(?i)\b(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+#12\b"
    }

    It "links main-evidence scaffold from README, docs, and PR Fast CI" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $runbook = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\32-issue12-build-lock.md") -Raw -Encoding UTF8
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8

        Assert-KitMatch $readme "docs/35-issue12-main-validation-evidence\.md"
        Assert-KitMatch $runbook "35-issue12-main-validation-evidence\.md"
        Assert-KitMatch $workflow ([regex]::Escape("tests/pester/Issue12MainValidationEvidence.Tests.ps1"))
    }
}
