[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreFinalStopLineHandoffReport.ps1"
. "$PSScriptRoot\..\common\FutureTrueUxRestore.ValidatorPrimitives.ps1"

$repoRoot = Get-FutureTrueUxRestoreValidatorRepoRoot -ValidatorScriptRoot $PSScriptRoot
$validatorState = New-FutureTrueUxRestoreValidatorState

$manifest = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path $ManifestPath
$section = $manifest.finalStopLineHandoff

Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.enabled -eq $true) -Message "finalStopLineHandoff is enabled"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.authorizationApproved -eq $false) -Message "authorizationApproved remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.executionApproved -eq $false) -Message "executionApproved remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.executeReady -eq $false) -Message "executeReady remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.trueExecution -eq $false) -Message "trueExecution remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.mutationCount -eq 0) -Message "mutationCount remains 0"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (@($section.allowedStopLineDecisions) -contains "pause-at-stop-line") -Message "pause-at-stop-line is allowed"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (@($section.allowedStopLineDecisions) -contains "start-true-restore-planning") -Message "true restore planning decision is manual planning only"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (@($section.forbiddenStopLineStates) -contains "closure-ready") -Message "closure-ready is forbidden"

$fixtureRoot = "tests/fixtures/user-experience/future-true-restore/final-stop-line-handoff"
$fixtureFiles = @(
    "pause-at-stop-line.json",
    "request-rework-for-missing-runner-gate.json",
    "start-true-restore-planning-requires-new-chain.json",
    "auto-close-wording-blocked.json",
    "execute-ready-wording-blocked.json"
)

$caseReports = @()
foreach ($fileName in $fixtureFiles) {
    $request = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path "$fixtureRoot/$fileName"
    $report = New-FutureTrueUxRestoreFinalStopLineHandoffReport -Manifest $manifest -Request $request -RepoRoot $repoRoot
    $expectedDecision = [string]$request.expectedDecision
    $caseReports += [pscustomobject][ordered]@{
        name = $fileName
        stopLineDecision = $report.stopLineDecision
        expectedDecision = $expectedDecision
        blockingReasons = @($report.blockingReasons)
        needsReworkReasons = @($report.needsReworkReasons)
    }

    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.stopLineDecision -eq $expectedDecision) -Message "$fileName matches expected decision"
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.authorizationApproved -eq $false -and $report.executionApproved -eq $false -and $report.executeReady -eq $false -and $report.trueExecution -eq $false -and $report.mutationCount -eq 0) -Message "$fileName remains non-executing"
}

$repoReport = New-FutureTrueUxRestoreFinalStopLineHandoffReport -Manifest $manifest -Request $null -RepoRoot $repoRoot
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($repoReport.stopLineDecision -eq "pause-at-stop-line") -Message "repository defaults to pause-at-stop-line"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($repoReport.blockingReasons.Count -eq 0) -Message "repository final stop-line has no blockers"

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-final-stop-line-handoff-validation"
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    status = Get-FutureTrueUxRestoreValidatorStatus -State $validatorState
    failureCount = Get-FutureTrueUxRestoreValidatorFailureCount -State $validatorState
    failures = @($validatorState.failures)
    repositoryHandoff = $repoReport
    cases = @($caseReports)
}

Write-FutureTrueUxRestoreValidatorReport -RepoRoot $repoRoot -ReportPath $ReportPath -ReportObject $reportObject -SuccessMessage "Future true UX final stop-line handoff report written" -Depth 14
Complete-FutureTrueUxRestoreValidatorRun -State $validatorState -ReportObject $reportObject
