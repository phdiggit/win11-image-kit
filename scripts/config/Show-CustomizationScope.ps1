param(
    [string]$ScopeManifestPath = "$PSScriptRoot\..\..\manifests\customization-scope.json",
    [string]$PathsManifestPath = "$PSScriptRoot\..\..\manifests\paths.json",
    [switch]$UseEffectiveConfiguration,
    [string]$StackName,
    [switch]$IncludeLocal,
    [string]$PathOverrideJson
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"
. "$PSScriptRoot\..\common\Resolve-KitEffectiveConfiguration.ps1"

$RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$scopeConfig = Get-Content -LiteralPath $ScopeManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$effectiveReport = $null

if ($UseEffectiveConfiguration) {
    $configLayersPath = if ($scopeConfig.PSObject.Properties.Name -contains "configLayersManifest") {
        [string]$scopeConfig.configLayersManifest
    } else {
        "manifests/config-layers.json"
    }

    $effectiveStackName = if (-not [string]::IsNullOrWhiteSpace($StackName)) {
        $StackName
    } elseif ($scopeConfig.PSObject.Properties.Name -contains "defaultStack" -and -not [string]::IsNullOrWhiteSpace([string]$scopeConfig.defaultStack)) {
        [string]$scopeConfig.defaultStack
    } else {
        "default"
    }

    $pathOverride = @{}
    if (-not [string]::IsNullOrWhiteSpace($PathOverrideJson)) {
        $pathOverride = ConvertTo-KitHashtable -InputObject ($PathOverrideJson | ConvertFrom-Json)
    }

    $effectiveReport = Resolve-KitEffectiveConfiguration `
        -ConfigLayersPath $configLayersPath `
        -StackName $effectiveStackName `
        -IncludeLocal:$IncludeLocal `
        -PathOverride $pathOverride `
        -RepoRoot $RepoRoot

    $pathMap = @{}
    foreach ($path in @($effectiveReport.pathSources)) {
        $pathMap[[string]$path.key] = [string]$path.value
    }
} else {
    $pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath
}

Write-KitLog ("当前定制 profile：{0}" -f $scopeConfig.profile)
Write-KitLog ("目标：{0}" -f $scopeConfig.goal)

if ($UseEffectiveConfiguration) {
    Write-KitLog ("Effective configuration stack: {0}" -f $effectiveReport.stackName)
    Write-KitLog ("Include local private override: {0}" -f $effectiveReport.includeLocal)
    Write-KitLog "Effective configuration source layers:"
    foreach ($layer in @($effectiveReport.appliedLayers)) {
        Write-KitLog ("  {0} ({1}) -> {2}" -f $layer.id, $layer.kind, $layer.path)
    }
}

Write-KitLog "路径配置："
foreach ($key in @($pathMap.Keys | Sort-Object)) {
    $value = $pathMap[[string]$key]
    Write-KitLog ("  {0} = {1}" -f $key, $value)
}

Write-KitLog "系统定制："
Write-KitLog ("  右键菜单：{0}" -f $scopeConfig.system.contextMenu.enabled)
Write-KitLog ("  开始菜单：{0}" -f $scopeConfig.system.startMenu.enabled)
if ($scopeConfig.system.PSObject.Properties.Name -contains "windowsTerminal") {
    Write-KitLog ("  Windows Terminal 配置：{0}" -f $scopeConfig.system.windowsTerminal.enabled)
    if ($scopeConfig.system.windowsTerminal.enabled) {
        Write-KitLog ("    来源：{0}" -f (Resolve-KitPath -Path $scopeConfig.system.windowsTerminal.source -PathMap $pathMap))
        Write-KitLog ("    目标：{0}" -f (Resolve-KitPath -Path $scopeConfig.system.windowsTerminal.destination -PathMap $pathMap))
    }
}
Write-KitLog ("  资源管理器选项：{0}" -f $scopeConfig.system.explorerOptions.enabled)
Write-KitLog ("  默认应用：{0}" -f $scopeConfig.system.defaultApps.enabled)
if ($scopeConfig.system.PSObject.Properties.Name -contains "vscodePortable") {
    Write-KitLog ("  VSCode 便携配置：{0}" -f $scopeConfig.system.vscodePortable.enabled)
    if ($scopeConfig.system.vscodePortable.enabled) {
        Write-KitLog ("    来源：{0}" -f (Resolve-KitPath -Path $scopeConfig.system.vscodePortable.source -PathMap $pathMap))
        Write-KitLog ("    目标：{0}" -f (Resolve-KitPath -Path $scopeConfig.system.vscodePortable.destination -PathMap $pathMap))
    }
}
Write-KitLog ("  Windows Defender：{0}" -f $scopeConfig.system.windowsDefender.mode)
Write-KitLog ("  安装火绒：{0}" -f $scopeConfig.system.huorong.install)

Write-KitLog "应用和数据清单："
Write-KitLog ("  软件清单：{0}" -f $scopeConfig.applications.softwareManifest)
Write-KitLog ("  服务清单：{0}" -f $scopeConfig.applications.servicesManifest)
Write-KitLog ("  Junction 清单：{0}" -f $scopeConfig.applications.junctionsManifest)
Write-KitLog ("  AppX 策略：{0}" -f $scopeConfig.appx.policy)

if ($scopeConfig.PSObject.Properties.Name -contains "reporting") {
    Write-KitLog "归档输出："
    foreach ($sectionName in @("build", "postDeploy", "validation")) {
        if ($scopeConfig.reporting.PSObject.Properties.Name -notcontains $sectionName) {
            continue
        }

        $section = $scopeConfig.reporting.$sectionName
        Write-KitLog ("  {0}：{1}" -f $sectionName, $section.enabled)
        if ($section.enabled) {
            Write-KitLog ("    日志目录：{0}" -f (Resolve-KitPath -Path $section.logDirectory -PathMap $pathMap))
            Write-KitLog ("    报告目录：{0}" -f (Resolve-KitPath -Path $section.reportDirectory -PathMap $pathMap))
        }
    }
}

Write-KitLog "用户可改项："
foreach ($item in $scopeConfig.userInteraction.allowedChanges) {
    Write-KitLog ("  {0}" -f $item)
}
