$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Issue 9 close preparation guardrails" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:Doc22 = Join-Path $script:RepoRoot "docs\22-issue9-close-preparation.md"
    }

    It "has close preparation status and required sections" {
        $doc = Get-Content -LiteralPath $script:Doc22 -Raw -Encoding UTF8

        Assert-KitMatch $doc "Status: ready-for-manual-closure-candidate"
        foreach ($text in @("Final Scope", "Evidence Chain", "Validation Policy", "Manual Closure Checklist", "Optional Manual Validation Evidence", "Closure Note Draft")) {
            Assert-KitMatch $doc $text
        }
    }

    It "keeps the evidence chain complete" {
        $doc = Get-Content -LiteralPath $script:Doc22 -Raw -Encoding UTF8
        foreach ($text in @(
            "docs/20-issue9-sysprep-appx-gate.md",
            "docs/21-issue9-sysprep-appx-acceptance.md",
            "docs/22-issue9-close-preparation.md",
            "docs/23-issue9-main-validation-evidence.md",
            "SysprepAppxInventory.Tests.ps1",
            "SysprepAppxReadiness.Tests.ps1",
            "SysprepAppxReport.Tests.ps1",
            "Issue9SysprepAppxGate.Tests.ps1",
            "Issue9SysprepAppxAcceptance.Tests.ps1",
            "Issue9ClosePrep.Tests.ps1",
            "Issue9MainValidationEvidence.Tests.ps1"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($text))
        }
    }

    It "states CI and smoke safety boundaries" {
        $doc = Get-Content -LiteralPath $script:Doc22 -Raw -Encoding UTF8

        Assert-KitMatch $doc "PR Fast CI must not run Sysprep"
        Assert-KitMatch $doc "AppX removal"
        Assert-KitMatch $doc "DISM removal"
        Assert-KitMatch $doc "profile mutation"
        Assert-KitMatch $doc "Real VM/admin smoke is optional manual evidence"
        Assert-KitMatch $doc "Maintainer reviews docs/23"
    }

    It "does not contain Issue 9 auto-close keyword combinations" {
        $doc = Get-Content -LiteralPath $script:Doc22 -Raw -Encoding UTF8

        Assert-KitNotMatch $doc "(?i)(close[sd]?|fix(e[sd])?|resolve[sd]?)\s+#9"
    }

    It "keeps README and docs links complete" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $doc20 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\20-issue9-sysprep-appx-gate.md") -Raw -Encoding UTF8

        Assert-KitMatch $readme "22-issue9-close-preparation\.md"
        Assert-KitMatch $doc20 "22-issue9-close-preparation\.md"
        Assert-KitMatch $doc20 "23-issue9-main-validation-evidence\.md"
    }

    It "is included in PR Fast CI" {
        $ci = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8

        Assert-KitMatch $ci ([regex]::Escape("tests/pester/Issue9ClosePrep.Tests.ps1"))
    }
}
