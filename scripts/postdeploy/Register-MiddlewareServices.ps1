#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ManifestPath = "$PSScriptRoot\..\..\manifests\services.json",
    [string]$PathsManifestPath = "$PSScriptRoot\..\..\manifests\paths.json"
)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath

foreach ($service in $manifest.services) {
    if (Get-Service -Name $service.name -ErrorAction SilentlyContinue) {
        Write-KitLog "服务已存在：$($service.name)"
        continue
    }

    $installCommand = Resolve-KitPath -Path $service.install -PathMap $pathMap
    if ($PSCmdlet.ShouldProcess($service.name, "注册中间件服务")) {
        Write-KitLog "待实现：注册服务 $($service.name)" "WARN"
        Write-KitLog $installCommand
    }
}
