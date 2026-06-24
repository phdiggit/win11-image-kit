$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
. (Join-Path $RepoRoot "tests\pester\TestHelpers.ps1")

Describe "Issue 6 close preparation package" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")

        function script:Get-Issue6ClosePrepDraft {
            param(
                [string]$Content
            )

            $match = [regex]::Match($Content, '(?s)```markdown\r?\n(?<body>Issue #6 final validation evidence:.*?Conclusion: ready for manual closure after all boxes are checked\.\r?\n)```')
            if (-not $match.Success) {
                throw "Copyable closure comment draft was not found."
            }

            return $match.Groups["body"].Value
        }

        $script:DocPath = @(Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "docs") -Filter "10-issue6-*.md" -ErrorAction SilentlyContinue)[0].FullName
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
        $script:Workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
    }

    It "keeps the close preparation document present" {
        Assert-KitNotNullOrEmpty (Get-Item -LiteralPath $script:DocPath -ErrorAction SilentlyContinue)
    }

    It "documents required close preparation and Full Validate terms" {
        foreach ($term in @(
            "Full Validate";
            "workflow_dispatch";
            "main push";
            "PR Fast CI";
            "PR_READY";
            "Refs #6";
            "manual closure";
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
                throw "Close preparation document is missing required term: $term"
            }
        }
    }

    It "contains a copyable manual closure comment draft" {
        $draft = Get-Issue6ClosePrepDraft -Content $script:Doc

        foreach ($term in @(
            "Issue #6 final validation evidence";
            "PR Fast CI passed";
            "Full Validate passed";
            "workflow_dispatch";
            "manual closure"
        )) {
            if (-not $draft.Contains($term)) {
                throw "Copyable closure draft is missing required term: $term"
            }
        }
    }

    It "names disallowed closing keywords outside the copyable draft" {
        foreach ($closingKeyword in @("Fixes #6"; "Closes #6"; "Resolves #6")) {
            if (-not $script:Doc.Contains($closingKeyword)) {
                throw "Close preparation document should name disallowed closing keyword: $closingKeyword"
            }
        }

        $draft = Get-Issue6ClosePrepDraft -Content $script:Doc
        foreach ($closingKeyword in @("Fixes #6"; "Closes #6"; "Resolves #6")) {
            if ($draft.Contains($closingKeyword)) {
                throw "Copyable closure draft must not contain closing keyword: $closingKeyword"
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

    It "keeps issue 6 fast acceptance tests in PR Fast CI" {
        $fullValidateIndex = $script:Workflow.IndexOf("full-validate:")
        if ($fullValidateIndex -le 0) {
            throw "CI workflow must keep the Full Validate job."
        }

        $fastWorkflow = $script:Workflow.Substring(0, $fullValidateIndex)
        foreach ($fastPath in @(
            "tests/pester/Issue6AcceptanceAudit.Tests.ps1";
            "tests/pester/DryRunAcceptanceBaseline.Tests.ps1";
            "tests/pester/ReportBlockingSummary.Tests.ps1";
            "tests/pester/PackageReportLinks.Tests.ps1";
            "tests/pester/OrchestratorStepResults.Tests.ps1";
            "tests/pester/Issue6ClosePrep.Tests.ps1"
        )) {
            if (-not $fastWorkflow.Contains($fastPath)) {
                throw "PR Fast CI is missing Issue 6 fast acceptance test: $fastPath"
            }
        }

        if ($fastWorkflow -match "Invoke-Pester -Path tests/pester\s+(-CI)?") {
            throw "PR Fast CI must not run the full tests/pester suite."
        }
    }
}
