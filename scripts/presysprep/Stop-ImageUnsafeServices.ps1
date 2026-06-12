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
        Write-KitLog "Service not found: $($service.name)"
        continue
    }

    if ($PSCmdlet.ShouldProcess($service.name, "Stop and delete service")) {
        Write-KitLog "Stopping service $($service.name)" "WARN"
        sc.exe stop $service.name | Out-Null
        Start-Sleep -Seconds 2
        Write-KitLog "Deleting service $($service.name)" "WARN"
        sc.exe delete $service.name | Out-Null
    }
}
