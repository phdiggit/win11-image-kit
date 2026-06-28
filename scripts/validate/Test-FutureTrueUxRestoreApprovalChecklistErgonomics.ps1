[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreApprovalChecklistErgonomicsReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$script:Failures = @()

function Read-FutureTrueUxApprovalChecklistJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $Path
    Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Assert-FutureTrueUxApprovalChecklist {
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

$manifest = Read-FutureTrueUxApprovalChecklistJson -Path $ManifestPath
$section = $manifest.approvalChecklistErgonomics

Assert-FutureTrueUxApprovalChecklist -Condition ($section.enabled -eq $true) -Message "approvalChecklistErgonomics is enabled"
Assert-FutureTrueUxApprovalChecklist -Condition ($section.authorizationApproved -eq $false) -Message "authorizationApproved remains false"
Assert-FutureTrueUxApprovalChecklist -Condition ($section.executionApproved -eq $false) -Message "executionApproved remains false"
Assert-FutureTrueUxApprovalChecklist -Condition ($section.executeReady -eq $false) -Message "executeReady remains false"
Assert-FutureTrueUxApprovalChecklist -Condition ($section.trueExecution -eq $false) -Message "trueExecution remains false"
Assert-FutureTrueUxApprovalChecklist -Condition ($section.mutationCount -eq 0) -Message "mutationCount remains 0"
Assert-FutureTrueUxApprovalChecklist -Condition (@($section.allowedChecklistDecisions) -contains "approval-checklist-ready") -Message "approval-checklist-ready is allowed"
Assert-FutureTrueUxApprovalChecklist -Condition (-not (@($section.allowedChecklistDecisions) -contains "authorization-review-ready")) -Message "authorization-review-ready is not a checklist decision"
Assert-FutureTrueUxApprovalChecklist -Condition (@($section.forbiddenChecklistDecisions) -contains "execute-ready") -Message "execute-ready is forbidden"

$fixtureRoot = "tests/fixtures/user-experience/future-true-restore/approval-checklist"
$fixtureFiles = @(
    "complete-current-user-checklist.json",
    "missing-human-decision-summary.json",
    "scope-label-hard-to-read.json",
    "evidence-boundary-ambiguous.json",
    "rollback-plan-too-vague.json",
    "approval-wording-drifts-to-execute-ready.json"
)

$caseReports = @()
foreach ($fileName in $fixtureFiles) {
    $request = Read-FutureTrueUxApprovalChecklistJson -Path "$fixtureRoot/$fileName"
    $report = New-FutureTrueUxRestoreApprovalChecklistErgonomicsReport -Manifest $manifest -Request $request -RepoRoot $repoRoot
    $expectedDecision = [string]$request.expectedDecision
    $caseReports += [pscustomobject][ordered]@{
        name = $fileName
        checklistDecision = $report.checklistDecision
        expectedDecision = $expectedDecision
        blockingReasons = @($report.blockingReasons)
        needsReworkReasons = @($report.needsReworkReasons)
    }

    Assert-FutureTrueUxApprovalChecklist -Condition ($report.checklistDecision -eq $expectedDecision) -Message "$fileName matches expected decision"
    Assert-FutureTrueUxApprovalChecklist -Condition ($report.authorizationApproved -eq $false -and $report.executionApproved -eq $false -and $report.executeReady -eq $false -and $report.trueExecution -eq $false -and $report.mutationCount -eq 0) -Message "$fileName remains non-executing"
    foreach ($requiredSection in @($section.requiredChecklistSections)) {
        Assert-FutureTrueUxApprovalChecklist -Condition ($report.checklistSections.PSObject.Properties.Name -contains [string]$requiredSection) -Message "$fileName includes $requiredSection"
    }
}

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-approval-checklist-ergonomics-validation"
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
    Write-Host "Future true UX approval checklist ergonomics report written: $resolvedReportPath"
}

$reportObject

if ($script:Failures.Count -gt 0) {
    exit 1
}
