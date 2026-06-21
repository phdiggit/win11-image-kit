[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ScopeManifestPath = "$PSScriptRoot\..\..\manifests\customization-scope.json",
    [string]$PathsManifestPath,
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Assert-KitElevation.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"
. "$PSScriptRoot\..\common\Invoke-KitStep.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path

Write-KitLog "开始执行部署后恢复"
Assert-KitElevation -Operation "部署后恢复编排" -AllowWhatIfPreview

$ScopeManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $ScopeManifestPath
$scopeConfig = Get-Content -LiteralPath $ScopeManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $PathsManifestPath) {
    $PathsManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $scopeConfig.pathsManifest
} else {
    $PathsManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $PathsManifestPath
}

$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath
Write-KitLog ("当前部署 profile：{0}" -f $scopeConfig.profile)
Write-KitLog ("工具根目录：{0}" -f $pathMap["ToolRoot"])
Write-KitLog ("数据根目录：{0}" -f $pathMap["DataRoot"])

$defenderMode = [string]$scopeConfig.system.windowsDefender.mode
$defenderEnabled = $defenderMode -eq "enabled-with-exclusions"
Invoke-KitStep `
    -Name "Windows Defender 排除项" `
    -ScriptPath "$PSScriptRoot\Set-DefenderExclusions.ps1" `
    -Enabled $defenderEnabled `
    -SupportsWhatIf $true `
    -ForwardWhatIf $WhatIfPreference `
    -StepKind "部署步骤" `
    -Arguments @{
        ManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $scopeConfig.system.windowsDefender.exclusionsManifest
        PathsManifestPath = $PathsManifestPath
    }

Invoke-KitStep `
    -Name "数据目录 Junction" `
    -ScriptPath "$PSScriptRoot\Set-DataJunctions.ps1" `
    -SupportsWhatIf $true `
    -ForwardWhatIf $WhatIfPreference `
    -StepKind "部署步骤" `
    -Arguments @{
        ManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $scopeConfig.applications.junctionsManifest
        PathsManifestPath = $PathsManifestPath
    }

Invoke-KitStep `
    -Name "部署后软件" `
    -ScriptPath "$PSScriptRoot\Install-PostDeploySoftware.ps1" `
    -SupportsWhatIf $true `
    -ForwardWhatIf $WhatIfPreference `
    -StepKind "部署步骤" `
    -Arguments @{
        ManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $scopeConfig.applications.softwareManifest
        PathsManifestPath = $PathsManifestPath
        ReportPath = $ReportPath
    }

Invoke-KitStep `
    -Name "中间件服务注册" `
    -ScriptPath "$PSScriptRoot\Register-MiddlewareServices.ps1" `
    -SupportsWhatIf $true `
    -ForwardWhatIf $WhatIfPreference `
    -StepKind "部署步骤" `
    -Arguments @{
        ManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $scopeConfig.applications.servicesManifest
        PathsManifestPath = $PathsManifestPath
    }

$restoreUserExperience = (
    $scopeConfig.system.startMenu.enabled -or
    $scopeConfig.system.defaultApps.enabled -or
    $scopeConfig.system.explorerOptions.enabled
)
Invoke-KitStep `
    -Name "用户体验恢复" `
    -ScriptPath "$PSScriptRoot\Restore-UserExperience.ps1" `
    -Enabled $restoreUserExperience `
    -SupportsWhatIf $true `
    -ForwardWhatIf $WhatIfPreference `
    -StepKind "部署步骤" `
    -Arguments @{
        ScopeManifestPath = $ScopeManifestPath
        PathsManifestPath = $PathsManifestPath
    }

Write-KitLog "部署后恢复完成" "OK"
