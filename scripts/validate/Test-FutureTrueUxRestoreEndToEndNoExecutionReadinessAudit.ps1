[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreEndToEndNoExecutionReadinessAuditReport.ps1"
. "$PSScriptRoot\..\common\FutureTrueUxRestore.ValidatorPrimitives.ps1"

$repoRoot = Get-FutureTrueUxRestoreValidatorRepoRoot -ValidatorScriptRoot $PSScriptRoot
$validatorState = New-FutureTrueUxRestoreValidatorState

$manifest = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path $ManifestPath
$section = $manifest.endToEndNoExecutionReadinessAudit

Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.enabled -eq $true) -Message "endToEndNoExecutionReadinessAudit is enabled"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.authorizationApproved -eq $false) -Message "authorizationApproved remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.executionApproved -eq $false) -Message "executionApproved remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.executeReady -eq $false) -Message "executeReady remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.trueExecution -eq $false) -Message "trueExecution remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.mutationCount -eq 0) -Message "mutationCount remains 0"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (@($section.requiredLayers) -contains "human-authorization-handoff") -Message "human authorization handoff is covered"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (@($section.forbiddenStates) -contains "closure-ready") -Message "closure-ready is forbidden"

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
    $request = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path "$fixtureRoot/$fileName"
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

    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.auditDecision -eq $expectedDecision) -Message "$fileName matches expected decision"
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.authorizationApproved -eq $false -and $report.executionApproved -eq $false -and $report.executeReady -eq $false -and $report.trueExecution -eq $false -and $report.mutationCount -eq 0) -Message "$fileName remains non-executing"
}

$repoReport = New-FutureTrueUxRestoreEndToEndNoExecutionReadinessAuditReport -Manifest $manifest -Request $null -RepoRoot $repoRoot
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($repoReport.auditDecision -eq "audit-ready") -Message "repository audit is ready"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($repoReport.blockingReasons.Count -eq 0) -Message "repository audit has no blockers"

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-end-to-end-no-execution-readiness-audit-validation"
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    status = Get-FutureTrueUxRestoreValidatorStatus -State $validatorState
    failureCount = Get-FutureTrueUxRestoreValidatorFailureCount -State $validatorState
    failures = @($validatorState.failures)
    repositoryAudit = $repoReport
    cases = @($caseReports)
}

Write-FutureTrueUxRestoreValidatorReport -RepoRoot $repoRoot -ReportPath $ReportPath -ReportObject $reportObject -SuccessMessage "Future true UX end-to-end no-execution readiness audit report written" -Depth 14
Complete-FutureTrueUxRestoreValidatorRun -State $validatorState -ReportObject $reportObject
