[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$RequestPath = "tests/fixtures/user-experience/future-true-restore/review/baseline-blocked.json"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreAuthorizationReviewReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path

function Read-FutureTrueUxReviewPlanJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $Path
    Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

$manifest = Read-FutureTrueUxReviewPlanJson -Path $ManifestPath
$request = Read-FutureTrueUxReviewPlanJson -Path $RequestPath
$report = New-FutureTrueUxRestoreAuthorizationReviewReport -Manifest $manifest -Request $request -RepoRoot $repoRoot

Write-Host "Future true UX restore authorization review plan"
Write-Host "Review workflow only: true"
Write-Host "AuthorizationApproved: false"
Write-Host "ExecutionApproved: false"
Write-Host "ExecuteReady: false"
Write-Host "True execution: false"
Write-Host "Mutation count: 0"
Write-Host "Review decision: $($report.reviewDecision)"
Write-Host "Allowed review decisions:"
foreach ($decision in @($report.allowedReviewDecisions)) {
    Write-Host ("- {0}" -f $decision)
}
Write-Host "Forbidden review decisions:"
foreach ($decision in @($report.forbiddenReviewDecisions)) {
    Write-Host ("- {0}" -f $decision)
}
Write-Host "Required packet fields:"
foreach ($field in @($manifest.authorizationReview.requiredPacketFields)) {
    Write-Host ("- {0}" -f $field)
}
Write-Host "Blocked reasons:"
foreach ($reason in @($report.blockedReasons)) {
    Write-Host ("- {0}" -f $reason)
}

$report | ConvertTo-Json -Depth 12
