Describe "Capability registry consistency" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Get-KitCapabilityRegistry.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitCapabilityConsistency.ps1")
        $script:Registry = Get-KitCapabilityRegistry -Path "manifests/capability-registry.json" -RepoRoot $script:RepoRoot
    }

    It "passes implemented capabilities with existing manifest, schema, tests, and docs" {
        $results = @(Test-KitCapabilityConsistency -Registry $script:Registry -RepoRoot $script:RepoRoot)
        Assert-KitEqual @($results | Where-Object { $_.status -eq "failed" }).Count 0

        foreach ($result in $results) {
            Assert-KitEqual $result.checks.manifestExists $true
            Assert-KitEqual $result.checks.schemaExists $true
            Assert-KitEqual $result.checks.testsExist $true
            Assert-KitEqual $result.checks.docsExist $true
            Assert-KitEqual $result.checks.hasAtLeastOneTest $true
            Assert-KitEqual $result.checks.hasAtLeastOneDoc $true
            Assert-KitEqual $result.checks.mutationBoundaryKnown $true
        }
    }

    It "fails missing entrypoints, tests, docs, and unknown implemented mutation level" {
        $capability = [pscustomobject]@{
            id = "bad-capability"
            issue = "#11"
            status = "implemented"
            context = "machine"
            mutationLevel = "unknown"
            manifest = "manifests/context-scope.json"
            schema = "schemas/context-scope.schema.json"
            entrypoints = @("scripts/common/Does-Not-Exist.ps1")
            validateEntrypoints = @()
            tests = @()
            docs = @()
            notes = "fixture"
        }
        $registry = [pscustomobject]@{ capabilities = @($capability) }

        $result = @(Test-KitCapabilityConsistency -Registry $registry -RepoRoot $script:RepoRoot)[0]
        Assert-KitEqual $result.status "failed"
        Assert-KitMatch ($result.errors -join ";") "entrypoints missing"
        Assert-KitMatch ($result.errors -join ";") "at least one test"
        Assert-KitMatch ($result.errors -join ";") "at least one doc"
        Assert-KitMatch ($result.errors -join ";") "mutationLevel=unknown"
    }

    It "marks real mutation, mixed context, and planned capabilities as manual instead of passed" {
        $capabilities = @(
            [pscustomobject]@{ id = "real"; issue = "#11"; status = "implemented"; context = "machine"; mutationLevel = "real-mutation"; manifest = "manifests/context-scope.json"; schema = "schemas/context-scope.schema.json"; entrypoints = @(); validateEntrypoints = @(); tests = @("tests/pester/ContextScopeSchema.Tests.ps1"); docs = @("docs/24-issue10-context-scope-split.md"); notes = "fixture" },
            [pscustomobject]@{ id = "mixed"; issue = "#11"; status = "implemented"; context = "mixed"; mutationLevel = "plan-only"; manifest = "manifests/context-scope.json"; schema = "schemas/context-scope.schema.json"; entrypoints = @(); validateEntrypoints = @(); tests = @("tests/pester/ContextScopeSchema.Tests.ps1"); docs = @("docs/24-issue10-context-scope-split.md"); notes = "fixture" },
            [pscustomobject]@{ id = "planned"; issue = "#11"; status = "planned"; context = "none"; mutationLevel = "audit-only"; manifest = "manifests/missing.json"; schema = "schemas/missing.schema.json"; entrypoints = @(); validateEntrypoints = @(); tests = @(); docs = @(); notes = "planned later" }
        )
        $registry = [pscustomobject]@{ capabilities = $capabilities }
        $results = @(Test-KitCapabilityConsistency -Registry $registry -RepoRoot $script:RepoRoot)

        foreach ($result in $results) {
            Assert-KitEqual $result.status "manual"
        }
    }

    It "registers software manifest to issue 13 and keeps non-strict orphan checks non-blocking" {
        $orphans = @(Get-KitCapabilityOrphanManifests -RepoRoot $script:RepoRoot -Registry $script:Registry)
        Assert-KitEqual ($orphans -contains "manifests/software.json") $false

        $results = @(Test-KitCapabilityConsistency -Registry $script:Registry -RepoRoot $script:RepoRoot)
        Assert-KitEqual @($results | Where-Object { $_.id -eq "orphan-manifest-check" }).Count 0
    }

    It "does not call real business handlers in PR Fast fixtures" {
        function Invoke-KitJunctionTransaction { }
        function Set-KitDefenderExclusionState { }
        function Get-KitAppxInventory { }

        Mock Invoke-KitJunctionTransaction { throw "should not call junction transaction" }
        Mock Set-KitDefenderExclusionState { throw "should not call Defender mutation" }
        Mock Get-KitAppxInventory { throw "should not call AppX inventory" }

        Test-KitCapabilityConsistency -Registry $script:Registry -RepoRoot $script:RepoRoot | Out-Null

        Assert-MockCalled Invoke-KitJunctionTransaction -Times 0 -Exactly
        Assert-MockCalled Set-KitDefenderExclusionState -Times 0 -Exactly
        Assert-MockCalled Get-KitAppxInventory -Times 0 -Exactly
    }
}
