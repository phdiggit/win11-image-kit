Describe "Issue 17 controlled execution authorization acceptance" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "keeps Issue 17 documents in staged acceptance and not close-ready" {
        $doc52 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\52-issue17-controlled-execution-intake.md") -Raw -Encoding UTF8
        $doc53 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\53-issue17-controlled-execution-acceptance.md") -Raw -Encoding UTF8
        $doc54 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\54-issue17-controlled-execution-safety-hardening.md") -Raw -Encoding UTF8
        $doc55 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\55-issue17-controlled-execution-authorization.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc52 'Status: `in-progress`'
        Assert-KitMatch $doc53 'Status: `in-acceptance`'
        Assert-KitMatch $doc54 'Status: `in-acceptance`'
        Assert-KitMatch $doc55 'Status: `in-acceptance`'
        Assert-KitNotMatch $doc55 "ready-for-manual-closure"
    }

    It "does not create Issue 17 closure or main evidence documents" {
        foreach ($path in @(
            "docs\55-issue17-close-preparation.md",
            "docs\55-issue17-main-validation-evidence.md",
            "docs\55-issue17-completion-summary.md",
            "docs\56-issue17-close-preparation.md",
            "docs\56-issue17-main-validation-evidence.md",
            "docs\56-issue17-completion-summary.md"
        )) {
            if (Test-Path -LiteralPath (Join-Path $script:RepoRoot $path)) {
                throw "Issue 17 closure document should not exist: $path"
            }
        }
    }

    It "keeps Issue 6 through 16 closure documents untouched by this task scope" {
        $changed = @(& git -C $script:RepoRoot -c core.quotepath=false diff --name-only)
        $forbidden = @($changed | Where-Object { $_ -match '^docs/.*issue(6|7|8|9|10|11|12|13|14|15|16).*(close|main-validation|completion)' })
        Assert-KitEqual $forbidden.Count 0
    }

    It "keeps paths.local.json out of Build Lock" {
        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $paths = @($buildLock.entries.path)

        Assert-KitEqual ($paths -contains "manifests/paths.local.json") $false
    }
}
