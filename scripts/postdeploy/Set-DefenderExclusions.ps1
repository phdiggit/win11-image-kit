#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param(
    [string]$ManifestPath = "$PSScriptRoot\..\..\manifests\defender-exclusions.json",
    [string]$PathsManifestPath = "$PSScriptRoot\..\..\manifests\paths.json"
)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"

if (-not (Get-Command Add-MpPreference -ErrorAction SilentlyContinue)) {
    Write-KitLog "当前系统不可用 Add-MpPreference，跳过 Defender 排除项设置。" "WARN"
    return
}

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    Write-KitLog "Defender 排除项清单不存在：$ManifestPath" "WARN"
    return
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath

foreach ($item in $manifest.paths) {
    $path = Resolve-KitPath -Path $item.path -PathMap $pathMap
    if (-not (Test-Path -LiteralPath $path)) {
        Write-KitLog "排除路径不存在，跳过：$($item.description) - $path" "WARN"
        continue
    }

    if ($PSCmdlet.ShouldProcess($path, "添加 Defender 路径排除项")) {
        Write-KitLog "添加 Defender 路径排除项：$($item.description) - $path"
        Add-MpPreference -ExclusionPath $path -ErrorAction Continue
    }
}

foreach ($item in $manifest.processes) {
    $path = Resolve-KitPath -Path $item.path -PathMap $pathMap
    if ($PSCmdlet.ShouldProcess($path, "添加 Defender 进程排除项")) {
        Write-KitLog "添加 Defender 进程排除项：$($item.description) - $path"
        Add-MpPreference -ExclusionProcess $path -ErrorAction Continue
    }
}

Write-KitLog "Defender 排除项设置完成" "OK"
