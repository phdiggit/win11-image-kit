Describe "Future true UX restore authorization review safety" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "keeps dangerous command names out of review scripts" {
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
            "scripts\common\New-FutureTrueUxRestoreAuthorizationReviewReport.ps1",
            "scripts\validate\Test-FutureTrueUxRestoreAuthorizationReview.ps1",
            "scripts\config\Show-FutureTrueUxRestoreAuthorizationReviewPlan.ps1"
        )

        foreach ($file in $files) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $file) -Raw -Encoding UTF8
            foreach ($pattern in $patterns) {
                Assert-KitNotMatch $text $pattern
            }
        }
    }

    It "keeps review artifacts report-only and manual-closure-safe" {
        $paths = @(
            "docs\76-future-true-ux-restore-unified-authorization-request.md",
            "docs\77-future-true-ux-restore-maintainer-review-checkpoint.md",
            "docs\78-future-true-ux-restore-evidence-packet-contract.md",
            "docs\79-future-true-ux-restore-authorization-state-machine.md",
            "scripts\common\New-FutureTrueUxRestoreAuthorizationReviewReport.ps1",
            "scripts\validate\Test-FutureTrueUxRestoreAuthorizationReview.ps1",
            "scripts\config\Show-FutureTrueUxRestoreAuthorizationReviewPlan.ps1"
        )

        foreach ($path in $paths) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $path) -Raw -Encoding UTF8
            Assert-KitNotMatch $text "(?i)\b(fixes|closes|resolves)\s+#18\b"
            Assert-KitMatch $text "(?i)(review|report|dry-run|AuthorizationApproved=false|ExecuteReady: false)"
        }
    }
}
