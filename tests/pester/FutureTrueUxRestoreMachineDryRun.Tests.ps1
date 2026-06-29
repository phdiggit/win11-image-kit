Describe "Future true UX restore machine dry-run gate" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreScopeDryRunReport.ps1")
    }

    It "keeps docs and manifest in machine dry-run state" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\74-future-true-ux-restore-machine-dry-run-gate.md") -Raw -Encoding UTF8
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $section = $manifest.machineDryRun

        Assert-KitMatch $doc 'Status:\s*`machine-dry-run-gate`'
        Assert-KitEqual $section.enabled $true
        Assert-KitEqual $section.scope "machine"
        Assert-KitEqual $section.authorizationApproved $false
        Assert-KitEqual $section.executionApproved $false
        Assert-KitEqual $section.allowMachineMutation $false
        Assert-KitEqual $section.allowCurrentUserFallback $false
        Assert-KitEqual $section.allowDefaultUserFallback $false
        Assert-KitEqual $section.allowOfflineImageFallback $false
    }

    It "keeps machine baseline blocked and ready fixture no-execute" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $baseline = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\machine\baseline-blocked.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $ready = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\machine\dry-run-ready-no-execute.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        $baselineReport = New-FutureTrueUxRestoreSingleScopeDryRunReport -Manifest $manifest -Request $baseline -Scope "machine" -RepoRoot $script:RepoRoot
        $readyReport = New-FutureTrueUxRestoreSingleScopeDryRunReport -Manifest $manifest -Request $ready -Scope "machine" -RepoRoot $script:RepoRoot

        Assert-KitEqual $baselineReport.decision "blocked"
        Assert-KitEqual $readyReport.decision "dry-run-ready"
        foreach ($report in @($baselineReport, $readyReport)) {
            Assert-KitEqual $report.scope "machine"
            Assert-KitEqual $report.authorizationApproved $false
            Assert-KitEqual $report.executionApproved $false
            Assert-KitEqual $report.trueExecution $false
            Assert-KitEqual $report.mutationCount 0
            Assert-KitEqual $report.machineConfirmed $false
            Assert-KitEqual $report.commandExitCodeSufficient $false
            Assert-KitEqual $report.userConfigurationConfirmed $false
        }
    }

    It "blocks machine unsafe fixtures" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $cases = @(
            @{ Path = "tests\fixtures\user-experience\future-true-restore\machine\missing-machine-identity.json"; Pattern = "machineIdentity" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\machine\current-user-claim-blocked.json"; Pattern = "current-user" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\machine\policy-write-requested-blocked.json"; Pattern = "policyWriteRequested" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\machine\service-requested-blocked.json"; Pattern = "serviceRequested" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\machine\defender-requested-blocked.json"; Pattern = "defenderRequested" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\machine\exit-code-only-success-blocked.json"; Pattern = "command exit code" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\machine\dry-run-report-success-blocked.json"; Pattern = "dry-run report" }
        )

        foreach ($case in $cases) {
            $request = Get-Content -LiteralPath (Join-Path $script:RepoRoot $case.Path) -Raw -Encoding UTF8 | ConvertFrom-Json
            $report = New-FutureTrueUxRestoreSingleScopeDryRunReport -Manifest $manifest -Request $request -Scope "machine" -RepoRoot $script:RepoRoot
            Assert-KitEqual $report.decision "blocked"
            Assert-KitMatch ($report.blockedReasons -join "`n") ([regex]::Escape($case.Pattern))
            Assert-KitEqual $report.trueExecution $false
            Assert-KitEqual $report.mutationCount 0
            Assert-KitEqual $report.machineConfirmed $false
        }
    }
}
