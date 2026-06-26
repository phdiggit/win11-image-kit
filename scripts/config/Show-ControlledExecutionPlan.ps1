[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/controlled-execution.json",
    [ValidateSet("dry-run", "what-if", "plan-only")]
    [string]$Mode = "plan-only"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-KitControlledExecutionReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$resolvedManifestPath = Resolve-KitControlledExecutionRepoPath -RepoRoot $repoRoot -Path $ManifestPath
$manifest = Get-Content -LiteralPath $resolvedManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$report = New-KitControlledExecutionReport -Manifest $manifest -RepoRoot $repoRoot -Mode $Mode -WhatIf

$report | ConvertTo-Json -Depth 12

