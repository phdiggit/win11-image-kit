$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
. (Join-Path $RepoRoot "tests\pester\TestHelpers.ps1")

Describe "Issue 6 completion summary archive" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")

        $script:DocPath = Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-6\12-issue6-completion-summary.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
        $script:Readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
    }

    It "keeps the post-close completion summary present" {
        Assert-KitNotNullOrEmpty (Get-Item -LiteralPath $script:DocPath -ErrorAction SilentlyContinue)
    }

    It "documents manual closure status and scope" {
        foreach ($term in @(
            "Status: closed-manually";
            "Issue #6 was closed manually";
            "StepResult";
            "required / optional failure policy";
            "childReportSummary";
            "Main Full Validate evidence record";
            "docs/archive/completed-roadmap/issue-6/11-issue6-main-validation-evidence.md"
        )) {
            if (-not $script:Doc.Contains($term)) {
                throw "Issue 6 completion summary is missing required term: $term"
            }
        }
    }

    It "links the evidence document chain from docs 08 through docs 11" {
        foreach ($docPathPrefix in @(
            "docs/08-";
            "docs/09-issue6-";
            "docs/10-issue6-";
            "docs/archive/completed-roadmap/issue-6/11-issue6-main-validation-evidence.md"
        )) {
            if (-not $script:Doc.Contains($docPathPrefix)) {
                throw "Issue 6 completion summary is missing evidence document prefix: $docPathPrefix"
            }
        }
    }

    It "keeps future work outside issue 6" {
        foreach ($term in @(
            "Future work outside #6";
            "AppX child report integration into the postdeploy top-level main chain";
            "Real VM / admin smoke validation";
            "real installer";
            "should not reopen the #6 implementation scope"
        )) {
            if (-not $script:Doc.Contains($term)) {
                throw "Issue 6 completion summary is missing future-work boundary: $term"
            }
        }
    }

    It "links the completion summary from README" {
        if (-not $script:Readme.Contains("docs/archive/completed-roadmap/issue-6/12-issue6-completion-summary.md")) {
            throw "README is missing the Issue 6 completion summary link."
        }
    }

    It "keeps the summary free of automatic closing keywords for issue 6" {
        $closingPattern = '(?i)\b(close[sd]?|fix(e[sd])?|resolve[sd]?)\s+#6\b'
        if ($script:Doc -match $closingPattern) {
            throw "Issue 6 completion summary must not contain an automatic closing keyword with issue 6."
        }
    }
}
