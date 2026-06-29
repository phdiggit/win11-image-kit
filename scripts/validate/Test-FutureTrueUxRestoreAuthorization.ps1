[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$BaselineAuthorizationPath = "tests/fixtures/user-experience/future-true-restore/authorization/baseline-blocked.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreAuthorizationReport.ps1"
. "$PSScriptRoot\..\common\FutureTrueUxRestore.ValidatorPrimitives.ps1"

$repoRoot = Get-FutureTrueUxRestoreValidatorRepoRoot -ValidatorScriptRoot $PSScriptRoot
$validatorState = New-FutureTrueUxRestoreValidatorState

$manifest = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path $ManifestPath
$baseline = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path $BaselineAuthorizationPath
$baselineReport = New-FutureTrueUxRestoreAuthorizationReport -Manifest $manifest -AuthorizationRequest $baseline -RepoRoot $repoRoot

Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($manifest.mode -eq "authorization-intake") -Message "manifest mode is authorization-intake"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($manifest.defaultDecision -eq "blocked") -Message "manifest default decision is blocked"
foreach ($flagName in @("allowRegistryMutation", "allowProfileMutation", "allowDefaultUserHiveMutation", "allowDefaultAppMutation", "allowStartMenuMutation", "allowTaskbarMutation", "allowDismMutation", "allowAppxMutation", "allowNetworkDownload")) {
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ([bool]$manifest.$flagName -eq $false) -Message "$flagName remains false"
}

Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($baselineReport.decision -eq "blocked") -Message "baseline report remains blocked"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($baselineReport.trueExecution -eq $false) -Message "baseline trueExecution is false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($baselineReport.mutationCount -eq 0) -Message "baseline mutationCount is zero"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($baselineReport.commandExitCodeSufficient -eq $false) -Message "command exit code is not sufficient"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($baselineReport.userConfigurationConfirmed -eq $false) -Message "user configuration is not confirmed"

$unsafeCases = @(
    @{ Name = "current-user-missing-rollback"; Path = "tests/fixtures/user-experience/future-true-restore/authorization/current-user-missing-rollback.json"; Pattern = "rollbackPlan" },
    @{ Name = "default-user-scope-mismatch"; Path = "tests/fixtures/user-experience/future-true-restore/authorization/default-user-scope-mismatch.json"; Pattern = "scope mismatch" },
    @{ Name = "offline-image-missing-identity"; Path = "tests/fixtures/user-experience/future-true-restore/authorization/offline-image-missing-identity.json"; Pattern = "targetIdentity" },
    @{ Name = "mutation-requested-blocked"; Path = "tests/fixtures/user-experience/future-true-restore/authorization/mutation-requested-blocked.json"; Pattern = "mutation request" },
    @{ Name = "exit-code-only-success-blocked"; Path = "tests/fixtures/user-experience/future-true-restore/authorization/exit-code-only-success-blocked.json"; Pattern = "command exit code" },
    @{ Name = "private-path-blocked"; Path = "tests/fixtures/user-experience/future-true-restore/evidence/private-path-blocked.json"; Pattern = "private local path" }
)

$caseReports = @()
foreach ($case in $unsafeCases) {
    $request = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path $case.Path
    $report = New-FutureTrueUxRestoreAuthorizationReport -Manifest $manifest -AuthorizationRequest $request -RepoRoot $repoRoot
    $caseReports += [pscustomobject][ordered]@{
        name = $case.Name
        decision = $report.decision
        blockedReasons = @($report.blockedReasons)
    }

    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.decision -eq "blocked") -Message "$($case.Name) remains blocked"
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (($report.blockedReasons -join "`n") -match [regex]::Escape($case.Pattern)) -Message "$($case.Name) records expected blocked reason"
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.trueExecution -eq $false -and $report.mutationCount -eq 0) -Message "$($case.Name) does not execute"
}

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-authorization-validation"
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    status = Get-FutureTrueUxRestoreValidatorStatus -State $validatorState
    failureCount = Get-FutureTrueUxRestoreValidatorFailureCount -State $validatorState
    failures = @($validatorState.failures)
    baseline = $baselineReport
    unsafeCases = @($caseReports)
}

Write-FutureTrueUxRestoreValidatorReport -RepoRoot $repoRoot -ReportPath $ReportPath -ReportObject $reportObject -SuccessMessage "Future true UX restore authorization report written"
Complete-FutureTrueUxRestoreValidatorRun -State $validatorState -ReportObject $reportObject
