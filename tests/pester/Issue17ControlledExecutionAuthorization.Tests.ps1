Describe "Issue 17 controlled execution authorization acceptance" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "keeps Issue 17 acceptance documents accepted and ready for manual closure" {
        $doc52 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-17\52-issue17-controlled-execution-intake.md") -Raw -Encoding UTF8
        $doc53 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-17\53-issue17-controlled-execution-acceptance.md") -Raw -Encoding UTF8
        $doc54 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-17\54-issue17-controlled-execution-safety-hardening.md") -Raw -Encoding UTF8
        $doc55 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-17\55-issue17-controlled-execution-authorization.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc52 'Status: `in-progress`'
        Assert-KitMatch $doc53 'Status: `accepted-ready-for-manual-closure`'
        Assert-KitMatch $doc54 'Status: `accepted-ready-for-manual-closure`'
        Assert-KitMatch $doc55 'Status: `accepted-ready-for-manual-closure`'
        Assert-KitMatch $doc55 "Post-PR #89 main push Full Validate evidence"
    }

    It "creates only ready close-prep and ready main evidence documents" {
        $closePrep = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-17\56-issue17-close-preparation.md") -Raw -Encoding UTF8
        $mainEvidence = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-17\57-issue17-main-validation-evidence.md") -Raw -Encoding UTF8

        Assert-KitMatch $closePrep 'Status: `ready-for-manual-closure`'
        Assert-KitMatch $mainEvidence 'Status: `ready-for-manual-closure`'

        foreach ($path in @(
            "docs\55-issue17-close-preparation.md",
            "docs\55-issue17-main-validation-evidence.md",
            "docs\55-issue17-completion-summary.md",
            "docs\56-issue17-completion-summary.md",
            "docs\57-issue17-completion-summary.md"
        )) {
            if (Test-Path -LiteralPath (Join-Path $script:RepoRoot $path)) {
                throw "Issue 17 closure document should not exist: $path"
            }
        }
    }

    It "keeps Issue 6 through 16 closure documents archived without auto-close drift" {
        foreach ($issue in 6..16) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-$issue")) $true
        }

        $docs = @(Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap") -Filter "*.md" -Recurse | Where-Object { $_.FullName -match 'issue-(6|7|8|9|10|11|12|13|14|15|16)' })
        foreach ($doc in $docs) {
            $text = Get-Content -LiteralPath $doc.FullName -Raw -Encoding UTF8
            Assert-KitNotMatch $text "(?i)\b(fixes|closes|resolves)\s+#(6|7|8|9|10|11|12|13|14|15|16)\b"
        }
    }

    It "keeps paths.local.json out of Build Lock" {
        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $paths = @($buildLock.entries.path)

        Assert-KitEqual ($paths -contains "manifests/paths.local.json") $false
    }
}
