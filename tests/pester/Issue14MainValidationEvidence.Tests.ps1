Describe "Issue 14 main validation evidence" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "allows pending or ready main validation sections" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-14\43-issue14-main-validation-evidence.md") -Raw -Encoding UTF8
        $statusMatch = [regex]::Match($doc, '(?m)^Status: `([^`]+)`')

        Assert-KitEqual $statusMatch.Success $true
        Assert-KitEqual (@("pending-main-validation", "ready-for-manual-closure") -contains $statusMatch.Groups[1].Value) $true
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

    It "validates pending or ready main workflow evidence fields" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-14\43-issue14-main-validation-evidence.md") -Raw -Encoding UTF8
        $status = ([regex]::Match($doc, '(?m)^Status: `([^`]+)`')).Groups[1].Value

        if ($status -eq "pending-main-validation") {
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
        } else {
            Assert-KitMatch $doc '\| Trigger source \| `(main push|workflow_dispatch)` \|'
            Assert-KitMatch $doc '\| Main SHA \| `[0-9a-f]{40}` \|'
            Assert-KitMatch $doc '\| Workflow run \| https://github\.com/phdiggit/win11-image-kit/actions/runs/[0-9]+ \|'
            Assert-KitMatch $doc '\| Full Validate job \| https://github\.com/phdiggit/win11-image-kit/actions/runs/[0-9]+/job/[0-9]+ \|'
            Assert-KitMatch $doc '\| Result \| `success` \|'
            Assert-KitMatch $doc '\| Notes \| .+ \|'
            Assert-KitMatch $doc '\| Report status \| `(passed|manual)` \|'
            Assert-KitMatch $doc '\| failedCount \| `0` \|'
            Assert-KitMatch $doc '\| manualCount \| `([0-9]+|not-captured)` \|'
            Assert-KitMatch $doc '\| gateCount \| `([0-9]+|not-captured)` \|'
            Assert-KitMatch $doc '\| Current readiness \| `ready-for-manual-closure` \|'
            Assert-KitMatch $doc '\| Required next evidence \| `none` \|'
            Assert-KitMatch $doc '\| PR Fast CI substitute allowed \| `false` \|'
            Assert-KitMatch $doc "same-SHA local report evidence"
        }
    }

    It "keeps real VM admin smoke not-run and not-provided" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-14\43-issue14-main-validation-evidence.md") -Raw -Encoding UTF8

        foreach ($term in @(
            '| Environment | `not-run` |',
            '| Operator | `not-provided` |',
            '| Date | `not-provided` |',
            '| Scope | `not-provided` |',
            '| Result | `not-run` |'
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        Assert-KitNotMatch $doc "(?i)real VM/admin smoke.*(success|passed|completed)"
        Assert-KitNotMatch $doc "(?i)\b(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+#14\b"
    }

    It "documents ready-state rules without activating them" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-14\43-issue14-main-validation-evidence.md") -Raw -Encoding UTF8
        $status = ([regex]::Match($doc, '(?m)^Status: `([^`]+)`')).Groups[1].Value

        if ($status -eq "pending-main-validation") {
            Assert-KitMatch $doc "Only a later evidence backfill task may promote this document"
        } else {
            Assert-KitMatch $doc "This document is ready because the main push Full Validate evidence above has been recorded and verified"
        }

        foreach ($pattern in @(
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
        $runbook = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-14\40-issue14-quality-gates.md") -Raw -Encoding UTF8
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $paths = @($buildLock.entries.path)

        Assert-KitMatch $readme "docs/archive/completed-roadmap/issue-14/43-issue14-main-validation-evidence\.md"
        Assert-KitMatch $runbook "43-issue14-main-validation-evidence\.md"
        Assert-KitMatch $workflow ([regex]::Escape("tests/pester/Issue14MainValidationEvidence.Tests.ps1"))
        Assert-KitEqual ($paths -contains "docs/archive/completed-roadmap/issue-14/43-issue14-main-validation-evidence.md") $true
        Assert-KitEqual ($paths -contains "tests/pester/Issue14MainValidationEvidence.Tests.ps1") $true
    }
}
