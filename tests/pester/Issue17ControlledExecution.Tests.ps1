Describe "Issue 17 controlled execution intake" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "records the real Issue 17 and Roadmap 19 sources" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\52-issue17-controlled-execution-intake.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc 'Status: `in-progress`'
        Assert-KitMatch $doc "https://github.com/phdiggit/win11-image-kit/issues/17"
        Assert-KitMatch $doc "https://github.com/phdiggit/win11-image-kit/issues/19"
        Assert-KitMatch $doc "WinPE"
        Assert-KitMatch $doc "Roadmap entry"
    }

    It "does not create obsolete Issue 17 closure documents or completion summaries" {
        $forbidden = @(
            "docs\54-issue17-close-preparation.md",
            "docs\54-issue17-main-validation-evidence.md",
            "docs\54-issue17-completion-summary.md",
            "docs\55-issue17-close-preparation.md",
            "docs\55-issue17-main-validation-evidence.md",
            "docs\55-issue17-completion-summary.md",
            "docs\56-issue17-completion-summary.md",
            "docs\57-issue17-completion-summary.md"
        )

        foreach ($path in $forbidden) {
            if (Test-Path -LiteralPath (Join-Path $script:RepoRoot $path)) {
                throw "Issue 17 closure document should not exist: $path"
            }
        }
    }

    It "keeps auto-close keywords out of Issue 17 docs" {
        $combined = @(
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\52-issue17-controlled-execution-intake.md") -Raw -Encoding UTF8
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\53-issue17-controlled-execution-acceptance.md") -Raw -Encoding UTF8
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\54-issue17-controlled-execution-safety-hardening.md") -Raw -Encoding UTF8
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\55-issue17-controlled-execution-authorization.md") -Raw -Encoding UTF8
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\56-issue17-close-preparation.md") -Raw -Encoding UTF8
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\57-issue17-main-validation-evidence.md") -Raw -Encoding UTF8
        ) -join "`n"

        Assert-KitNotMatch $combined '(?im)^\s*(Fixes|Closes|Resolves)\s+#17\b'
    }
}
