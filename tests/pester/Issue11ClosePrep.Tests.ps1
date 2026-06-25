Describe "Issue 11 close preparation" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "records close-prep status and manual closure boundaries" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\30-issue11-close-preparation.md") -Raw -Encoding UTF8

        foreach ($term in @(
            'Status: `ready-for-manual-closure-candidate`',
            "## Final Scope",
            "## Evidence Chain",
            "## Validation Policy",
            "## Manual Closure Checklist",
            "## Optional Evidence Pending",
            "## Closure Note Draft",
            "manual closure",
            "pending-main-validation"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }
    }

    It "lists the full Issue 11 evidence chain" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\30-issue11-close-preparation.md") -Raw -Encoding UTF8

        foreach ($path in @(
            "docs/28-issue11-capability-registry.md",
            "docs/29-issue11-capability-registry-acceptance.md",
            "docs/30-issue11-close-preparation.md",
            "docs/31-issue11-main-validation-evidence.md",
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
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\30-issue11-close-preparation.md") -Raw -Encoding UTF8

        foreach ($term in @(
            "must not call real business handlers",
            "real system mutation",
            "VM or administrator smoke validation is optional",
            "workflow-dispatch",
            "manual closure"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        Assert-KitNotMatch $doc "(?i)\b(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+#11\b"
    }

    It "links close-prep evidence from README and PR Fast CI" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8

        Assert-KitMatch $readme "docs/30-issue11-close-preparation\.md"
        Assert-KitMatch $workflow ([regex]::Escape("tests/pester/Issue11ClosePrep.Tests.ps1"))
    }
}
