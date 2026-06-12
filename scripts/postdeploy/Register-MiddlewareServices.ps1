#Requires -RunAsAdministrator

param(
    [string]$ManifestPath = "$PSScriptRoot\..\..\manifests\services.json"
)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\..\common\Write-Log.ps1"

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

foreach ($service in $manifest.services) {
    if (Get-Service -Name $service.name -ErrorAction SilentlyContinue) {
        Write-KitLog "Service already exists: $($service.name)"
        continue
    }

    Write-KitLog "TODO register service: $($service.name)" "WARN"
    Write-KitLog $service.install
}
