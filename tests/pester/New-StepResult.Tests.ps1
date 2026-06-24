$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
. (Join-Path $RepoRoot "tests\pester\TestHelpers.ps1")
. (Join-Path $RepoRoot "scripts\common\New-StepResult.ps1")

Describe "Step result model" {
    It "creates changed results with required default" {
        $result = New-KitStepResult -Name "install-tool" -Status changed

        Assert-KitEqual $result.status "changed"
        Assert-KitEqual $result.changed $true
        Assert-KitEqual $result.required $true
    }

    It "creates unchanged results without changed flag" {
        $result = New-KitStepResult -Name "already-ready" -Status unchanged

        Assert-KitEqual $result.status "unchanged"
        Assert-KitEqual $result.changed $false
    }

    It "keeps skipped reason" {
        $result = New-KitStepResult -Name "disabled-step" -Status skipped -SkippedReason "scope-disabled"

        Assert-KitEqual $result.status "skipped"
        Assert-KitEqual $result.skippedReason "scope-disabled"
    }

    It "keeps manual action" {
        $result = New-KitStepResult -Name "manual-installer" -Status manual -ManualAction "run setup.exe"

        Assert-KitEqual $result.status "manual"
        Assert-KitEqual $result.manualAction "run setup.exe"
    }

    It "marks whatif results as preview and unchanged" {
        $result = New-KitStepResult -Name "preview-step" -Status whatif

        Assert-KitEqual $result.status "whatif"
        Assert-KitEqual $result.whatIf $true
        Assert-KitEqual $result.changed $false
    }

    It "keeps failed errors as an array" {
        $result = New-KitStepResult -Name "required-step" -Status failed -Errors @("missing source")

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.errors.Count 1
        Assert-KitEqual $result.errors[0] "missing source"
    }

    It "makes required failures blocking" {
        $summary = Get-KitStepResultSummary -Results @(
            (New-KitStepResult -Name "required-step" -Status failed -Required $true -Errors @("failed"))
        )

        Assert-KitEqual $summary.hasBlockingFailure $true
        Assert-KitEqual $summary.failedRequiredCount 1
        Assert-KitEqual $summary.exitCode 1
    }

    It "counts optional failures without changing exit code by itself" {
        $summary = Get-KitStepResultSummary -Results @(
            (New-KitStepResult -Name "optional-step" -Status failed -Required $false -Errors @("missing optional source"))
        )

        Assert-KitEqual $summary.hasBlockingFailure $false
        Assert-KitEqual $summary.failedOptionalCount 1
        Assert-KitEqual $summary.exitCode 0
    }

    It "counts mixed statuses" {
        $summary = Get-KitStepResultSummary -Results @(
            (New-KitStepResult -Name "changed" -Status changed),
            (New-KitStepResult -Name "unchanged" -Status unchanged),
            (New-KitStepResult -Name "skipped" -Status skipped -SkippedReason "disabled"),
            (New-KitStepResult -Name "manual" -Status manual -ManualAction "manual setup"),
            (New-KitStepResult -Name "whatif" -Status whatif),
            (New-KitStepResult -Name "failed" -Status failed -Errors @("failed"))
        )

        Assert-KitEqual $summary.statusCounts.changed 1
        Assert-KitEqual $summary.statusCounts.unchanged 1
        Assert-KitEqual $summary.statusCounts.skipped 1
        Assert-KitEqual $summary.statusCounts.manual 1
        Assert-KitEqual $summary.statusCounts.whatif 1
        Assert-KitEqual $summary.statusCounts.failed 1
    }

    It "sets comparable timestamps" {
        $startedAt = Get-Date
        $endedAt = $startedAt.AddSeconds(1)
        $result = New-KitStepResult -Name "timed-step" -Status unchanged -StartedAt $startedAt -EndedAt $endedAt

        Assert-KitNotNullOrEmpty $result.startedAt
        Assert-KitNotNullOrEmpty $result.endedAt
        if ([datetime]::Parse($result.endedAt) -lt [datetime]::Parse($result.startedAt)) {
            throw "endedAt is earlier than startedAt."
        }
    }
}
