[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param(
    [string]$ManifestPath = "$PSScriptRoot\..\..\manifests\defender-exclusions.json",
    [string]$PathsManifestPath = "$PSScriptRoot\..\..\manifests\paths.json",
    [string]$ReportPath,
    [switch]$ReportRequired
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Assert-KitElevation.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"
. "$PSScriptRoot\..\common\Test-KitDefenderState.ps1"

Assert-KitElevation -Operation "Defender 排除项设置" -AllowWhatIfPreview

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    Write-KitLog "Defender 排除项清单不存在：$ManifestPath" "WARN"
    return
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath
$defenderResults = @()

function Write-DefenderStateReport {
    param(
        [AllowNull()]
        $Results = @()
    )

    $report = New-KitDefenderStateReport -Results $Results
    if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
        $written = Write-KitTextFile -Path $ReportPath -Content ($report | ConvertTo-Json -Depth 10) -Description "Defender 状态验证报告" -Required:$ReportRequired
        if ($written) {
            Write-KitLog "Defender 状态验证报告已写入：$ReportPath" "OK"
        }
    }

    return $report.defenderSummary
}

foreach ($item in $manifest.paths) {
    $path = Resolve-KitPath -Path $item.path -PathMap $pathMap
    if (-not (Test-Path -LiteralPath $path)) {
        Write-KitLog "排除路径不存在，跳过：$($item.description) - $path" "WARN"
        continue
    }

    if ($PSCmdlet.ShouldProcess($path, "添加 Defender 路径排除项")) {
        if (-not (Get-Command Add-MpPreference -ErrorAction SilentlyContinue)) {
            Write-KitLog "当前系统不可用 Add-MpPreference，跳过 Defender 排除项设置。" "WARN"
            continue
        }
        Write-KitLog "添加 Defender 路径排除项：$($item.description) - $path"
        Add-MpPreference -ExclusionPath $path -ErrorAction Continue
    }
}

foreach ($item in $manifest.processes) {
    $path = Resolve-KitPath -Path $item.path -PathMap $pathMap
    if ($PSCmdlet.ShouldProcess($path, "添加 Defender 进程排除项")) {
        if (-not (Get-Command Add-MpPreference -ErrorAction SilentlyContinue)) {
            Write-KitLog "当前系统不可用 Add-MpPreference，跳过 Defender 排除项设置。" "WARN"
            continue
        }
        Write-KitLog "添加 Defender 进程排除项：$($item.description) - $path"
        Add-MpPreference -ExclusionProcess $path -ErrorAction Continue
    }
}

if ($manifest.PSObject.Properties.Name -contains "stateChecks") {
    if ($WhatIfPreference) {
        $defenderResults += Test-KitDefenderState -Config @($manifest.stateChecks) -WhatIf
    } else {
        $defenderResults += Test-KitDefenderState -Config @($manifest.stateChecks)
    }
}

$defenderSummary = Write-DefenderStateReport -Results $defenderResults
if ($defenderSummary.exitCode -ne 0) {
    throw "Defender 状态验证失败：$($defenderSummary.failedRequiredCount) 项 required 检查失败。"
}

Write-KitLog "Defender 排除项设置完成" "OK"
