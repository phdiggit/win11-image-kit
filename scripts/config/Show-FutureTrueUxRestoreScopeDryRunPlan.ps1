[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreScopeDryRunReport.ps1"
. "$PSScriptRoot\..\common\FutureTrueUxRestore.PresentationPrimitives.ps1"

$repoRoot = Get-FutureTrueUxRestorePresentationRepoRoot -PresentationScriptRoot $PSScriptRoot

$fixtureRoot = "tests/fixtures/user-experience/future-true-restore"
$requestsByScope = @{
    "current-user" = Read-FutureTrueUxRestorePresentationJson -RepoRoot $repoRoot -Path "$fixtureRoot/current-user/baseline-blocked.json"
    "default-user" = Read-FutureTrueUxRestorePresentationJson -RepoRoot $repoRoot -Path "$fixtureRoot/default-user/baseline-blocked.json"
    "offline-image" = Read-FutureTrueUxRestorePresentationJson -RepoRoot $repoRoot -Path "$fixtureRoot/offline-image/baseline-blocked.json"
    "machine" = Read-FutureTrueUxRestorePresentationJson -RepoRoot $repoRoot -Path "$fixtureRoot/machine/baseline-blocked.json"
}

$report = New-FutureTrueUxRestoreScopeDryRunReport `
    -Manifest (Read-FutureTrueUxRestorePresentationJson -RepoRoot $repoRoot -Path $ManifestPath) `
    -RequestsByScope $requestsByScope `
    -RepoRoot $repoRoot

Write-FutureTrueUxRestorePresentationHeader -Title "Future true UX restore scope dry-run plan"
Write-FutureTrueUxRestorePresentationLine -Label "Dry-run only" -Value "true"
Write-FutureTrueUxRestorePresentationLine -Label "AuthorizationApproved" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "ExecutionApproved" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "Aggregate decision" -Value $report.aggregateDecision
Write-FutureTrueUxRestorePresentationLine -Label "True execution" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "Mutation count" -Value 0
Write-FutureTrueUxRestorePresentationLine -Label "Command exit code sufficient" -Value "false"

foreach ($scopeReport in @($report.scopeReports)) {
    Write-Host ""
    Write-FutureTrueUxRestorePresentationLine -Label "Scope" -Value $scopeReport.scope
    Write-FutureTrueUxRestorePresentationLine -Label "Decision" -Value $scopeReport.decision
    Write-FutureTrueUxRestorePresentationObjectProperties -Title "Required evidence:" -InputObject $scopeReport.evidenceContract
    Write-FutureTrueUxRestorePresentationList -Title "Blocked reasons:" -Items $scopeReport.blockedReasons -FormatItem {
        param($reason)
        $reason
    }
}

Write-FutureTrueUxRestorePresentationReportJson -ReportObject $report -Depth 12
