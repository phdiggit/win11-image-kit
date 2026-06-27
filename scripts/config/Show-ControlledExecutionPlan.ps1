[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/controlled-execution.json",
    [string]$DiskIdentityPath = "tests/fixtures/controlled-execution/disk-identity/matched.json",
    [string]$ConfirmationTokenPath = "tests/fixtures/controlled-execution/confirmation-token/matched.json",
    [string]$WimMetadataPath = "tests/fixtures/controlled-execution/wim-image/matched.json",
    [string]$WinREPlanPath = "tests/fixtures/controlled-execution/winre-plan/planned.json",
    [string]$NativeCommandPlanPath = "tests/fixtures/controlled-execution/native-command/planned.json",
    [string]$AuthorizationPath = "tests/fixtures/controlled-execution/authorization/matched.json",
    [string]$NativeCommandSimulationPath = "tests/fixtures/controlled-execution/native-command-simulation/baseline-success.json",
    [ValidateSet("dry-run", "what-if", "plan-only")]
    [string]$Mode = "plan-only"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-KitControlledExecutionReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$resolvedManifestPath = Resolve-KitControlledExecutionRepoPath -RepoRoot $repoRoot -Path $ManifestPath
$manifest = Get-Content -LiteralPath $resolvedManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$diskIdentity = Get-Content -LiteralPath (Resolve-KitControlledExecutionRepoPath -RepoRoot $repoRoot -Path $DiskIdentityPath) -Raw -Encoding UTF8 | ConvertFrom-Json
$confirmationToken = Get-Content -LiteralPath (Resolve-KitControlledExecutionRepoPath -RepoRoot $repoRoot -Path $ConfirmationTokenPath) -Raw -Encoding UTF8 | ConvertFrom-Json
$wimMetadata = Get-Content -LiteralPath (Resolve-KitControlledExecutionRepoPath -RepoRoot $repoRoot -Path $WimMetadataPath) -Raw -Encoding UTF8 | ConvertFrom-Json
$winREPlan = Get-Content -LiteralPath (Resolve-KitControlledExecutionRepoPath -RepoRoot $repoRoot -Path $WinREPlanPath) -Raw -Encoding UTF8 | ConvertFrom-Json
$nativeCommandPlan = Get-Content -LiteralPath (Resolve-KitControlledExecutionRepoPath -RepoRoot $repoRoot -Path $NativeCommandPlanPath) -Raw -Encoding UTF8 | ConvertFrom-Json
$authorization = Get-Content -LiteralPath (Resolve-KitControlledExecutionRepoPath -RepoRoot $repoRoot -Path $AuthorizationPath) -Raw -Encoding UTF8 | ConvertFrom-Json
$nativeCommandSimulation = Get-Content -LiteralPath (Resolve-KitControlledExecutionRepoPath -RepoRoot $repoRoot -Path $NativeCommandSimulationPath) -Raw -Encoding UTF8 | ConvertFrom-Json
$report = New-KitControlledExecutionReport `
    -Manifest $manifest `
    -RepoRoot $repoRoot `
    -Mode $Mode `
    -DiskIdentity $diskIdentity `
    -ConfirmationToken $confirmationToken `
    -WimMetadata $wimMetadata `
    -WinREPlan $winREPlan `
    -NativeCommandPlan $nativeCommandPlan `
    -Authorization $authorization `
    -NativeCommandSimulation $nativeCommandSimulation `
    -WhatIf

Write-Host "Plan only: no native command executed"
Write-Host "True execution: false"
$report | ConvertTo-Json -Depth 12

