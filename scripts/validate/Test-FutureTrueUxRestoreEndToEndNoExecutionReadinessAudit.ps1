[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreEndToEndNoExecutionReadinessAuditReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$script:Failures = @()

function Read-FutureTrueUxNoExecutionAuditJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $Path
    Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Assert-FutureTrueUxNoExecutionAudit {
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if ($Condition) {
        Write-Host "[OK] $Message" -ForegroundColor Green
    } else {
        $script:Failures += $Message
        Write-Host "[ERROR] $Message" -ForegroundColor Red
    }
}

$manifest = Read-FutureTrueUxNoExecutionAuditJson -Path $ManifestPath
$section = $manifest.endToEndNoExecutionReadinessAudit

Assert-FutureTrueUxNoExecutionAudit -Condition ($section.enabled -eq $true) -Message "endToEndNoExecutionReadinessAudit is enabled"
Assert-FutureTrueUxNoExecutionAudit -Condition ($section.authorizationApproved -eq $false) -Message "authorizationApproved remains false"
Assert-FutureTrueUxNoExecutionAudit -Condition ($section.executionApproved -eq $false) -Message "executionApproved remains false"
Assert-FutureTrueUxNoExecutionAudit -Condition ($section.executeReady -eq $false) -Message "executeReady remains false"
Assert-FutureTrueUxNoExecutionAudit -Condition ($section.trueExecution -eq $false) -Message "trueExecution remains false"
Assert-FutureTrueUxNoExecutionAudit -Condition ($section.mutationCount -eq 0) -Message "mutationCount remains 0"
Assert-FutureTrueUxNoExecutionAudit -Condition (@($section.requiredLayers) -contains "human-authorization-handoff") -Message "human authorization handoff is covered"
Assert-FutureTrueUxNoExecutionAudit -Condition (@($section.forbiddenStates) -contains "closure-ready") -Message "closure-ready is forbidden"

$fixtureRoot = "tests/fixtures/user-experience/future-true-restore/no-execution-readiness-audit"
$fixtureFiles = @(
    "complete-no-execution-chain.json",
    "missing-layer.json",
    "execution-flag-drift.json",
    "state-promotion-drift.json",
    "issue-18-closure-drift.json",
    "dangerous-command-vocabulary.json",
    "missing-runner-stop-line.json"
)

$caseReports = @()
foreach ($fileName in $fixtureFiles) {
    $request = Read-FutureTrueUxNoExecutionAuditJson -Path "$fixtureRoot/$fileName"
    $report = New-FutureTrueUxRestoreEndToEndNoExecutionReadinessAuditReport -Manifest $manifest -Request $request -RepoRoot $repoRoot
    $expectedDecision = [string]$request.expectedDecision
    $caseReports += [pscustomobject][ordered]@{
        name = $fileName
        auditDecision = $report.auditDecision
        expectedDecision = $expectedDecision
        missingLayers = @($report.missingLayers)
        blockingReasons = @($report.blockingReasons)
        needsReworkReasons = @($report.needsReworkReasons)
    }

    Assert-FutureTrueUxNoExecutionAudit -Condition ($report.auditDecision -eq $expectedDecision) -Message "$fileName matches expected decision"
    Assert-FutureTrueUxNoExecutionAudit -Condition ($report.authorizationApproved -eq $false -and $report.executionApproved -eq $false -and $report.executeReady -eq $false -and $report.trueExecution -eq $false -and $report.mutationCount -eq 0) -Message "$fileName remains non-executing"
}

$repoReport = New-FutureTrueUxRestoreEndToEndNoExecutionReadinessAuditReport -Manifest $manifest -Request $null -RepoRoot $repoRoot
Assert-FutureTrueUxNoExecutionAudit -Condition ($repoReport.auditDecision -eq "audit-ready") -Message "repository audit is ready"
Assert-FutureTrueUxNoExecutionAudit -Condition ($repoReport.blockingReasons.Count -eq 0) -Message "repository audit has no blockers"

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-end-to-end-no-execution-readiness-audit-validation"
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    status = $(if ($script:Failures.Count -eq 0) { "passed" } else { "failed" })
    failureCount = $script:Failures.Count
    failures = @($script:Failures)
    repositoryAudit = $repoReport
    cases = @($caseReports)
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $resolvedReportPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $ReportPath
    $reportDirectory = Split-Path -Path $resolvedReportPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $reportObject | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Write-Host "Future true UX end-to-end no-execution readiness audit report written: $resolvedReportPath"
}

$reportObject

if ($script:Failures.Count -gt 0) {
    exit 1
}
