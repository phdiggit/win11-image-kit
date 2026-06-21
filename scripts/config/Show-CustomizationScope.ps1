param(
    [string]$ScopeManifestPath = "$PSScriptRoot\..\..\manifests\customization-scope.json",
    [string]$PathsManifestPath = "$PSScriptRoot\..\..\manifests\paths.json"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"

$scopeConfig = Get-Content -LiteralPath $ScopeManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath

Write-KitLog ("当前定制 profile：{0}" -f $scopeConfig.profile)
Write-KitLog ("目标：{0}" -f $scopeConfig.goal)

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

Write-KitLog "用户可改项："
foreach ($item in $scopeConfig.userInteraction.allowedChanges) {
    Write-KitLog ("  {0}" -f $item)
}
