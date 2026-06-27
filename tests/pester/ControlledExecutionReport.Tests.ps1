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
        if ($report.summary.failedCount -lt 1) {
            throw "Expected a failed action when native simulation input is missing."
        }
        if ($report.summary.blockedActionCount -lt 1) {
            throw "Expected blocked actions when authorization input is missing."
        }
        Assert-KitEqual $report.summary.diskIdentityMismatchCount 1
        Assert-KitEqual $report.summary.confirmationTokenFailureCount 1
        Assert-KitEqual $report.summary.wimValidationFailureCount 1
        Assert-KitEqual $report.summary.winrePlanFailureCount 1
        Assert-KitEqual $report.summary.nativeCommandFailureCount 1
        Assert-KitEqual $report.summary.authorizationFailureCount 1
        Assert-KitEqual $report.summary.simulatedCommandCount 0
        Assert-KitEqual $report.inputs.diskIdentity.status "blocked"
        foreach ($action in @($report.actions)) {
            Assert-KitEqual $action.executed $false
        }
    }

    It "generates a passing report when baseline fixture inputs are supplied" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\controlled-execution.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $diskIdentity = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\disk-identity\matched.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $confirmationToken = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\confirmation-token\matched.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $wimMetadata = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\wim-image\matched.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $winrePlan = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\winre-plan\planned.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $nativeCommandPlan = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\native-command\planned.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $authorization = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\authorization\matched.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $nativeCommandSimulation = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\native-command-simulation\baseline-success.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        $report = New-KitControlledExecutionReport `
            -Manifest $manifest `
            -RepoRoot $script:RepoRoot `
            -DiskIdentity $diskIdentity `
            -ConfirmationToken $confirmationToken `
            -WimMetadata $wimMetadata `
            -WinREPlan $winrePlan `
            -NativeCommandPlan $nativeCommandPlan `
            -Authorization $authorization `
            -NativeCommandSimulation $nativeCommandSimulation `
            -WhatIf

        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.inputs.diskIdentity.status "matched"
        Assert-KitEqual $report.inputs.confirmationToken.status "matched"
        Assert-KitEqual $report.inputs.wimMetadata.status "matched"
        Assert-KitEqual $report.inputs.winrePlan.status "planned"
        Assert-KitEqual $report.inputs.nativeCommandPlan.status "planned"
        Assert-KitEqual $report.authorization.status "planned"
        Assert-KitEqual $report.simulation.status "simulated-success"
    }

    It "keeps WinPE actions unexecuted even when missing inputs block planning" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\controlled-execution.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $report = New-KitControlledExecutionReport -Manifest $manifest -RepoRoot $script:RepoRoot -WhatIf
        $winpeAction = @($report.actions | Where-Object { $_.requiresWinPE })[0]

        Assert-KitNotNullOrEmpty $winpeAction
        Assert-KitEqual $winpeAction.executed $false
    }
}
