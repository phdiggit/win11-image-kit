Describe "Future true UX restore mock review drill" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreMockReviewDrillReport.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-future-ux-mock-review-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    It "writes a passing mock review drill validation report" {
        $reportPath = Join-Path $script:TempRoot "future-ux-mock-review.json"
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $script:RepoRoot "scripts\validate\Test-FutureTrueUxRestoreMockReviewDrill.ps1") -ReportPath $reportPath | Out-Null
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.failureCount 0
        Assert-KitEqual $report.complete.reportType "future-true-ux-restore-mock-review-drill"
        Assert-KitEqual $report.complete.reviewDecision "authorization-review-ready"
        Assert-KitEqual $report.complete.executionDecision "not-approved"
        Assert-KitEqual $report.complete.blockedForExecution $true
        Assert-KitEqual $report.complete.trueExecution $false
        Assert-KitEqual $report.complete.mutationCount 0
    }

    It "allows a complete current-user mock packet to be review-ready only" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $request = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\mock-review\current-user-complete-packet.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $report = New-FutureTrueUxRestoreMockReviewDrillReport -Manifest $manifest -Request $request -RepoRoot $script:RepoRoot

        Assert-KitEqual $report.scope "current-user"
        Assert-KitEqual $report.packetStatus "complete"
        Assert-KitEqual $report.reviewDecision "authorization-review-ready"
        Assert-KitEqual $report.executionDecision "not-approved"
        Assert-KitEqual $report.authorizationApproved $false
        Assert-KitEqual $report.executionApproved $false
        Assert-KitEqual $report.executeReady $false
        Assert-KitEqual $report.trueExecution $false
        Assert-KitEqual $report.mutationCount 0
        Assert-KitEqual $report.userConfigurationConfirmed $false
        Assert-KitEqual $report.privatePathRedacted $true
    }
}
