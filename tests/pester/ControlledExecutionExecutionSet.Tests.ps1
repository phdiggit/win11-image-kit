Describe "Controlled execution execution-set matrix" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitControlledExecutionReport.ps1")

        $script:Manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\controlled-execution.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:DiskIdentity = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\disk-identity\matched.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:ConfirmationToken = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\confirmation-token\matched.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:WimMetadata = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\wim-image\matched.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:WinREPlan = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\winre-plan\planned.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:NativeCommandPlan = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\native-command\planned.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:Authorization = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\authorization\matched.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:NativeCommandSimulation = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\native-command-simulation\baseline-success.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    }

    function New-BaselineExecutionSetReport {
        param(
            [AllowNull()]$Manifest = $script:Manifest,
            [AllowNull()]$NativeCommandSimulation = $script:NativeCommandSimulation
        )

        New-KitControlledExecutionReport `
            -Manifest $Manifest `
            -RepoRoot $script:RepoRoot `
            -DiskIdentity $script:DiskIdentity `
            -ConfirmationToken $script:ConfirmationToken `
            -WimMetadata $script:WimMetadata `
            -WinREPlan $script:WinREPlan `
            -NativeCommandPlan $script:NativeCommandPlan `
            -Authorization $script:Authorization `
            -NativeCommandSimulation $NativeCommandSimulation `
            -WhatIf
    }

    It "includes the Issue 17 execution-set matrix and keeps all actions unexecuted" {
        $report = New-BaselineExecutionSetReport
        $stages = @($report.stageResults.stage)

        foreach ($stage in @("preflight", "disk-identity", "confirmation-token", "wim-validation", "partition-plan", "apply-plan", "boot-plan", "winre-plan", "native-command-simulation", "final-report")) {
            Assert-KitEqual ($stages -contains $stage) $true
        }

        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.summary.dependencyBlockedCount 0
        foreach ($action in @($report.actions)) {
            Assert-KitEqual $action.executed $false
        }
    }

    It "blocks downstream actions when a dependency is blocked" {
        $manifest = $script:Manifest | ConvertTo-Json -Depth 12 | ConvertFrom-Json
        $partition = @($manifest.actions | Where-Object { $_.id -eq "partition-plan" })[0]
        $partition.mutationKind = "disk"

        $report = New-BaselineExecutionSetReport -Manifest $manifest
        $applyPlan = @($report.actions | Where-Object { $_.id -eq "apply-plan" })[0]

        Assert-KitEqual $report.status "failed"
        Assert-KitEqual $applyPlan.status "blocked"
        Assert-KitMatch $applyPlan.reason "blocked by dependency"
        if ($report.summary.dependencyBlockedCount -lt 1) {
            throw "Expected dependencyBlockedCount to be greater than zero."
        }
    }

    It "blocks the final report after a simulated native command failure" {
        $failedSimulation = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\native-command-simulation\reagentc-failure.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $report = New-BaselineExecutionSetReport -NativeCommandSimulation $failedSimulation
        $finalReport = @($report.actions | Where-Object { $_.id -eq "final-report" })[0]

        Assert-KitEqual $report.status "failed"
        Assert-KitEqual $report.summary.simulatedFailureCount 1
        Assert-KitEqual $finalReport.status "blocked"
        Assert-KitMatch $finalReport.reason "blocked by dependency"
    }
}
