[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$AuthorizationPath = "tests/fixtures/user-experience/future-true-restore/authorization/baseline-blocked.json"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreAuthorizationReport.ps1"
. "$PSScriptRoot\..\common\FutureTrueUxRestore.PresentationPrimitives.ps1"

$repoRoot = Get-FutureTrueUxRestorePresentationRepoRoot -PresentationScriptRoot $PSScriptRoot

$report = New-FutureTrueUxRestoreAuthorizationReport `
    -Manifest (Read-FutureTrueUxRestorePresentationJson -RepoRoot $repoRoot -Path $ManifestPath) `
    -AuthorizationRequest (Read-FutureTrueUxRestorePresentationJson -RepoRoot $repoRoot -Path $AuthorizationPath) `
    -RepoRoot $repoRoot

Write-FutureTrueUxRestorePresentationHeader -Title "Future true UX restore authorization intake plan"
Write-FutureTrueUxRestorePresentationLine -Label "Dry-run only" -Value "true"
Write-FutureTrueUxRestorePresentationLine -Label "Default deny" -Value "true"
Write-FutureTrueUxRestorePresentationLine -Label "Decision" -Value $report.decision
Write-FutureTrueUxRestorePresentationLine -Label "True execution" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "Mutation count" -Value 0
Write-FutureTrueUxRestorePresentationLine -Label "Command exit code sufficient" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "User configuration confirmed" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "Registry mutation" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "Profile mutation" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "Default User hive mutation" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "Default app mutation" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "Start menu mutation" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "Taskbar mutation" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "Image servicing mutation" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "AppX mutation" -Value "false"
Write-FutureTrueUxRestorePresentationLine -Label "Network download" -Value "false"
Write-FutureTrueUxRestorePresentationList -Title "Required scopes:" -Items $report.evidenceRequirements -FormatItem {
    param($item)
    "{0}: {1}" -f $item.scope, $item.safetyGate
}

Write-FutureTrueUxRestorePresentationReportJson -ReportObject $report -Depth 12
