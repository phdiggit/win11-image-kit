[CmdletBinding()]
param(
    [string]$LockPath = "manifests/build-lock.json",
    [string]$ReportPath,
    [switch]$AuditOnly
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Get-KitBuildLock.ps1"
. "$PSScriptRoot\..\common\New-KitBuildLockReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$lock = Get-KitBuildLock -Path $LockPath -RepoRoot $repoRoot
$report = New-KitBuildLockReport -BuildLock $lock -RepoRoot $repoRoot -AuditOnly:$AuditOnly -WhatIf

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $resolvedReportPath = Resolve-KitBuildLockRepoPath -RepoRoot $repoRoot -Path $ReportPath
    $reportDirectory = Split-Path -Path $resolvedReportPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Write-Host "Build lock report written: $resolvedReportPath"
}

$report

if ($report.status -eq "failed") {
    exit 1
}
