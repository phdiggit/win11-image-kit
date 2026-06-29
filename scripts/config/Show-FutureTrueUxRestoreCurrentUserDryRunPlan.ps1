[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$RequestPath = "tests/fixtures/user-experience/future-true-restore/current-user/baseline-blocked.json"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreCurrentUserDryRunReport.ps1"
. "$PSScriptRoot\..\common\FutureTrueUxRestore.PresentationPrimitives.ps1"

$repoRoot = Get-FutureTrueUxRestorePresentationRepoRoot -PresentationScriptRoot $PSScriptRoot

$report = New-FutureTrueUxRestoreCurrentUserDryRunReport `
    -Manifest (Read-FutureTrueUxRestorePresentationJson -RepoRoot $repoRoot -Path $ManifestPath) `
    -Request (Read-FutureTrueUxRestorePresentationJson -RepoRoot $repoRoot -Path $RequestPath) `
    -RepoRoot $repoRoot

Write-FutureTrueUxRestorePresentationHeader -Title "Future true UX restore current-user dry-run plan"
Write-FutureTrueUxRestorePresentationLine -Label "Scope" -Value "current-user"
Write-FutureTrueUxRestorePresentationLine -Label "Dry-run only" -Value "true"
Write-FutureTrueUxRestorePresentationLine -Label "AuthorizationApproved" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "ExecutionApproved" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "Decision" -Value $report.decision
Write-FutureTrueUxRestorePresentationLine -Label "True execution" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "Mutation count" -Value 0
Write-FutureTrueUxRestorePresentationLine -Label "Current user confirmed" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "Command exit code sufficient" -Value "false"
Write-FutureTrueUxRestorePresentationObjectProperties -Title "Required evidence:" -InputObject $report.evidenceContract
Write-FutureTrueUxRestorePresentationList -Title "Blocked reasons:" -Items $report.blockedReasons -FormatItem {
    param($reason)
    $reason
}

Write-FutureTrueUxRestorePresentationReportJson -ReportObject $report -Depth 12
