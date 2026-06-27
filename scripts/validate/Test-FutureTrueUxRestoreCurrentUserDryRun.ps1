[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$BaselinePath = "tests/fixtures/user-experience/future-true-restore/current-user/baseline-blocked.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreCurrentUserDryRunReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$script:Failures = @()

function Read-FutureTrueUxCurrentUserJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $Path
    Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Assert-FutureTrueUxCurrentUser {
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

$manifest = Read-FutureTrueUxCurrentUserJson -Path $ManifestPath
$section = $manifest.currentUserDryRun

Assert-FutureTrueUxCurrentUser -Condition ($section.enabled -eq $true) -Message "currentUserDryRun is enabled"
Assert-FutureTrueUxCurrentUser -Condition ($section.scope -eq "current-user") -Message "currentUserDryRun scope is current-user"
foreach ($flagName in @("authorizationApproved", "executionApproved", "allowCurrentUserMutation", "allowDefaultUserFallback", "allowMachineFallback", "allowOfflineImageFallback")) {
    Assert-FutureTrueUxCurrentUser -Condition ([bool]$section.$flagName -eq $false) -Message "$flagName remains false"
}

$baseline = Read-FutureTrueUxCurrentUserJson -Path $BaselinePath
$baselineReport = New-FutureTrueUxRestoreCurrentUserDryRunReport -Manifest $manifest -Request $baseline -RepoRoot $repoRoot
Assert-FutureTrueUxCurrentUser -Condition ($baselineReport.decision -eq "blocked") -Message "baseline remains blocked"
Assert-FutureTrueUxCurrentUser -Condition ($baselineReport.trueExecution -eq $false) -Message "baseline trueExecution is false"
Assert-FutureTrueUxCurrentUser -Condition ($baselineReport.mutationCount -eq 0) -Message "baseline mutationCount is zero"
Assert-FutureTrueUxCurrentUser -Condition ($baselineReport.currentUserConfirmed -eq $false) -Message "current user is not confirmed in this stage"

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
    $request = Read-FutureTrueUxCurrentUserJson -Path $case.Path
    $report = New-FutureTrueUxRestoreCurrentUserDryRunReport -Manifest $manifest -Request $request -RepoRoot $repoRoot
    $caseReports += [pscustomobject][ordered]@{
        name = $case.Name
        decision = $report.decision
        blockedReasons = @($report.blockedReasons)
    }

    Assert-FutureTrueUxCurrentUser -Condition ($report.decision -eq $case.Decision) -Message "$($case.Name) decision is $($case.Decision)"
    Assert-FutureTrueUxCurrentUser -Condition ($report.trueExecution -eq $false -and $report.mutationCount -eq 0 -and $report.currentUserConfirmed -eq $false) -Message "$($case.Name) does not execute or confirm current user"
    if (-not [string]::IsNullOrWhiteSpace($case.Pattern)) {
        Assert-FutureTrueUxCurrentUser -Condition (($report.blockedReasons -join "`n") -match [regex]::Escape($case.Pattern)) -Message "$($case.Name) records expected blocked reason"
    }
}

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-current-user-dry-run-validation"
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    status = $(if ($script:Failures.Count -eq 0) { "passed" } else { "failed" })
    failureCount = $script:Failures.Count
    failures = @($script:Failures)
    baseline = $baselineReport
    cases = @($caseReports)
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $resolvedReportPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $ReportPath
    $reportDirectory = Split-Path -Path $resolvedReportPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $reportObject | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Write-Host "Future true UX current-user dry-run report written: $resolvedReportPath"
}

$reportObject

if ($script:Failures.Count -gt 0) {
    exit 1
}
