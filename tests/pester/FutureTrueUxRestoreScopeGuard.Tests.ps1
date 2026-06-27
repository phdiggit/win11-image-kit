Describe "Future true UX restore scope guard matrix" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreScopeDryRunReport.ps1")
    }

    It "documents the four-scope guard matrix" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\75-future-true-ux-restore-scope-guard-matrix.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc 'Status:\s*`scope-guard-matrix`'
        foreach ($scope in @("current-user", "default-user", "offline-image", "machine")) {
            Assert-KitMatch $doc ([regex]::Escape($scope))
        }
        Assert-KitMatch $doc "Fallback across scopes is blocked"
    }

    It "keeps aggregate report no-mutation across four ready fixtures" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $fixtureRoot = "tests\fixtures\user-experience\future-true-restore"
        $requestsByScope = @{
            "current-user" = Get-Content -LiteralPath (Join-Path $script:RepoRoot "$fixtureRoot\current-user\dry-run-ready-no-execute.json") -Raw -Encoding UTF8 | ConvertFrom-Json
            "default-user" = Get-Content -LiteralPath (Join-Path $script:RepoRoot "$fixtureRoot\default-user\dry-run-ready-no-execute.json") -Raw -Encoding UTF8 | ConvertFrom-Json
            "offline-image" = Get-Content -LiteralPath (Join-Path $script:RepoRoot "$fixtureRoot\offline-image\dry-run-ready-no-execute.json") -Raw -Encoding UTF8 | ConvertFrom-Json
            "machine" = Get-Content -LiteralPath (Join-Path $script:RepoRoot "$fixtureRoot\machine\dry-run-ready-no-execute.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        }

        $report = New-FutureTrueUxRestoreScopeDryRunReport -Manifest $manifest -RequestsByScope $requestsByScope -RepoRoot $script:RepoRoot
        Assert-KitEqual $report.aggregateDecision "dry-run-ready"
        Assert-KitEqual $report.blockedCount 0
        Assert-KitEqual $report.dryRunReadyCount 4
        Assert-KitEqual $report.trueExecution $false
        Assert-KitEqual $report.mutationCount 0
        Assert-KitEqual $report.commandExitCodeSufficient $false
        Assert-KitEqual $report.userConfigurationConfirmed $false
    }

    It "blocks cross-scope evidence substitution" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $cases = @(
            @{ Scope = "current-user"; Path = "tests\fixtures\user-experience\future-true-restore\current-user\default-user-scope-claim-blocked.json"; Pattern = "default-user" },
            @{ Scope = "default-user"; Path = "tests\fixtures\user-experience\future-true-restore\default-user\current-user-scope-claim-blocked.json"; Pattern = "current-user" },
            @{ Scope = "offline-image"; Path = "tests\fixtures\user-experience\future-true-restore\offline-image\current-machine-claim-blocked.json"; Pattern = "current-machine" },
            @{ Scope = "machine"; Path = "tests\fixtures\user-experience\future-true-restore\machine\current-user-claim-blocked.json"; Pattern = "current-user" }
        )

        foreach ($case in $cases) {
            $request = Get-Content -LiteralPath (Join-Path $script:RepoRoot $case.Path) -Raw -Encoding UTF8 | ConvertFrom-Json
            $report = New-FutureTrueUxRestoreSingleScopeDryRunReport -Manifest $manifest -Request $request -Scope $case.Scope -RepoRoot $script:RepoRoot
            Assert-KitEqual $report.decision "blocked"
            Assert-KitMatch ($report.blockedReasons -join "`n") ([regex]::Escape($case.Pattern))
            Assert-KitEqual $report.trueExecution $false
            Assert-KitEqual $report.mutationCount 0
        }
    }
}
