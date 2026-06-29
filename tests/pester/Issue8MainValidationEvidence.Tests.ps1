$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Issue 8 main validation evidence" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")

        $script:Doc19Path = Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-8\19-issue8-main-validation-evidence.md"
        $script:Doc18Path = Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-8\18-issue8-close-preparation.md"
        $script:ReadmePath = Join-Path $script:RepoRoot "README.md"
        $script:CiPath = Join-Path $script:RepoRoot ".github\workflows\ci.yml"

        $script:Doc19 = Get-Content -LiteralPath $script:Doc19Path -Raw -Encoding UTF8
        $script:Doc18 = Get-Content -LiteralPath $script:Doc18Path -Raw -Encoding UTF8
        $script:Readme = Get-Content -LiteralPath $script:ReadmePath -Raw -Encoding UTF8
        $script:Ci = Get-Content -LiteralPath $script:CiPath -Raw -Encoding UTF8
    }

    It "keeps docs 19 present with an allowed evidence status" {
        Assert-KitNotNullOrEmpty (Get-Item -LiteralPath $script:Doc19Path -ErrorAction SilentlyContinue)
        $statusLine = @($script:Doc19 -split "`r?`n" | Where-Object { $_ -like "Status:*" })[0]
        Assert-KitNotNullOrEmpty $statusLine
        $status = ($statusLine -replace "^Status:\s*", "").Trim()
        if ($status -notin @("pending-main-validation", "ready-for-manual-closure")) {
            throw "docs/19 has unsupported status: $status"
        }
    }

    It "keeps the evidence chain complete" {
        foreach ($requiredTerm in @(
            "docs/archive/completed-roadmap/issue-8/16-issue8-defender-exclusion-policy.md";
            "docs/archive/completed-roadmap/issue-8/17-issue8-defender-exclusion-acceptance.md";
            "docs/archive/completed-roadmap/issue-8/18-issue8-close-preparation.md";
            "docs/archive/completed-roadmap/issue-8/19-issue8-main-validation-evidence.md";
            "tests/pester/DefenderExclusionPolicy.Tests.ps1";
            "tests/pester/DefenderExclusionState.Tests.ps1";
            "tests/pester/DefenderExclusionPostDeploy.Tests.ps1";
            "tests/pester/Issue8DefenderAcceptance.Tests.ps1";
            "tests/pester/Issue8ClosePrep.Tests.ps1";
            "tests/pester/Issue8MainValidationEvidence.Tests.ps1"
        )) {
            if (-not $script:Doc19.Contains($requiredTerm)) {
                throw "docs/19 is missing evidence chain term: $requiredTerm"
            }
        }
    }

    It "distinguishes PR Fast CI from main validation evidence" {
        foreach ($requiredTerm in @(
            "PR Fast CI is not a substitute for main validation evidence";
            "main push Windows CI / Full Validate";
            "workflow_dispatch";
            "Maintainer-provided real VM/admin smoke evidence"
        )) {
            if (-not $script:Doc19.Contains($requiredTerm)) {
                throw "docs/19 is missing evidence boundary term: $requiredTerm"
            }
        }
    }

    It "does not present pending main evidence as ready" {
        $statusLine = @($script:Doc19 -split "`r?`n" | Where-Object { $_ -like "Status:*" })[0]
        $status = ($statusLine -replace "^Status:\s*", "").Trim()
        $hasPendingMainEvidence = $script:Doc19.Contains("Main SHA: pending") -or
            $script:Doc19.Contains("Workflow run: pending") -or
            $script:Doc19.Contains("Result: pending")

        if ($hasPendingMainEvidence -and $status -eq "ready-for-manual-closure") {
            throw "docs/19 must not be ready when main evidence is still pending."
        }

        if ($status -eq "pending-main-validation") {
            if (-not $script:Doc19.Contains("Current readiness: pending-main-validation")) {
                throw "pending docs/19 status must keep matching current readiness."
            }

            if ($script:Doc19.Contains("Result: success")) {
                throw "pending docs/19 status must not contain success main validation evidence."
            }
        }

        if ($status -eq "ready-for-manual-closure") {
            foreach ($forbiddenPending in @("Trigger source: pending"; "Main SHA: pending"; "Workflow run: pending"; "Result: pending")) {
                if ($script:Doc19.Contains($forbiddenPending)) {
                    throw "ready docs/19 status must not contain pending main evidence: $forbiddenPending"
                }
            }

            if (-not ($script:Doc19.Contains("Trigger source: main push") -or $script:Doc19.Contains("Trigger source: workflow_dispatch"))) {
                throw "ready docs/19 status requires a main push or workflow_dispatch trigger."
            }

            if (-not ($script:Doc19 -match "(?m)^- Main SHA: [0-9a-f]{40}\r?$")) {
                throw "ready docs/19 status requires a full main commit SHA."
            }

            if (-not ($script:Doc19 -match "(?m)^- Workflow run: https://github\.com/phdiggit/win11-image-kit/actions/runs/[0-9]+\r?$")) {
                throw "ready docs/19 status requires an actions run URL."
            }

            if (-not $script:Doc19.Contains("Result: success")) {
                throw "ready docs/19 status requires success result."
            }

            if (-not $script:Doc19.Contains("Current readiness: ready-for-manual-closure")) {
                throw "ready docs/19 status requires matching manual closure readiness."
            }

            if (-not $script:Doc19.Contains("manually close Issue #8")) {
                throw "ready docs/19 status must keep maintainer manual closure semantics."
            }

            if (-not $script:Doc19.Contains("PR Fast CI is not a substitute for this evidence")) {
                throw "ready docs/19 status must continue distinguishing PR Fast CI from main validation evidence."
            }

            if (-not $script:Doc19.Contains("Real VM/admin smoke: optional / not-run")) {
                throw "ready docs/19 status must keep real VM/admin smoke optional when it was not run."
            }
        }
    }

    It "keeps real VM smoke optional and not-run by default" {
        foreach ($requiredTerm in @(
            "Environment: not-run";
            "Operator: not-provided";
            "Result: not-run";
            "Real VM/admin smoke: optional / not-run"
        )) {
            if (-not $script:Doc19.Contains($requiredTerm)) {
                throw "docs/19 is missing default real VM/admin smoke term: $requiredTerm"
            }
        }
    }

    It "avoids automatic issue-closing phrases for issue 8" {
        $verbs = @("close", "closed", "closes", "fix", "fixed", "fixes", "resolve", "resolved", "resolves")
        $issueRef = ([string][char]35) + "8"
        foreach ($verb in $verbs) {
            $pattern = "(?i)\b$verb\s+$([regex]::Escape($issueRef))\b"
            if ($script:Doc19 -match $pattern) {
                throw "docs/19 must not contain an automatic issue-closing phrase for issue 8."
            }
        }
    }

    It "links README, docs 18, and docs 19" {
        if (-not $script:Readme.Contains("docs/archive/completed-roadmap/issue-8/19-issue8-main-validation-evidence.md")) {
            throw "README is missing docs/19 main validation evidence entry."
        }

        if (-not $script:Doc18.Contains("19-issue8-main-validation-evidence.md")) {
            throw "docs/18 must link to docs/19."
        }

        if (-not $script:Doc19.Contains("docs/archive/completed-roadmap/issue-8/18-issue8-close-preparation.md")) {
            throw "docs/19 must reference docs/18."
        }
    }

    It "keeps PR Fast CI wired to main validation evidence tests" {
        if (-not $script:Ci.Contains("tests/pester/Issue8MainValidationEvidence.Tests.ps1")) {
            throw "PR Fast CI is missing Issue8MainValidationEvidence.Tests.ps1."
        }
    }
}
