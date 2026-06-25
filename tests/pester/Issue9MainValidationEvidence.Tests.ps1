$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Issue 9 main validation evidence scaffold" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:Doc23 = Join-Path $script:RepoRoot "docs\23-issue9-main-validation-evidence.md"
    }

    It "exists with default pending status" {
        $doc = Get-Content -LiteralPath $script:Doc23 -Raw -Encoding UTF8
        $statusLine = @($doc -split "`r?`n" | Where-Object { $_ -like "Status:*" })[0]

        Assert-KitEqual $statusLine "Status: pending-main-validation"
    }

    It "does not pretend pending evidence is ready" {
        $doc = Get-Content -LiteralPath $script:Doc23 -Raw -Encoding UTF8
        $readinessLine = @($doc -split "`r?`n" | Where-Object { $_ -like "- Current readiness:*" })[0]

        Assert-KitMatch $doc "Trigger source: pending"
        Assert-KitMatch $doc "Main SHA: pending"
        Assert-KitMatch $doc "Workflow run: pending"
        Assert-KitMatch $doc "Result: pending"
        Assert-KitEqual $readinessLine "- Current readiness: pending-main-validation"
    }

    It "documents ready-state rules for future main evidence" {
        $doc = Get-Content -LiteralPath $script:Doc23 -Raw -Encoding UTF8

        Assert-KitMatch $doc "main push or workflow_dispatch"
        Assert-KitMatch $doc "40-character main SHA"
        Assert-KitMatch $doc "Actions workflow URL"
        Assert-KitMatch $doc "Result: success"
        Assert-KitMatch $doc "Current readiness: ready-for-manual-closure"
    }

    It "keeps PR Fast CI separate from main validation evidence" {
        $doc = Get-Content -LiteralPath $script:Doc23 -Raw -Encoding UTF8

        Assert-KitMatch $doc "cannot|不能|must not"
        Assert-KitMatch $doc "PR Fast CI"
        Assert-KitMatch $doc "main validation evidence"
        Assert-KitMatch $doc "Real VM/admin Smoke|Real VM/admin smoke"
        Assert-KitMatch $doc "not-run"
    }

    It "does not contain Issue 9 auto-close keyword combinations" {
        $doc = Get-Content -LiteralPath $script:Doc23 -Raw -Encoding UTF8

        Assert-KitNotMatch $doc "(?i)(close[sd]?|fix(e[sd])?|resolve[sd]?)\s+#9"
    }

    It "is included in PR Fast CI" {
        $ci = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8

        Assert-KitMatch $ci ([regex]::Escape("tests/pester/Issue9MainValidationEvidence.Tests.ps1"))
    }
}
