[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/user-experience-restore.json",
    [string]$WindowsContextPath = "tests/fixtures/user-experience/windows-context/windows-11-24h2.json",
    [string]$DefaultAppsPath = "tests/fixtures/user-experience/default-apps/baseline.json",
    [string]$StartMenuPath = "tests/fixtures/user-experience/start-menu/baseline.json",
    [string]$TaskbarPath = "tests/fixtures/user-experience/taskbar/baseline.json",
    [string]$CapabilityMatrixPath = "tests/fixtures/user-experience/capability-matrix/windows-11-24h2-supported.json",
    [string]$TemplateMetadataPath = "tests/fixtures/user-experience/template-metadata/default-apps-24h2.json",
    [string]$VerificationPlanPath = "tests/fixtures/user-experience/verification/default-apps-planned.json",
    [string]$ScopeSemanticsPath = "tests/fixtures/user-experience/scope-semantics/default-user-vs-current-user.json",
    [ValidateSet("plan-only", "report-only", "fixture")]
    [string]$Mode = "plan-only"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-KitUserExperienceRestoreReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path

function Read-KitUserExperiencePlanJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-KitUserExperienceRestoreRepoPath -RepoRoot $repoRoot -Path $Path
    Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

$report = New-KitUserExperienceRestoreReport `
    -Manifest (Read-KitUserExperiencePlanJson -Path $ManifestPath) `
    -RepoRoot $repoRoot `
    -Mode $Mode `
    -WindowsContext (Read-KitUserExperiencePlanJson -Path $WindowsContextPath) `
    -DefaultApps (Read-KitUserExperiencePlanJson -Path $DefaultAppsPath) `
    -StartMenu (Read-KitUserExperiencePlanJson -Path $StartMenuPath) `
    -Taskbar (Read-KitUserExperiencePlanJson -Path $TaskbarPath) `
    -CapabilityMatrix (Read-KitUserExperiencePlanJson -Path $CapabilityMatrixPath) `
    -TemplateMetadata (Read-KitUserExperiencePlanJson -Path $TemplateMetadataPath) `
    -ScopeSemantics (Read-KitUserExperiencePlanJson -Path $ScopeSemanticsPath) `
    -VerificationPlan (Read-KitUserExperiencePlanJson -Path $VerificationPlanPath) `
    -WhatIf

Write-Host "Plan only: no user experience mutation executed"
Write-Host "True execution: false"
Write-Host "Registry mutation: false"
Write-Host "Profile mutation: false"
Write-Host "Default app mutation: false"
Write-Host "Start menu mutation: false"
Write-Host "Taskbar mutation: false"
Write-Host "Command exit code sufficient: false"
Write-Host "User configuration confirmed: false"
$report | ConvertTo-Json -Depth 12
