[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$BaselineAuthorizationPath = "tests/fixtures/user-experience/future-true-restore/authorization/baseline-blocked.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreAuthorizationReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$script:Failures = @()

function Read-FutureTrueUxRestoreJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $Path
    Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Add-FutureTrueUxRestoreFailure {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $script:Failures += $Message
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Assert-FutureTrueUxRestore {
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not $Condition) {
        Add-FutureTrueUxRestoreFailure -Message $Message
    } else {
        Write-Host "[OK] $Message" -ForegroundColor Green
    }
}

$manifest = Read-FutureTrueUxRestoreJson -Path $ManifestPath
$baseline = Read-FutureTrueUxRestoreJson -Path $BaselineAuthorizationPath
$baselineReport = New-FutureTrueUxRestoreAuthorizationReport -Manifest $manifest -AuthorizationRequest $baseline -RepoRoot $repoRoot

Assert-FutureTrueUxRestore -Condition ($manifest.mode -eq "authorization-intake") -Message "manifest mode is authorization-intake"
Assert-FutureTrueUxRestore -Condition ($manifest.defaultDecision -eq "blocked") -Message "manifest default decision is blocked"
foreach ($flagName in @("allowRegistryMutation", "allowProfileMutation", "allowDefaultUserHiveMutation", "allowDefaultAppMutation", "allowStartMenuMutation", "allowTaskbarMutation", "allowDismMutation", "allowAppxMutation", "allowNetworkDownload")) {
    Assert-FutureTrueUxRestore -Condition ([bool]$manifest.$flagName -eq $false) -Message "$flagName remains false"
}

Assert-FutureTrueUxRestore -Condition ($baselineReport.decision -eq "blocked") -Message "baseline report remains blocked"
Assert-FutureTrueUxRestore -Condition ($baselineReport.trueExecution -eq $false) -Message "baseline trueExecution is false"
Assert-FutureTrueUxRestore -Condition ($baselineReport.mutationCount -eq 0) -Message "baseline mutationCount is zero"
Assert-FutureTrueUxRestore -Condition ($baselineReport.commandExitCodeSufficient -eq $false) -Message "command exit code is not sufficient"
Assert-FutureTrueUxRestore -Condition ($baselineReport.userConfigurationConfirmed -eq $false) -Message "user configuration is not confirmed"

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
    $request = Read-FutureTrueUxRestoreJson -Path $case.Path
    $report = New-FutureTrueUxRestoreAuthorizationReport -Manifest $manifest -AuthorizationRequest $request -RepoRoot $repoRoot
    $caseReports += [pscustomobject][ordered]@{
        name = $case.Name
        decision = $report.decision
        blockedReasons = @($report.blockedReasons)
    }

    Assert-FutureTrueUxRestore -Condition ($report.decision -eq "blocked") -Message "$($case.Name) remains blocked"
    Assert-FutureTrueUxRestore -Condition (($report.blockedReasons -join "`n") -match [regex]::Escape($case.Pattern)) -Message "$($case.Name) records expected blocked reason"
    Assert-FutureTrueUxRestore -Condition ($report.trueExecution -eq $false -and $report.mutationCount -eq 0) -Message "$($case.Name) does not execute"
}

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-authorization-validation"
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    status = $(if ($script:Failures.Count -eq 0) { "passed" } else { "failed" })
    failureCount = $script:Failures.Count
    failures = @($script:Failures)
    baseline = $baselineReport
    unsafeCases = @($caseReports)
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $resolvedReportPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $ReportPath
    $reportDirectory = Split-Path -Path $resolvedReportPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $reportObject | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Write-Host "Future true UX restore authorization report written: $resolvedReportPath"
}

$reportObject

if ($script:Failures.Count -gt 0) {
    exit 1
}
