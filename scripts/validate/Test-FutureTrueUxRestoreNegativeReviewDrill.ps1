[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$FixtureRoot = "tests/fixtures/user-experience/future-true-restore/negative-review",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreNegativeReviewDrillReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$script:Failures = @()

function Read-FutureTrueUxNegativeReviewJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $Path
    Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Assert-FutureTrueUxNegativeReview {
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

$manifest = Read-FutureTrueUxNegativeReviewJson -Path $ManifestPath
$section = $manifest.negativeReviewDrill

Assert-FutureTrueUxNegativeReview -Condition ($section.enabled -eq $true) -Message "negativeReviewDrill is enabled"
Assert-FutureTrueUxNegativeReview -Condition ($section.mode -eq "negative-review-drill") -Message "negativeReviewDrill mode is fixed"
Assert-FutureTrueUxNegativeReview -Condition ($section.defaultScope -eq "current-user") -Message "default scope is current-user"
Assert-FutureTrueUxNegativeReview -Condition ($section.authorizationApproved -eq $false) -Message "authorizationApproved remains false"
Assert-FutureTrueUxNegativeReview -Condition ($section.executionApproved -eq $false) -Message "executionApproved remains false"
Assert-FutureTrueUxNegativeReview -Condition ($section.executeReady -eq $false) -Message "executeReady remains false"
Assert-FutureTrueUxNegativeReview -Condition ($section.trueExecution -eq $false) -Message "trueExecution remains false"
Assert-FutureTrueUxNegativeReview -Condition ($section.mutationCount -eq 0) -Message "mutationCount remains 0"
Assert-FutureTrueUxNegativeReview -Condition (-not (@($section.allowedNegativeDecisions) -contains "authorization-review-ready")) -Message "allowed negative decisions exclude review-ready"
Assert-FutureTrueUxNegativeReview -Condition (-not (@($section.allowedNegativeDecisions) -contains "execute-ready")) -Message "allowed negative decisions exclude execute-ready"
Assert-FutureTrueUxNegativeReview -Condition ((@($section.forbiddenNegativeDecisions) -contains "authorization-review-ready") -and (@($section.forbiddenNegativeDecisions) -contains "execute-ready") -and (@($section.forbiddenNegativeDecisions) -contains "executed") -and (@($section.forbiddenNegativeDecisions) -contains "completed")) -Message "review-ready and execution states are forbidden"

$resolvedFixtureRoot = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $FixtureRoot
$fixtures = @(Get-ChildItem -LiteralPath $resolvedFixtureRoot -Filter "*.json" | Sort-Object Name)
Assert-FutureTrueUxNegativeReview -Condition ($fixtures.Count -ge 6) -Message "at least six negative review fixtures exist"

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

    Assert-FutureTrueUxNegativeReview -Condition ($report.reportType -eq "future-true-ux-restore-negative-review-drill") -Message "$($fixture.Name) emits negative drill report"
    Assert-FutureTrueUxNegativeReview -Condition ($report.reviewDecision -eq $request.expectedDecision) -Message "$($fixture.Name) matches expected decision"
    foreach ($code in $expectedCodes) {
        Assert-FutureTrueUxNegativeReview -Condition (@($report.reasonCodes) -contains $code) -Message "$($fixture.Name) records $code"
    }
    Assert-FutureTrueUxNegativeReview -Condition ($report.executeReady -eq $false -and $report.trueExecution -eq $false -and $report.mutationCount -eq 0) -Message "$($fixture.Name) does not execute"
}

foreach ($requiredCode in @($section.requiredReasonCodes)) {
    $seen = $false
    foreach ($caseReport in $caseReports) {
        if (@($caseReport.reasonCodes) -contains $requiredCode) {
            $seen = $true
            break
        }
    }
    Assert-FutureTrueUxNegativeReview -Condition $seen -Message "bundle covers $requiredCode"
}

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-negative-review-drill-validation"
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    status = $(if ($script:Failures.Count -eq 0) { "passed" } else { "failed" })
    failureCount = $script:Failures.Count
    failures = @($script:Failures)
    cases = @($caseReports)
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $resolvedReportPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $ReportPath
    $reportDirectory = Split-Path -Path $resolvedReportPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $reportObject | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Write-Host "Future true UX negative review drill report written: $resolvedReportPath"
}

$reportObject

if ($script:Failures.Count -gt 0) {
    exit 1
}
