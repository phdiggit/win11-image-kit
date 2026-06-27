[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$RequestPath = "tests/fixtures/user-experience/future-true-restore/current-user/baseline-blocked.json"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreCurrentUserDryRunReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path

function Read-FutureTrueUxCurrentUserPlanJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $Path
    Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

$report = New-FutureTrueUxRestoreCurrentUserDryRunReport `
    -Manifest (Read-FutureTrueUxCurrentUserPlanJson -Path $ManifestPath) `
    -Request (Read-FutureTrueUxCurrentUserPlanJson -Path $RequestPath) `
    -RepoRoot $repoRoot

Write-Host "Future true UX restore current-user dry-run plan"
Write-Host "Scope: current-user"
Write-Host "Dry-run only: true"
Write-Host "AuthorizationApproved: false"
Write-Host "ExecutionApproved: false"
Write-Host "Decision: $($report.decision)"
Write-Host "True execution: false"
Write-Host "Mutation count: 0"
Write-Host "Current user confirmed: false"
Write-Host "Command exit code sufficient: false"
Write-Host "Required evidence:"
foreach ($property in @($report.evidenceContract.PSObject.Properties)) {
    Write-Host ("- {0}: {1}" -f $property.Name, $property.Value)
}
Write-Host "Blocked reasons:"
foreach ($reason in @($report.blockedReasons)) {
    Write-Host ("- {0}" -f $reason)
}

$report | ConvertTo-Json -Depth 12
