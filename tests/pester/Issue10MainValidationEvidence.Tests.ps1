Describe "Issue 10 main validation evidence scaffold" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\27-issue10-main-validation-evidence.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
    }

    It "keeps the scaffold pending by default" {
        Assert-KitEqual (Test-Path -LiteralPath $script:DocPath) $true
        Assert-KitMatch $script:Doc "Status: pending-main-validation"
        Assert-KitMatch $script:Doc "Current readiness: pending-main-validation"
    }

    It "does not pretend pending evidence is ready" {
        foreach ($pending in @("Trigger source | pending", "Main SHA | pending", "Workflow run | pending", "Result | pending")) {
            Assert-KitMatch $script:Doc ([regex]::Escape($pending))
        }
        Assert-KitNotMatch $script:Doc "Status: ready-for-manual-closure"
    }

    It "documents the reserved ready-state rules" {
        foreach ($rule in @("main push", "workflow_dispatch", "40-character SHA", "Actions workflow URL", "Result: success", "ready-for-manual-closure")) {
            Assert-KitMatch $script:Doc ([regex]::Escape($rule))
        }
    }

    It "keeps PR Fast CI out of main validation evidence" {
        Assert-KitMatch $script:Doc "PR Fast CI is not a substitute"
        Assert-KitMatch $script:Doc "Environment | not-run"
        Assert-KitMatch $script:Doc "Result | not-run"
    }

    It "does not contain issue-closing keywords aimed at issue 10" {
        Assert-KitNotMatch $script:Doc "(?i)\b(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+#10\b"
    }

    It "keeps PR Fast CI coverage wired" {
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
        Assert-KitMatch $workflow ([regex]::Escape("tests/pester/Issue10MainValidationEvidence.Tests.ps1"))
    }
}
