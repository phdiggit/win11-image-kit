Describe "Future true UX restore mock review safety prune" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "keeps mock review drill scripts and fixtures pruned without workflow changes" {
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreMockReviewDrillReport.ps1")) $false
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\mock-review")) $false
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "scripts\validate\Test-FutureTrueUxRestoreMockReviewDrill.ps1")) $true
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml")) $true
    }

    It "keeps dangerous command names out of the compatibility validator" {
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
        $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\validate\Test-FutureTrueUxRestoreMockReviewDrill.ps1") -Raw -Encoding UTF8

        foreach ($pattern in $patterns) {
            Assert-KitNotMatch $text $pattern
        }
    }

    It "does not create Issue 18 completion summary or keep pruned Issue 14-18 completed-roadmap docs" {
        Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\01-mock-review")) $false

        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "docs") -Filter "*issue18*.md" -Recurse) {
            Assert-KitNotMatch $file.Name "completion-summary"
        }

        foreach ($issue in 6..13) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-$issue")) $true
        }

        foreach ($issue in 14..18) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-$issue")) $false
        }
    }
}
