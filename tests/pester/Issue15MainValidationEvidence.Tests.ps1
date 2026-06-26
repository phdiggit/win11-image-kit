Describe "Issue 15 main validation evidence scaffold" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\47-issue15-main-validation-evidence.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
    }

    It "keeps the scaffold pending and rejects PR Fast CI as a substitute" {
        Assert-KitMatch $script:Doc 'Status:\s*`pending-main-validation`'
        Assert-KitMatch $script:Doc "Pull request-only Fast CI is not a substitute"
        Assert-KitMatch $script:Doc '\| PR Fast CI substitute allowed \| `false` \|'
        Assert-KitNotMatch $script:Doc "(?i)(Fixes|Closes|Resolves)\s+#15"
    }

    It "keeps all main evidence fields pending" {
        foreach ($field in @("Trigger source", "Main SHA", "Workflow run", "Full Validate job", "Result", "Notes")) {
            Assert-KitMatch $script:Doc ('\| {0} \| `pending` \|' -f [regex]::Escape($field))
        }
    }

    It "keeps effective configuration and real smoke evidence unfilled" {
        foreach ($field in @("Report status", "failedCount", "stackCount", "CLI override fixture")) {
            Assert-KitMatch $script:Doc ('\| {0} \| `pending` \|' -f [regex]::Escape($field))
        }

        Assert-KitMatch $script:Doc '\| local override included \| `false` \|'
        Assert-KitMatch $script:Doc '\| Environment \| `not-run` \|'
        Assert-KitMatch $script:Doc '\| Operator \| `not-provided` \|'
        Assert-KitMatch $script:Doc '\| Date \| `not-provided` \|'
        Assert-KitMatch $script:Doc '\| Scope \| `not-provided` \|'
        Assert-KitMatch $script:Doc '\| Result \| `not-run` \|'
    }
}
