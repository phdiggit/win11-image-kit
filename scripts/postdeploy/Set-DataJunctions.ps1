[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param(
    [string]$ManifestPath = "$PSScriptRoot\..\..\manifests\junctions.json",
    [string]$PathsManifestPath = "$PSScriptRoot\..\..\manifests\paths.json",
    [string]$ReportPath,
    [switch]$ReportRequired
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Assert-KitElevation.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"
. "$PSScriptRoot\..\common\Test-KitJunctionState.ps1"
. "$PSScriptRoot\..\common\Test-KitJunctionPreflight.ps1"
. "$PSScriptRoot\..\common\Invoke-KitJunctionTransaction.ps1"

Assert-KitElevation -Operation "数据目录 Junction 设置" -AllowWhatIfPreview

function Write-DataJunctionReport {
    param(
        [AllowNull()]
        $Results = @()
    )

    $report = New-KitJunctionStateReport -Results $Results
    if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
        $written = Write-KitTextFile -Path $ReportPath -Content ($report | ConvertTo-Json -Depth 10) -Description "Junction 状态验证报告" -Required:$ReportRequired
        if ($written) {
            Write-KitLog "Junction 状态验证报告已写入：$ReportPath" "OK"
        }
    }

    return $report.junctionSummary
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath
$junctionResults = @()

foreach ($junction in $manifest.junctions) {
    $resolvedJunction = [pscustomobject]@{
        name = [string]$junction.description
        description = [string]$junction.description
        source = Resolve-KitPath -Path $junction.source -PathMap $pathMap
        target = Resolve-KitPath -Path $junction.target -PathMap $pathMap
        required = if ($junction.PSObject.Properties.Name -contains "required") { [bool]$junction.required } else { $true }
        failurePolicy = if ($junction.PSObject.Properties.Name -contains "failurePolicy" -and -not [string]::IsNullOrWhiteSpace([string]$junction.failurePolicy)) { [string]$junction.failurePolicy } else { "fail" }
        onTargetConflict = if ($junction.PSObject.Properties.Name -contains "onTargetConflict" -and -not [string]::IsNullOrWhiteSpace([string]$junction.onTargetConflict)) { [string]$junction.onTargetConflict } else { "fail" }
        backupRetention = if ($junction.PSObject.Properties.Name -contains "backupRetention" -and -not [string]::IsNullOrWhiteSpace([string]$junction.backupRetention)) { [string]$junction.backupRetention } else { "keep" }
        verificationMode = if ($junction.PSObject.Properties.Name -contains "verificationMode" -and -not [string]::IsNullOrWhiteSpace([string]$junction.verificationMode)) { [string]$junction.verificationMode } else { "countAndSize" }
    }

    $preflight = Test-KitDataJunctionPreflight -JunctionConfig $resolvedJunction -WhatIf:$WhatIfPreference
    Write-KitLog ("Junction 预检：{0}，计划：{1}，状态：{2}，原因：{3}" -f $resolvedJunction.description, $preflight.planAction, $preflight.status, $preflight.reason)

    if ($preflight.status -ne "changed" -and $preflight.status -ne "whatif") {
        $junctionResults += $preflight
        continue
    }

    $junctionResults += Invoke-KitDataJunctionTransaction `
        -JunctionConfig $resolvedJunction `
        -PreflightResult $preflight `
        -WhatIf:$WhatIfPreference
}

$junctionSummary = Write-DataJunctionReport -Results $junctionResults
if ($junctionSummary.exitCode -ne 0) {
    throw "Junction 状态验证失败：$($junctionSummary.failedRequiredCount) 项 required Junction 失败。"
}

Write-KitLog "目录 Junction 设置完成" "OK"
