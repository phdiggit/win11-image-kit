[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreAuthorizationReport.ps1"
. "$PSScriptRoot\..\common\FutureTrueUxRestore.ValidatorPrimitives.ps1"

$repoRoot = Get-FutureTrueUxRestoreValidatorRepoRoot -ValidatorScriptRoot $PSScriptRoot
$validatorState = New-FutureTrueUxRestoreValidatorState

$manifest = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path $ManifestPath
$qualityGates = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path "manifests/quality-gates.json"

$helperPath = Join-Path $repoRoot "scripts\common\New-FutureTrueUxRestoreMockReviewDrillReport.ps1"
$fixturePath = Join-Path $repoRoot "tests\fixtures\user-experience\future-true-restore\mock-review"

Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (-not ($manifest.PSObject.Properties.Name -contains "mockReviewDrill")) -Message "mockReviewDrill manifest section is pruned"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (-not (@($qualityGates.gates.id) -contains "future-true-ux-mock-review-drill")) -Message "mock review drill quality gate is pruned"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (-not (Test-Path -LiteralPath $helperPath)) -Message "mock review drill report helper is pruned"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (-not (Test-Path -LiteralPath $fixturePath)) -Message "mock review fixture family is pruned"

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-mock-review-drill-pruned-validation"
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    status = Get-FutureTrueUxRestoreValidatorStatus -State $validatorState
    failureCount = Get-FutureTrueUxRestoreValidatorFailureCount -State $validatorState
    failures = @($validatorState.failures)
    pruned = [pscustomobject][ordered]@{
        manifestSection = "mockReviewDrill"
        qualityGate = "future-true-ux-mock-review-drill"
        reportHelper = "scripts/common/New-FutureTrueUxRestoreMockReviewDrillReport.ps1"
        fixtureFamily = "tests/fixtures/user-experience/future-true-restore/mock-review"
    }
    authorizationApproved = $false
    executionApproved = $false
    executeReady = $false
    trueExecution = $false
    mutationCount = 0
}

Write-FutureTrueUxRestoreValidatorReport -RepoRoot $repoRoot -ReportPath $ReportPath -ReportObject $reportObject -SuccessMessage "Future true UX mock review drill prune validation report written"
Complete-FutureTrueUxRestoreValidatorRun -State $validatorState -ReportObject $reportObject
