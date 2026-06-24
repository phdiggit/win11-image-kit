$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
. (Join-Path $RepoRoot "tests\pester\TestHelpers.ps1")

Describe "Issue 6 acceptance audit closeout" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")

        $script:AuditDocPath = @(Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "docs") -Filter "09-issue6-*.md" -ErrorAction SilentlyContinue)[0].FullName
        $script:AuditDoc = Get-Content -LiteralPath $script:AuditDocPath -Raw -Encoding UTF8
        $script:Workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
        $script:WorkflowDoc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\codex-workflow.md") -Raw -Encoding UTF8
        $script:TaskCardTemplate = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\codex-task-card-template.md") -Raw -Encoding UTF8
        $script:ChildReportHelper = Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\common\Get-KitChildReportSummary.ps1") -Raw -Encoding UTF8
    }

    It "keeps the final audit checklist and required issue 6 terms visible" {
        Assert-KitNotNullOrEmpty (Get-Item -LiteralPath $script:AuditDocPath -ErrorAction SilentlyContinue)

        foreach ($term in @(
            "StepResult";
            "package";
            "service";
            "junction";
            "defender";
            "appx";
            "userExperience";
            "childReportSummary";
            "failedRequired";
            "failedOptional";
            "PR_READY";
            "Fast CI";
            "Full Validate";
            "Refs #6"
        )) {
            if (-not $script:AuditDoc.Contains($term)) {
                throw "Issue 6 audit documentation is missing required term: $term"
            }
        }
    }

    It "documents manual closure checks without using issue closing keywords" {
        foreach ($term in @(
            "manual closure gate";
            "missing report";
            "parse failed";
            "hasBlockingFailure";
            "exitCode";
            "Full Validate"
        )) {
            if (-not $script:AuditDoc.Contains($term)) {
                throw "Issue 6 manual closure checklist is missing term: $term"
            }
        }

        foreach ($closingKeyword in @("Fixes #6"; "Closes #6"; "Resolves #6")) {
            if (-not $script:AuditDoc.Contains($closingKeyword)) {
                throw "Issue 6 audit document should explicitly name disallowed closing keyword: $closingKeyword"
            }
        }
    }

    It "keeps the newest audit test in PR Fast CI without turning fast CI into full Pester" {
        $fullValidateIndex = $script:Workflow.IndexOf("full-validate:")
        if ($fullValidateIndex -le 0) {
            throw "Workflow must keep the Full Validate job."
        }
        $fastWorkflow = $script:Workflow.Substring(0, $fullValidateIndex)

        foreach ($fastPath in @(
            "tests/pester/OrchestratorStepResults.Tests.ps1";
            "tests/pester/PackageReportLinks.Tests.ps1";
            "tests/pester/ReportBlockingSummary.Tests.ps1";
            "tests/pester/DryRunAcceptanceBaseline.Tests.ps1";
            "tests/pester/ServiceStateVerification.Tests.ps1";
            "tests/pester/JunctionStateVerification.Tests.ps1";
            "tests/pester/DefenderAppxStateVerification.Tests.ps1";
            "tests/pester/UserExperienceStateVerification.Tests.ps1";
            "tests/pester/Issue6AcceptanceAudit.Tests.ps1"
        )) {
            if (-not $fastWorkflow.Contains($fastPath)) {
                throw "PR Fast CI is missing expected Pester path: $fastPath"
            }
        }

        if ($fastWorkflow -match "Invoke-Pester -Path tests/pester\s+(-CI)?") {
            throw "PR Fast CI must not run the full tests/pester suite."
        }

        if (-not ($script:Workflow -match "name:\s+Full Validate")) {
            throw "Workflow must keep the Full Validate job."
        }
    }

    It "keeps task workflow documentation on Refs #6 semantics" {
        foreach ($doc in @($script:WorkflowDoc, $script:TaskCardTemplate)) {
            if (-not $doc.Contains("Refs #<issue>")) {
                throw "Task workflow docs must keep staged PR issue reference guidance."
            }
        }
    }

    It "keeps child report summary able to represent all issue 6 child domains" {
        foreach ($term in @(
            "PackageReports";
            "ServiceReports";
            "JunctionReports";
            "DefenderReports";
            "AppxReports";
            "UserExperienceReports";
            "failedRequired";
            "failedOptional";
            "hasBlockingFailure";
            "exitCode"
        )) {
            if (-not $script:ChildReportHelper.Contains($term)) {
                throw "Child report helper is missing expected Issue 6 term: $term"
            }
        }
    }
}
