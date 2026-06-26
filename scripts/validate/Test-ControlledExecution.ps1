[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/controlled-execution.json",
    [string]$ReportPath,
    [ValidateSet("dry-run", "what-if", "plan-only")]
    [string]$Mode = "dry-run"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-KitControlledExecutionReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$resolvedManifestPath = Resolve-KitControlledExecutionRepoPath -RepoRoot $repoRoot -Path $ManifestPath
$manifest = Get-Content -LiteralPath $resolvedManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$report = New-KitControlledExecutionReport -Manifest $manifest -RepoRoot $repoRoot -Mode $Mode -WhatIf

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $resolvedReportPath = Resolve-KitControlledExecutionRepoPath -RepoRoot $repoRoot -Path $ReportPath
    $reportDirectory = Split-Path -Path $resolvedReportPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Write-Host "Controlled execution report written: $resolvedReportPath"
}

$report

if ($report.summary.failedCount -gt 0 -or $report.summary.blockedActionCount -gt 0) {
    exit 1
}
