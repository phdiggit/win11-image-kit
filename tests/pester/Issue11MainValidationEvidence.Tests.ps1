Describe "Issue 11 main validation evidence" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "supports pending or ready main validation evidence states" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-11\31-issue11-main-validation-evidence.md") -Raw -Encoding UTF8
        $statusMatch = [regex]::Match($doc, '(?m)^Status: `([^`]+)`')

        Assert-KitEqual $statusMatch.Success $true
        Assert-KitEqual (@("pending-main-validation", "ready-for-manual-closure") -contains $statusMatch.Groups[1].Value) $true
        Assert-KitMatch $doc "## Evidence Sources"
        Assert-KitMatch $doc "## Current Evidence"
        Assert-KitMatch $doc "Manual Closure Readiness"
        Assert-KitMatch $doc ([regex]::Escape('Status: `not-run`'))

        if ($statusMatch.Groups[1].Value -eq "ready-for-manual-closure") {
            Assert-KitMatch $doc '\| Status \| `success` \|'
            Assert-KitMatch $doc '\| Main commit SHA \| `[0-9a-f]{40}` \|'
            Assert-KitMatch $doc '\| Workflow trigger \| `(main push|workflow_dispatch)` \|'
            Assert-KitMatch $doc "\| Workflow URL \| https://github\.com/phdiggit/win11-image-kit/actions/runs/[0-9]+ \|"
            Assert-KitMatch $doc '\| Validate result \| `success` \|'
            Assert-KitMatch $doc ([regex]::Escape('Status: `ready-for-manual-closure`'))
            Assert-KitMatch $doc "Full Validate succeeded"
        } else {
            foreach ($term in @(
                '| Status | `pending` |',
                '| Main commit SHA | `pending` |',
                '| Workflow trigger | `pending` |',
                '| Workflow URL | `pending` |',
                '| Validate result | `pending` |',
                'Status: `pending`'
            )) {
                Assert-KitMatch $doc ([regex]::Escape($term))
            }
            Assert-KitNotMatch $doc '\| Validate result \| `success` \|'
            Assert-KitNotMatch $doc ([regex]::Escape('Status: `ready-for-manual-closure`'))
        }
    }

    It "requires main or workflow-dispatch evidence instead of PR Fast CI" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-11\31-issue11-main-validation-evidence.md") -Raw -Encoding UTF8

        foreach ($term in @(
            'push` workflow on `main`',
            'workflow_dispatch` workflow targeting `main`',
            "Pull request-only Fast CI",
            "is not a substitute",
            "40-character commit SHA",
            "workflow URL",
            "Full Validate result"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }
    }

    It "documents optional real VM smoke without implying it ran" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-11\31-issue11-main-validation-evidence.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc "Real VM or administrator smoke validation is optional"
        Assert-KitMatch $doc "PR Fast CI"
        Assert-KitMatch $doc "not-run"
        Assert-KitNotMatch $doc "(?i)\b(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+#11\b"
    }

    It "links main-evidence scaffold from README and PR Fast CI" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8

        Assert-KitMatch $readme "docs/archive/completed-roadmap/issue-11/31-issue11-main-validation-evidence\.md"
        Assert-KitMatch $workflow ([regex]::Escape("tests/pester/Issue11MainValidationEvidence.Tests.ps1"))
    }
}
