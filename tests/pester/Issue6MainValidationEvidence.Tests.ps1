$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
. (Join-Path $RepoRoot "tests\pester\TestHelpers.ps1")

Describe "Issue 6 main validation evidence package" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")

        function script:Get-Issue6FinalClosureComment {
            param(
                [string]$Content
            )

            $match = [regex]::Match($Content, '(?s)```markdown\r?\n(?<body>Issue #6 final validation evidence:.*?Conclusion: ready for manual closure after every box above is checked\.\r?\n)```')
            if (-not $match.Success) {
                throw "Copyable final closure comment was not found."
            }

            return $match.Groups["body"].Value
        }

        $script:DocPath = Join-Path $script:RepoRoot "docs\11-issue6-main-validation-evidence.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
        $script:Workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
    }

    It "keeps the main validation evidence document present" {
        Assert-KitNotNullOrEmpty (Get-Item -LiteralPath $script:DocPath -ErrorAction SilentlyContinue)
    }

    It "documents final validation evidence terms" {
        foreach ($term in @(
            "Issue #6";
            "validation evidence";
            "PR Fast CI";
            "Full Validate";
            "workflow_dispatch";
            "main push";
            "childReportSummary";
            "hasBlockingFailure";
            "exitCode";
            "StepResult";
            "package";
            "service";
            "junction";
            "defender";
            "appx";
            "userExperience"
        )) {
            if (-not $script:Doc.Contains($term)) {
                throw "Main validation evidence document is missing required term: $term"
            }
        }

        if (-not (($script:Doc.Contains("pending-main-full-validate")) -or ($script:Doc.Contains("ready-for-manual-closure")))) {
            throw "Main validation evidence document must include a closure status."
        }
    }

    It "contains evidence fields for PR Fast CI and main Full Validate" {
        foreach ($term in @(
            "Final PR:";
            "Head SHA:";
            "Workflow run:";
            "Validate result:";
            "Full Validate on PR:";
            "Evidence captured by:";
            "Trigger source: main push / workflow_dispatch";
            "Main SHA:";
            "Full Validate result:";
            "Notes:"
        )) {
            if (-not $script:Doc.Contains($term)) {
                throw "Main validation evidence document is missing evidence field: $term"
            }
        }
    }

    It "contains a copyable final manual closure comment" {
        $comment = Get-Issue6FinalClosureComment -Content $script:Doc

        foreach ($term in @(
            "Issue #6 final validation evidence";
            "PR Fast CI passed";
            "Full Validate passed";
            "workflow_dispatch";
            "childReportSummary";
            "No blocking follow-up PR remains open";
            "manual closure"
        )) {
            if (-not $comment.Contains($term)) {
                throw "Copyable final closure comment is missing required term: $term"
            }
        }
    }

    It "keeps the copyable final comment free of automatic closing keywords" {
        $comment = Get-Issue6FinalClosureComment -Content $script:Doc
        foreach ($closingKeyword in @("Fixes #6"; "Closes #6"; "Resolves #6")) {
            if ($comment.Contains($closingKeyword)) {
                throw "Copyable final closure comment must not contain closing keyword: $closingKeyword"
            }
        }
    }

    It "documents staged PR issue reference semantics without auto closing issue 6" {
        foreach ($term in @(
            "Refs #6";
            "PR body uses";
            "does not automatically close #6"
        )) {
            if (-not $script:Doc.Contains($term)) {
                throw "Main validation evidence document is missing staged PR term: $term"
            }
        }
    }

    It "keeps Full Validate on main and workflow_dispatch while skipped for pull_request" {
        foreach ($term in @(
            "workflow_dispatch:";
            "push:";
            "branches:";
            "- main";
            "name: Full Validate";
            "if: github.event_name != 'pull_request'"
        )) {
            if (-not $script:Workflow.Contains($term)) {
                throw "CI workflow is missing Full Validate trigger or PR skip term: $term"
            }
        }
    }

    It "keeps the final validation evidence test in PR Fast CI" {
        $fullValidateIndex = $script:Workflow.IndexOf("full-validate:")
        if ($fullValidateIndex -le 0) {
            throw "CI workflow must keep the Full Validate job."
        }

        $fastWorkflow = $script:Workflow.Substring(0, $fullValidateIndex)
        foreach ($fastPath in @(
            "tests/pester/Issue6AcceptanceAudit.Tests.ps1";
            "tests/pester/Issue6ClosePrep.Tests.ps1";
            "tests/pester/DryRunAcceptanceBaseline.Tests.ps1";
            "tests/pester/ReportBlockingSummary.Tests.ps1";
            "tests/pester/PackageReportLinks.Tests.ps1";
            "tests/pester/OrchestratorStepResults.Tests.ps1";
            "tests/pester/Issue6MainValidationEvidence.Tests.ps1"
        )) {
            if (-not $fastWorkflow.Contains($fastPath)) {
                throw "PR Fast CI is missing Issue 6 final validation evidence test: $fastPath"
            }
        }

        if ($fastWorkflow -match "Invoke-Pester -Path tests/pester\s+(-CI)?") {
            throw "PR Fast CI must not run the full tests/pester suite."
        }
    }
}
