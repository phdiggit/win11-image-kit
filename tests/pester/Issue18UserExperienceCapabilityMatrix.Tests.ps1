Describe "Issue 18 user experience capability matrix docs" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "adds docs/60 with scope and evidence semantics" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\60-issue18-user-experience-capability-matrix.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc 'Status: `accepted-ready-for-manual-closure`'
        Assert-KitMatch $doc "default-user.*not.*current-user"
        Assert-KitMatch $doc "Writing Default Profile does not modify the current user"
        Assert-KitMatch $doc "Command exit code is not enough UX evidence"
        Assert-KitMatch $doc "ready close-prep"
        Assert-KitMatch $doc "ready main evidence"
    }

    It "keeps Issue 18 out of completion summary docs" {
        $docs = @(Get-ChildItem -Path (Join-Path $script:RepoRoot "docs") -Filter "*issue18*.md" | ForEach-Object { $_.Name })

        Assert-KitEqual ($docs -contains "60-issue18-user-experience-capability-matrix.md") $true
        Assert-KitEqual ($docs -contains "62-issue18-close-preparation.md") $true
        Assert-KitEqual ($docs -contains "63-issue18-main-validation-evidence.md") $true
        Assert-KitEqual (@($docs | Where-Object { $_ -match "completion-summary" }).Count) 0
    }
}
