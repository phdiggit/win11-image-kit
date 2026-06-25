Describe "Issue 12 close preparation" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "records close-prep status and manual closure boundaries" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\34-issue12-close-preparation.md") -Raw -Encoding UTF8
        $statusMatch = [regex]::Match($doc, '(?m)^Status: `([^`]+)`')

        Assert-KitEqual $statusMatch.Success $true
        Assert-KitEqual (@("ready-for-manual-closure-candidate", "ready-for-manual-closure") -contains $statusMatch.Groups[1].Value) $true
        foreach ($term in @(
            "## Final Scope",
            "## Evidence Chain",
            "## Validation Policy",
            "## Manual Closure Checklist",
            "## Recorded Evidence",
            "## Optional Manual Validation Evidence",
            "## Closure Note Draft",
            "manual issue handling"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        if ($statusMatch.Groups[1].Value -eq "ready-for-manual-closure") {
            foreach ($term in @(
                "Main/workflow validation success evidence",
                "main push Windows CI / Full Validate",
                "Trigger source",
                'Result: `success`',
                "Full Validate job",
                "Build Lock report",
                "failedCount=0",
                "real VM/admin smoke",
                "not-run"
            )) {
                Assert-KitMatch $doc ([regex]::Escape($term))
            }
        }
    }

    It "lists the full Issue 12 evidence chain" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\34-issue12-close-preparation.md") -Raw -Encoding UTF8

        foreach ($path in @(
            "docs/32-issue12-build-lock.md",
            "docs/33-issue12-build-lock-acceptance.md",
            "docs/34-issue12-close-preparation.md",
            "docs/35-issue12-main-validation-evidence.md",
            "tests/pester/BuildLockSchema.Tests.ps1",
            "tests/pester/BuildLockHash.Tests.ps1",
            "tests/pester/BuildLockValidation.Tests.ps1",
            "tests/pester/BuildLockReport.Tests.ps1",
            "tests/pester/Issue12BuildLock.Tests.ps1",
            "tests/pester/Issue12BuildLockAcceptance.Tests.ps1",
            "tests/pester/Issue12ClosePrep.Tests.ps1",
            "tests/pester/Issue12MainValidationEvidence.Tests.ps1"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($path))
        }
    }

    It "keeps validation policy report-only and manual evidence optional" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\34-issue12-close-preparation.md") -Raw -Encoding UTF8

        foreach ($term in @(
            "must not run real build",
            "network access",
            "signing",
            "business handler",
            "system mutation",
            "Real VM/admin smoke is optional manual evidence"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        Assert-KitNotMatch $doc "(?i)\b(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+#12\b"
    }

    It "links close-prep evidence from README, docs, and PR Fast CI" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $runbook = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\32-issue12-build-lock.md") -Raw -Encoding UTF8
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8

        Assert-KitMatch $readme "docs/34-issue12-close-preparation\.md"
        Assert-KitMatch $runbook "34-issue12-close-preparation\.md"
        Assert-KitMatch $workflow ([regex]::Escape("tests/pester/Issue12ClosePrep.Tests.ps1"))
    }
}
