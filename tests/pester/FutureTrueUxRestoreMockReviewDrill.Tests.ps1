Describe "Future true UX restore mock review drill prune" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-future-ux-mock-review-pruned-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    It "keeps the workflow-compatible validator passing as a prune guard" {
        $reportPath = Join-Path $script:TempRoot "future-ux-mock-review-pruned.json"
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $script:RepoRoot "scripts\validate\Test-FutureTrueUxRestoreMockReviewDrill.ps1") -ReportPath $reportPath | Out-Null
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.failureCount 0
        Assert-KitEqual $report.reportType "future-true-ux-restore-mock-review-drill-pruned-validation"
        Assert-KitEqual $report.authorizationApproved $false
        Assert-KitEqual $report.executionApproved $false
        Assert-KitEqual $report.executeReady $false
        Assert-KitEqual $report.trueExecution $false
        Assert-KitEqual $report.mutationCount 0
    }

    It "keeps mock review drill long-term surfaces pruned" {
        $qualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual ($manifest.PSObject.Properties.Name -contains "mockReviewDrill") $false
        Assert-KitEqual (@($qualityGates.gates.id) -contains "future-true-ux-mock-review-drill") $false
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreMockReviewDrillReport.ps1")) $false
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\mock-review")) $false
    }
}
