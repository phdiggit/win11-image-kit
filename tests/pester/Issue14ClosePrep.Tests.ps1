Describe "Issue 14 close preparation" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "records candidate or ready status and manual closure sections" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-14\42-issue14-close-preparation.md") -Raw -Encoding UTF8
        $statusMatch = [regex]::Match($doc, '(?m)^Status: `([^`]+)`')

        Assert-KitEqual $statusMatch.Success $true
        Assert-KitEqual (@("ready-for-manual-closure-candidate", "ready-for-manual-closure") -contains $statusMatch.Groups[1].Value) $true
        foreach ($term in @(
            "## Evidence Chain",
            "## Validation Policy",
            "## Manual Closure Checklist",
            "## Optional Manual Validation Evidence",
            "## Closure Note Draft",
            "## Related Documents"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        Assert-KitMatch $doc "## Final Scope"
    }

    It "keeps closure state aligned with main evidence" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-14\42-issue14-close-preparation.md") -Raw -Encoding UTF8
        $status = ([regex]::Match($doc, '(?m)^Status: `([^`]+)`')).Groups[1].Value

        if ($status -eq "ready-for-manual-closure-candidate") {
            foreach ($term in @(
                'docs/43 is `pending-main-validation`',
                "only a manual-closure candidate",
                "PR Fast CI is not main/workflow evidence",
                "Full Validate on pull requests remains skipped",
                "main/workflow validation evidence must come from a later"
            )) {
                Assert-KitMatch $doc ([regex]::Escape($term))
            }

            Assert-KitNotMatch $doc '(?m)^Status: `ready-for-manual-closure`'
        } else {
            foreach ($term in @(
                'docs/43 records verified `main` push Full Validate evidence',
                'docs/43 records verified `main` push or `workflow_dispatch` evidence',
                "PR Fast CI is still not main/workflow evidence",
                "does not automatically close Issue #14"
            )) {
                Assert-KitMatch $doc ([regex]::Escape($term))
            }
        }

        Assert-KitNotMatch $doc "(?i)\b(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+#14\b"
    }

    It "does not claim real smoke or true execution success" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-14\42-issue14-close-preparation.md") -Raw -Encoding UTF8

        foreach ($term in @(
            "real Windows image build",
            "installer/service mutation",
            "network download",
            "registry/profile/hive mutation",
            "Real VM/admin smoke is optional manual evidence",
            "must not be invented",
            "separate task or issue"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        Assert-KitNotMatch $doc "(?i)real VM/admin smoke.*(success|passed|completed)"
        Assert-KitNotMatch $doc "(?i)true execution.*(success|passed|completed)"
    }

    It "links close-prep from README, docs, CI, and Build Lock" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $runbook = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-14\40-issue14-quality-gates.md") -Raw -Encoding UTF8
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $paths = @($buildLock.entries.path)

        Assert-KitMatch $readme "docs/archive/completed-roadmap/issue-14/42-issue14-close-preparation\.md"
        Assert-KitMatch $runbook "42-issue14-close-preparation\.md"
        Assert-KitMatch $workflow ([regex]::Escape("tests/pester/Issue14ClosePrep.Tests.ps1"))
        Assert-KitEqual ($paths -contains "docs/archive/completed-roadmap/issue-14/42-issue14-close-preparation.md") $true
        Assert-KitEqual ($paths -contains "tests/pester/Issue14ClosePrep.Tests.ps1") $true
    }
}
