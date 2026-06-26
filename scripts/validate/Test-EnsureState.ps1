[CmdletBinding()]
param(
    [string]$SoftwareManifestPath = "manifests/software.json",
    [string]$ServicesManifestPath = "manifests/services.json",
    [string]$ReportPath,
    [switch]$FixtureOnly
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-KitEnsureStatePlan.ps1"
. "$PSScriptRoot\..\common\New-KitEnsureStateReport.ps1"

function Resolve-KitEnsureRepoPath {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }

    return [IO.Path]::GetFullPath((Join-Path -Path $RepoRoot -ChildPath $Path))
}

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$softwarePath = Resolve-KitEnsureRepoPath -RepoRoot $repoRoot -Path $SoftwareManifestPath
$servicesPath = Resolve-KitEnsureRepoPath -RepoRoot $repoRoot -Path $ServicesManifestPath
$softwareManifest = Get-Content -LiteralPath $softwarePath -Raw -Encoding UTF8 | ConvertFrom-Json
$servicesManifest = Get-Content -LiteralPath $servicesPath -Raw -Encoding UTF8 | ConvertFrom-Json

$planArgs = @{
    SoftwareManifest = $softwareManifest
    ServicesManifest = $servicesManifest
    WhatIf = $true
}
if ($FixtureOnly) {
    $planArgs.SoftwareFixtureState = @()
    $planArgs.ServiceFixtureState = @()
}

$plan = New-KitEnsureStatePlan @planArgs
$report = New-KitEnsureStateReport -Plan $plan -WhatIf

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $resolvedReportPath = Resolve-KitEnsureRepoPath -RepoRoot $repoRoot -Path $ReportPath
    $reportDirectory = Split-Path -Path $resolvedReportPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Write-Host "Ensure-state report written: $resolvedReportPath"
}

$report

if ($report.status -eq "failed") {
    exit 1
}
