Describe "Issue 16 close-prep candidate" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\50-issue16-close-preparation.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
    }

    It "keeps docs 50 in an allowed close-prep state" {
        Assert-KitMatch $script:Doc 'Status:\s*`(ready-for-manual-closure-candidate|ready-for-manual-closure)`'
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
            Assert-KitMatch $script:Doc ([regex]::Escape($term))
        }
        Assert-KitMatch $script:Doc "candidate only|manual closure candidate only|maintainer manual closure"
        Assert-KitMatch $script:Doc "PR Fast CI is not used as a substitute"
        Assert-KitMatch $script:Doc "not-captured"
        Assert-KitMatch $script:Doc "true execution|real build|real deploy|service mutation"
        Assert-KitMatch $script:Doc "local private override|paths\.local\.json"
        Assert-KitNotMatch $script:Doc "(?i)\b(fixes|closes|resolves)\s+#16\b"
        Assert-KitMatch $script:Doc "No Issue #16 completion summary"
    }

    It "requires main validation evidence when close prep is ready" {
        if ($script:Doc -match 'Status:\s*`ready-for-manual-closure`') {
            Assert-KitMatch $script:Doc "post-PR #81 main push Full Validate"
            $evidenceDoc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\51-issue16-main-validation-evidence.md") -Raw -Encoding UTF8
            Assert-KitMatch $evidenceDoc 'Status:\s*`ready-for-manual-closure`'
            Assert-KitMatch $evidenceDoc '\| Result \| `success` \|'
        }
    }

    It "does not create an Issue 16 completion summary" {
        $issue16Docs = @(Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "docs") -Filter "*issue16*.md")
        Assert-KitEqual (@($issue16Docs | Where-Object { $_.Name -match "completion-summary" }).Count) 0
    }
}
