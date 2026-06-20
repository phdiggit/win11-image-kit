#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ScopeManifestPath = "$PSScriptRoot\..\..\manifests\customization-scope.json",
    [string]$PathsManifestPath,
    [switch]$SkipPortableApps,
    [switch]$SkipSystemTweaks,
    [switch]$SkipDevRuntime,
    [switch]$SkipMiddleware
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path

function Resolve-RepoPath {
    param(
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    if ([IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path -Path $repoRoot -ChildPath $Path
}

function Invoke-BuildStep {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [hashtable]$Arguments = @{},

        [bool]$Enabled = $true,

        [bool]$SupportsWhatIf = $false
    )

    if (-not $Enabled) {
        Write-KitLog "跳过构建步骤：$Name"
        return
    }

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        throw "构建步骤脚本不存在：$ScriptPath"
    }

    $stepArguments = @{} + $Arguments
    if ($SupportsWhatIf -and $WhatIfPreference) {
        $stepArguments["WhatIf"] = $true
    }

    Write-KitLog "执行构建步骤：$Name"
    & $ScriptPath @stepArguments
}

Write-KitLog "开始执行金镜像构建编排"

$scopeConfig = Get-Content -LiteralPath $ScopeManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $PathsManifestPath) {
    $PathsManifestPath = Resolve-RepoPath -Path $scopeConfig.pathsManifest
} else {
    $PathsManifestPath = Resolve-RepoPath -Path $PathsManifestPath
}

$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath
Write-KitLog ("当前构建 profile：{0}" -f $scopeConfig.profile)
Write-KitLog ("工具根目录：{0}" -f $pathMap["ToolRoot"])
Write-KitLog ("安装包根目录：{0}" -f $pathMap["PackageRoot"])

Invoke-BuildStep `
    -Name "golden-image 归档软件包" `
    -ScriptPath "$PSScriptRoot\Install-PortableApps.ps1" `
    -Enabled (-not $SkipPortableApps) `
    -SupportsWhatIf $true `
    -Arguments @{
        ManifestPath = Resolve-RepoPath -Path $scopeConfig.applications.softwareManifest
        PathsManifestPath = $PathsManifestPath
        Stage = "golden-image"
    }

Invoke-BuildStep `
    -Name "开发运行时占位检查" `
    -ScriptPath "$PSScriptRoot\Install-DevRuntime.ps1" `
    -Enabled (-not $SkipDevRuntime)

Invoke-BuildStep `
    -Name "中间件占位检查" `
    -ScriptPath "$PSScriptRoot\Install-Middleware.ps1" `
    -Enabled (-not $SkipMiddleware)

$systemTweaksEnabled = (
    $scopeConfig.system.contextMenu.enabled -or
    $scopeConfig.system.explorerOptions.enabled
)
Invoke-BuildStep `
    -Name "系统级配置" `
    -ScriptPath "$PSScriptRoot\Set-SystemTweaks.ps1" `
    -Enabled ($systemTweaksEnabled -and -not $SkipSystemTweaks) `
    -SupportsWhatIf $true `
    -Arguments @{
        PathsManifestPath = $PathsManifestPath
    }

Write-KitLog "金镜像构建编排完成" "OK"
