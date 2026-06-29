Describe "Issue 11 close preparation" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "records close-prep status and manual closure boundaries" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-11\30-issue11-close-preparation.md") -Raw -Encoding UTF8
        $statusMatch = [regex]::Match($doc, '(?m)^Status: `([^`]+)`')

        Assert-KitEqual $statusMatch.Success $true
        Assert-KitEqual (@("ready-for-manual-closure-candidate", "ready-for-manual-closure") -contains $statusMatch.Groups[1].Value) $true
        foreach ($term in @(
            "## Final Scope",
            "## Evidence Chain",
            "## Validation Policy",
            "## Manual Closure Checklist",
            "## Closure Note Draft",
            "manual closure"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        if ($statusMatch.Groups[1].Value -eq "ready-for-manual-closure") {
            foreach ($term in @(
                "Main/workflow validation success evidence",
                "Trigger source: main push",
                "Result: success",
                "Full Validate succeeded",
                "real VM/admin smoke | not-run"
            )) {
                Assert-KitMatch $doc ([regex]::Escape($term))
            }
        } else {
            Assert-KitMatch $doc "pending-main-validation"
            Assert-KitMatch $doc "## Optional Evidence Pending"
        }
    }

    It "lists the full Issue 11 evidence chain" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-11\30-issue11-close-preparation.md") -Raw -Encoding UTF8

        foreach ($path in @(
            "docs/archive/completed-roadmap/issue-11/28-issue11-capability-registry.md",
            "docs/archive/completed-roadmap/issue-11/29-issue11-capability-registry-acceptance.md",
            "docs/archive/completed-roadmap/issue-11/30-issue11-close-preparation.md",
            "docs/archive/completed-roadmap/issue-11/31-issue11-main-validation-evidence.md",
            "tests/pester/CapabilityRegistrySchema.Tests.ps1",
            "tests/pester/CapabilityRegistryConsistency.Tests.ps1",
            "tests/pester/CapabilityRegistryReport.Tests.ps1",
            "tests/pester/Issue11CapabilityRegistry.Tests.ps1",
            "tests/pester/Issue11CapabilityRegistryAcceptance.Tests.ps1",
            "tests/pester/Issue11ClosePrep.Tests.ps1",
            "tests/pester/Issue11MainValidationEvidence.Tests.ps1"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($path))
        }
    }

    It "keeps validation policy report-only and avoids auto-closing keywords" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-11\30-issue11-close-preparation.md") -Raw -Encoding UTF8

        foreach ($term in @(
            "must not call real business handlers",
            "real system mutation",
            "VM or administrator smoke validation is optional",
            "workflow_dispatch",
            "manual closure"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        Assert-KitNotMatch $doc "(?i)\b(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+#11\b"
    }

    It "links close-prep evidence from README and PR Fast CI" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8

        Assert-KitMatch $readme "docs/archive/completed-roadmap/issue-11/30-issue11-close-preparation\.md"
        Assert-KitMatch $workflow ([regex]::Escape("tests/pester/Issue11ClosePrep.Tests.ps1"))
    }
}
