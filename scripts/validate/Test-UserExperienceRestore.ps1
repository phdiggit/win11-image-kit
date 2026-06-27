[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/user-experience-restore.json",
    [string]$WindowsContextPath = "tests/fixtures/user-experience/windows-context/windows-11-24h2.json",
    [string]$DefaultAppsPath = "tests/fixtures/user-experience/default-apps/baseline.json",
    [string]$StartMenuPath = "tests/fixtures/user-experience/start-menu/baseline.json",
    [string]$TaskbarPath = "tests/fixtures/user-experience/taskbar/baseline.json",
    [string]$LocalPrivatePath,
    [string]$ReportPath,
    [ValidateSet("plan-only", "report-only", "fixture")]
    [string]$Mode = "plan-only"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-KitUserExperienceRestoreReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path

function Read-KitUserExperienceJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-KitUserExperienceRestoreRepoPath -RepoRoot $repoRoot -Path $Path
    Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

$manifest = Read-KitUserExperienceJson -Path $ManifestPath
$windowsContext = Read-KitUserExperienceJson -Path $WindowsContextPath
$defaultApps = Read-KitUserExperienceJson -Path $DefaultAppsPath
$startMenu = Read-KitUserExperienceJson -Path $StartMenuPath
$taskbar = Read-KitUserExperienceJson -Path $TaskbarPath
$localPrivatePathFixture = $null
if (-not [string]::IsNullOrWhiteSpace($LocalPrivatePath)) {
    $localPrivatePathFixture = Read-KitUserExperienceJson -Path $LocalPrivatePath
}

$report = New-KitUserExperienceRestoreReport `
    -Manifest $manifest `
    -RepoRoot $repoRoot `
    -Mode $Mode `
    -WindowsContext $windowsContext `
    -DefaultApps $defaultApps `
    -StartMenu $startMenu `
    -Taskbar $taskbar `
    -LocalPrivatePathFixture $localPrivatePathFixture `
    -WhatIf

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $resolvedReportPath = Resolve-KitUserExperienceRestoreRepoPath -RepoRoot $repoRoot -Path $ReportPath
    $reportDirectory = Split-Path -Path $resolvedReportPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Write-Host "User experience restore report written: $resolvedReportPath"
}

$report

if (
    $report.summary.failedCount -gt 0 -or
    $report.summary.blockedCount -gt 0 -or
    $report.summary.registryWriteCount -gt 0 -or
    $report.summary.profileWriteCount -gt 0 -or
    $report.summary.defaultAppMutationCount -gt 0 -or
    $report.summary.startMenuMutationCount -gt 0 -or
    $report.summary.taskbarMutationCount -gt 0 -or
    $report.summary.unsupportedVersionCount -gt 0 -or
    $report.summary.missingBuildCount -gt 0 -or
    $report.summary.missingCapabilityCount -gt 0 -or
    $report.summary.localPrivatePathCount -gt 0 -or
    $report.trueExecution
) {
    exit 1
}
