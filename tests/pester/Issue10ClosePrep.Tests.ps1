Describe "Issue 10 close preparation guardrails" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\26-issue10-close-preparation.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
    }

    It "keeps the close preparation document in an allowed manual closure state" {
        Assert-KitEqual (Test-Path -LiteralPath $script:DocPath) $true
        Assert-KitMatch $script:Doc "Status: (ready-for-manual-closure-candidate|ready-for-manual-closure)"
        foreach ($section in @("## Final Scope", "## Evidence Chain", "## Validation Policy", "## Manual Closure Checklist", "## Optional Manual Validation Evidence", "## Closure Note Draft")) {
            Assert-KitMatch $script:Doc ([regex]::Escape($section))
        }
    }

    It "lists the complete evidence chain" {
        foreach ($evidence in @(
            "24-issue10-context-scope-split.md",
            "25-issue10-context-scope-acceptance.md",
            "26-issue10-close-preparation.md",
            "27-issue10-main-validation-evidence.md",
            "ContextScopeSchema.Tests.ps1",
            "ContextScopeResolver.Tests.ps1",
            "ContextScopeSafety.Tests.ps1",
            "ContextScopeReport.Tests.ps1",
            "Issue10ContextScope.Tests.ps1",
            "Issue10ContextScopeAcceptance.Tests.ps1",
            "Issue10ClosePrep.Tests.ps1",
            "Issue10MainValidationEvidence.Tests.ps1"
        )) {
            Assert-KitMatch $script:Doc ([regex]::Escape($evidence))
        }
    }

    It "keeps PR Fast CI mutation boundaries explicit" {
        foreach ($boundary in @("reg load", "reg unload", "HKCU/HKLM writes", "profile mutation", "optional manual evidence")) {
            Assert-KitMatch $script:Doc ([regex]::Escape($boundary))
        }
    }

    It "requires recorded main evidence when the close preparation state is ready" {
        if ($script:Doc -match "Status: ready-for-manual-closure\r?\n") {
            foreach ($evidence in @(
                "Main/workflow validation success evidence",
                "Trigger source | main push",
                "Result | success",
                "Full Validate succeeded",
                "Real VM/admin smoke | optional / not-run"
            )) {
                Assert-KitMatch $script:Doc ([regex]::Escape($evidence))
            }

            Assert-KitMatch $script:Doc 'Main SHA \| `?[0-9a-f]{40}`?'
            Assert-KitMatch $script:Doc "Workflow run \| https://github\.com/phdiggit/win11-image-kit/actions/runs/[0-9]+"
        }
    }

    It "does not contain issue-closing keywords aimed at issue 10" {
        Assert-KitNotMatch $script:Doc "(?i)\b(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+#10\b"
    }

    It "keeps README links and CI coverage complete" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8

        Assert-KitMatch $readme "docs/26-issue10-close-preparation\.md"
        Assert-KitMatch $workflow ([regex]::Escape("tests/pester/Issue10ClosePrep.Tests.ps1"))
    }
}
