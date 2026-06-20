#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ManifestPath = "$PSScriptRoot\..\..\manifests\junctions.json",
    [string]$PathsManifestPath = "$PSScriptRoot\..\..\manifests\paths.json"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"

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
    [CmdletBinding(SupportsShouldProcess)]
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
                Write-KitLog "robocopy 迁移失败：$Source" "ERROR"
                return
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

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath

foreach ($junction in $manifest.junctions) {
    Set-DataJunction `
        -Source (Resolve-KitPath -Path $junction.source -PathMap $pathMap) `
        -Target (Resolve-KitPath -Path $junction.target -PathMap $pathMap) `
        -Description $junction.description
}

Write-KitLog "目录 Junction 设置完成" "OK"
