Describe "Capability registry report" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Get-KitCapabilityRegistry.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitCapabilityConsistencyReport.ps1")
    }

    It "creates a capability-consistency report with summary and orphan manifests" {
        $registry = Get-KitCapabilityRegistry -Path "manifests/capability-registry.json" -RepoRoot $script:RepoRoot
        $report = New-KitCapabilityConsistencyReport -Registry $registry -RepoRoot $script:RepoRoot -WhatIf

        Assert-KitEqual $report.reportType "capability-consistency"
        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.summary.total 5
        Assert-KitEqual $report.summary.passedCount 5
        Assert-KitEqual $report.summary.failedCount 0
        Assert-KitEqual ($report.summary.orphanManifestCount -gt 0) $true
        Assert-KitEqual (@($report.orphanManifests) -contains "manifests/software.json") $true
        Assert-KitEqual $report.whatIf $true
    }

    It "keeps failed, manual, warning, and orphan details in the report" {
        $capabilities = @(
            [pscustomobject]@{ id = "passed"; issue = "#11"; status = "implemented"; context = "machine"; mutationLevel = "audit-only"; manifest = "manifests/context-scope.json"; schema = "schemas/context-scope.schema.json"; entrypoints = @(); validateEntrypoints = @(); tests = @("tests/pester/ContextScopeSchema.Tests.ps1"); docs = @("docs/24-issue10-context-scope-split.md"); notes = "fixture" },
            [pscustomobject]@{ id = "manual"; issue = "#11"; status = "implemented"; context = "mixed"; mutationLevel = "plan-only"; manifest = "manifests/context-scope.json"; schema = "schemas/context-scope.schema.json"; entrypoints = @(); validateEntrypoints = @(); tests = @("tests/pester/ContextScopeSchema.Tests.ps1"); docs = @("docs/24-issue10-context-scope-split.md"); notes = "fixture" },
            [pscustomobject]@{ id = "failed"; issue = "#11"; status = "implemented"; context = "machine"; mutationLevel = "unknown"; manifest = "manifests/context-scope.json"; schema = "schemas/context-scope.schema.json"; entrypoints = @("scripts/common/Missing.ps1"); validateEntrypoints = @(); tests = @(); docs = @(); notes = "fixture" }
        )
        $registry = [pscustomobject]@{ capabilities = $capabilities }
        $report = New-KitCapabilityConsistencyReport -Registry $registry -RepoRoot $script:RepoRoot -WhatIf

        Assert-KitEqual $report.status "failed"
        Assert-KitEqual $report.summary.passedCount 1
        Assert-KitEqual $report.summary.manualCount 1
        Assert-KitEqual $report.summary.failedCount 1
        Assert-KitEqual ($report.summary.warningCount -gt 0) $true
        Assert-KitEqual (@($report.capabilities | Where-Object { $_.id -eq "failed" }).Count) 1
        Assert-KitEqual (@($report.orphanManifests).Count -gt 0) $true
    }

    It "serializes report JSON and writes an explicit temp report path" {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-capability-report-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
        $reportPath = Join-Path $tempRoot "capability-consistency.json"
        try {
            & (Join-Path $script:RepoRoot "scripts\validate\Test-CapabilityRegistry.ps1") -ReportPath $reportPath | Out-Null
            $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $json = $report | ConvertTo-Json -Depth 10

            Assert-KitMatch $json "capability-consistency"
            Assert-KitEqual $report.reportType "capability-consistency"
            Assert-KitEqual $report.status "passed"
            Assert-KitEqual @($report.capabilities).Count 5
        } finally {
            if ([IO.Directory]::Exists($tempRoot)) {
                [IO.Directory]::Delete($tempRoot, $true)
            }
        }
    }
}
