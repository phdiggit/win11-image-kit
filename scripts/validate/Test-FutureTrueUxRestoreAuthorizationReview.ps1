[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreAuthorizationReviewReport.ps1"
. "$PSScriptRoot\..\common\FutureTrueUxRestore.ValidatorPrimitives.ps1"

$repoRoot = Get-FutureTrueUxRestoreValidatorRepoRoot -ValidatorScriptRoot $PSScriptRoot
$validatorState = New-FutureTrueUxRestoreValidatorState

$manifest = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path $ManifestPath
$section = $manifest.authorizationReview

Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.enabled -eq $true) -Message "authorizationReview is enabled"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.authorizationApproved -eq $false) -Message "authorizationApproved remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.executionApproved -eq $false) -Message "executionApproved remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.executeReady -eq $false) -Message "executeReady remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (@($section.forbiddenReviewDecisions) -contains "execute-ready") -Message "execute-ready is forbidden"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (-not (@($section.allowedReviewDecisions) -contains "execute-ready")) -Message "allowed decisions exclude execute-ready"

$fixtureRoot = "tests/fixtures/user-experience/future-true-restore/review"
$baseline = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path "$fixtureRoot/baseline-blocked.json"
$baselineReport = New-FutureTrueUxRestoreAuthorizationReviewReport -Manifest $manifest -Request $baseline -RepoRoot $repoRoot
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($baselineReport.reviewDecision -eq "blocked") -Message "baseline remains blocked"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($baselineReport.trueExecution -eq $false -and $baselineReport.mutationCount -eq 0 -and $baselineReport.executeReady -eq $false) -Message "baseline does not execute"

$readyCases = @(
    "current-user-review-ready.json",
    "default-user-review-ready.json",
    "offline-image-review-ready.json",
    "machine-review-ready.json"
)
$caseReports = @()
foreach ($fileName in $readyCases) {
    $request = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path "$fixtureRoot/$fileName"
    $report = New-FutureTrueUxRestoreAuthorizationReviewReport -Manifest $manifest -Request $request -RepoRoot $repoRoot
    $caseReports += [pscustomobject][ordered]@{ name = $fileName; reviewDecision = $report.reviewDecision; blockedReasons = @($report.blockedReasons) }
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.reviewDecision -eq "authorization-review-ready") -Message "$fileName can be authorization-review-ready"
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.evidencePacketStatus -eq "complete") -Message "$fileName packet is complete"
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.trueExecution -eq $false -and $report.mutationCount -eq 0 -and $report.executeReady -eq $false) -Message "$fileName does not execute"
}

$blockedCases = @(
    @{ Name = "missing-before-evidence-blocked"; Path = "$fixtureRoot/missing-before-evidence-blocked.json"; Pattern = "beforeEvidence" },
    @{ Name = "missing-rollback-blocked"; Path = "$fixtureRoot/missing-rollback-blocked.json"; Pattern = "rollbackPlan" },
    @{ Name = "private-path-blocked"; Path = "$fixtureRoot/private-path-blocked.json"; Pattern = "private path" },
    @{ Name = "cross-scope-evidence-blocked"; Path = "$fixtureRoot/cross-scope-evidence-blocked.json"; Pattern = "scope guard" },
    @{ Name = "execute-ready-requested-blocked"; Path = "$fixtureRoot/execute-ready-requested-blocked.json"; Pattern = "execute-ready" },
    @{ Name = "execution-approved-requested-blocked"; Path = "$fixtureRoot/execution-approved-requested-blocked.json"; Pattern = "execution approval" },
    @{ Name = "auto-close-keyword-blocked"; Path = "$fixtureRoot/auto-close-keyword-blocked.json"; Pattern = "auto-close" },
    @{ Name = "exit-code-only-success-blocked"; Path = "$fixtureRoot/exit-code-only-success-blocked.json"; Pattern = "command exit code" }
)

foreach ($case in $blockedCases) {
    $request = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path $case.Path
    $report = New-FutureTrueUxRestoreAuthorizationReviewReport -Manifest $manifest -Request $request -RepoRoot $repoRoot
    $caseReports += [pscustomobject][ordered]@{ name = $case.Name; reviewDecision = $report.reviewDecision; blockedReasons = @($report.blockedReasons) }
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.reviewDecision -eq "blocked") -Message "$($case.Name) is blocked"
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (($report.blockedReasons -join "`n") -match [regex]::Escape($case.Pattern)) -Message "$($case.Name) records expected blocked reason"
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.trueExecution -eq $false -and $report.mutationCount -eq 0 -and $report.executeReady -eq $false) -Message "$($case.Name) does not execute"
}

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-authorization-review-validation"
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    status = Get-FutureTrueUxRestoreValidatorStatus -State $validatorState
    failureCount = Get-FutureTrueUxRestoreValidatorFailureCount -State $validatorState
    failures = @($validatorState.failures)
    baseline = $baselineReport
    cases = @($caseReports)
}

Write-FutureTrueUxRestoreValidatorReport -RepoRoot $repoRoot -ReportPath $ReportPath -ReportObject $reportObject -SuccessMessage "Future true UX authorization review report written"
Complete-FutureTrueUxRestoreValidatorRun -State $validatorState -ReportObject $reportObject
