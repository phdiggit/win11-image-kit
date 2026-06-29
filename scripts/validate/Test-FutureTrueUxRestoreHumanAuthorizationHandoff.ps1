[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreHumanAuthorizationHandoffReport.ps1"
. "$PSScriptRoot\..\common\FutureTrueUxRestore.ValidatorPrimitives.ps1"

$repoRoot = Get-FutureTrueUxRestoreValidatorRepoRoot -ValidatorScriptRoot $PSScriptRoot
$validatorState = New-FutureTrueUxRestoreValidatorState

$manifest = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path $ManifestPath
$section = $manifest.humanAuthorizationHandoff

Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.enabled -eq $true) -Message "humanAuthorizationHandoff is enabled"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.authorizationApproved -eq $false) -Message "authorizationApproved remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.executionApproved -eq $false) -Message "executionApproved remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.executeReady -eq $false) -Message "executeReady remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.trueExecution -eq $false) -Message "trueExecution remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.mutationCount -eq 0) -Message "mutationCount remains 0"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (@($section.allowedHandoffDecisions) -contains "handoff-ready-for-human-review") -Message "handoff-ready-for-human-review is allowed"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (-not (@($section.allowedHandoffDecisions) -contains "authorization-review-ready")) -Message "authorization-review-ready is not a handoff decision"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (@($section.forbiddenHandoffDecisions) -contains "closure-ready") -Message "closure-ready is forbidden"

$fixtureRoot = "tests/fixtures/user-experience/future-true-restore/human-authorization-handoff"
$fixtureFiles = @(
    "complete-current-user-human-handoff.json",
    "missing-artifact-index.json",
    "missing-manual-decision-placeholder.json",
    "handoff-promotes-preview-to-authorization-ready.json",
    "handoff-promotes-report-to-real-evidence.json",
    "handoff-drifts-to-execute-ready.json",
    "handoff-mentions-issue-18-closure.json",
    "private-path-not-redacted.json"
)

$caseReports = @()
foreach ($fileName in $fixtureFiles) {
    $request = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path "$fixtureRoot/$fileName"
    $report = New-FutureTrueUxRestoreHumanAuthorizationHandoffReport -Manifest $manifest -Request $request -RepoRoot $repoRoot
    $expectedDecision = [string]$request.expectedDecision
    $caseReports += [pscustomobject][ordered]@{
        name = $fileName
        handoffDecision = $report.handoffDecision
        expectedDecision = $expectedDecision
        blockingReasons = @($report.blockingReasons)
        needsReworkReasons = @($report.needsReworkReasons)
    }

    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.handoffDecision -eq $expectedDecision) -Message "$fileName matches expected decision"
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.authorizationApproved -eq $false -and $report.executionApproved -eq $false -and $report.executeReady -eq $false -and $report.trueExecution -eq $false -and $report.mutationCount -eq 0) -Message "$fileName remains non-executing"
    foreach ($requiredSection in @($section.requiredHandoffSections)) {
        Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.handoffSections.PSObject.Properties.Name -contains [string]$requiredSection) -Message "$fileName includes $requiredSection"
    }
}

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-human-authorization-handoff-validation"
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    status = Get-FutureTrueUxRestoreValidatorStatus -State $validatorState
    failureCount = Get-FutureTrueUxRestoreValidatorFailureCount -State $validatorState
    failures = @($validatorState.failures)
    cases = @($caseReports)
}

Write-FutureTrueUxRestoreValidatorReport -RepoRoot $repoRoot -ReportPath $ReportPath -ReportObject $reportObject -SuccessMessage "Future true UX human authorization handoff report written"
Complete-FutureTrueUxRestoreValidatorRun -State $validatorState -ReportObject $reportObject
