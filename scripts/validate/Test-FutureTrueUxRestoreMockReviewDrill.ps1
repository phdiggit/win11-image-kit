[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreMockReviewDrillReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$script:Failures = @()

function Read-FutureTrueUxMockReviewJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $Path
    Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Assert-FutureTrueUxMockReview {
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

$manifest = Read-FutureTrueUxMockReviewJson -Path $ManifestPath
$section = $manifest.mockReviewDrill

Assert-FutureTrueUxMockReview -Condition ($section.enabled -eq $true) -Message "mockReviewDrill is enabled"
Assert-FutureTrueUxMockReview -Condition ($section.mode -eq "mock-review-drill") -Message "mockReviewDrill mode is fixed"
Assert-FutureTrueUxMockReview -Condition ($section.defaultScope -eq "current-user") -Message "default scope is current-user"
Assert-FutureTrueUxMockReview -Condition ($section.authorizationApproved -eq $false) -Message "authorizationApproved remains false"
Assert-FutureTrueUxMockReview -Condition ($section.executionApproved -eq $false) -Message "executionApproved remains false"
Assert-FutureTrueUxMockReview -Condition ($section.executeReady -eq $false) -Message "executeReady remains false"
Assert-FutureTrueUxMockReview -Condition ($section.trueExecution -eq $false) -Message "trueExecution remains false"
Assert-FutureTrueUxMockReview -Condition ($section.mutationCount -eq 0) -Message "mutationCount remains 0"
Assert-FutureTrueUxMockReview -Condition (-not (@($section.allowedMockDecisions) -contains "execute-ready")) -Message "allowed mock decisions exclude execute-ready"
Assert-FutureTrueUxMockReview -Condition ((@($section.forbiddenMockDecisions) -contains "execute-ready") -and (@($section.forbiddenMockDecisions) -contains "executed") -and (@($section.forbiddenMockDecisions) -contains "completed")) -Message "execute-ready, executed, and completed are forbidden"

$fixtureRoot = "tests/fixtures/user-experience/future-true-restore/mock-review"
$complete = Read-FutureTrueUxMockReviewJson -Path "$fixtureRoot/current-user-complete-packet.json"
$completeReport = New-FutureTrueUxRestoreMockReviewDrillReport -Manifest $manifest -Request $complete -RepoRoot $repoRoot
Assert-FutureTrueUxMockReview -Condition ($completeReport.reviewDecision -eq "authorization-review-ready") -Message "complete current-user packet can be authorization-review-ready"
Assert-FutureTrueUxMockReview -Condition ($completeReport.packetStatus -eq "complete") -Message "complete current-user packet is complete"
Assert-FutureTrueUxMockReview -Condition ($completeReport.executionDecision -eq "not-approved") -Message "execution decision remains not-approved"
Assert-FutureTrueUxMockReview -Condition ($completeReport.blockedForExecution -eq $true) -Message "complete packet remains blocked for execution"
Assert-FutureTrueUxMockReview -Condition ($completeReport.trueExecution -eq $false -and $completeReport.mutationCount -eq 0 -and $completeReport.executeReady -eq $false) -Message "complete packet does not execute"
Assert-FutureTrueUxMockReview -Condition (@($completeReport.decisionLedger.stage) -contains "execute-ready-blocked") -Message "decision ledger includes execute-ready-blocked"
Assert-FutureTrueUxMockReview -Condition ($completeReport.transcript.warning -match "not execution approval") -Message "transcript warns review-ready is not execution approval"

$blockedCases = @(
    @{ Name = "negative-missing-reviewer-checklist"; Path = "$fixtureRoot/negative-missing-reviewer-checklist.json"; Pattern = "reviewerChecklist" },
    @{ Name = "negative-cross-scope-packet"; Path = "$fixtureRoot/negative-cross-scope-packet.json"; Pattern = "scope guard" },
    @{ Name = "negative-private-path"; Path = "$fixtureRoot/negative-private-path.json"; Pattern = "private path" },
    @{ Name = "negative-execute-ready"; Path = "$fixtureRoot/negative-execute-ready.json"; Pattern = "execute-ready" },
    @{ Name = "negative-executed"; Path = "$fixtureRoot/negative-executed.json"; Pattern = "executed" },
    @{ Name = "negative-completed"; Path = "$fixtureRoot/negative-completed.json"; Pattern = "completed" },
    @{ Name = "negative-auto-close-keyword"; Path = "$fixtureRoot/negative-auto-close-keyword.json"; Pattern = "auto-close" }
)

$caseReports = @([pscustomobject][ordered]@{ name = "current-user-complete-packet"; reviewDecision = $completeReport.reviewDecision; blockedReasons = @($completeReport.blockedReasons) })
foreach ($case in $blockedCases) {
    $request = Read-FutureTrueUxMockReviewJson -Path $case.Path
    $report = New-FutureTrueUxRestoreMockReviewDrillReport -Manifest $manifest -Request $request -RepoRoot $repoRoot
    $caseReports += [pscustomobject][ordered]@{ name = $case.Name; reviewDecision = $report.reviewDecision; blockedReasons = @($report.blockedReasons) }
    Assert-FutureTrueUxMockReview -Condition ($report.reviewDecision -eq "blocked") -Message "$($case.Name) is blocked"
    Assert-FutureTrueUxMockReview -Condition (($report.blockedReasons -join "`n") -match [regex]::Escape($case.Pattern)) -Message "$($case.Name) records expected blocked reason"
    Assert-FutureTrueUxMockReview -Condition ($report.trueExecution -eq $false -and $report.mutationCount -eq 0 -and $report.executeReady -eq $false) -Message "$($case.Name) does not execute"
}

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-mock-review-drill-validation"
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    status = $(if ($script:Failures.Count -eq 0) { "passed" } else { "failed" })
    failureCount = $script:Failures.Count
    failures = @($script:Failures)
    complete = $completeReport
    cases = @($caseReports)
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $resolvedReportPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $ReportPath
    $reportDirectory = Split-Path -Path $resolvedReportPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $reportObject | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Write-Host "Future true UX mock review drill report written: $resolvedReportPath"
}

$reportObject

if ($script:Failures.Count -gt 0) {
    exit 1
}
