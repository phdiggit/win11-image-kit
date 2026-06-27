Describe "Issue 18 user experience restore intake" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "records the real Issue 18 and Roadmap 19 source" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\58-issue18-user-experience-restore-intake.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc 'Status: `in-progress`'
        Assert-KitMatch $doc "https://github.com/phdiggit/win11-image-kit/issues/18"
        Assert-KitMatch $doc "https://github.com/phdiggit/win11-image-kit/issues/19"
        Assert-KitMatch $doc "Issue #18"
        Assert-KitMatch $doc "report-only"
    }

    It "does not add Issue 18 close-prep, main-evidence, or completion summary docs" {
        $docs = @(Get-ChildItem -Path (Join-Path $script:RepoRoot "docs") -Filter "*issue18*.md" | ForEach-Object { $_.Name })

        Assert-KitEqual ($docs -contains "58-issue18-user-experience-restore-intake.md") $true
        Assert-KitEqual ($docs -contains "59-issue18-user-experience-restore-acceptance.md") $true
        Assert-KitEqual (@($docs | Where-Object { $_ -match "close-preparation|main-validation-evidence|completion-summary" }).Count) 0
    }
}
