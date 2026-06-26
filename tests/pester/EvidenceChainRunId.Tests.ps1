Describe "Evidence chain Run ID linkage" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitEvidenceChainReport.ps1")
    }

    It "generates a required pattern-valid runId" {
        $report = New-KitEvidenceChainReport -RepoRoot $script:RepoRoot -SourceSha "5688a741e98a29572a99dc1e025b9f97c7876dc3"

        Assert-KitMatch $report.runId '^kit-run-[0-9]{8}T[0-9]{6}Z-[a-f0-9]{7,12}$'
        Assert-KitEqual ($report.PSObject.Properties.Name -contains "lifecycle") $true
        Assert-KitEqual $report.lifecycle.configRunId $report.runId
        Assert-KitEqual $report.lifecycle.validateRunId $report.runId
        Assert-KitEqual $report.lifecycle.buildRunId "not-captured"
        Assert-KitEqual $report.lifecycle.captureRunId "not-captured"
        Assert-KitEqual $report.lifecycle.deployRunId "not-captured"
        Assert-KitEqual $report.lifecycle.acceptanceRunId "manual"
    }

    It "accepts explicit runId and upstreamRunId values" {
        $runId = "kit-run-20260626T123456Z-a659a041"
        $upstreamRunId = "kit-run-20260625T123456Z-b659a041"
        $report = New-KitEvidenceChainReport -RepoRoot $script:RepoRoot -RunId $runId -UpstreamRunId $upstreamRunId

        Assert-KitEqual $report.runId $runId
        Assert-KitEqual $report.upstreamRunId $upstreamRunId
        Assert-KitEqual (@($report.stageLinks | Where-Object { $_.stage -eq "config" })[0].runId) $runId
        Assert-KitEqual (@($report.stageLinks | Where-Object { $_.stage -eq "validate" })[0].upstreamRunId) $upstreamRunId
    }

    It "keeps fixture run linkage pattern-valid" {
        $fixture = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\evidence-chain\sample-run-linkage.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitMatch $fixture.runId '^kit-run-[0-9]{8}T[0-9]{6}Z-[a-f0-9]{7,12}$'
        foreach ($link in @($fixture.stageLinks)) {
            Assert-KitMatch ([string]$link.runId) '^(kit-run-[0-9]{8}T[0-9]{6}Z-[a-f0-9]{7,12}|manual|not-captured)$'
        }
    }

    It "shows runId, artifact count, and redaction summary" {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $script:RepoRoot "scripts\config\Show-EvidenceChain.ps1") 2>&1
        $text = $output -join "`n"

        Assert-KitMatch $text "Run ID:"
        Assert-KitMatch $text "artifacts=4"
        Assert-KitMatch $text "Redactions: redacted=1; blocked=0"
    }
}
