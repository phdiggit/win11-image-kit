[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/evidence-chain.json",
    [string]$InputDirectory = "tests/fixtures/evidence-chain/sample-report-inputs",
    [ValidateSet("fixture", "local", "ci", "main", "workflow_dispatch", "manual")]
    [string]$SourceKind = "fixture",
    [string]$SourceSha,
    [string]$WorkflowRunUrl,
    [string]$JobUrl,
    [string]$RunId,
    [string]$UpstreamRunId,
    [string]$ArtifactIndexPath = "tests/fixtures/evidence-chain/sample-artifact-index.json"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-KitEvidenceChainReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$report = New-KitEvidenceChainReport `
    -ManifestPath $ManifestPath `
    -InputDirectory $InputDirectory `
    -SourceKind $SourceKind `
    -SourceSha $SourceSha `
    -WorkflowRunUrl $WorkflowRunUrl `
    -JobUrl $JobUrl `
    -RunId $RunId `
    -UpstreamRunId $UpstreamRunId `
    -ArtifactIndexPath $ArtifactIndexPath `
    -RepoRoot $repoRoot

Write-Host ("Evidence chain: {0}" -f $report.chainId)
Write-Host ("Status: {0}" -f $report.status)
Write-Host ("Run ID: {0}" -f $report.runId)
if ($report.PSObject.Properties.Name -contains "upstreamRunId") {
    Write-Host ("Upstream Run ID: {0}" -f $report.upstreamRunId)
}
Write-Host ("Source: {0}" -f $report.source.kind)
Write-Host ("Summary: stages={0}; producers={1}; passed={2}; failed={3}; manual={4}; not-captured={5}; artifacts={6}" -f `
    $report.summary.stageCount, `
    $report.summary.producerCount, `
    $report.summary.passedCount, `
    $report.summary.failedCount, `
    $report.summary.manualCount, `
    $report.summary.notCapturedCount, `
    $report.summary.artifactCount)
Write-Host ("Redactions: redacted={0}; blocked={1}" -f $report.redactions.redactedCount, $report.redactions.blockedCount)

foreach ($stage in @($report.stages)) {
    Write-Host ("- {0}: {1} (runId={2}, producers={3}, passed={4}, failed={5}, manual={6}, not-captured={7})" -f `
        $stage.stage, `
        $stage.status, `
        $stage.runId, `
        $stage.producerCount, `
        $stage.passedCount, `
        $stage.failedCount, `
        $stage.manualCount, `
        $stage.notCapturedCount)
}

$report
