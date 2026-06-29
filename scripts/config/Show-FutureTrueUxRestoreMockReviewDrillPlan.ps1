[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$RequestPath = "tests/fixtures/user-experience/future-true-restore/mock-review/current-user-complete-packet.json"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreMockReviewDrillReport.ps1"
. "$PSScriptRoot\..\common\FutureTrueUxRestore.PresentationPrimitives.ps1"

$repoRoot = Get-FutureTrueUxRestorePresentationRepoRoot -PresentationScriptRoot $PSScriptRoot

$manifest = Read-FutureTrueUxRestorePresentationJson -RepoRoot $repoRoot -Path $ManifestPath
$request = Read-FutureTrueUxRestorePresentationJson -RepoRoot $repoRoot -Path $RequestPath
$report = New-FutureTrueUxRestoreMockReviewDrillReport -Manifest $manifest -Request $request -RepoRoot $repoRoot

Write-FutureTrueUxRestorePresentationHeader -Title "Future true UX restore mock review drill plan"
Write-FutureTrueUxRestorePresentationLine -Label "Mock drill only" -Value "true"
Write-FutureTrueUxRestorePresentationLine -Label "Scope" -Value $report.scope
Write-FutureTrueUxRestorePresentationLine -Label "Packet status" -Value $report.packetStatus
Write-FutureTrueUxRestorePresentationLine -Label "Review decision" -Value $report.reviewDecision
Write-FutureTrueUxRestorePresentationLine -Label "Execution decision" -Value $report.executionDecision
Write-FutureTrueUxRestorePresentationLine -Label "AuthorizationApproved" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "ExecutionApproved" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "ExecuteReady" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "True execution" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "Mutation count" -Value 0
Write-FutureTrueUxRestorePresentationLine -Label "Execution frozen" -Value "true"
Write-FutureTrueUxRestorePresentationList -Title "Decision ledger:" -Items $report.decisionLedger -FormatItem {
    param($entry)
    "{0}: {1}" -f $entry.stage, $entry.decision
}
Write-FutureTrueUxRestorePresentationList -Title "Blocked reasons:" -Items $report.blockedReasons -FormatItem {
    param($reason)
    $reason
}

Write-FutureTrueUxRestorePresentationReportJson -ReportObject $report -Depth 12
