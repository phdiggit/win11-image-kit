Describe "Quality gate report" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitQualityGateReport.ps1")
        $script:Manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    }

    It "creates a report-only object with summary and safety fields" {
        $report = New-KitQualityGateReport -QualityGateManifest $script:Manifest -RepoRoot $script:RepoRoot -WhatIf

        Assert-KitEqual $report.reportType "quality-gates"
        Assert-KitEqual $report.status "manual"
        Assert-KitEqual $report.summary.totalCount @($script:Manifest.gates).Count
        Assert-KitEqual $report.summary.failedCount 0
        Assert-KitEqual $report.summary.manualCount 1
        Assert-KitEqual $report.safety.realBuild $false
        Assert-KitEqual $report.safety.realMutation $false
        Assert-KitEqual $report.safety.networkDownload $false
        Assert-KitEqual $report.safety.registryProfileHiveWrite $false
        Assert-KitEqual $report.whatIf $true
    }

    It "marks the analyzer gate as manual and non-blocking" {
        $report = New-KitQualityGateReport -QualityGateManifest $script:Manifest -RepoRoot $script:RepoRoot -WhatIf
        $gate = @($report.gates | Where-Object { $_.id -eq "psscriptanalyzer" })[0]

        Assert-KitEqual $gate.blocking $false
        Assert-KitEqual $gate.status "manual"
        Assert-KitMatch ($gate.warnings -join "`n") "manual or non-blocking"
    }

    It "fails missing entrypoints and true-execution gates" {
        $fixture = [pscustomobject]@{
            manifestVersion = 1
            gates = @(
                [pscustomobject]@{
                    id = "bad-entrypoint"
                    displayName = "Bad entrypoint"
                    layer = "pr-fast"
                    trigger = "pull_request"
                    mode = "static"
                    required = $true
                    blocking = $true
                    entrypoint = "missing\quality-gate.txt"
                    evidence = "report"
                    notes = "fixture"
                },
                [pscustomobject]@{
                    id = "true-execution"
                    displayName = "True execution"
                    layer = "future-true-execution"
                    trigger = "separate-issue"
                    mode = "true-execution"
                    required = $true
                    blocking = $true
                    entrypoint = "README.md"
                    evidence = "manual"
                    notes = "fixture"
                }
            )
        }

        $report = New-KitQualityGateReport -QualityGateManifest $fixture -RepoRoot $script:RepoRoot -WhatIf

        Assert-KitEqual $report.status "failed"
        Assert-KitEqual $report.summary.failedCount 2
        Assert-KitMatch (($report.gates.errors | ForEach-Object { $_ }) -join "`n") "true-execution"
        Assert-KitMatch (($report.gates.errors | ForEach-Object { $_ }) -join "`n") "entrypoint missing"
    }
}
