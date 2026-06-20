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
. "$PSScriptRoot\..\common\Invoke-KitStep.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path

Write-KitLog "开始执行金镜像构建编排"

$ScopeManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $ScopeManifestPath
$scopeConfig = Get-Content -LiteralPath $ScopeManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $PathsManifestPath) {
    $PathsManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $scopeConfig.pathsManifest
} else {
    $PathsManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $PathsManifestPath
}

$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath
Write-KitLog ("当前构建 profile：{0}" -f $scopeConfig.profile)
Write-KitLog ("工具根目录：{0}" -f $pathMap["ToolRoot"])
Write-KitLog ("安装包根目录：{0}" -f $pathMap["PackageRoot"])

Invoke-KitStep `
    -Name "golden-image 归档软件包" `
    -ScriptPath "$PSScriptRoot\Install-PortableApps.ps1" `
    -Enabled (-not $SkipPortableApps) `
    -SupportsWhatIf $true `
    -ForwardWhatIf $WhatIfPreference `
    -StepKind "构建步骤" `
    -Arguments @{
        ManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $scopeConfig.applications.softwareManifest
        PathsManifestPath = $PathsManifestPath
        Stage = "golden-image"
    }

Invoke-KitStep `
    -Name "开发运行时占位检查" `
    -ScriptPath "$PSScriptRoot\Install-DevRuntime.ps1" `
    -Enabled (-not $SkipDevRuntime) `
    -StepKind "构建步骤"

Invoke-KitStep `
    -Name "中间件占位检查" `
    -ScriptPath "$PSScriptRoot\Install-Middleware.ps1" `
    -Enabled (-not $SkipMiddleware) `
    -StepKind "构建步骤"

$systemTweaksEnabled = (
    $scopeConfig.system.contextMenu.enabled -or
    $scopeConfig.system.explorerOptions.enabled
)
Invoke-KitStep `
    -Name "系统级配置" `
    -ScriptPath "$PSScriptRoot\Set-SystemTweaks.ps1" `
    -Enabled ($systemTweaksEnabled -and -not $SkipSystemTweaks) `
    -SupportsWhatIf $true `
    -ForwardWhatIf $WhatIfPreference `
    -StepKind "构建步骤" `
    -Arguments @{
        PathsManifestPath = $PathsManifestPath
    }

Write-KitLog "金镜像构建编排完成" "OK"
