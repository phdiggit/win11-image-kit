[CmdletBinding()]
param(
    [string]$RegistryPath = "manifests/capability-registry.json",
    [string]$ReportPath,
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Get-KitCapabilityRegistry.ps1"
. "$PSScriptRoot\..\common\New-KitCapabilityConsistencyReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$registry = Get-KitCapabilityRegistry -Path $RegistryPath -RepoRoot $repoRoot
$report = New-KitCapabilityConsistencyReport -Registry $registry -RepoRoot $repoRoot -Strict:$Strict -WhatIf

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $resolvedReportPath = Resolve-KitCapabilityRepoPath -RepoRoot $repoRoot -Path $ReportPath
    $reportDirectory = Split-Path -Path $resolvedReportPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Write-Host "Capability consistency report written: $resolvedReportPath"
}

$report

if ($report.status -eq "failed") {
    exit 1
}
