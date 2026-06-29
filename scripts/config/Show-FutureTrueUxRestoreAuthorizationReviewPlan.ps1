[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$RequestPath = "tests/fixtures/user-experience/future-true-restore/review/baseline-blocked.json"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreAuthorizationReviewReport.ps1"
. "$PSScriptRoot\..\common\FutureTrueUxRestore.PresentationPrimitives.ps1"

$repoRoot = Get-FutureTrueUxRestorePresentationRepoRoot -PresentationScriptRoot $PSScriptRoot

$manifest = Read-FutureTrueUxRestorePresentationJson -RepoRoot $repoRoot -Path $ManifestPath
$request = Read-FutureTrueUxRestorePresentationJson -RepoRoot $repoRoot -Path $RequestPath
$report = New-FutureTrueUxRestoreAuthorizationReviewReport -Manifest $manifest -Request $request -RepoRoot $repoRoot

Write-FutureTrueUxRestorePresentationHeader -Title "Future true UX restore authorization review plan"
Write-FutureTrueUxRestorePresentationLine -Label "Review workflow only" -Value "true"
Write-FutureTrueUxRestorePresentationLine -Label "AuthorizationApproved" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "ExecutionApproved" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "ExecuteReady" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "True execution" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "Mutation count" -Value 0
Write-FutureTrueUxRestorePresentationLine -Label "Review decision" -Value $report.reviewDecision
Write-FutureTrueUxRestorePresentationList -Title "Allowed review decisions:" -Items $report.allowedReviewDecisions -FormatItem {
    param($decision)
    $decision
}
Write-FutureTrueUxRestorePresentationList -Title "Forbidden review decisions:" -Items $report.forbiddenReviewDecisions -FormatItem {
    param($decision)
    $decision
}
Write-FutureTrueUxRestorePresentationList -Title "Required packet fields:" -Items $manifest.authorizationReview.requiredPacketFields -FormatItem {
    param($field)
    $field
}
Write-FutureTrueUxRestorePresentationList -Title "Blocked reasons:" -Items $report.blockedReasons -FormatItem {
    param($reason)
    $reason
}

Write-FutureTrueUxRestorePresentationReportJson -ReportObject $report -Depth 12
