Describe "Future true UX restore negative review drill" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreNegativeReviewDrillReport.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-future-ux-negative-review-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    It "writes a passing negative review drill validation report" {
        $reportPath = Join-Path $script:TempRoot "future-ux-negative-review.json"
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $script:RepoRoot "scripts\validate\Test-FutureTrueUxRestoreNegativeReviewDrill.ps1") -ReportPath $reportPath | Out-Null
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.failureCount 0
        Assert-KitEqual (@($report.cases).Count -ge 8) $true
        foreach ($case in @($report.cases)) {
            Assert-KitEqual $case.executeReady $false
            Assert-KitEqual $case.trueExecution $false
            Assert-KitEqual $case.mutationCount 0
        }
    }

    It "covers every required negative review reason code" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $fixtureRoot = Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\negative-review"
        $seen = @{}

        foreach ($fixture in @(Get-ChildItem -LiteralPath $fixtureRoot -Filter "*.json")) {
            $request = Get-Content -LiteralPath $fixture.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $report = New-FutureTrueUxRestoreNegativeReviewDrillReport -Manifest $manifest -Request $request -RepoRoot $script:RepoRoot
            Assert-KitEqual $report.reviewDecision $request.expectedDecision
            foreach ($code in @($request.expectedReasonCodes)) {
                Assert-KitEqual (@($report.reasonCodes) -contains $code) $true
                $seen[$code] = $true
            }
            Assert-KitEqual $report.executeReady $false
            Assert-KitEqual $report.trueExecution $false
            Assert-KitEqual $report.blockedForExecution $true
        }

        foreach ($requiredCode in @($manifest.negativeReviewDrill.requiredReasonCodes)) {
            Assert-KitEqual $seen.ContainsKey($requiredCode) $true
        }
    }

    It "classifies mock and report-only artifacts as non-real evidence" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $mockRequest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\negative-review\mock-packet-as-real-evidence.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $reportRequest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\negative-review\report-only-as-real-evidence.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        $mockReport = New-FutureTrueUxRestoreNegativeReviewDrillReport -Manifest $manifest -Request $mockRequest -RepoRoot $script:RepoRoot
        $reportOnlyReport = New-FutureTrueUxRestoreNegativeReviewDrillReport -Manifest $manifest -Request $reportRequest -RepoRoot $script:RepoRoot

        Assert-KitEqual $mockReport.evidenceClassification.mockEvidence $true
        Assert-KitEqual $mockReport.evidenceClassification.trueUxRestoreEvidence $false
        Assert-KitEqual $mockReport.evidenceClassification.acceptedAsTrueEvidence $false
        Assert-KitEqual $reportOnlyReport.evidenceClassification.dryRunEvidence $true
        Assert-KitEqual $reportOnlyReport.evidenceClassification.handlerReportEvidence $true
        Assert-KitEqual $reportOnlyReport.evidenceClassification.manualChecklistEvidence $true
        Assert-KitEqual $reportOnlyReport.evidenceClassification.acceptedAsTrueEvidence $false
    }

    It "does not contain executable high-risk command forms" {
        $paths = @(
            "scripts\common\New-FutureTrueUxRestoreNegativeReviewDrillReport.ps1",
            "scripts\validate\Test-FutureTrueUxRestoreNegativeReviewDrill.ps1"
        )

        foreach ($path in $paths) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $path) -Raw -Encoding UTF8
            Assert-KitNotMatch $text "(?i)\bStart-Process\b"
            Assert-KitNotMatch $text "(?i)\bInvoke-Expression\b"
            Assert-KitNotMatch $text "(?i)\bSet-ItemProperty\b"
            Assert-KitNotMatch $text "(?i)\bAdd-MpPreference\b"
            Assert-KitNotMatch $text "(?i)\bRemove-AppxPackage\b"
            Assert-KitNotMatch $text "(?i)\bNew-ItemProperty\b"
            Assert-KitNotMatch $text "(?i)&\s*(dism|winget|choco|msiexec)\b"
        }
    }
}
