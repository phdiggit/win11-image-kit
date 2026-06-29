[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreIntegratedPacketPreviewReport.ps1"
. "$PSScriptRoot\..\common\FutureTrueUxRestore.ValidatorPrimitives.ps1"

$repoRoot = Get-FutureTrueUxRestoreValidatorRepoRoot -ValidatorScriptRoot $PSScriptRoot
$validatorState = New-FutureTrueUxRestoreValidatorState

$manifest = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path $ManifestPath
$section = $manifest.integratedPacketPreview

Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.enabled -eq $true) -Message "integratedPacketPreview is enabled"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.authorizationApproved -eq $false) -Message "authorizationApproved remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.executionApproved -eq $false) -Message "executionApproved remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.executeReady -eq $false) -Message "executeReady remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.trueExecution -eq $false) -Message "trueExecution remains false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.mutationCount -eq 0) -Message "mutationCount remains 0"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (@($section.allowedPreviewDecisions) -contains "packet-preview-ready") -Message "packet-preview-ready is allowed"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (-not (@($section.allowedPreviewDecisions) -contains "authorization-review-ready")) -Message "authorization-review-ready is not a preview decision"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (@($section.forbiddenPreviewDecisions) -contains "execute-ready") -Message "execute-ready is forbidden"

$fixtureRoot = "tests/fixtures/user-experience/future-true-restore/packet-preview"
$fixtureFiles = @(
    "complete-current-user-packet-preview.json",
    "missing-runner-gate-reminder.json",
    "missing-negative-blocker-summary.json",
    "evidence-boundary-promotes-report-to-real.json",
    "preview-wording-drifts-to-authorization-ready.json",
    "preview-wording-drifts-to-execute-ready.json",
    "private-path-not-redacted.json"
)

$caseReports = @()
foreach ($fileName in $fixtureFiles) {
    $request = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path "$fixtureRoot/$fileName"
    $report = New-FutureTrueUxRestoreIntegratedPacketPreviewReport -Manifest $manifest -Request $request -RepoRoot $repoRoot
    $expectedDecision = [string]$request.expectedDecision
    $caseReports += [pscustomobject][ordered]@{
        name = $fileName
        previewDecision = $report.previewDecision
        expectedDecision = $expectedDecision
        blockingReasons = @($report.blockingReasons)
        needsReworkReasons = @($report.needsReworkReasons)
    }

    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.previewDecision -eq $expectedDecision) -Message "$fileName matches expected decision"
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.authorizationApproved -eq $false -and $report.executionApproved -eq $false -and $report.executeReady -eq $false -and $report.trueExecution -eq $false -and $report.mutationCount -eq 0) -Message "$fileName remains non-executing"
    foreach ($requiredSection in @($section.requiredPreviewSections)) {
        Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.packetPreviewSections.PSObject.Properties.Name -contains [string]$requiredSection) -Message "$fileName includes $requiredSection"
    }
}

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-integrated-packet-preview-validation"
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    status = Get-FutureTrueUxRestoreValidatorStatus -State $validatorState
    failureCount = Get-FutureTrueUxRestoreValidatorFailureCount -State $validatorState
    failures = @($validatorState.failures)
    cases = @($caseReports)
}

Write-FutureTrueUxRestoreValidatorReport -RepoRoot $repoRoot -ReportPath $ReportPath -ReportObject $reportObject -SuccessMessage "Future true UX integrated packet preview report written"
Complete-FutureTrueUxRestoreValidatorRun -State $validatorState -ReportObject $reportObject
