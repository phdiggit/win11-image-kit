[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/future-true-ux-restore-authorization.json",
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-FutureTrueUxRestoreIntegratedPacketPreviewReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$script:Failures = @()

function Read-FutureTrueUxPacketPreviewJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $repoRoot -Path $Path
    Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Assert-FutureTrueUxPacketPreview {
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

$manifest = Read-FutureTrueUxPacketPreviewJson -Path $ManifestPath
$section = $manifest.integratedPacketPreview

Assert-FutureTrueUxPacketPreview -Condition ($section.enabled -eq $true) -Message "integratedPacketPreview is enabled"
Assert-FutureTrueUxPacketPreview -Condition ($section.authorizationApproved -eq $false) -Message "authorizationApproved remains false"
Assert-FutureTrueUxPacketPreview -Condition ($section.executionApproved -eq $false) -Message "executionApproved remains false"
Assert-FutureTrueUxPacketPreview -Condition ($section.executeReady -eq $false) -Message "executeReady remains false"
Assert-FutureTrueUxPacketPreview -Condition ($section.trueExecution -eq $false) -Message "trueExecution remains false"
Assert-FutureTrueUxPacketPreview -Condition ($section.mutationCount -eq 0) -Message "mutationCount remains 0"
Assert-FutureTrueUxPacketPreview -Condition (@($section.allowedPreviewDecisions) -contains "packet-preview-ready") -Message "packet-preview-ready is allowed"
Assert-FutureTrueUxPacketPreview -Condition (-not (@($section.allowedPreviewDecisions) -contains "authorization-review-ready")) -Message "authorization-review-ready is not a preview decision"
Assert-FutureTrueUxPacketPreview -Condition (@($section.forbiddenPreviewDecisions) -contains "execute-ready") -Message "execute-ready is forbidden"

$fixtureRoot = "tests/fixtures/user-experience/future-true-restore/packet-preview"
$fixtureFiles = @(
    "complete-current-user-packet-preview.json",
    "missing-runner-gate-reminder.json",
    "missing-negative-blocker-summary.json",
    "evidence-boundary-promotes-report-to-real.json",
    "preview-wording-drifts-to-authorization-ready.json",
    "preview-wording-drifts-to-execute-ready.json",
    "private-path-not-redacted.json"
)

$caseReports = @()
foreach ($fileName in $fixtureFiles) {
    $request = Read-FutureTrueUxPacketPreviewJson -Path "$fixtureRoot/$fileName"
    $report = New-FutureTrueUxRestoreIntegratedPacketPreviewReport -Manifest $manifest -Request $request -RepoRoot $repoRoot
    $expectedDecision = [string]$request.expectedDecision
    $caseReports += [pscustomobject][ordered]@{
        name = $fileName
        previewDecision = $report.previewDecision
        expectedDecision = $expectedDecision
        blockingReasons = @($report.blockingReasons)
        needsReworkReasons = @($report.needsReworkReasons)
    }

    Assert-FutureTrueUxPacketPreview -Condition ($report.previewDecision -eq $expectedDecision) -Message "$fileName matches expected decision"
    Assert-FutureTrueUxPacketPreview -Condition ($report.authorizationApproved -eq $false -and $report.executionApproved -eq $false -and $report.executeReady -eq $false -and $report.trueExecution -eq $false -and $report.mutationCount -eq 0) -Message "$fileName remains non-executing"
    foreach ($requiredSection in @($section.requiredPreviewSections)) {
        Assert-FutureTrueUxPacketPreview -Condition ($report.packetPreviewSections.PSObject.Properties.Name -contains [string]$requiredSection) -Message "$fileName includes $requiredSection"
    }
}

$reportObject = [pscustomobject][ordered]@{
    reportType = "future-true-ux-restore-integrated-packet-preview-validation"
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
    Write-Host "Future true UX integrated packet preview report written: $resolvedReportPath"
}

$reportObject

if ($script:Failures.Count -gt 0) {
    exit 1
}
