#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ManifestPath = "$PSScriptRoot\..\..\manifests\services.json"
)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\..\common\Write-Log.ps1"

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

foreach ($service in $manifest.services) {
    $existing = Get-Service -Name $service.name -ErrorAction SilentlyContinue
    if (-not $existing) {
        Write-KitLog "服务不存在：$($service.name)"
        continue
    }

    if ($PSCmdlet.ShouldProcess($service.name, "停止并删除服务")) {
        Write-KitLog "停止服务：$($service.name)" "WARN"
        sc.exe stop $service.name | Out-Null
        Start-Sleep -Seconds 2
        Write-KitLog "删除服务：$($service.name)" "WARN"
        sc.exe delete $service.name | Out-Null
    }
}
