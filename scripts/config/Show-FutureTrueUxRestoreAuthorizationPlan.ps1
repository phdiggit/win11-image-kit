[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$AuthorizationPath = "tests/fixtures/user-experience/future-true-restore/authorization/baseline-blocked.json"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreAuthorizationReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path

function Read-FutureTrueUxRestorePlanJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $Path
    Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

$report = New-FutureTrueUxRestoreAuthorizationReport `
    -Manifest (Read-FutureTrueUxRestorePlanJson -Path $ManifestPath) `
    -AuthorizationRequest (Read-FutureTrueUxRestorePlanJson -Path $AuthorizationPath) `
    -RepoRoot $repoRoot

Write-Host "Future true UX restore authorization intake plan"
Write-Host "Dry-run only: true"
Write-Host "Default deny: true"
Write-Host "Decision: $($report.decision)"
Write-Host "True execution: false"
Write-Host "Mutation count: 0"
Write-Host "Command exit code sufficient: false"
Write-Host "User configuration confirmed: false"
Write-Host "Registry mutation: false"
Write-Host "Profile mutation: false"
Write-Host "Default User hive mutation: false"
Write-Host "Default app mutation: false"
Write-Host "Start menu mutation: false"
Write-Host "Taskbar mutation: false"
Write-Host "Image servicing mutation: false"
Write-Host "AppX mutation: false"
Write-Host "Network download: false"
Write-Host "Required scopes:"
foreach ($item in @($report.evidenceRequirements)) {
    Write-Host ("- {0}: {1}" -f $item.scope, $item.safetyGate)
}

$report | ConvertTo-Json -Depth 12
