Describe "Issue 13 main validation evidence" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "allows pending or ready evidence state" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\39-issue13-main-validation-evidence.md") -Raw -Encoding UTF8
        $statusMatch = [regex]::Match($doc, '(?m)^Status: `([^`]+)`')

        Assert-KitEqual $statusMatch.Success $true
        Assert-KitEqual (@("pending-main-validation", "ready-for-manual-closure") -contains $statusMatch.Groups[1].Value) $true
        foreach ($term in @(
            "## Evidence Sources",
            "## Current Evidence",
            "## Ensure-State Evidence",
            "## Real VM/Admin Smoke",
            "## Manual Closure Readiness",
            "## Ready-State Rules",
            "## Copyable Manual Closure Comment Draft"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }
    }

    It "validates pending or ready evidence details" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\39-issue13-main-validation-evidence.md") -Raw -Encoding UTF8
        $status = ([regex]::Match($doc, '(?m)^Status: `([^`]+)`')).Groups[1].Value

        if ($status -eq "pending-main-validation") {
            foreach ($term in @(
                '| Trigger source | `pending` |',
                '| Main SHA | `pending` |',
                '| Workflow run | `pending` |',
                '| Result | `pending` |',
                '| Report status | `pending` |',
                '| failedCount | `pending` |',
                '| plannedActionCount | `pending` |',
                '| Current readiness | `pending-main-validation` |'
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
            Assert-KitMatch $doc '\| Report status \| `(passed|manual)` \|'
            Assert-KitMatch $doc '\| failedCount \| `0` \|'
            Assert-KitMatch $doc '\| plannedActionCount \| `[0-9]+` \|'
            Assert-KitMatch $doc '\| Current readiness \| `ready-for-manual-closure` \|'
            Assert-KitMatch $doc '\| Required next evidence \| `none` \|'
        }
    }

    It "documents ready-state rules for future main evidence" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\39-issue13-main-validation-evidence.md") -Raw -Encoding UTF8

        foreach ($term in @(
            'Trigger source is `main push` or `workflow_dispatch`',
            "Main SHA is a 40-character Git SHA",
            "Workflow run is a GitHub Actions URL",
            "Full Validate job",
            'Result is `success`',
            'Ensure-State report status is `passed` or `manual`',
            'failedCount is `0`',
            'Current readiness is `ready-for-manual-closure`'
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }
    }

    It "keeps PR Fast CI separate from main evidence and smoke optional" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\39-issue13-main-validation-evidence.md") -Raw -Encoding UTF8

        foreach ($term in @(
            "Pull request-only Fast CI is not a substitute",
            'Ensure-State report `manual` with `failedCount=0` is acceptable review evidence, not execution evidence',
            "Real VM/admin smoke is optional manual evidence",
            "not-run",
            "not-provided",
            'PR Fast CI substitute allowed | `false`'
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        Assert-KitNotMatch $doc "(?i)\b(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+#13\b"
        Assert-KitNotMatch $doc "(?i)\| Result \| `(completed|passed)` \|"
    }

    It "links main-evidence scaffold from README, docs, and PR Fast CI" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $runbook = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\36-issue13-ensure-state.md") -Raw -Encoding UTF8
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8

        Assert-KitMatch $readme "docs/39-issue13-main-validation-evidence\.md"
        Assert-KitMatch $runbook "39-issue13-main-validation-evidence\.md"
        Assert-KitMatch $workflow ([regex]::Escape("tests/pester/Issue13MainValidationEvidence.Tests.ps1"))
    }
}
