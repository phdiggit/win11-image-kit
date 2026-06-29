[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$BaselinePath = "tests/fixtures/user-experience/future-true-restore/current-user/baseline-blocked.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreCurrentUserDryRunReport.ps1"
. "$PSScriptRoot\..\common\FutureTrueUxRestore.ValidatorPrimitives.ps1"

$repoRoot = Get-FutureTrueUxRestoreValidatorRepoRoot -ValidatorScriptRoot $PSScriptRoot
$validatorState = New-FutureTrueUxRestoreValidatorState

$manifest = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path $ManifestPath
$section = $manifest.currentUserDryRun

Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.enabled -eq $true) -Message "currentUserDryRun is enabled"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.scope -eq "current-user") -Message "currentUserDryRun scope is current-user"
foreach ($flagName in @("authorizationApproved", "executionApproved", "allowCurrentUserMutation", "allowDefaultUserFallback", "allowMachineFallback", "allowOfflineImageFallback")) {
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ([bool]$section.$flagName -eq $false) -Message "$flagName remains false"
}

$baseline = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path $BaselinePath
$baselineReport = New-FutureTrueUxRestoreCurrentUserDryRunReport -Manifest $manifest -Request $baseline -RepoRoot $repoRoot
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($baselineReport.decision -eq "blocked") -Message "baseline remains blocked"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($baselineReport.trueExecution -eq $false) -Message "baseline trueExecution is false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($baselineReport.mutationCount -eq 0) -Message "baseline mutationCount is zero"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($baselineReport.currentUserConfirmed -eq $false) -Message "current user is not confirmed in this stage"

$cases = @(
    @{ Name = "dry-run-ready-no-execute"; Path = "tests/fixtures/user-experience/future-true-restore/current-user/dry-run-ready-no-execute.json"; Decision = "dry-run-ready"; Pattern = "" },
    @{ Name = "missing-redacted-user"; Path = "tests/fixtures/user-experience/future-true-restore/current-user/missing-redacted-user.json"; Decision = "blocked"; Pattern = "redactedUserIdentity" },
    @{ Name = "default-user-scope-claim-blocked"; Path = "tests/fixtures/user-experience/future-true-restore/current-user/default-user-scope-claim-blocked.json"; Decision = "blocked"; Pattern = "default-user" },
    @{ Name = "machine-scope-claim-blocked"; Path = "tests/fixtures/user-experience/future-true-restore/current-user/machine-scope-claim-blocked.json"; Decision = "blocked"; Pattern = "machine" },
    @{ Name = "offline-image-scope-claim-blocked"; Path = "tests/fixtures/user-experience/future-true-restore/current-user/offline-image-scope-claim-blocked.json"; Decision = "blocked"; Pattern = "offline-image" },
    @{ Name = "authorization-approved-without-execution-blocked"; Path = "tests/fixtures/user-experience/future-true-restore/current-user/authorization-approved-without-execution-blocked.json"; Decision = "blocked"; Pattern = "authorization approval without execution approval" },
    @{ Name = "execution-approved-without-authorization-blocked"; Path = "tests/fixtures/user-experience/future-true-restore/current-user/execution-approved-without-authorization-blocked.json"; Decision = "blocked"; Pattern = "execution approval without authorization approval" },
    @{ Name = "exit-code-only-success-blocked"; Path = "tests/fixtures/user-experience/future-true-restore/current-user/exit-code-only-success-blocked.json"; Decision = "blocked"; Pattern = "command exit code" },
    @{ Name = "private-profile-path-blocked"; Path = "tests/fixtures/user-experience/future-true-restore/current-user/private-profile-path-blocked.json"; Decision = "blocked"; Pattern = "private profile path" },
    @{ Name = "mutation-requested-blocked"; Path = "tests/fixtures/user-experience/future-true-restore/current-user/mutation-requested-blocked.json"; Decision = "blocked"; Pattern = "mutation request" }
)

$caseReports = @()
foreach ($case in $cases) {
    $request = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path $case.Path
    $report = New-FutureTrueUxRestoreCurrentUserDryRunReport -Manifest $manifest -Request $request -RepoRoot $repoRoot
    $caseReports += [pscustomobject][ordered]@{
        name = $case.Name
        decision = $report.decision
        blockedReasons = @($report.blockedReasons)
    }

    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.decision -eq $case.Decision) -Message "$($case.Name) decision is $($case.Decision)"
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.trueExecution -eq $false -and $report.mutationCount -eq 0 -and $report.currentUserConfirmed -eq $false) -Message "$($case.Name) does not execute or confirm current user"
    if (-not [string]::IsNullOrWhiteSpace($case.Pattern)) {
        Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (($report.blockedReasons -join "`n") -match [regex]::Escape($case.Pattern)) -Message "$($case.Name) records expected blocked reason"
    }
}

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-current-user-dry-run-validation"
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    status = Get-FutureTrueUxRestoreValidatorStatus -State $validatorState
    failureCount = Get-FutureTrueUxRestoreValidatorFailureCount -State $validatorState
    failures = @($validatorState.failures)
    baseline = $baselineReport
    cases = @($caseReports)
}

Write-FutureTrueUxRestoreValidatorReport -RepoRoot $repoRoot -ReportPath $ReportPath -ReportObject $reportObject -SuccessMessage "Future true UX current-user dry-run report written"
Complete-FutureTrueUxRestoreValidatorRun -State $validatorState -ReportObject $reportObject
