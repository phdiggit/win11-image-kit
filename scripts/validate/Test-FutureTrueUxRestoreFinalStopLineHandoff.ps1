[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreFinalStopLineHandoffReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$script:Failures = @()

function Read-FutureTrueUxFinalStopLineJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $Path
    Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Assert-FutureTrueUxFinalStopLine {
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

$manifest = Read-FutureTrueUxFinalStopLineJson -Path $ManifestPath
$section = $manifest.finalStopLineHandoff

Assert-FutureTrueUxFinalStopLine -Condition ($section.enabled -eq $true) -Message "finalStopLineHandoff is enabled"
Assert-FutureTrueUxFinalStopLine -Condition ($section.authorizationApproved -eq $false) -Message "authorizationApproved remains false"
Assert-FutureTrueUxFinalStopLine -Condition ($section.executionApproved -eq $false) -Message "executionApproved remains false"
Assert-FutureTrueUxFinalStopLine -Condition ($section.executeReady -eq $false) -Message "executeReady remains false"
Assert-FutureTrueUxFinalStopLine -Condition ($section.trueExecution -eq $false) -Message "trueExecution remains false"
Assert-FutureTrueUxFinalStopLine -Condition ($section.mutationCount -eq 0) -Message "mutationCount remains 0"
Assert-FutureTrueUxFinalStopLine -Condition (@($section.allowedStopLineDecisions) -contains "pause-at-stop-line") -Message "pause-at-stop-line is allowed"
Assert-FutureTrueUxFinalStopLine -Condition (@($section.allowedStopLineDecisions) -contains "start-true-restore-planning") -Message "true restore planning decision is manual planning only"
Assert-FutureTrueUxFinalStopLine -Condition (@($section.forbiddenStopLineStates) -contains "closure-ready") -Message "closure-ready is forbidden"

$fixtureRoot = "tests/fixtures/user-experience/future-true-restore/final-stop-line-handoff"
$fixtureFiles = @(
    "pause-at-stop-line.json",
    "request-rework-for-missing-runner-gate.json",
    "start-true-restore-planning-requires-new-chain.json",
    "auto-close-wording-blocked.json",
    "execute-ready-wording-blocked.json"
)

$caseReports = @()
foreach ($fileName in $fixtureFiles) {
    $request = Read-FutureTrueUxFinalStopLineJson -Path "$fixtureRoot/$fileName"
    $report = New-FutureTrueUxRestoreFinalStopLineHandoffReport -Manifest $manifest -Request $request -RepoRoot $repoRoot
    $expectedDecision = [string]$request.expectedDecision
    $caseReports += [pscustomobject][ordered]@{
        name = $fileName
        stopLineDecision = $report.stopLineDecision
        expectedDecision = $expectedDecision
        blockingReasons = @($report.blockingReasons)
        needsReworkReasons = @($report.needsReworkReasons)
    }

    Assert-FutureTrueUxFinalStopLine -Condition ($report.stopLineDecision -eq $expectedDecision) -Message "$fileName matches expected decision"
    Assert-FutureTrueUxFinalStopLine -Condition ($report.authorizationApproved -eq $false -and $report.executionApproved -eq $false -and $report.executeReady -eq $false -and $report.trueExecution -eq $false -and $report.mutationCount -eq 0) -Message "$fileName remains non-executing"
}

$repoReport = New-FutureTrueUxRestoreFinalStopLineHandoffReport -Manifest $manifest -Request $null -RepoRoot $repoRoot
Assert-FutureTrueUxFinalStopLine -Condition ($repoReport.stopLineDecision -eq "pause-at-stop-line") -Message "repository defaults to pause-at-stop-line"
Assert-FutureTrueUxFinalStopLine -Condition ($repoReport.blockingReasons.Count -eq 0) -Message "repository final stop-line has no blockers"

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-final-stop-line-handoff-validation"
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    status = $(if ($script:Failures.Count -eq 0) { "passed" } else { "failed" })
    failureCount = $script:Failures.Count
    failures = @($script:Failures)
    repositoryHandoff = $repoReport
    cases = @($caseReports)
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $resolvedReportPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $ReportPath
    $reportDirectory = Split-Path -Path $resolvedReportPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $reportObject | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Write-Host "Future true UX final stop-line handoff report written: $resolvedReportPath"
}

$reportObject

if ($script:Failures.Count -gt 0) {
    exit 1
}
