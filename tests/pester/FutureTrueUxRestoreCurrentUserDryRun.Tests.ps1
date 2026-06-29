Describe "Future true UX restore current-user dry-run gate" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreCurrentUserDryRunReport.ps1")
    }

    It "keeps docs and manifest in current-user dry-run state" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\69-future-true-ux-restore-current-user-dry-run-gate.md") -Raw -Encoding UTF8
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $section = $manifest.currentUserDryRun

        Assert-KitMatch $doc 'Status:\s*`current-user-dry-run-gate`'
        Assert-KitEqual $section.enabled $true
        Assert-KitEqual $section.scope "current-user"
        Assert-KitEqual $section.authorizationApproved $false
        Assert-KitEqual $section.executionApproved $false
        Assert-KitEqual $section.allowCurrentUserMutation $false
        Assert-KitEqual $section.allowDefaultUserFallback $false
        Assert-KitEqual $section.allowMachineFallback $false
        Assert-KitEqual $section.allowOfflineImageFallback $false
    }

    It "keeps baseline blocked and dry-run-ready no-execute safe" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $baseline = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\current-user\baseline-blocked.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $ready = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\current-user\dry-run-ready-no-execute.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        $baselineReport = New-FutureTrueUxRestoreCurrentUserDryRunReport -Manifest $manifest -Request $baseline -RepoRoot $script:RepoRoot
        $readyReport = New-FutureTrueUxRestoreCurrentUserDryRunReport -Manifest $manifest -Request $ready -RepoRoot $script:RepoRoot

        Assert-KitEqual $baselineReport.decision "blocked"
        Assert-KitEqual $readyReport.decision "dry-run-ready"
        foreach ($report in @($baselineReport, $readyReport)) {
            Assert-KitEqual $report.scope "current-user"
            Assert-KitEqual $report.authorizationApproved $false
            Assert-KitEqual $report.executionApproved $false
            Assert-KitEqual $report.trueExecution $false
            Assert-KitEqual $report.mutationCount 0
            Assert-KitEqual $report.currentUserConfirmed $false
            Assert-KitEqual $report.commandExitCodeSufficient $false
            Assert-KitEqual $report.userConfigurationConfirmed $false
        }
    }

    It "blocks current-user unsafe fixtures" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $cases = @(
            @{ Path = "tests\fixtures\user-experience\future-true-restore\current-user\missing-redacted-user.json"; Pattern = "redactedUserIdentity" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\current-user\default-user-scope-claim-blocked.json"; Pattern = "default-user" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\current-user\machine-scope-claim-blocked.json"; Pattern = "machine" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\current-user\offline-image-scope-claim-blocked.json"; Pattern = "offline-image" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\current-user\exit-code-only-success-blocked.json"; Pattern = "command exit code" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\current-user\private-profile-path-blocked.json"; Pattern = "private profile path" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\current-user\mutation-requested-blocked.json"; Pattern = "mutation request" }
        )

        foreach ($case in $cases) {
            $request = Get-Content -LiteralPath (Join-Path $script:RepoRoot $case.Path) -Raw -Encoding UTF8 | ConvertFrom-Json
            $report = New-FutureTrueUxRestoreCurrentUserDryRunReport -Manifest $manifest -Request $request -RepoRoot $script:RepoRoot
            Assert-KitEqual $report.decision "blocked"
            Assert-KitMatch ($report.blockedReasons -join "`n") ([regex]::Escape($case.Pattern))
            Assert-KitEqual $report.trueExecution $false
            Assert-KitEqual $report.mutationCount 0
            Assert-KitEqual $report.currentUserConfirmed $false
        }
    }
}
