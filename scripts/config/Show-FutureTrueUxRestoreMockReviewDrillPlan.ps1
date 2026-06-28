[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$RequestPath = "tests/fixtures/user-experience/future-true-restore/mock-review/current-user-complete-packet.json"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreMockReviewDrillReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path

function Read-FutureTrueUxMockReviewPlanJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $Path
    Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

$manifest = Read-FutureTrueUxMockReviewPlanJson -Path $ManifestPath
$request = Read-FutureTrueUxMockReviewPlanJson -Path $RequestPath
$report = New-FutureTrueUxRestoreMockReviewDrillReport -Manifest $manifest -Request $request -RepoRoot $repoRoot

Write-Host "Future true UX restore mock review drill plan"
Write-Host "Mock drill only: true"
Write-Host "Scope: $($report.scope)"
Write-Host "Packet status: $($report.packetStatus)"
Write-Host "Review decision: $($report.reviewDecision)"
Write-Host "Execution decision: $($report.executionDecision)"
Write-Host "AuthorizationApproved: false"
Write-Host "ExecutionApproved: false"
Write-Host "ExecuteReady: false"
Write-Host "True execution: false"
Write-Host "Mutation count: 0"
Write-Host "Execution frozen: true"
Write-Host "Decision ledger:"
foreach ($entry in @($report.decisionLedger)) {
    Write-Host ("- {0}: {1}" -f $entry.stage, $entry.decision)
}
Write-Host "Blocked reasons:"
foreach ($reason in @($report.blockedReasons)) {
    Write-Host ("- {0}" -f $reason)
}

$report | ConvertTo-Json -Depth 12
