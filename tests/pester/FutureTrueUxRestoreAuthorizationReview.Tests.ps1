Describe "Future true UX restore authorization review" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreAuthorizationReviewReport.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-future-ux-review-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    It "writes a passing authorization review validation report" {
        $reportPath = Join-Path $script:TempRoot "future-ux-auth-review.json"
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $script:RepoRoot "scripts\validate\Test-FutureTrueUxRestoreAuthorizationReview.ps1") -ReportPath $reportPath | Out-Null
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.failureCount 0
        Assert-KitEqual $report.baseline.reviewDecision "blocked"
        Assert-KitEqual $report.baseline.trueExecution $false
        Assert-KitEqual $report.baseline.mutationCount 0
        Assert-KitEqual $report.baseline.executeReady $false
    }

    It "allows complete packets to reach authorization-review-ready without execution" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($fileName in @(
            "current-user-review-ready.json",
            "default-user-review-ready.json",
            "offline-image-review-ready.json",
            "machine-review-ready.json"
        )) {
            $request = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\review\$fileName") -Raw -Encoding UTF8 | ConvertFrom-Json
            $report = New-FutureTrueUxRestoreAuthorizationReviewReport -Manifest $manifest -Request $request -RepoRoot $script:RepoRoot

            Assert-KitEqual $report.reviewDecision "authorization-review-ready"
            Assert-KitEqual $report.evidencePacketStatus "complete"
            Assert-KitEqual $report.authorizationApproved $false
            Assert-KitEqual $report.executionApproved $false
            Assert-KitEqual $report.executeReady $false
            Assert-KitEqual $report.trueExecution $false
            Assert-KitEqual $report.mutationCount 0
        }
    }

    It "blocks incomplete, cross-scope, private-path, and execution-ready requests" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $cases = @(
            @{ File = "missing-before-evidence-blocked.json"; Pattern = "beforeEvidence" },
            @{ File = "missing-rollback-blocked.json"; Pattern = "rollbackPlan" },
            @{ File = "private-path-blocked.json"; Pattern = "private path" },
            @{ File = "cross-scope-evidence-blocked.json"; Pattern = "scope guard" },
            @{ File = "execute-ready-requested-blocked.json"; Pattern = "execute-ready" },
            @{ File = "execution-approved-requested-blocked.json"; Pattern = "execution approval" },
            @{ File = "auto-close-keyword-blocked.json"; Pattern = "auto-close" },
            @{ File = "exit-code-only-success-blocked.json"; Pattern = "command exit code" }
        )

        foreach ($case in $cases) {
            $request = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\review\$($case.File)") -Raw -Encoding UTF8 | ConvertFrom-Json
            $report = New-FutureTrueUxRestoreAuthorizationReviewReport -Manifest $manifest -Request $request -RepoRoot $script:RepoRoot

            Assert-KitEqual $report.reviewDecision "blocked"
            Assert-KitMatch ($report.blockedReasons -join "`n") ([regex]::Escape($case.Pattern))
            Assert-KitEqual $report.trueExecution $false
            Assert-KitEqual $report.mutationCount 0
            Assert-KitEqual $report.executeReady $false
        }
    }
}
