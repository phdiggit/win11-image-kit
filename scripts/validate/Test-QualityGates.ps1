[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/quality-gates.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-KitQualityGateReport.ps1"

function Resolve-KitQualityGateValidateRepoPath {
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
$resolvedManifestPath = Resolve-KitQualityGateValidateRepoPath -RepoRoot $repoRoot -Path $ManifestPath
$manifest = Get-Content -LiteralPath $resolvedManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$report = New-KitQualityGateReport -QualityGateManifest $manifest -RepoRoot $repoRoot -WhatIf

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $resolvedReportPath = Resolve-KitQualityGateValidateRepoPath -RepoRoot $repoRoot -Path $ReportPath
    $reportDirectory = Split-Path -Path $resolvedReportPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Write-Host "Quality gates report written: $resolvedReportPath"
}

$report

if ($report.summary.failedCount -gt 0) {
    exit 1
}
