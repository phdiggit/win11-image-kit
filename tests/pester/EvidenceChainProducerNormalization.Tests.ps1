Describe "Evidence chain producer normalization" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitEvidenceChainReport.ps1")
    }

    It "normalizes existing report-only producers" {
        $report = New-KitEvidenceChainReport -RepoRoot $script:RepoRoot
        foreach ($producerId in @("project-config", "build-lock", "quality-gates", "effective-configuration", "pester-summary")) {
            $item = @($report.evidence | Where-Object { $_.producerId -eq $producerId })[0]
            Assert-KitEqual $item.status "passed"
            Assert-KitEqual $item.manual $false
            Assert-KitEqual $item.runId $report.runId
        }

        Assert-KitEqual $report.producerNormalization.normalizedCount 5
        Assert-KitEqual $report.producerNormalization.missingRequiredCount 0
        Assert-KitEqual $report.producerNormalization.reportTypeMismatchCount 0
        Assert-KitEqual $report.producerNormalization.disallowedManualCount 0
        Assert-KitEqual $report.producerNormalization.disallowedNotCapturedCount 0
        Assert-KitEqual $report.producerNormalization.inputPolicyViolationCount 0
    }

    It "keeps lifecycle placeholders out of passed counts" {
        $report = New-KitEvidenceChainReport -RepoRoot $script:RepoRoot
        foreach ($producerId in @("real-build", "capture", "deploy")) {
            $item = @($report.evidence | Where-Object { $_.producerId -eq $producerId })[0]
            Assert-KitEqual $item.status "not-captured"
            Assert-KitEqual $item.manual $true
            Assert-KitEqual $item.runId "not-captured"
        }

        $smoke = @($report.evidence | Where-Object { $_.producerId -eq "admin-vm-smoke" })[0]
        Assert-KitEqual $smoke.status "manual"
        Assert-KitEqual $smoke.runId "manual"
        Assert-KitEqual $report.summary.passedCount 5
    }
}
