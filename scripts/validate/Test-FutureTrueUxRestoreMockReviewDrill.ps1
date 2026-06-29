[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreMockReviewDrillReport.ps1"
. "$PSScriptRoot\..\common\FutureTrueUxRestore.ValidatorPrimitives.ps1"

$repoRoot = Get-FutureTrueUxRestoreValidatorRepoRoot -ValidatorScriptRoot $PSScriptRoot
$validatorState = New-FutureTrueUxRestoreValidatorState

$manifest = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path $ManifestPath
$section = $manifest.mockReviewDrill

Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.enabled -eq $true) -Message "mockReviewDrill is enabled"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.mode -eq "mock-review-drill") -Message "mockReviewDrill mode is fixed"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.defaultScope -eq "current-user") -Message "default scope is current-user"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.authorizationApproved -eq $false) -Message "authorizationApproved remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.executionApproved -eq $false) -Message "executionApproved remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.executeReady -eq $false) -Message "executeReady remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.trueExecution -eq $false) -Message "trueExecution remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.mutationCount -eq 0) -Message "mutationCount remains 0"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (-not (@($section.allowedMockDecisions) -contains "execute-ready")) -Message "allowed mock decisions exclude execute-ready"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ((@($section.forbiddenMockDecisions) -contains "execute-ready") -and (@($section.forbiddenMockDecisions) -contains "executed") -and (@($section.forbiddenMockDecisions) -contains "completed")) -Message "execute-ready, executed, and completed are forbidden"

$fixtureRoot = "tests/fixtures/user-experience/future-true-restore/mock-review"
$complete = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path "$fixtureRoot/current-user-complete-packet.json"
$completeReport = New-FutureTrueUxRestoreMockReviewDrillReport -Manifest $manifest -Request $complete -RepoRoot $repoRoot
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($completeReport.reviewDecision -eq "authorization-review-ready") -Message "complete current-user packet can be authorization-review-ready"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($completeReport.packetStatus -eq "complete") -Message "complete current-user packet is complete"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($completeReport.executionDecision -eq "not-approved") -Message "execution decision remains not-approved"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($completeReport.blockedForExecution -eq $true) -Message "complete packet remains blocked for execution"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($completeReport.trueExecution -eq $false -and $completeReport.mutationCount -eq 0 -and $completeReport.executeReady -eq $false) -Message "complete packet does not execute"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (@($completeReport.decisionLedger.stage) -contains "execute-ready-blocked") -Message "decision ledger includes execute-ready-blocked"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($completeReport.transcript.warning -match "not execution approval") -Message "transcript warns review-ready is not execution approval"

$blockedCases = @(
    @{ Name = "negative-missing-reviewer-checklist"; Path = "$fixtureRoot/negative-missing-reviewer-checklist.json"; Pattern = "reviewerChecklist" },
    @{ Name = "negative-cross-scope-packet"; Path = "$fixtureRoot/negative-cross-scope-packet.json"; Pattern = "scope guard" },
    @{ Name = "negative-private-path"; Path = "$fixtureRoot/negative-private-path.json"; Pattern = "private path" },
    @{ Name = "negative-execute-ready"; Path = "$fixtureRoot/negative-execute-ready.json"; Pattern = "execute-ready" },
    @{ Name = "negative-executed"; Path = "$fixtureRoot/negative-executed.json"; Pattern = "executed" },
    @{ Name = "negative-completed"; Path = "$fixtureRoot/negative-completed.json"; Pattern = "completed" },
    @{ Name = "negative-auto-close-keyword"; Path = "$fixtureRoot/negative-auto-close-keyword.json"; Pattern = "auto-close" }
)

$caseReports = @([pscustomobject][ordered]@{ name = "current-user-complete-packet"; reviewDecision = $completeReport.reviewDecision; blockedReasons = @($completeReport.blockedReasons) })
foreach ($case in $blockedCases) {
    $request = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path $case.Path
    $report = New-FutureTrueUxRestoreMockReviewDrillReport -Manifest $manifest -Request $request -RepoRoot $repoRoot
    $caseReports += [pscustomobject][ordered]@{ name = $case.Name; reviewDecision = $report.reviewDecision; blockedReasons = @($report.blockedReasons) }
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.reviewDecision -eq "blocked") -Message "$($case.Name) is blocked"
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (($report.blockedReasons -join "`n") -match [regex]::Escape($case.Pattern)) -Message "$($case.Name) records expected blocked reason"
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.trueExecution -eq $false -and $report.mutationCount -eq 0 -and $report.executeReady -eq $false) -Message "$($case.Name) does not execute"
}

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-mock-review-drill-validation"
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    status = Get-FutureTrueUxRestoreValidatorStatus -State $validatorState
    failureCount = Get-FutureTrueUxRestoreValidatorFailureCount -State $validatorState
    failures = @($validatorState.failures)
    complete = $completeReport
    cases = @($caseReports)
}

Write-FutureTrueUxRestoreValidatorReport -RepoRoot $repoRoot -ReportPath $ReportPath -ReportObject $reportObject -SuccessMessage "Future true UX mock review drill report written"
Complete-FutureTrueUxRestoreValidatorRun -State $validatorState -ReportObject $reportObject
