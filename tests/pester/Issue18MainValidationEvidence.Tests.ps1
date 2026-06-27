Describe "Issue 18 main validation evidence scaffold" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\63-issue18-main-validation-evidence.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
    }

    It "records post-96 main workflow success evidence" {
        Assert-KitMatch $script:Doc 'Status:\s*`ready-for-manual-closure`'
        Assert-KitMatch $script:Doc '\| Trigger source \| main push \|'
        Assert-KitMatch $script:Doc '\| Main SHA \| [0-9a-f]{40} \|'
        Assert-KitMatch $script:Doc '\| Workflow run \| https://github\.com/phdiggit/win11-image-kit/actions/runs/28285895794 \|'
        Assert-KitMatch $script:Doc '\| Full Validate job \| https://github\.com/phdiggit/win11-image-kit/actions/runs/28285895794/job/83809686636 \|'
        Assert-KitMatch $script:Doc '\| Result \| success \|'
        Assert-KitMatch $script:Doc "post-PR #96 Full Validate completed successfully"
        Assert-KitMatch $script:Doc "git log -1 --format=%H"
        Assert-KitMatch $script:Doc "eac9e5b7e68498480fec803a46466c13936ad399"
        Assert-KitMatch $script:Doc '\| PR Fast CI substitute allowed \| false \|'
        Assert-KitMatch $script:Doc '\| Fixture substitute allowed \| false \|'
        Assert-KitMatch $script:Doc '\| Handler report substitute allowed \| false \|'
        Assert-KitMatch $script:Doc '\| Manual checklist substitute allowed \| false \|'
        Assert-KitNotMatch $script:Doc "(?i)\b(fixes|closes|resolves)\s+#18\b"
    }

    It "keeps previous failed runs as historical blockers only" {
        Assert-KitMatch $script:Doc "## Previous Blocked Evidence Attempts"
        Assert-KitMatch $script:Doc "actions/runs/28284104911"
        Assert-KitMatch $script:Doc "bcda2cfd9598b6f445a186e03bc3a849506c9a92"
        Assert-KitMatch $script:Doc "actions/runs/28284104911/job/83804976569"
        Assert-KitMatch $script:Doc "Run Pester tests with PowerShell 7"
        Assert-KitMatch $script:Doc "30-minute step timeout"
        Assert-KitMatch $script:Doc "non-data object adapter properties"
        Assert-KitMatch $script:Doc "failed run is recorded only as blocked evidence"
        Assert-KitMatch $script:Doc "actions/runs/28281913558"
        Assert-KitMatch $script:Doc "c634998b4d050601f72183f3114d463639518b9b"
        Assert-KitMatch $script:Doc "superseded for readiness by the post-PR #96"
        Assert-KitMatch $script:Doc "historical blocked evidence only"
        Assert-KitMatch $script:Doc "not used as ready evidence"
    }

    It "keeps the PowerShell 7 full Pester step bounded" {
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
        Assert-KitMatch $workflow "Run Pester tests with PowerShell 7"
        Assert-KitMatch $workflow "(?s)- name: Run Pester tests with PowerShell 7\s+timeout-minutes: 30\s+shell: pwsh"
    }

    It "records report-only UX and handler evidence without mutation claims" {
        foreach ($field in @(
            "failedCount",
            "blockedCount",
            "unsupportedCapabilityCount",
            "scopeMismatchCount",
            "templateMetadataFailureCount",
            "verificationFailureCount",
            "requestedApplyBlockedCount",
            "handlerExecutionCount",
            "registryWriteCount",
            "profileWriteCount",
            "defaultAppMutationCount",
            "startMenuMutationCount",
            "taskbarMutationCount"
        )) {
            Assert-KitMatch $script:Doc ('\| {0} \| 0 \|' -f [regex]::Escape($field))
        }

        Assert-KitMatch $script:Doc '\| Report status \| passed \|'
        Assert-KitMatch $script:Doc '\| Restore-UserExperience report status \| planned \|'
        Assert-KitMatch $script:Doc '\| plannedHandlerCount \| 2 \|'
        Assert-KitMatch $script:Doc '\| manualChecklistCount \| 3 \|'
        Assert-KitMatch $script:Doc '\| trueExecution \| false \|'
        Assert-KitMatch $script:Doc '\| whatIf \| true \|'
        Assert-KitMatch $script:Doc "not real UX restore evidence"
    }

    It "keeps real UX restore evidence not-run or not-provided" {
        foreach ($field in @(
            "Registry write | not-run",
            "Profile write | not-run",
            "Default user hive write | not-run",
            "Current user default-app mutation | not-run",
            "Default app import | not-run",
            "Start menu import | not-run",
            "Taskbar mutation | not-run",
            "AppX query/mutation as evidence | not-run",
            "Real user configuration verification | not-provided",
            "Admin/VM smoke | not-provided"
        )) {
            Assert-KitMatch $script:Doc ([regex]::Escape($field))
        }

        Assert-KitMatch $script:Doc '\| Current readiness \| ready-for-manual-closure \|'
        Assert-KitMatch $script:Doc '\| Required next evidence \| satisfied by post-PR #96 main/workflow Full Validate success \|'
    }
}
