[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreScopeDryRunReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$script:Failures = @()

function Read-FutureTrueUxScopeJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $Path
    Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Assert-FutureTrueUxScopeDryRun {
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if ($Condition) {
        Write-Host "[OK] $Message" -ForegroundColor Green
    } else {
        $script:Failures += $Message
        Write-Host "[ERROR] $Message" -ForegroundColor Red
    }
}

$manifest = Read-FutureTrueUxScopeJson -Path $ManifestPath
$sectionExpectations = @(
    @{ Scope = "current-user"; Section = "currentUserDryRun"; Flags = @("authorizationApproved", "executionApproved", "allowCurrentUserMutation", "allowDefaultUserFallback", "allowMachineFallback", "allowOfflineImageFallback") },
    @{ Scope = "default-user"; Section = "defaultUserDryRun"; Flags = @("authorizationApproved", "executionApproved", "allowDefaultUserMutation", "allowCurrentUserFallback", "allowMachineFallback", "allowOfflineImageFallback") },
    @{ Scope = "offline-image"; Section = "offlineImageDryRun"; Flags = @("authorizationApproved", "executionApproved", "allowOfflineImageMutation", "allowCurrentMachineFallback", "allowCurrentUserFallback", "allowDefaultUserFallback") },
    @{ Scope = "machine"; Section = "machineDryRun"; Flags = @("authorizationApproved", "executionApproved", "allowMachineMutation", "allowCurrentUserFallback", "allowDefaultUserFallback", "allowOfflineImageFallback") }
)

foreach ($expectation in $sectionExpectations) {
    $section = $manifest.($expectation.Section)
    Assert-FutureTrueUxScopeDryRun -Condition ($null -ne $section) -Message "$($expectation.Section) section exists"
    Assert-FutureTrueUxScopeDryRun -Condition ($section.enabled -eq $true) -Message "$($expectation.Section) is enabled"
    Assert-FutureTrueUxScopeDryRun -Condition ($section.scope -eq $expectation.Scope) -Message "$($expectation.Section) scope is $($expectation.Scope)"
    Assert-FutureTrueUxScopeDryRun -Condition ($section.defaultDecision -eq "blocked") -Message "$($expectation.Section) defaults to blocked"
    foreach ($flagName in $expectation.Flags) {
        Assert-FutureTrueUxScopeDryRun -Condition ([bool]$section.$flagName -eq $false) -Message "$($expectation.Section) $flagName remains false"
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
    "current-user" = Read-FutureTrueUxScopeJson -Path "$fixtureRoot/current-user/dry-run-ready-no-execute.json"
}

foreach ($scopeCase in $scopeCases) {
    $baseline = Read-FutureTrueUxScopeJson -Path $scopeCase.Baseline
    $ready = Read-FutureTrueUxScopeJson -Path $scopeCase.Ready
    $readyRequestsByScope[$scopeCase.Scope] = $ready

    $baselineReport = New-FutureTrueUxRestoreSingleScopeDryRunReport -Manifest $manifest -Request $baseline -Scope $scopeCase.Scope -RepoRoot $repoRoot
    $readyReport = New-FutureTrueUxRestoreSingleScopeDryRunReport -Manifest $manifest -Request $ready -Scope $scopeCase.Scope -RepoRoot $repoRoot

    Assert-FutureTrueUxScopeDryRun -Condition ($baselineReport.decision -eq "blocked") -Message "$($scopeCase.Scope) baseline remains blocked"
    Assert-FutureTrueUxScopeDryRun -Condition ($readyReport.decision -eq "dry-run-ready") -Message "$($scopeCase.Scope) dry-run-ready fixture is ready"
    foreach ($report in @($baselineReport, $readyReport)) {
        Assert-FutureTrueUxScopeDryRun -Condition ($report.trueExecution -eq $false) -Message "$($scopeCase.Scope) report trueExecution is false"
        Assert-FutureTrueUxScopeDryRun -Condition ($report.mutationCount -eq 0) -Message "$($scopeCase.Scope) report mutationCount is zero"
        Assert-FutureTrueUxScopeDryRun -Condition ($report.commandExitCodeSufficient -eq $false) -Message "$($scopeCase.Scope) command exit code is insufficient"
    }

    foreach ($case in $scopeCase.Cases) {
        $request = Read-FutureTrueUxScopeJson -Path $case.Path
        $report = New-FutureTrueUxRestoreSingleScopeDryRunReport -Manifest $manifest -Request $request -Scope $scopeCase.Scope -RepoRoot $repoRoot
        $caseReports += [pscustomobject][ordered]@{
            scope = $scopeCase.Scope
            name = $case.Name
            decision = $report.decision
            blockedReasons = @($report.blockedReasons)
        }

        Assert-FutureTrueUxScopeDryRun -Condition ($report.decision -eq "blocked") -Message "$($scopeCase.Scope) $($case.Name) is blocked"
        Assert-FutureTrueUxScopeDryRun -Condition (($report.blockedReasons -join "`n") -match [regex]::Escape($case.Pattern)) -Message "$($scopeCase.Scope) $($case.Name) records expected blocked reason"
        Assert-FutureTrueUxScopeDryRun -Condition ($report.trueExecution -eq $false -and $report.mutationCount -eq 0) -Message "$($scopeCase.Scope) $($case.Name) does not execute"
    }
}

$aggregateReport = New-FutureTrueUxRestoreScopeDryRunReport -Manifest $manifest -RequestsByScope $readyRequestsByScope -RepoRoot $repoRoot
Assert-FutureTrueUxScopeDryRun -Condition ($aggregateReport.aggregateDecision -eq "dry-run-ready") -Message "aggregate ready fixtures are dry-run-ready"
Assert-FutureTrueUxScopeDryRun -Condition ($aggregateReport.trueExecution -eq $false) -Message "aggregate trueExecution is false"
Assert-FutureTrueUxScopeDryRun -Condition ($aggregateReport.mutationCount -eq 0) -Message "aggregate mutationCount is zero"
Assert-FutureTrueUxScopeDryRun -Condition ($aggregateReport.dryRunReadyCount -eq 4) -Message "aggregate covers four dry-run-ready scopes"

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-scope-dry-run-validation"
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    status = $(if ($script:Failures.Count -eq 0) { "passed" } else { "failed" })
    failureCount = $script:Failures.Count
    failures = @($script:Failures)
    aggregate = $aggregateReport
    cases = @($caseReports)
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $resolvedReportPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $ReportPath
    $reportDirectory = Split-Path -Path $resolvedReportPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $reportObject | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Write-Host "Future true UX scope dry-run report written: $resolvedReportPath"
}

$reportObject

if ($script:Failures.Count -gt 0) {
    exit 1
}
