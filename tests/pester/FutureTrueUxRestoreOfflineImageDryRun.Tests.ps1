Describe "Future true UX restore offline-image dry-run gate" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreScopeDryRunReport.ps1")
    }

    It "keeps docs and manifest in offline-image dry-run state" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\73-future-true-ux-restore-offline-image-dry-run-gate.md") -Raw -Encoding UTF8
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $section = $manifest.offlineImageDryRun

        Assert-KitMatch $doc 'Status:\s*`offline-image-dry-run-gate`'
        Assert-KitEqual $section.enabled $true
        Assert-KitEqual $section.scope "offline-image"
        Assert-KitEqual $section.authorizationApproved $false
        Assert-KitEqual $section.executionApproved $false
        Assert-KitEqual $section.allowOfflineImageMutation $false
        Assert-KitEqual $section.allowCurrentMachineFallback $false
        Assert-KitEqual $section.allowCurrentUserFallback $false
        Assert-KitEqual $section.allowDefaultUserFallback $false
    }

    It "keeps offline-image baseline blocked and ready fixture no-execute" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $baseline = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\offline-image\baseline-blocked.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $ready = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\offline-image\dry-run-ready-no-execute.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        $baselineReport = New-FutureTrueUxRestoreSingleScopeDryRunReport -Manifest $manifest -Request $baseline -Scope "offline-image" -RepoRoot $script:RepoRoot
        $readyReport = New-FutureTrueUxRestoreSingleScopeDryRunReport -Manifest $manifest -Request $ready -Scope "offline-image" -RepoRoot $script:RepoRoot

        Assert-KitEqual $baselineReport.decision "blocked"
        Assert-KitEqual $readyReport.decision "dry-run-ready"
        foreach ($report in @($baselineReport, $readyReport)) {
            Assert-KitEqual $report.scope "offline-image"
            Assert-KitEqual $report.authorizationApproved $false
            Assert-KitEqual $report.executionApproved $false
            Assert-KitEqual $report.trueExecution $false
            Assert-KitEqual $report.mutationCount 0
            Assert-KitEqual $report.offlineImageConfirmed $false
            Assert-KitEqual $report.commandExitCodeSufficient $false
            Assert-KitEqual $report.userConfigurationConfirmed $false
        }
    }

    It "blocks offline-image unsafe fixtures" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $cases = @(
            @{ Path = "tests\fixtures\user-experience\future-true-restore\offline-image\missing-image-identity.json"; Pattern = "imageIdentity" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\offline-image\current-machine-claim-blocked.json"; Pattern = "current-machine" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\offline-image\image-servicing-requested-blocked.json"; Pattern = "imageServicingRequested" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\offline-image\mount-requested-blocked.json"; Pattern = "mountRequested" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\offline-image\private-mount-path-blocked.json"; Pattern = "private path" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\offline-image\exit-code-only-success-blocked.json"; Pattern = "command exit code" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\offline-image\handler-report-success-blocked.json"; Pattern = "handler report" }
        )

        foreach ($case in $cases) {
            $request = Get-Content -LiteralPath (Join-Path $script:RepoRoot $case.Path) -Raw -Encoding UTF8 | ConvertFrom-Json
            $report = New-FutureTrueUxRestoreSingleScopeDryRunReport -Manifest $manifest -Request $request -Scope "offline-image" -RepoRoot $script:RepoRoot
            Assert-KitEqual $report.decision "blocked"
            Assert-KitMatch ($report.blockedReasons -join "`n") ([regex]::Escape($case.Pattern))
            Assert-KitEqual $report.trueExecution $false
            Assert-KitEqual $report.mutationCount 0
            Assert-KitEqual $report.offlineImageConfirmed $false
        }
    }
}
