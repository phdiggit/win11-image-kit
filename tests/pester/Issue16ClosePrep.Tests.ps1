Describe "Issue 16 close-prep candidate" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "keeps docs 50 as candidate only" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\50-issue16-close-preparation.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc 'Status:\s*`ready-for-manual-closure-candidate`'
        foreach ($term in @(
            "## Final Scope Candidate",
            "## Evidence Chain Scope",
            "## Producer Adapter Scope",
            "## Validation Policy",
            "## Manual Closure Checklist",
            "## Optional Manual Validation Evidence",
            "## Closure Note Draft",
            "## Related Documents"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }
        Assert-KitMatch $doc "candidate only|manual closure candidate only"
        Assert-KitMatch $doc "PR Fast CI is not used as a substitute"
        Assert-KitMatch $doc "not-captured"
        Assert-KitNotMatch $doc "(?i)\b(fixes|closes|resolves)\s+#16\b"
        Assert-KitMatch $doc "No Issue #16 completion summary"
    }

    It "does not create an Issue 16 completion summary" {
        $issue16Docs = @(Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "docs") -Filter "*issue16*.md")
        Assert-KitEqual (@($issue16Docs | Where-Object { $_.Name -match "completion-summary" }).Count) 0
    }
}
