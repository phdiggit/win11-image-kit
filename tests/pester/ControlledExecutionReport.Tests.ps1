Describe "Controlled execution report builder" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitControlledExecutionReport.ps1")
    }

    It "does not execute actions even when fixture inputs are missing" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\controlled-execution.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $report = New-KitControlledExecutionReport -Manifest $manifest -RepoRoot $script:RepoRoot -WhatIf

        Assert-KitEqual $report.reportType "controlled-execution"
        Assert-KitEqual $report.whatIf $true
        Assert-KitEqual $report.trueExecution $false
        Assert-KitEqual $report.status "failed"
        Assert-KitEqual $report.summary.failedCount 0
        Assert-KitEqual $report.summary.blockedActionCount 0
        Assert-KitEqual $report.summary.diskIdentityMismatchCount 1
        Assert-KitEqual $report.summary.confirmationTokenFailureCount 1
        Assert-KitEqual $report.summary.wimValidationFailureCount 1
        Assert-KitEqual $report.summary.winrePlanFailureCount 1
        Assert-KitEqual $report.summary.nativeCommandFailureCount 1
        Assert-KitEqual $report.summary.plannedActionCount $report.summary.actionCount
        Assert-KitEqual $report.inputs.diskIdentity.status "blocked"
        foreach ($action in @($report.actions)) {
            Assert-KitEqual $action.executed $false
            Assert-KitEqual $action.status "planned"
        }
    }

    It "generates a passing report when baseline fixture inputs are supplied" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\controlled-execution.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $diskIdentity = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\disk-identity\matched.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $confirmationToken = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\confirmation-token\matched.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $wimMetadata = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\wim-image\matched.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $winrePlan = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\winre-plan\planned.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $nativeCommandPlan = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\native-command\planned.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        $report = New-KitControlledExecutionReport `
            -Manifest $manifest `
            -RepoRoot $script:RepoRoot `
            -DiskIdentity $diskIdentity `
            -ConfirmationToken $confirmationToken `
            -WimMetadata $wimMetadata `
            -WinREPlan $winrePlan `
            -NativeCommandPlan $nativeCommandPlan `
            -WhatIf

        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.inputs.diskIdentity.status "matched"
        Assert-KitEqual $report.inputs.confirmationToken.status "matched"
        Assert-KitEqual $report.inputs.wimMetadata.status "matched"
        Assert-KitEqual $report.inputs.winrePlan.status "planned"
        Assert-KitEqual $report.inputs.nativeCommandPlan.status "planned"
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
