Describe "Future true UX restore execute gate dual approval" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreCurrentUserDryRunReport.ps1")
    }

    It "documents separate authorization and execution approvals" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\71-future-true-ux-restore-execute-gate-dual-approval.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc 'Status:\s*`execute-gate-draft`'
        Assert-KitMatch $doc "AuthorizationApproved=true"
        Assert-KitMatch $doc "ExecutionApproved=true"
        Assert-KitMatch $doc "AuthorizationApproved=false"
        Assert-KitMatch $doc "ExecutionApproved=false"
        Assert-KitMatch $doc "Without both approvals true"
        foreach ($scope in @("current-user", "default-user", "offline-image", "machine")) {
            Assert-KitMatch $doc ([regex]::Escape($scope))
        }
    }

    It "blocks one-sided approvals and keeps report frozen false" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $cases = @(
            @{ Path = "tests\fixtures\user-experience\future-true-restore\current-user\authorization-approved-without-execution-blocked.json"; Pattern = "authorization approval without execution approval" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\current-user\execution-approved-without-authorization-blocked.json"; Pattern = "execution approval without authorization approval" }
        )

        foreach ($case in $cases) {
            $request = Get-Content -LiteralPath (Join-Path $script:RepoRoot $case.Path) -Raw -Encoding UTF8 | ConvertFrom-Json
            $report = New-FutureTrueUxRestoreCurrentUserDryRunReport -Manifest $manifest -Request $request -RepoRoot $script:RepoRoot
            Assert-KitEqual $report.decision "blocked"
            Assert-KitMatch ($report.blockedReasons -join "`n") ([regex]::Escape($case.Pattern))
            Assert-KitEqual $report.authorizationApproved $false
            Assert-KitEqual $report.executionApproved $false
            Assert-KitEqual $report.trueExecution $false
            Assert-KitEqual $report.mutationCount 0
        }
    }
}
