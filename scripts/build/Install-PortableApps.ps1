#Requires -RunAsAdministrator

param(
    [string]$ManifestPath = "$PSScriptRoot\..\..\manifests\software.json"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"

Write-KitLog "Loading software manifest: $ManifestPath"
$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

foreach ($package in $manifest.packages) {
    if ($package.type -ne "zip") {
        continue
    }

    Write-KitLog "Installing $($package.name)"
    if (-not (Test-Path $package.source)) {
        Write-KitLog "Missing package: $($package.source)" "WARN"
        continue
    }

    New-Item -ItemType Directory -Path $package.destination -Force | Out-Null
    Expand-Archive -LiteralPath $package.source -DestinationPath $package.destination -Force

    if ($package.env) {
        $package.env.PSObject.Properties | ForEach-Object {
            [Environment]::SetEnvironmentVariable($_.Name, $_.Value, "Machine")
            Write-KitLog "Set machine env $($_.Name)"
        }
    }
}

Write-KitLog "Portable app installation finished" "OK"
