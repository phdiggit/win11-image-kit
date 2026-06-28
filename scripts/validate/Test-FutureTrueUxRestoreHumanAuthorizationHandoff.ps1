[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreHumanAuthorizationHandoffReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$script:Failures = @()

function Read-FutureTrueUxHumanHandoffJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $Path
    Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Assert-FutureTrueUxHumanHandoff {
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

$manifest = Read-FutureTrueUxHumanHandoffJson -Path $ManifestPath
$section = $manifest.humanAuthorizationHandoff

Assert-FutureTrueUxHumanHandoff -Condition ($section.enabled -eq $true) -Message "humanAuthorizationHandoff is enabled"
Assert-FutureTrueUxHumanHandoff -Condition ($section.authorizationApproved -eq $false) -Message "authorizationApproved remains false"
Assert-FutureTrueUxHumanHandoff -Condition ($section.executionApproved -eq $false) -Message "executionApproved remains false"
Assert-FutureTrueUxHumanHandoff -Condition ($section.executeReady -eq $false) -Message "executeReady remains false"
Assert-FutureTrueUxHumanHandoff -Condition ($section.trueExecution -eq $false) -Message "trueExecution remains false"
Assert-FutureTrueUxHumanHandoff -Condition ($section.mutationCount -eq 0) -Message "mutationCount remains 0"
Assert-FutureTrueUxHumanHandoff -Condition (@($section.allowedHandoffDecisions) -contains "handoff-ready-for-human-review") -Message "handoff-ready-for-human-review is allowed"
Assert-FutureTrueUxHumanHandoff -Condition (-not (@($section.allowedHandoffDecisions) -contains "authorization-review-ready")) -Message "authorization-review-ready is not a handoff decision"
Assert-FutureTrueUxHumanHandoff -Condition (@($section.forbiddenHandoffDecisions) -contains "closure-ready") -Message "closure-ready is forbidden"

$fixtureRoot = "tests/fixtures/user-experience/future-true-restore/human-authorization-handoff"
$fixtureFiles = @(
    "complete-current-user-human-handoff.json",
    "missing-artifact-index.json",
    "missing-manual-decision-placeholder.json",
    "handoff-promotes-preview-to-authorization-ready.json",
    "handoff-promotes-report-to-real-evidence.json",
    "handoff-drifts-to-execute-ready.json",
    "handoff-mentions-issue-18-closure.json",
    "private-path-not-redacted.json"
)

$caseReports = @()
foreach ($fileName in $fixtureFiles) {
    $request = Read-FutureTrueUxHumanHandoffJson -Path "$fixtureRoot/$fileName"
    $report = New-FutureTrueUxRestoreHumanAuthorizationHandoffReport -Manifest $manifest -Request $request -RepoRoot $repoRoot
    $expectedDecision = [string]$request.expectedDecision
    $caseReports += [pscustomobject][ordered]@{
        name = $fileName
        handoffDecision = $report.handoffDecision
        expectedDecision = $expectedDecision
        blockingReasons = @($report.blockingReasons)
        needsReworkReasons = @($report.needsReworkReasons)
    }

    Assert-FutureTrueUxHumanHandoff -Condition ($report.handoffDecision -eq $expectedDecision) -Message "$fileName matches expected decision"
    Assert-FutureTrueUxHumanHandoff -Condition ($report.authorizationApproved -eq $false -and $report.executionApproved -eq $false -and $report.executeReady -eq $false -and $report.trueExecution -eq $false -and $report.mutationCount -eq 0) -Message "$fileName remains non-executing"
    foreach ($requiredSection in @($section.requiredHandoffSections)) {
        Assert-FutureTrueUxHumanHandoff -Condition ($report.handoffSections.PSObject.Properties.Name -contains [string]$requiredSection) -Message "$fileName includes $requiredSection"
    }
}

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-human-authorization-handoff-validation"
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
    Write-Host "Future true UX human authorization handoff report written: $resolvedReportPath"
}

$reportObject

if ($script:Failures.Count -gt 0) {
    exit 1
}
