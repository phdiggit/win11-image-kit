#Requires -RunAsAdministrator

param(
    [string]$ManifestPath = "$PSScriptRoot\..\..\manifests\junctions.json"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"

if (-not (Test-Path "D:\")) {
    Write-KitLog "D: not found. Skipping junction setup." "WARN"
    exit 0
}

function Expand-KitPath {
    param([string]$Path)
    [Environment]::ExpandEnvironmentVariables($Path)
}

function Set-DataJunction {
    param(
        [string]$Source,
        [string]$Target,
        [string]$Description
    )

    Write-KitLog "${Description}: $Source -> $Target"
    New-Item -ItemType Directory -Path $Target -Force | Out-Null

    if (Test-Path $Source) {
        $item = Get-Item $Source -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-KitLog "Already a reparse point: $Source"
            return
        }

        robocopy $Source $Target /E /MOVE /NJH /NJS /NFL /NDL | Out-Null
        if ($LASTEXITCODE -ge 8) {
            Write-KitLog "robocopy failed for $Source" "ERROR"
            return
        }
        Remove-Item -LiteralPath $Source -Force -ErrorAction SilentlyContinue
    }

    $parent = Split-Path $Source -Parent
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    cmd.exe /c "mklink /J `"$Source`" `"$Target`"" | Out-Null
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($junction in $manifest.junctions) {
    Set-DataJunction -Source (Expand-KitPath $junction.source) -Target $junction.target -Description $junction.description
}

Write-KitLog "Junction setup finished" "OK"
