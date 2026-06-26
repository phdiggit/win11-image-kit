Describe "Controlled execution report builder" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitControlledExecutionReport.ps1")
    }

    It "generates a report-only baseline without executed actions" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\controlled-execution.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $report = New-KitControlledExecutionReport -Manifest $manifest -RepoRoot $script:RepoRoot -WhatIf

        Assert-KitEqual $report.reportType "controlled-execution"
        Assert-KitEqual $report.whatIf $true
        Assert-KitEqual $report.trueExecution $false
        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.summary.failedCount 0
        Assert-KitEqual $report.summary.blockedActionCount 0
        Assert-KitEqual $report.summary.plannedActionCount $report.summary.actionCount
        foreach ($action in @($report.actions)) {
            Assert-KitEqual $action.executed $false
            Assert-KitEqual $action.status "planned"
        }
    }

    It "keeps WinPE actions planned rather than executed" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\controlled-execution.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $report = New-KitControlledExecutionReport -Manifest $manifest -RepoRoot $script:RepoRoot -WhatIf
        $winpeAction = @($report.actions | Where-Object { $_.requiresWinPE })[0]

        Assert-KitNotNullOrEmpty $winpeAction
        Assert-KitEqual $winpeAction.status "planned"
        Assert-KitEqual $winpeAction.executed $false
    }
}
