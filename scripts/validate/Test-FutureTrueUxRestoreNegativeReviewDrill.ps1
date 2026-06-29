[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$FixtureRoot = "tests/fixtures/user-experience/future-true-restore/negative-review",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreNegativeReviewDrillReport.ps1"
. "$PSScriptRoot\..\common\FutureTrueUxRestore.ValidatorPrimitives.ps1"

$repoRoot = Get-FutureTrueUxRestoreValidatorRepoRoot -ValidatorScriptRoot $PSScriptRoot
$validatorState = New-FutureTrueUxRestoreValidatorState

$manifest = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path $ManifestPath
$section = $manifest.negativeReviewDrill

Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.enabled -eq $true) -Message "negativeReviewDrill is enabled"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.mode -eq "negative-review-drill") -Message "negativeReviewDrill mode is fixed"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.defaultScope -eq "current-user") -Message "default scope is current-user"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.authorizationApproved -eq $false) -Message "authorizationApproved remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.executionApproved -eq $false) -Message "executionApproved remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.executeReady -eq $false) -Message "executeReady remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.trueExecution -eq $false) -Message "trueExecution remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.mutationCount -eq 0) -Message "mutationCount remains 0"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (-not (@($section.allowedNegativeDecisions) -contains "authorization-review-ready")) -Message "allowed negative decisions exclude review-ready"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (-not (@($section.allowedNegativeDecisions) -contains "execute-ready")) -Message "allowed negative decisions exclude execute-ready"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ((@($section.forbiddenNegativeDecisions) -contains "authorization-review-ready") -and (@($section.forbiddenNegativeDecisions) -contains "execute-ready") -and (@($section.forbiddenNegativeDecisions) -contains "executed") -and (@($section.forbiddenNegativeDecisions) -contains "completed")) -Message "review-ready and execution states are forbidden"

$resolvedFixtureRoot = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $FixtureRoot
$fixtures = @(Get-ChildItem -LiteralPath $resolvedFixtureRoot -Filter "*.json" | Sort-Object Name)
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($fixtures.Count -ge 6) -Message "at least six negative review fixtures exist"

$caseReports = @()
foreach ($fixture in $fixtures) {
    $request = Get-Content -LiteralPath $fixture.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $report = New-FutureTrueUxRestoreNegativeReviewDrillReport -Manifest $manifest -Request $request -RepoRoot $repoRoot
    $expectedCodes = @($request.expectedReasonCodes)

    $caseReports += [pscustomobject][ordered]@{
        name = $fixture.Name
        decision = $report.reviewDecision
        reasonCodes = @($report.reasonCodes)
        executeReady = $report.executeReady
        trueExecution = $report.trueExecution
        mutationCount = $report.mutationCount
    }

    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.reportType -eq "future-true-ux-restore-negative-review-drill") -Message "$($fixture.Name) emits negative drill report"
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.reviewDecision -eq $request.expectedDecision) -Message "$($fixture.Name) matches expected decision"
    foreach ($code in $expectedCodes) {
        Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (@($report.reasonCodes) -contains $code) -Message "$($fixture.Name) records $code"
    }
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.executeReady -eq $false -and $report.trueExecution -eq $false -and $report.mutationCount -eq 0) -Message "$($fixture.Name) does not execute"
}

foreach ($requiredCode in @($section.requiredReasonCodes)) {
    $seen = $false
    foreach ($caseReport in $caseReports) {
        if (@($caseReport.reasonCodes) -contains $requiredCode) {
            $seen = $true
            break
        }
    }
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition $seen -Message "bundle covers $requiredCode"
}

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-negative-review-drill-validation"
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    status = Get-FutureTrueUxRestoreValidatorStatus -State $validatorState
    failureCount = Get-FutureTrueUxRestoreValidatorFailureCount -State $validatorState
    failures = @($validatorState.failures)
    cases = @($caseReports)
}

Write-FutureTrueUxRestoreValidatorReport -RepoRoot $repoRoot -ReportPath $ReportPath -ReportObject $reportObject -SuccessMessage "Future true UX negative review drill report written"
Complete-FutureTrueUxRestoreValidatorRun -State $validatorState -ReportObject $reportObject
