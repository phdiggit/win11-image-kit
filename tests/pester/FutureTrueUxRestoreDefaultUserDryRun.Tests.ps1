Describe "Future true UX restore default-user dry-run gate" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreScopeDryRunReport.ps1")
    }

    It "keeps docs and manifest in default-user dry-run state" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\72-future-true-ux-restore-default-user-dry-run-gate.md") -Raw -Encoding UTF8
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $section = $manifest.defaultUserDryRun

        Assert-KitMatch $doc 'Status:\s*`default-user-dry-run-gate`'
        Assert-KitEqual $section.enabled $true
        Assert-KitEqual $section.scope "default-user"
        Assert-KitEqual $section.authorizationApproved $false
        Assert-KitEqual $section.executionApproved $false
        Assert-KitEqual $section.allowDefaultUserMutation $false
        Assert-KitEqual $section.allowCurrentUserFallback $false
        Assert-KitEqual $section.allowMachineFallback $false
        Assert-KitEqual $section.allowOfflineImageFallback $false
    }

    It "keeps default-user baseline blocked and ready fixture no-execute" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $baseline = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\default-user\baseline-blocked.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $ready = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\default-user\dry-run-ready-no-execute.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        $baselineReport = New-FutureTrueUxRestoreSingleScopeDryRunReport -Manifest $manifest -Request $baseline -Scope "default-user" -RepoRoot $script:RepoRoot
        $readyReport = New-FutureTrueUxRestoreSingleScopeDryRunReport -Manifest $manifest -Request $ready -Scope "default-user" -RepoRoot $script:RepoRoot

        Assert-KitEqual $baselineReport.decision "blocked"
        Assert-KitEqual $readyReport.decision "dry-run-ready"
        foreach ($report in @($baselineReport, $readyReport)) {
            Assert-KitEqual $report.scope "default-user"
            Assert-KitEqual $report.authorizationApproved $false
            Assert-KitEqual $report.executionApproved $false
            Assert-KitEqual $report.trueExecution $false
            Assert-KitEqual $report.mutationCount 0
            Assert-KitEqual $report.defaultUserConfirmed $false
            Assert-KitEqual $report.commandExitCodeSufficient $false
            Assert-KitEqual $report.userConfigurationConfirmed $false
        }
    }

    It "blocks default-user unsafe fixtures" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $cases = @(
            @{ Path = "tests\fixtures\user-experience\future-true-restore\default-user\missing-template-source.json"; Pattern = "templateSource" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\default-user\current-user-scope-claim-blocked.json"; Pattern = "current-user" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\default-user\private-profile-path-blocked.json"; Pattern = "private path" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\default-user\hive-load-requested-blocked.json"; Pattern = "hiveLoadRequested" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\default-user\mutation-requested-blocked.json"; Pattern = "mutationRequested" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\default-user\exit-code-only-success-blocked.json"; Pattern = "command exit code" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\default-user\manual-checklist-success-blocked.json"; Pattern = "manual checklist" }
        )

        foreach ($case in $cases) {
            $request = Get-Content -LiteralPath (Join-Path $script:RepoRoot $case.Path) -Raw -Encoding UTF8 | ConvertFrom-Json
            $report = New-FutureTrueUxRestoreSingleScopeDryRunReport -Manifest $manifest -Request $request -Scope "default-user" -RepoRoot $script:RepoRoot
            Assert-KitEqual $report.decision "blocked"
            Assert-KitMatch ($report.blockedReasons -join "`n") ([regex]::Escape($case.Pattern))
            Assert-KitEqual $report.trueExecution $false
            Assert-KitEqual $report.mutationCount 0
            Assert-KitEqual $report.defaultUserConfirmed $false
        }
    }
}
