$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Issue 8 close preparation evidence" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")

        $script:Doc18Path = Join-Path $script:RepoRoot "docs\18-issue8-close-preparation.md"
        $script:Doc17Path = Join-Path $script:RepoRoot "docs\17-issue8-defender-exclusion-acceptance.md"
        $script:ReadmePath = Join-Path $script:RepoRoot "README.md"
        $script:CiPath = Join-Path $script:RepoRoot ".github\workflows\ci.yml"

        $script:Doc18 = Get-Content -LiteralPath $script:Doc18Path -Raw -Encoding UTF8
        $script:Doc17 = Get-Content -LiteralPath $script:Doc17Path -Raw -Encoding UTF8
        $script:Readme = Get-Content -LiteralPath $script:ReadmePath -Raw -Encoding UTF8
        $script:Ci = Get-Content -LiteralPath $script:CiPath -Raw -Encoding UTF8
    }

    It "keeps the close preparation document present and in candidate state" {
        Assert-KitNotNullOrEmpty (Get-Item -LiteralPath $script:Doc18Path -ErrorAction SilentlyContinue)
        $statusLine = @($script:Doc18 -split "`r?`n" | Where-Object { $_ -like "Status:*" })[0]
        Assert-KitNotNullOrEmpty $statusLine
        $status = ($statusLine -replace "^Status:\s*", "").Trim()
        Assert-KitEqual $status "ready-for-manual-closure-candidate"

        foreach ($requiredHeading in @(
            "## Final Scope";
            "## Evidence Chain";
            "## Validation Policy";
            "## Manual Closure Checklist";
            "## Optional Manual Validation Evidence";
            "## Closure Note Draft"
        )) {
            if (-not $script:Doc18.Contains($requiredHeading)) {
                throw "docs/18 is missing heading: $requiredHeading"
            }
        }
    }

    It "keeps the Issue 8 evidence chain complete" {
        foreach ($requiredTerm in @(
            "docs/16-issue8-defender-exclusion-policy.md";
            "docs/17-issue8-defender-exclusion-acceptance.md";
            "docs/18-issue8-close-preparation.md";
            "docs/19-issue8-main-validation-evidence.md";
            "tests/pester/DefenderExclusionPolicy.Tests.ps1";
            "tests/pester/DefenderExclusionState.Tests.ps1";
            "tests/pester/DefenderExclusionPostDeploy.Tests.ps1";
            "tests/pester/Issue8DefenderAcceptance.Tests.ps1";
            "tests/pester/Issue8ClosePrep.Tests.ps1";
            "tests/pester/Issue8MainValidationEvidence.Tests.ps1"
        )) {
            if (-not $script:Doc18.Contains($requiredTerm)) {
                throw "docs/18 is missing evidence chain term: $requiredTerm"
            }
        }
    }

    It "documents CI boundaries and optional manual smoke evidence" {
        foreach ($requiredTerm in @(
            "must not perform real Defender mutation";
            "Real VM/admin smoke evidence is optional manual evidence";
            "not a normal PR blocking requirement";
            "recorded in [Issue #8 Main Validation Evidence]";
            "candidate rather than a final ready state"
        )) {
            if (-not $script:Doc18.Contains($requiredTerm)) {
                throw "docs/18 is missing CI boundary term: $requiredTerm"
            }
        }
    }

    It "keeps manual closure semantics and avoids automatic issue-closing phrases" {
        foreach ($requiredTerm in @(
            "closed manually by a maintainer";
            "manual closure candidate";
            "ready-for-manual-closure-candidate"
        )) {
            if (-not $script:Doc18.Contains($requiredTerm)) {
                throw "docs/18 is missing manual closure term: $requiredTerm"
            }
        }

        $verbs = @("close", "closed", "closes", "fix", "fixed", "fixes", "resolve", "resolved", "resolves")
        $issueRef = ([string][char]35) + "8"
        foreach ($verb in $verbs) {
            $pattern = "(?i)\b$verb\s+$([regex]::Escape($issueRef))\b"
            if ($script:Doc18 -match $pattern) {
                throw "docs/18 must not contain an automatic issue-closing phrase for issue 8."
            }
        }
    }

    It "links README, docs 17, docs 18, and docs 19 entry points" {
        if (-not $script:Readme.Contains("docs/18-issue8-close-preparation.md")) {
            throw "README is missing docs/18 entry."
        }

        if (-not $script:Readme.Contains("docs/19-issue8-main-validation-evidence.md")) {
            throw "README is missing docs/19 entry."
        }

        if (-not $script:Doc17.Contains("Status: accepted-pending-manual-closure")) {
            throw "docs/17 status is not aligned with manual closure preparation."
        }

        if (-not $script:Doc17.Contains("18-issue8-close-preparation.md")) {
            throw "docs/17 must link to docs/18."
        }

        if (-not $script:Doc18.Contains("17-issue8-defender-exclusion-acceptance.md")) {
            throw "docs/18 must link back to docs/17."
        }

        if (-not $script:Doc18.Contains("19-issue8-main-validation-evidence.md")) {
            throw "docs/18 must link to docs/19."
        }
    }

    It "keeps PR Fast CI wired to close prep tests" {
        if (-not $script:Ci.Contains("tests/pester/Issue8ClosePrep.Tests.ps1")) {
            throw "PR Fast CI is missing Issue8ClosePrep.Tests.ps1."
        }

        Assert-KitNotMatch $script:Ci "Add-MpPreference"
        Assert-KitNotMatch $script:Ci "Remove-MpPreference"
        Assert-KitNotMatch $script:Ci "Set-MpPreference"
    }
}
