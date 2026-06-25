#Requires -Version 5.1

param(
    [string]$ManifestPath = "manifests/sysprep-appx-gate.json",
    [string]$ReportPath = "",
    [string]$InventoryPath = "",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
. "$PSScriptRoot\..\common\Get-KitAppxInventory.ps1"
. "$PSScriptRoot\..\common\Test-KitSysprepAppxReadiness.ps1"

function Resolve-RepoRelativePath {
    param(
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }

    return [IO.Path]::GetFullPath((Join-Path -Path $RepoRoot -ChildPath $Path))
}

$resolvedManifestPath = Resolve-RepoRelativePath -Path $ManifestPath
if (-not (Test-Path -LiteralPath $resolvedManifestPath)) {
    throw "Sysprep AppX gate manifest not found: $ManifestPath"
}

$policy = Get-Content -LiteralPath $resolvedManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($InventoryPath)) {
    $inventory = Get-KitAppxInventory
} else {
    $resolvedInventoryPath = Resolve-RepoRelativePath -Path $InventoryPath
    $inventory = Get-Content -LiteralPath $resolvedInventoryPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

$report = Test-KitSysprepAppxReadiness -Inventory $inventory -Policy $policy -PolicyPath $resolvedManifestPath -WhatIf:$WhatIf

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $resolvedReportPath = Resolve-RepoRelativePath -Path $ReportPath
    $reportDirectory = Split-Path -Path $resolvedReportPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Write-Host ("Sysprep AppX readiness report written: {0}" -f $resolvedReportPath)
}

Write-Host ("Sysprep AppX readiness status: {0}, exitCode={1}, blocking={2}, manual={3}" -f $report.status, $report.exitCode, $report.summary.blockingCount, $report.summary.manualCount)
$report

if ([int]$report.exitCode -ne 0) {
    exit ([int]$report.exitCode)
}
