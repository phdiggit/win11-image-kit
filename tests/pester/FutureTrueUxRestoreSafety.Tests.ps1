Describe "Future true UX restore safety" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreAuthorizationReport.ps1")
    }

    It "blocks unsafe fixture reasons" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $cases = @(
            @{ Path = "tests\fixtures\user-experience\future-true-restore\authorization\current-user-missing-rollback.json"; Pattern = "rollbackPlan" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\authorization\default-user-scope-mismatch.json"; Pattern = "scope mismatch" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\authorization\offline-image-missing-identity.json"; Pattern = "targetIdentity" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\authorization\mutation-requested-blocked.json"; Pattern = "mutation request" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\authorization\exit-code-only-success-blocked.json"; Pattern = "command exit code" },
            @{ Path = "tests\fixtures\user-experience\future-true-restore\evidence\private-path-blocked.json"; Pattern = "private local path" }
        )

        foreach ($case in $cases) {
            $request = Get-Content -LiteralPath (Join-Path $script:RepoRoot $case.Path) -Raw -Encoding UTF8 | ConvertFrom-Json
            $report = New-FutureTrueUxRestoreAuthorizationReport -Manifest $manifest -AuthorizationRequest $request -RepoRoot $script:RepoRoot
            Assert-KitEqual $report.decision "blocked"
            Assert-KitMatch ($report.blockedReasons -join "`n") ([regex]::Escape($case.Pattern))
            Assert-KitEqual $report.trueExecution $false
            Assert-KitEqual $report.mutationCount 0
        }
    }

    It "keeps dangerous command names out of new scripts" {
        $patterns = @(
            '\bSet-ItemProperty\b',
            '\bNew-ItemProperty\b',
            '\bRemove-ItemProperty\b',
            '\breg\.exe\b',
            '\breg\s+add\b',
            '\breg\s+delete\b',
            '\bDism(\.exe)?\b',
            '\bImport-StartLayout\b',
            '\bExport-StartLayout\b',
            '\bGet-StartApps\b',
            '\bGet-AppxPackage\b',
            '\bGet-AppxProvisionedPackage\b',
            '\bInvoke-Expression\b',
            '\bInvoke-WebRequest\b',
            '\bInvoke-RestMethod\b',
            '\bInstall-Module\b',
            '\bwinget\b',
            '\bchoco\b',
            '\bmsiexec\b'
        )
        $files = @(
            "scripts\common\New-FutureTrueUxRestoreAuthorizationReport.ps1",
            "scripts\validate\Test-FutureTrueUxRestoreAuthorization.ps1",
            "scripts\config\Show-FutureTrueUxRestoreAuthorizationPlan.ps1"
        )

        foreach ($file in $files) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $file) -Raw -Encoding UTF8
            foreach ($pattern in $patterns) {
                Assert-KitNotMatch $text $pattern
            }
        }
    }
}
