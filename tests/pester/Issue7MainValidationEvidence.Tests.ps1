$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Issue 7 main validation evidence" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")

        $script:Doc15Path = Join-Path $script:RepoRoot "docs\15-issue7-main-validation-evidence.md"
        $script:Doc14Path = Join-Path $script:RepoRoot "docs\14-issue7-close-preparation.md"
        $script:ReadmePath = Join-Path $script:RepoRoot "README.md"
        $script:CiPath = Join-Path $script:RepoRoot ".github\workflows\ci.yml"

        $script:Doc15 = Get-Content -LiteralPath $script:Doc15Path -Raw -Encoding UTF8
        $script:Doc14 = Get-Content -LiteralPath $script:Doc14Path -Raw -Encoding UTF8
        $script:Readme = Get-Content -LiteralPath $script:ReadmePath -Raw -Encoding UTF8
        $script:Ci = Get-Content -LiteralPath $script:CiPath -Raw -Encoding UTF8
    }

    It "keeps docs 15 present with an allowed evidence status" {
        Assert-KitNotNullOrEmpty (Get-Item -LiteralPath $script:Doc15Path -ErrorAction SilentlyContinue)
        $statusLine = @($script:Doc15 -split "`r?`n" | Where-Object { $_ -like "Status:*" })[0]
        Assert-KitNotNullOrEmpty $statusLine
        $status = ($statusLine -replace "^Status:\s*", "").Trim()
        if ($status -notin @("pending-main-validation", "ready-for-manual-closure")) {
            throw "docs/15 has unsupported status: $status"
        }
    }

    It "keeps the evidence chain complete" {
        foreach ($requiredTerm in @(
            "docs/13-issue7-junction-transaction-acceptance.md";
            "docs/14-issue7-close-preparation.md";
            "docs/15-issue7-main-validation-evidence.md";
            "tests/pester/JunctionTransactionPreflight.Tests.ps1";
            "tests/pester/JunctionTransactionExecution.Tests.ps1";
            "tests/pester/JunctionStateVerification.Tests.ps1";
            "tests/pester/Issue7JunctionAcceptance.Tests.ps1";
            "tests/pester/Issue7ClosePrep.Tests.ps1";
            "tests/pester/Issue7MainValidationEvidence.Tests.ps1"
        )) {
            if (-not $script:Doc15.Contains($requiredTerm)) {
                throw "docs/15 is missing evidence chain term: $requiredTerm"
            }
        }
    }

    It "distinguishes PR Fast CI from main validation evidence" {
        foreach ($requiredTerm in @(
            "PR Fast CI is not a substitute for main validation evidence";
            "main` push Windows CI / Full Validate";
            "workflow_dispatch";
            "Maintainer-provided real VM/admin smoke evidence"
        )) {
            if (-not $script:Doc15.Contains($requiredTerm)) {
                throw "docs/15 is missing evidence boundary term: $requiredTerm"
            }
        }
    }

    It "does not present pending main evidence as ready" {
        $statusLine = @($script:Doc15 -split "`r?`n" | Where-Object { $_ -like "Status:*" })[0]
        $status = ($statusLine -replace "^Status:\s*", "").Trim()
        $hasPendingMainEvidence = $script:Doc15.Contains("Main SHA: pending") -or
            $script:Doc15.Contains("Workflow run: pending") -or
            $script:Doc15.Contains("Result: pending")

        if ($hasPendingMainEvidence -and $status -eq "ready-for-manual-closure") {
            throw "docs/15 must not be ready when main evidence is still pending."
        }

        if ($status -eq "ready-for-manual-closure") {
            foreach ($forbiddenPending in @("Trigger source: pending"; "Main SHA: pending"; "Workflow run: pending"; "Result: pending")) {
                if ($script:Doc15.Contains($forbiddenPending)) {
                    throw "ready docs/15 status must not contain pending main evidence: $forbiddenPending"
                }
            }

            if (-not ($script:Doc15.Contains("Result: success") -and ($script:Doc15.Contains("Trigger source: main push") -or $script:Doc15.Contains("Trigger source: workflow_dispatch")))) {
                throw "ready docs/15 status requires success result and a main push or workflow_dispatch trigger."
            }
        }
    }

    It "avoids automatic issue-closing phrases for issue 7" {
        $verbs = @("close", "closed", "closes", "fix", "fixed", "fixes", "resolve", "resolved", "resolves")
        $issueRef = ([string][char]35) + "7"
        foreach ($verb in $verbs) {
            $pattern = "(?i)\b$verb\s+$([regex]::Escape($issueRef))\b"
            if ($script:Doc15 -match $pattern) {
                throw "docs/15 must not contain an automatic issue-closing phrase for issue 7."
            }
        }
    }

    It "links README, docs 14, and docs 15" {
        if (-not $script:Readme.Contains("docs/15-issue7-main-validation-evidence.md")) {
            throw "README is missing the docs/15 main validation evidence entry."
        }

        if (-not $script:Doc14.Contains("15-issue7-main-validation-evidence.md")) {
            throw "docs/14 must link to docs/15."
        }

        if (-not $script:Doc15.Contains("docs/14-issue7-close-preparation.md")) {
            throw "docs/15 must reference docs/14."
        }
    }

    It "keeps PR Fast CI wired to main validation evidence tests" {
        if (-not $script:Ci.Contains("tests/pester/Issue7MainValidationEvidence.Tests.ps1")) {
            throw "PR Fast CI is missing Issue7MainValidationEvidence.Tests.ps1."
        }
    }
}
