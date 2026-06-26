Describe "Evidence chain report builder" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitEvidenceChainReport.ps1")
    }

    It "generates the baseline report with manual placeholders separated from passed evidence" {
        $report = New-KitEvidenceChainReport -RepoRoot $script:RepoRoot -SourceSha "5688a741e98a29572a99dc1e025b9f97c7876dc3"

        Assert-KitEqual $report.reportType "evidence-chain"
        Assert-KitEqual $report.schemaVersion 1
        Assert-KitEqual $report.inputSetId "issue16-pr-fast-fixture"
        Assert-KitEqual $report.summary.stageCount 6
        Assert-KitEqual $report.summary.producerCount 9
        Assert-KitEqual $report.summary.passedCount 5
        Assert-KitEqual $report.summary.failedCount 0
        Assert-KitEqual $report.summary.manualCount 1
        Assert-KitEqual $report.summary.notCapturedCount 3
        Assert-KitEqual $report.status "manual"
        Assert-KitEqual @($report.inputReports).Count 5
        Assert-KitEqual $report.producerNormalization.normalizedCount 5
        Assert-KitEqual $report.producerNormalization.missingRequiredCount 0

        foreach ($producerId in @("real-build", "capture", "deploy")) {
            $item = @($report.evidence | Where-Object { $_.producerId -eq $producerId })[0]
            Assert-KitEqual $item.status "not-captured"
            Assert-KitEqual $item.manual $true
            Assert-KitEqual $item.reproducible $false
        }

        $smoke = @($report.evidence | Where-Object { $_.producerId -eq "admin-vm-smoke" })[0]
        Assert-KitEqual $smoke.status "manual"
        Assert-KitEqual $smoke.manual $true
    }

    It "keeps report artifact references non-private and repo-relative" {
        $report = New-KitEvidenceChainReport -RepoRoot $script:RepoRoot

        foreach ($item in @($report.evidence)) {
            foreach ($artifact in @($item.artifactReferences)) {
                Assert-KitEqual $artifact.private $false
                Assert-KitNotMatch ([string]$artifact.path) '(^|[\\/])paths\.local\.json$'
                Assert-KitNotMatch ([string]$artifact.path) '^[A-Za-z]:[\\/]'
                Assert-KitNotMatch ([string]$artifact.path) '^\\\\'
            }
        }
    }
}
