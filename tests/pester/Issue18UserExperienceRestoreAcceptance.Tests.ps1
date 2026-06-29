Describe "Issue 18 user experience restore acceptance scaffold" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "keeps acceptance in the current report-only stage" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-18\59-issue18-user-experience-restore-acceptance.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc 'Status: `accepted-ready-for-manual-closure`'
        Assert-KitMatch $doc "post-PR #96 main/workflow success evidence"
        Assert-KitMatch $doc "PR Fast CI is not main/workflow evidence"
        Assert-KitMatch $doc "Fixture/report-only validation is not real UX restore evidence"
        Assert-KitMatch $doc "handler reports are not real UX restore evidence"
        Assert-KitMatch $doc "manual checklist rows are not success evidence"
        Assert-KitMatch $doc "does not confirm that user configuration has taken effect"
    }

    It "keeps Quality Gates and Build Lock wired for Issue 18" {
        $qualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $gateIds = @($qualityGates.gates | ForEach-Object { [string]$_.id })
        $lockedPaths = @($buildLock.entries | ForEach-Object { [string]$_.path })

        foreach ($id in @(
            "user-experience-restore",
            "issue18-intake",
            "issue18-acceptance",
            "user-experience-default-apps-plan",
            "user-experience-start-menu-plan",
            "user-experience-capability-matrix",
            "user-experience-template-metadata",
            "user-experience-scope-semantics",
            "user-experience-verification-plan",
            "issue18-capability-matrix",
            "issue18-close-prep",
            "issue18-main-evidence-scaffold"
        )) {
            Assert-KitEqual ($gateIds -contains $id) $true
        }

        foreach ($path in @(
            "docs/archive/completed-roadmap/issue-18/58-issue18-user-experience-restore-intake.md",
            "docs/archive/completed-roadmap/issue-18/59-issue18-user-experience-restore-acceptance.md",
            "docs/archive/completed-roadmap/issue-18/60-issue18-user-experience-capability-matrix.md",
            "docs/archive/completed-roadmap/issue-18/61-issue18-restore-handler-integration.md",
            "docs/archive/completed-roadmap/issue-18/62-issue18-close-preparation.md",
            "docs/archive/completed-roadmap/issue-18/63-issue18-main-validation-evidence.md",
            "manifests/user-experience-restore.json",
            "scripts/validate/Test-UserExperienceRestore.ps1",
            "tests/pester/Issue18ClosePrep.Tests.ps1",
            "tests/pester/Issue18MainValidationEvidence.Tests.ps1",
            "tests/pester/UserExperienceCapabilityMatrix.Tests.ps1",
            "tests/pester/UserExperienceVerificationPlan.Tests.ps1"
        )) {
            Assert-KitEqual ($lockedPaths -contains $path) $true
        }

        Assert-KitEqual ($lockedPaths -contains "manifests/paths.local.json") $false
    }
}
