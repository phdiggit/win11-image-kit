#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ManifestPath = "$PSScriptRoot\..\..\manifests\appx-cleanup.json",
    [string]$ReportPath,
    [switch]$ReportRequired
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Resolve-KitOutputPath.ps1"
. "$PSScriptRoot\..\common\Test-KitAppxState.ps1"

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "AppX 状态检查清单不存在：$ManifestPath"
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$stateChecks = @()
if ($manifest.PSObject.Properties.Name -contains "stateChecks") {
    $stateChecks = @($manifest.stateChecks)
}

$results = @()
if ($stateChecks.Count -gt 0) {
    $results = @(Test-KitAppxState -Config $stateChecks -WhatIf:$WhatIfPreference)
}
$report = New-KitAppxStateReport -Results $results

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $written = Write-KitTextFile -Path $ReportPath -Content ($report | ConvertTo-Json -Depth 12) -Description "AppX 状态验证报告" -Required:$ReportRequired
    if ($written) {
        Write-KitLog "AppX 状态验证报告已写入：$ReportPath" "OK"
    }
}

if ($report.appxSummary.exitCode -ne 0) {
    throw "AppX 状态验证失败：$($report.appxSummary.failedRequiredCount) 项 required 检查失败。"
}

