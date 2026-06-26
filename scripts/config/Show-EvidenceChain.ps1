[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/evidence-chain.json",
    [string]$InputDirectory = "tests/fixtures/evidence-chain/sample-report-inputs",
    [ValidateSet("fixture", "local", "ci", "main", "workflow_dispatch", "manual")]
    [string]$SourceKind = "fixture",
    [string]$SourceSha,
    [string]$WorkflowRunUrl,
    [string]$JobUrl
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
    -RepoRoot $repoRoot

Write-Host ("Evidence chain: {0}" -f $report.chainId)
Write-Host ("Status: {0}" -f $report.status)
Write-Host ("Source: {0}" -f $report.source.kind)
Write-Host ("Summary: stages={0}; producers={1}; passed={2}; failed={3}; manual={4}; not-captured={5}" -f `
    $report.summary.stageCount, `
    $report.summary.producerCount, `
    $report.summary.passedCount, `
    $report.summary.failedCount, `
    $report.summary.manualCount, `
    $report.summary.notCapturedCount)

foreach ($stage in @($report.stages)) {
    Write-Host ("- {0}: {1} (producers={2}, passed={3}, failed={4}, manual={5}, not-captured={6})" -f `
        $stage.stage, `
        $stage.status, `
        $stage.producerCount, `
        $stage.passedCount, `
        $stage.failedCount, `
        $stage.manualCount, `
        $stage.notCapturedCount)
}

$report
