Describe "Issue 18 user experience capability matrix docs" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "adds docs/60 with scope and evidence semantics" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\60-issue18-user-experience-capability-matrix.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc 'Status: `in-acceptance`'
        Assert-KitMatch $doc "default-user.*not.*current-user"
        Assert-KitMatch $doc "Writing Default Profile does not modify the current user"
        Assert-KitMatch $doc "Command exit code is not enough UX evidence"
        Assert-KitMatch $doc "no Issue #18 close-prep"
    }

    It "keeps Issue 18 out of close-prep and main evidence docs" {
        $docs = @(Get-ChildItem -Path (Join-Path $script:RepoRoot "docs") -Filter "*issue18*.md" | ForEach-Object { $_.Name })

        Assert-KitEqual ($docs -contains "60-issue18-user-experience-capability-matrix.md") $true
        Assert-KitEqual (@($docs | Where-Object { $_ -match "close-preparation|main-validation-evidence|completion-summary" }).Count) 0
    }
}
