Describe "Issue 13 close preparation" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "records candidate or ready status and manual closure sections" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\38-issue13-close-preparation.md") -Raw -Encoding UTF8
        $statusMatch = [regex]::Match($doc, '(?m)^Status: `([^`]+)`')

        Assert-KitEqual $statusMatch.Success $true
        Assert-KitEqual (@("ready-for-manual-closure-candidate", "ready-for-manual-closure") -contains $statusMatch.Groups[1].Value) $true
        foreach ($term in @(
            "## Final Scope",
            "## Evidence Chain",
            "## Validation Policy",
            "## Manual Closure Checklist",
            "## Optional Manual Validation Evidence",
            "## Closure Note Draft",
            "manual issue handling"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        if ($statusMatch.Groups[1].Value -eq "ready-for-manual-closure") {
            foreach ($term in @(
                "Main/workflow validation evidence is recorded in docs/39",
                "main/workflow validation | success",
                "Main push Windows CI / Full Validate succeeded",
                "real VM/admin smoke | not-run"
            )) {
                Assert-KitMatch $doc ([regex]::Escape($term))
            }
        }
    }

    It "lists the full Issue 13 evidence chain" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\38-issue13-close-preparation.md") -Raw -Encoding UTF8

        foreach ($path in @(
            "docs/36-issue13-ensure-state.md",
            "docs/37-issue13-ensure-state-acceptance.md",
            "docs/38-issue13-close-preparation.md",
            "docs/39-issue13-main-validation-evidence.md",
            "tests/pester/EnsureStateSchema.Tests.ps1",
            "tests/pester/EnsureStatePlan.Tests.ps1",
            "tests/pester/EnsureStateReport.Tests.ps1",
            "tests/pester/EnsureStateValidation.Tests.ps1",
            "tests/pester/Issue13EnsureState.Tests.ps1",
            "tests/pester/Issue13EnsureStateAcceptance.Tests.ps1",
            "tests/pester/Issue13ClosePrep.Tests.ps1",
            "tests/pester/Issue13MainValidationEvidence.Tests.ps1"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($path))
        }
    }

    It "keeps validation policy report-only and real smoke optional" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\38-issue13-close-preparation.md") -Raw -Encoding UTF8

        foreach ($term in @(
            "must not run real install/uninstall/upgrade",
            "service mutation",
            "network",
            "signing",
            "registry/profile/hive mutation",
            "image build",
            "Real VM/admin smoke is optional manual evidence",
            "PR Fast CI is not used as a substitute"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        Assert-KitNotMatch $doc "(?i)\b(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+#13\b"
        Assert-KitNotMatch $doc "(?i)real VM/admin smoke \| (completed|success|passed)"
        Assert-KitMatch $doc "separate task or issue|outside this scope"
    }

    It "links close-prep evidence from README, docs, and PR Fast CI" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $runbook = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\36-issue13-ensure-state.md") -Raw -Encoding UTF8
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8

        Assert-KitMatch $readme "docs/38-issue13-close-preparation\.md"
        Assert-KitMatch $runbook "38-issue13-close-preparation\.md"
        Assert-KitMatch $workflow ([regex]::Escape("tests/pester/Issue13ClosePrep.Tests.ps1"))
    }
}
