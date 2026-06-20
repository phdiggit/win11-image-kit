#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ScopeManifestPath = "$PSScriptRoot\..\..\manifests\customization-scope.json",
    [string]$PathsManifestPath
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

function Invoke-PostDeployStep {
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
        Write-KitLog "跳过部署步骤：$Name"
        return
    }

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        throw "部署步骤脚本不存在：$ScriptPath"
    }

    $stepArguments = @{} + $Arguments
    if ($SupportsWhatIf -and $WhatIfPreference) {
        $stepArguments["WhatIf"] = $true
    }

    Write-KitLog "执行部署步骤：$Name"
    & $ScriptPath @stepArguments
}

Write-KitLog "开始执行部署后恢复"

$scopeConfig = Get-Content -LiteralPath $ScopeManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $PathsManifestPath) {
    $PathsManifestPath = Resolve-RepoPath -Path $scopeConfig.pathsManifest
} else {
    $PathsManifestPath = Resolve-RepoPath -Path $PathsManifestPath
}

$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath
Write-KitLog ("当前部署 profile：{0}" -f $scopeConfig.profile)
Write-KitLog ("工具根目录：{0}" -f $pathMap["ToolRoot"])
Write-KitLog ("数据根目录：{0}" -f $pathMap["DataRoot"])

$defenderMode = [string]$scopeConfig.system.windowsDefender.mode
$defenderEnabled = $defenderMode -eq "enabled-with-exclusions"
Invoke-PostDeployStep `
    -Name "Windows Defender 排除项" `
    -ScriptPath "$PSScriptRoot\Set-DefenderExclusions.ps1" `
    -Enabled $defenderEnabled `
    -SupportsWhatIf $true `
    -Arguments @{
        ManifestPath = Resolve-RepoPath -Path $scopeConfig.system.windowsDefender.exclusionsManifest
        PathsManifestPath = $PathsManifestPath
    }

Invoke-PostDeployStep `
    -Name "数据目录 Junction" `
    -ScriptPath "$PSScriptRoot\Set-DataJunctions.ps1" `
    -SupportsWhatIf $true `
    -Arguments @{
        ManifestPath = Resolve-RepoPath -Path $scopeConfig.applications.junctionsManifest
        PathsManifestPath = $PathsManifestPath
    }

Invoke-PostDeployStep `
    -Name "中间件服务注册" `
    -ScriptPath "$PSScriptRoot\Register-MiddlewareServices.ps1" `
    -SupportsWhatIf $true `
    -Arguments @{
        ManifestPath = Resolve-RepoPath -Path $scopeConfig.applications.servicesManifest
        PathsManifestPath = $PathsManifestPath
    }

$restoreUserExperience = (
    $scopeConfig.system.startMenu.enabled -or
    $scopeConfig.system.defaultApps.enabled -or
    $scopeConfig.system.explorerOptions.enabled
)
Invoke-PostDeployStep `
    -Name "用户体验恢复" `
    -ScriptPath "$PSScriptRoot\Restore-UserExperience.ps1" `
    -Enabled $restoreUserExperience

Write-KitLog "部署后恢复完成" "OK"
