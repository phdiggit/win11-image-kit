[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreAuthorizationReviewReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$script:Failures = @()

function Read-FutureTrueUxReviewJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $Path
    Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Assert-FutureTrueUxReview {
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

$manifest = Read-FutureTrueUxReviewJson -Path $ManifestPath
$section = $manifest.authorizationReview

Assert-FutureTrueUxReview -Condition ($section.enabled -eq $true) -Message "authorizationReview is enabled"
Assert-FutureTrueUxReview -Condition ($section.authorizationApproved -eq $false) -Message "authorizationApproved remains false"
Assert-FutureTrueUxReview -Condition ($section.executionApproved -eq $false) -Message "executionApproved remains false"
Assert-FutureTrueUxReview -Condition ($section.executeReady -eq $false) -Message "executeReady remains false"
Assert-FutureTrueUxReview -Condition (@($section.forbiddenReviewDecisions) -contains "execute-ready") -Message "execute-ready is forbidden"
Assert-FutureTrueUxReview -Condition (-not (@($section.allowedReviewDecisions) -contains "execute-ready")) -Message "allowed decisions exclude execute-ready"

$fixtureRoot = "tests/fixtures/user-experience/future-true-restore/review"
$baseline = Read-FutureTrueUxReviewJson -Path "$fixtureRoot/baseline-blocked.json"
$baselineReport = New-FutureTrueUxRestoreAuthorizationReviewReport -Manifest $manifest -Request $baseline -RepoRoot $repoRoot
Assert-FutureTrueUxReview -Condition ($baselineReport.reviewDecision -eq "blocked") -Message "baseline remains blocked"
Assert-FutureTrueUxReview -Condition ($baselineReport.trueExecution -eq $false -and $baselineReport.mutationCount -eq 0 -and $baselineReport.executeReady -eq $false) -Message "baseline does not execute"

$readyCases = @(
    "current-user-review-ready.json",
    "default-user-review-ready.json",
    "offline-image-review-ready.json",
    "machine-review-ready.json"
)
$caseReports = @()
foreach ($fileName in $readyCases) {
    $request = Read-FutureTrueUxReviewJson -Path "$fixtureRoot/$fileName"
    $report = New-FutureTrueUxRestoreAuthorizationReviewReport -Manifest $manifest -Request $request -RepoRoot $repoRoot
    $caseReports += [pscustomobject][ordered]@{ name = $fileName; reviewDecision = $report.reviewDecision; blockedReasons = @($report.blockedReasons) }
    Assert-FutureTrueUxReview -Condition ($report.reviewDecision -eq "authorization-review-ready") -Message "$fileName can be authorization-review-ready"
    Assert-FutureTrueUxReview -Condition ($report.evidencePacketStatus -eq "complete") -Message "$fileName packet is complete"
    Assert-FutureTrueUxReview -Condition ($report.trueExecution -eq $false -and $report.mutationCount -eq 0 -and $report.executeReady -eq $false) -Message "$fileName does not execute"
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
    $request = Read-FutureTrueUxReviewJson -Path $case.Path
    $report = New-FutureTrueUxRestoreAuthorizationReviewReport -Manifest $manifest -Request $request -RepoRoot $repoRoot
    $caseReports += [pscustomobject][ordered]@{ name = $case.Name; reviewDecision = $report.reviewDecision; blockedReasons = @($report.blockedReasons) }
    Assert-FutureTrueUxReview -Condition ($report.reviewDecision -eq "blocked") -Message "$($case.Name) is blocked"
    Assert-FutureTrueUxReview -Condition (($report.blockedReasons -join "`n") -match [regex]::Escape($case.Pattern)) -Message "$($case.Name) records expected blocked reason"
    Assert-FutureTrueUxReview -Condition ($report.trueExecution -eq $false -and $report.mutationCount -eq 0 -and $report.executeReady -eq $false) -Message "$($case.Name) does not execute"
}

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-authorization-review-validation"
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
    Write-Host "Future true UX authorization review report written: $resolvedReportPath"
}

$reportObject

if ($script:Failures.Count -gt 0) {
    exit 1
}
