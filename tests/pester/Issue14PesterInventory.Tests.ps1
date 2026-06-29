Describe "Issue 14 Pester inventory" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:Workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
    }

    It "wires Issue 14 guardrail tests into PR Fast CI" {
        foreach ($path in @(
            "tests/pester/Issue14QualityGates.Tests.ps1",
            "tests/pester/Issue14CiPolicy.Tests.ps1",
            "tests/pester/Issue14PesterInventory.Tests.ps1",
            "tests/pester/Issue14AnalyzerPolicy.Tests.ps1"
        )) {
            Assert-KitMatch $script:Workflow ([regex]::Escape($path))
        }
    }

    It "keeps important issue guardrail tests in the fast Pester list" {
        foreach ($path in @(
            "tests/pester/Issue7JunctionAcceptance.Tests.ps1",
            "tests/pester/Issue8DefenderAcceptance.Tests.ps1",
            "tests/pester/Issue9SysprepAppxAcceptance.Tests.ps1",
            "tests/pester/Issue10ContextScopeAcceptance.Tests.ps1",
            "tests/pester/Issue11CapabilityRegistryAcceptance.Tests.ps1",
            "tests/pester/Issue12BuildLockAcceptance.Tests.ps1",
            "tests/pester/Issue13EnsureStateAcceptance.Tests.ps1",
            "tests/pester/Issue13MainValidationEvidence.Tests.ps1"
        )) {
            Assert-KitMatch $script:Workflow ([regex]::Escape($path))
        }
    }

    It "keeps Full Validate broad without requiring it on PRs" {
        Assert-KitMatch $script:Workflow "Invoke-Pester -Path tests/pester"
        Assert-KitMatch $script:Workflow "if:\s*github\.event_name != 'pull_request'"

        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-14\40-issue14-quality-gates.md") -Raw -Encoding UTF8
        Assert-KitMatch $doc 'Full Validate runs `tests/pester`'
        Assert-KitMatch $doc "Adding new Pester files requires updating CI wiring"
    }
}
