Describe "Issue 17 controlled execution acceptance scaffold" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "keeps docs/53 accepted but pending main validation" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\53-issue17-controlled-execution-acceptance.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc 'Status: `accepted-pending-main-validation`'
        Assert-KitMatch $doc "does not claim real lifecycle evidence or main/workflow evidence"
        Assert-KitMatch $doc "manual closure review is candidate-only"
        Assert-KitMatch $doc "no automatic Issue #17 closure"
        Assert-KitNotMatch $doc 'Status: `ready-for-manual-closure`'
    }

    It "documents safety boundaries without claiming true execution" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\53-issue17-controlled-execution-acceptance.md") -Raw -Encoding UTF8

        foreach ($pattern in @(
            "no real build, capture, deploy",
            "no DISM, Sysprep, AppX, Defender, Junction, Service",
            "no software install",
            "no local private artifact",
            "no Issue #6-#16 close-prep"
        )) {
            Assert-KitMatch $doc $pattern
        }
    }
}
