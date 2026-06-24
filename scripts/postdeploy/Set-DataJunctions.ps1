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

Assert-KitElevation -Operation "数据目录 Junction 设置" -AllowWhatIfPreview

function Test-DriveRoot {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $qualifier = Split-Path -Path $Path -Qualifier
    if ([string]::IsNullOrWhiteSpace($qualifier)) {
        return $true
    }

    return Test-Path -LiteralPath ("{0}\" -f $qualifier)
}

function Set-DataJunction {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [string]$Description
    )

    Write-KitLog ("{0}: {1} -> {2}" -f $Description, $Source, $Target)

    if (-not (Test-DriveRoot -Path $Target)) {
        Write-KitLog "目标数据盘不存在，跳过：$Target" "WARN"
        return
    }

    if ($PSCmdlet.ShouldProcess($Target, "创建 Junction 目标目录")) {
        New-Item -ItemType Directory -Path $Target -Force | Out-Null
    }

    if (Test-Path -LiteralPath $Source) {
        $item = Get-Item -LiteralPath $Source -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-KitLog "已经是重解析点：$Source"
            return
        }

        if ($PSCmdlet.ShouldProcess($Source, "迁移目录内容到 $Target")) {
            robocopy $Source $Target /E /MOVE /NJH /NJS /NFL /NDL | Out-Null
            if ($LASTEXITCODE -ge 8) {
                throw "robocopy 迁移失败：$Source，退出码：$LASTEXITCODE"
            }
        }

        if ($PSCmdlet.ShouldProcess($Source, "删除迁移后的源目录")) {
            Remove-Item -LiteralPath $Source -Force -ErrorAction SilentlyContinue
        }
    }

    $parent = Split-Path -Path $Source -Parent
    if ($PSCmdlet.ShouldProcess($parent, "创建 Junction 父目录")) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if ($PSCmdlet.ShouldProcess($Source, "创建 Junction 指向 $Target")) {
        cmd.exe /c "mklink /J `"$Source`" `"$Target`"" | Out-Null
    }
}

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

    if ($preflight.status -ne "changed") {
        $junctionResults += $preflight
        continue
    }

    Set-DataJunction `
        -Source $resolvedJunction.source `
        -Target $resolvedJunction.target `
        -Description $resolvedJunction.description

    $junctionResults += Test-KitJunctionState -JunctionConfig $resolvedJunction
}

$junctionSummary = Write-DataJunctionReport -Results $junctionResults
if ($junctionSummary.exitCode -ne 0) {
    throw "Junction 状态验证失败：$($junctionSummary.failedRequiredCount) 项 required Junction 失败。"
}

Write-KitLog "目录 Junction 设置完成" "OK"
