[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreScopeDryRunReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path

function Read-FutureTrueUxScopePlanJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $Path
    Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

$fixtureRoot = "tests/fixtures/user-experience/future-true-restore"
$requestsByScope = @{
    "current-user" = Read-FutureTrueUxScopePlanJson -Path "$fixtureRoot/current-user/baseline-blocked.json"
    "default-user" = Read-FutureTrueUxScopePlanJson -Path "$fixtureRoot/default-user/baseline-blocked.json"
    "offline-image" = Read-FutureTrueUxScopePlanJson -Path "$fixtureRoot/offline-image/baseline-blocked.json"
    "machine" = Read-FutureTrueUxScopePlanJson -Path "$fixtureRoot/machine/baseline-blocked.json"
}

$report = New-FutureTrueUxRestoreScopeDryRunReport `
    -Manifest (Read-FutureTrueUxScopePlanJson -Path $ManifestPath) `
    -RequestsByScope $requestsByScope `
    -RepoRoot $repoRoot

Write-Host "Future true UX restore scope dry-run plan"
Write-Host "Dry-run only: true"
Write-Host "AuthorizationApproved: false"
Write-Host "ExecutionApproved: false"
Write-Host "Aggregate decision: $($report.aggregateDecision)"
Write-Host "True execution: false"
Write-Host "Mutation count: 0"
Write-Host "Command exit code sufficient: false"

foreach ($scopeReport in @($report.scopeReports)) {
    Write-Host ""
    Write-Host "Scope: $($scopeReport.scope)"
    Write-Host "Decision: $($scopeReport.decision)"
    Write-Host "Required evidence:"
    foreach ($property in @($scopeReport.evidenceContract.PSObject.Properties)) {
        Write-Host ("- {0}: {1}" -f $property.Name, $property.Value)
    }
    Write-Host "Blocked reasons:"
    foreach ($reason in @($scopeReport.blockedReasons)) {
        Write-Host ("- {0}" -f $reason)
    }
}

$report | ConvertTo-Json -Depth 12
