Describe "Repository governance audit" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\108-repo-documentation-script-governance-audit.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
    }

    It "records the report-only governance audit document" {
        Assert-KitEqual (Test-Path -LiteralPath $script:DocPath) $true
        Assert-KitMatch $script:Doc 'Status:\s*`repo-governance-audit`'
        Assert-KitMatch $script:Doc "Documentation Inventory"
        Assert-KitMatch $script:Doc "Script And Fixture Inventory"
        Assert-KitMatch $script:Doc "Quality Gate And Build Lock Alignment"
    }

    It "keeps Issue 19 as a reference without auto-close wording" {
        Assert-KitMatch $script:Doc "Refs #19"
        Assert-KitNotMatch $script:Doc "(?i)\b(fixes|closes|resolves)\s+#19\b"
        Assert-KitMatch $script:Doc "does not edit or close GitHub issues"
    }

    It "keeps true execution semantics frozen in the audit" {
        Assert-KitMatch $script:Doc '\| `authorizationApproved` \| `false` \|'
        Assert-KitMatch $script:Doc '\| `executionApproved` \| `false` \|'
        Assert-KitMatch $script:Doc '\| `executeReady` \| `false` \|'
        Assert-KitMatch $script:Doc '\| `trueExecution` \| `false` \|'
        Assert-KitMatch $script:Doc '\| `mutationCount` \| `0` \|'
        Assert-KitNotMatch $script:Doc "authorizationApproved\s*=\s*true"
        Assert-KitNotMatch $script:Doc "executionApproved\s*=\s*true"
        Assert-KitNotMatch $script:Doc "executeReady\s*=\s*true"
        Assert-KitNotMatch $script:Doc "trueExecution\s*=\s*true"
    }

    It "reports but does not require workflow, quality gate, or build lock edits" {
        Assert-KitMatch $script:Doc 'does not modify `.github/workflows/ci.yml`'
        Assert-KitMatch $script:Doc "Existing quality gate ordering and required flags"
        Assert-KitMatch $script:Doc "Existing Build Lock entries and hashes"
    }
}
