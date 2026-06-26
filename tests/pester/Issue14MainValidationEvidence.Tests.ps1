Describe "Issue 14 main validation evidence" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "records pending main validation sections" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\43-issue14-main-validation-evidence.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc ([regex]::Escape('Status: `pending-main-validation`'))
        foreach ($term in @(
            "## Evidence Sources",
            "## Current Evidence",
            "## Quality Gate Evidence",
            "## Real VM/Admin Smoke",
            "## Manual Closure Readiness",
            "## Ready-State Rules",
            "## Copyable Manual Closure Comment Draft"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }
    }

    It "keeps all main workflow evidence fields pending" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\43-issue14-main-validation-evidence.md") -Raw -Encoding UTF8

        foreach ($term in @(
            '| Trigger source | `pending` |',
            '| Main SHA | `pending` |',
            '| Workflow run | `pending` |',
            '| Full Validate job | `pending` |',
            '| Result | `pending` |',
            '| Notes | `pending` |',
            '| Report status | `pending` |',
            '| failedCount | `pending` |',
            '| manualCount | `pending` |',
            '| gateCount | `pending` |',
            '| Current readiness | `pending-main-validation` |',
            '| Required next evidence | `main/workflow validation` |',
            '| PR Fast CI substitute allowed | `false` |'
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        Assert-KitNotMatch $doc '\| Result \| `success` \|'
        Assert-KitNotMatch $doc '\| Current readiness \| `ready-for-manual-closure` \|'
    }

    It "keeps real VM admin smoke not-run and not-provided" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\43-issue14-main-validation-evidence.md") -Raw -Encoding UTF8

        foreach ($term in @(
            '| Environment | `not-run` |',
            '| Operator | `not-provided` |',
            '| Date | `not-provided` |',
            '| Scope | `not-provided` |',
            '| Result | `not-run` |'
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        Assert-KitNotMatch $doc "(?i)main validation evidence is complete"
        Assert-KitNotMatch $doc "(?i)real VM/admin smoke.*(success|passed|completed)"
        Assert-KitNotMatch $doc "(?i)\b(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+#14\b"
    }

    It "documents ready-state rules without activating them" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\43-issue14-main-validation-evidence.md") -Raw -Encoding UTF8

        foreach ($pattern in @(
            "Only a later evidence backfill task may promote this document",
            "Trigger source is .main push. or .workflow_dispatch.",
            "Main SHA is a 40-character Git SHA",
            "Workflow run is a GitHub Actions URL",
            "Full Validate job is a GitHub Actions job URL",
            "Result is .success.",
            "Quality-gates report status is .passed. or .manual.",
            "failedCount is .0.",
            "PR Fast CI substitute allowed remains .false.",
            "Current readiness is .ready-for-manual-closure."
        )) {
            Assert-KitMatch $doc $pattern
        }
    }

    It "links main-evidence scaffold from README, docs, CI, and Build Lock" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $runbook = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\40-issue14-quality-gates.md") -Raw -Encoding UTF8
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $paths = @($buildLock.entries.path)

        Assert-KitMatch $readme "docs/43-issue14-main-validation-evidence\.md"
        Assert-KitMatch $runbook "43-issue14-main-validation-evidence\.md"
        Assert-KitMatch $workflow ([regex]::Escape("tests/pester/Issue14MainValidationEvidence.Tests.ps1"))
        Assert-KitEqual ($paths -contains "docs/43-issue14-main-validation-evidence.md") $true
        Assert-KitEqual ($paths -contains "tests/pester/Issue14MainValidationEvidence.Tests.ps1") $true
    }
}
