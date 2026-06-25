$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Issue 7 close preparation evidence" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")

        $script:Doc14Path = Join-Path $script:RepoRoot "docs\14-issue7-close-preparation.md"
        $script:Doc13Path = Join-Path $script:RepoRoot "docs\13-issue7-junction-transaction-acceptance.md"
        $script:ReadmePath = Join-Path $script:RepoRoot "README.md"
        $script:CiPath = Join-Path $script:RepoRoot ".github\workflows\ci.yml"

        $script:Doc14 = Get-Content -LiteralPath $script:Doc14Path -Raw -Encoding UTF8
        $script:Doc13 = Get-Content -LiteralPath $script:Doc13Path -Raw -Encoding UTF8
        $script:Readme = Get-Content -LiteralPath $script:ReadmePath -Raw -Encoding UTF8
        $script:Ci = Get-Content -LiteralPath $script:CiPath -Raw -Encoding UTF8
    }

    It "keeps the close preparation document present and in manual closure candidate state" {
        Assert-KitNotNullOrEmpty (Get-Item -LiteralPath $script:Doc14Path -ErrorAction SilentlyContinue)
        if (-not $script:Doc14.Contains("Status: ready-for-manual-closure-candidate")) {
            throw "docs/14 is missing the manual closure candidate status."
        }
    }

    It "keeps the evidence chain complete" {
        foreach ($requiredTerm in @(
            "docs/13-issue7-junction-transaction-acceptance.md";
            "tests/pester/JunctionTransactionPreflight.Tests.ps1";
            "tests/pester/JunctionTransactionExecution.Tests.ps1";
            "tests/pester/JunctionStateVerification.Tests.ps1";
            "tests/pester/Issue7JunctionAcceptance.Tests.ps1";
            "tests/pester/Issue7ClosePrep.Tests.ps1"
        )) {
            if (-not $script:Doc14.Contains($requiredTerm)) {
                throw "docs/14 is missing evidence chain term: $requiredTerm"
            }
        }
    }

    It "documents CI boundaries and optional manual smoke evidence" {
        foreach ($requiredTerm in @(
            "does not run real user-directory migration";
            "NAS writes";
            "admin-only Junction mutation";
            "Real VM/admin smoke evidence is optional manual evidence";
            "not a normal PR blocking requirement"
        )) {
            if (-not $script:Doc14.Contains($requiredTerm)) {
                throw "docs/14 is missing CI boundary term: $requiredTerm"
            }
        }
    }

    It "keeps manual closure semantics and avoids automatic issue-closing phrases" {
        foreach ($requiredTerm in @(
            "closed manually by a maintainer";
            "manual closure readiness";
            "ready-for-manual-closure-candidate"
        )) {
            if (-not $script:Doc14.Contains($requiredTerm)) {
                throw "docs/14 is missing manual closure term: $requiredTerm"
            }
        }

        $verbs = @("close", "closed", "closes", "fix", "fixed", "fixes", "resolve", "resolved", "resolves")
        $issueRef = ([string][char]35) + "7"
        foreach ($verb in $verbs) {
            $pattern = "(?i)\b$verb\s+$([regex]::Escape($issueRef))\b"
            if ($script:Doc14 -match $pattern) {
                throw "docs/14 must not contain an automatic issue-closing phrase for issue 7."
            }
        }
    }

    It "keeps active Junction migration code free of robocopy MOVE" {
        $moveSwitch = ([string][char]47) + "MOVE"
        $movePattern = '(?im)^\s*robocopy\b[^\r\n]*\s' + [regex]::Escape($moveSwitch) + '\b'
        foreach ($relativePath in @(
            "scripts\postdeploy\Set-DataJunctions.ps1";
            "scripts\common\Invoke-KitJunctionTransaction.ps1"
        )) {
            $content = Get-Content -LiteralPath (Join-Path $script:RepoRoot $relativePath) -Raw -Encoding UTF8
            if ($content -match $movePattern) {
                throw "Active Junction migration path must not use robocopy MOVE switch: $relativePath"
            }
        }
    }

    It "links docs 13, docs 14, and README entry points" {
        if (-not $script:Doc13.Contains("Status: accepted-pending-manual-closure")) {
            throw "docs/13 status is not aligned with manual closure preparation."
        }

        if (-not $script:Doc13.Contains("14-issue7-close-preparation.md")) {
            throw "docs/13 must link to docs/14."
        }

        if (-not $script:Doc14.Contains("13-issue7-junction-transaction-acceptance.md")) {
            throw "docs/14 must link back to docs/13."
        }

        if (-not $script:Readme.Contains("docs/14-issue7-close-preparation.md")) {
            throw "README is missing the docs/14 close preparation entry."
        }
    }

    It "keeps PR Fast CI wired to close prep tests" {
        if (-not $script:Ci.Contains("tests/pester/Issue7ClosePrep.Tests.ps1")) {
            throw "PR Fast CI is missing Issue7ClosePrep.Tests.ps1."
        }
    }
}
