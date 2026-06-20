#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param(
    [string]$ManifestPath = "$PSScriptRoot\..\..\manifests\services.json"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"

function Invoke-ServiceControlCommand {
    param(
        [Parameter(Mandatory)]
        [string]$Description,

        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    Write-KitLog $Description "WARN"
    $output = & sc.exe @Arguments 2>&1
    $exitCode = $LASTEXITCODE

    foreach ($line in @($output)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$line)) {
            Write-KitLog ([string]$line)
        }
    }

    if ($exitCode -ne 0) {
        throw "$Description 失败，exit code: $exitCode"
    }
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

foreach ($service in $manifest.services) {
    $existing = Get-Service -Name $service.name -ErrorAction SilentlyContinue
    if (-not $existing) {
        Write-KitLog "服务不存在：$($service.name)"
        continue
    }

    if ($PSCmdlet.ShouldProcess($service.name, "停止并删除服务")) {
        if ($existing.Status -ne "Stopped") {
            Invoke-ServiceControlCommand -Description "停止服务：$($service.name)" -Arguments @("stop", $service.name)
            Start-Sleep -Seconds 2
        }

        Invoke-ServiceControlCommand -Description "删除服务：$($service.name)" -Arguments @("delete", $service.name)
    }
}
