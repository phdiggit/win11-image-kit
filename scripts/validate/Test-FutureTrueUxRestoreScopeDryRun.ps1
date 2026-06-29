[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreScopeDryRunReport.ps1"
. "$PSScriptRoot\..\common\FutureTrueUxRestore.ValidatorPrimitives.ps1"

$repoRoot = Get-FutureTrueUxRestoreValidatorRepoRoot -ValidatorScriptRoot $PSScriptRoot
$validatorState = New-FutureTrueUxRestoreValidatorState

$manifest = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path $ManifestPath
$sectionExpectations = @(
    @{ Scope = "current-user"; Section = "currentUserDryRun"; Flags = @("authorizationApproved", "executionApproved", "allowCurrentUserMutation", "allowDefaultUserFallback", "allowMachineFallback", "allowOfflineImageFallback") },
    @{ Scope = "default-user"; Section = "defaultUserDryRun"; Flags = @("authorizationApproved", "executionApproved", "allowDefaultUserMutation", "allowCurrentUserFallback", "allowMachineFallback", "allowOfflineImageFallback") },
    @{ Scope = "offline-image"; Section = "offlineImageDryRun"; Flags = @("authorizationApproved", "executionApproved", "allowOfflineImageMutation", "allowCurrentMachineFallback", "allowCurrentUserFallback", "allowDefaultUserFallback") },
    @{ Scope = "machine"; Section = "machineDryRun"; Flags = @("authorizationApproved", "executionApproved", "allowMachineMutation", "allowCurrentUserFallback", "allowDefaultUserFallback", "allowOfflineImageFallback") }
)

foreach ($expectation in $sectionExpectations) {
    $section = $manifest.($expectation.Section)
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($null -ne $section) -Message "$($expectation.Section) section exists"
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.enabled -eq $true) -Message "$($expectation.Section) is enabled"
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.scope -eq $expectation.Scope) -Message "$($expectation.Section) scope is $($expectation.Scope)"
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($section.defaultDecision -eq "blocked") -Message "$($expectation.Section) defaults to blocked"
    foreach ($flagName in $expectation.Flags) {
        Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ([bool]$section.$flagName -eq $false) -Message "$($expectation.Section) $flagName remains false"
    }
}

$fixtureRoot = "tests/fixtures/user-experience/future-true-restore"
$scopeCases = @(
    @{
        Scope = "default-user"
        Baseline = "$fixtureRoot/default-user/baseline-blocked.json"
        Ready = "$fixtureRoot/default-user/dry-run-ready-no-execute.json"
        Cases = @(
            @{ Name = "missing-template-source"; Path = "$fixtureRoot/default-user/missing-template-source.json"; Pattern = "templateSource" },
            @{ Name = "current-user-scope-claim-blocked"; Path = "$fixtureRoot/default-user/current-user-scope-claim-blocked.json"; Pattern = "current-user" },
            @{ Name = "private-profile-path-blocked"; Path = "$fixtureRoot/default-user/private-profile-path-blocked.json"; Pattern = "private path" },
            @{ Name = "hive-load-requested-blocked"; Path = "$fixtureRoot/default-user/hive-load-requested-blocked.json"; Pattern = "hiveLoadRequested" },
            @{ Name = "mutation-requested-blocked"; Path = "$fixtureRoot/default-user/mutation-requested-blocked.json"; Pattern = "mutationRequested" },
            @{ Name = "exit-code-only-success-blocked"; Path = "$fixtureRoot/default-user/exit-code-only-success-blocked.json"; Pattern = "command exit code" },
            @{ Name = "manual-checklist-success-blocked"; Path = "$fixtureRoot/default-user/manual-checklist-success-blocked.json"; Pattern = "manual checklist" }
        )
    },
    @{
        Scope = "offline-image"
        Baseline = "$fixtureRoot/offline-image/baseline-blocked.json"
        Ready = "$fixtureRoot/offline-image/dry-run-ready-no-execute.json"
        Cases = @(
            @{ Name = "missing-image-identity"; Path = "$fixtureRoot/offline-image/missing-image-identity.json"; Pattern = "imageIdentity" },
            @{ Name = "current-machine-claim-blocked"; Path = "$fixtureRoot/offline-image/current-machine-claim-blocked.json"; Pattern = "current-machine" },
            @{ Name = "image-servicing-requested-blocked"; Path = "$fixtureRoot/offline-image/image-servicing-requested-blocked.json"; Pattern = "imageServicingRequested" },
            @{ Name = "mount-requested-blocked"; Path = "$fixtureRoot/offline-image/mount-requested-blocked.json"; Pattern = "mountRequested" },
            @{ Name = "private-mount-path-blocked"; Path = "$fixtureRoot/offline-image/private-mount-path-blocked.json"; Pattern = "private path" },
            @{ Name = "exit-code-only-success-blocked"; Path = "$fixtureRoot/offline-image/exit-code-only-success-blocked.json"; Pattern = "command exit code" },
            @{ Name = "handler-report-success-blocked"; Path = "$fixtureRoot/offline-image/handler-report-success-blocked.json"; Pattern = "handler report" }
        )
    },
    @{
        Scope = "machine"
        Baseline = "$fixtureRoot/machine/baseline-blocked.json"
        Ready = "$fixtureRoot/machine/dry-run-ready-no-execute.json"
        Cases = @(
            @{ Name = "missing-machine-identity"; Path = "$fixtureRoot/machine/missing-machine-identity.json"; Pattern = "machineIdentity" },
            @{ Name = "current-user-claim-blocked"; Path = "$fixtureRoot/machine/current-user-claim-blocked.json"; Pattern = "current-user" },
            @{ Name = "policy-write-requested-blocked"; Path = "$fixtureRoot/machine/policy-write-requested-blocked.json"; Pattern = "policyWriteRequested" },
            @{ Name = "service-requested-blocked"; Path = "$fixtureRoot/machine/service-requested-blocked.json"; Pattern = "serviceRequested" },
            @{ Name = "defender-requested-blocked"; Path = "$fixtureRoot/machine/defender-requested-blocked.json"; Pattern = "defenderRequested" },
            @{ Name = "exit-code-only-success-blocked"; Path = "$fixtureRoot/machine/exit-code-only-success-blocked.json"; Pattern = "command exit code" },
            @{ Name = "dry-run-report-success-blocked"; Path = "$fixtureRoot/machine/dry-run-report-success-blocked.json"; Pattern = "dry-run report" }
        )
    }
)

$caseReports = @()
$readyRequestsByScope = @{
    "current-user" = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path "$fixtureRoot/current-user/dry-run-ready-no-execute.json"
}

foreach ($scopeCase in $scopeCases) {
    $baseline = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path $scopeCase.Baseline
    $ready = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path $scopeCase.Ready
    $readyRequestsByScope[$scopeCase.Scope] = $ready

    $baselineReport = New-FutureTrueUxRestoreSingleScopeDryRunReport -Manifest $manifest -Request $baseline -Scope $scopeCase.Scope -RepoRoot $repoRoot
    $readyReport = New-FutureTrueUxRestoreSingleScopeDryRunReport -Manifest $manifest -Request $ready -Scope $scopeCase.Scope -RepoRoot $repoRoot

    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($baselineReport.decision -eq "blocked") -Message "$($scopeCase.Scope) baseline remains blocked"
    Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($readyReport.decision -eq "dry-run-ready") -Message "$($scopeCase.Scope) dry-run-ready fixture is ready"
    foreach ($report in @($baselineReport, $readyReport)) {
        Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.trueExecution -eq $false) -Message "$($scopeCase.Scope) report trueExecution is false"
        Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.mutationCount -eq 0) -Message "$($scopeCase.Scope) report mutationCount is zero"
        Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.commandExitCodeSufficient -eq $false) -Message "$($scopeCase.Scope) command exit code is insufficient"
    }

    foreach ($case in $scopeCase.Cases) {
        $request = Read-FutureTrueUxRestoreValidatorJson -RepoRoot $repoRoot -Path $case.Path
        $report = New-FutureTrueUxRestoreSingleScopeDryRunReport -Manifest $manifest -Request $request -Scope $scopeCase.Scope -RepoRoot $repoRoot
        $caseReports += [pscustomobject][ordered]@{
            scope = $scopeCase.Scope
            name = $case.Name
            decision = $report.decision
            blockedReasons = @($report.blockedReasons)
        }

        Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.decision -eq "blocked") -Message "$($scopeCase.Scope) $($case.Name) is blocked"
        Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition (($report.blockedReasons -join "`n") -match [regex]::Escape($case.Pattern)) -Message "$($scopeCase.Scope) $($case.Name) records expected blocked reason"
        Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($report.trueExecution -eq $false -and $report.mutationCount -eq 0) -Message "$($scopeCase.Scope) $($case.Name) does not execute"
    }
}

$aggregateReport = New-FutureTrueUxRestoreScopeDryRunReport -Manifest $manifest -RequestsByScope $readyRequestsByScope -RepoRoot $repoRoot
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($aggregateReport.aggregateDecision -eq "dry-run-ready") -Message "aggregate ready fixtures are dry-run-ready"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($aggregateReport.trueExecution -eq $false) -Message "aggregate trueExecution is false"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($aggregateReport.mutationCount -eq 0) -Message "aggregate mutationCount is zero"
Add-FutureTrueUxRestoreValidatorCheck -State $validatorState -Condition ($aggregateReport.dryRunReadyCount -eq 4) -Message "aggregate covers four dry-run-ready scopes"

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-scope-dry-run-validation"
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    status = Get-FutureTrueUxRestoreValidatorStatus -State $validatorState
    failureCount = Get-FutureTrueUxRestoreValidatorFailureCount -State $validatorState
    failures = @($validatorState.failures)
    aggregate = $aggregateReport
    cases = @($caseReports)
}

Write-FutureTrueUxRestoreValidatorReport -RepoRoot $repoRoot -ReportPath $ReportPath -ReportObject $reportObject -SuccessMessage "Future true UX scope dry-run report written"
Complete-FutureTrueUxRestoreValidatorRun -State $validatorState -ReportObject $reportObject
