Describe "Issue 18 main validation evidence scaffold" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\63-issue18-main-validation-evidence.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
    }

    It "keeps docs/63 pending and rejects substitute evidence" {
        Assert-KitMatch $script:Doc 'Status:\s*`pending-main-validation`'
        Assert-KitMatch $script:Doc '\| Trigger source \| pending \|'
        Assert-KitMatch $script:Doc '\| Main SHA \| pending \|'
        Assert-KitMatch $script:Doc '\| Workflow run \| pending \|'
        Assert-KitMatch $script:Doc '\| Full Validate job \| pending \|'
        Assert-KitMatch $script:Doc '\| Result \| pending \|'
        Assert-KitMatch $script:Doc '\| PR Fast CI substitute allowed \| false \|'
        Assert-KitMatch $script:Doc '\| Fixture substitute allowed \| false \|'
        Assert-KitMatch $script:Doc '\| Handler report substitute allowed \| false \|'
        Assert-KitMatch $script:Doc '\| Manual checklist substitute allowed \| false \|'
        Assert-KitNotMatch $script:Doc "(?i)\b(fixes|closes|resolves)\s+#18\b"
    }

    It "records the post-95 failed run as blocked evidence only" {
        Assert-KitMatch $script:Doc "## Blocked Evidence Attempt"
        Assert-KitMatch $script:Doc "actions/runs/28284104911"
        Assert-KitMatch $script:Doc "bcda2cfd9598b6f445a186e03bc3a849506c9a92"
        Assert-KitMatch $script:Doc "actions/runs/28284104911/job/83804976569"
        Assert-KitMatch $script:Doc "Run Pester tests with PowerShell 7"
        Assert-KitMatch $script:Doc "30-minute step timeout"
        Assert-KitMatch $script:Doc "non-data object adapter properties"
        Assert-KitMatch $script:Doc "failed run is recorded only as blocked evidence"
        Assert-KitMatch $script:Doc "not used as ready evidence"
    }

    It "keeps the post-94 failed run as previous blocked evidence only" {
        Assert-KitMatch $script:Doc "## Previous Blocked Evidence Attempt"
        Assert-KitMatch $script:Doc "actions/runs/28281913558"
        Assert-KitMatch $script:Doc "c634998b4d050601f72183f3114d463639518b9b"
        Assert-KitMatch $script:Doc "Run Pester tests with PowerShell 7"
        Assert-KitMatch $script:Doc "conclusion ``failure``"
        Assert-KitMatch $script:Doc "historical blocked evidence only"
        Assert-KitMatch $script:Doc "not used as ready evidence"
    }

    It "keeps the PowerShell 7 full Pester step bounded" {
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
        Assert-KitMatch $workflow "Run Pester tests with PowerShell 7"
        Assert-KitMatch $workflow "(?s)- name: Run Pester tests with PowerShell 7\s+timeout-minutes: 30\s+shell: pwsh"
    }

    It "keeps UX restore report evidence pending and report-only" {
        foreach ($field in @(
            "Report status",
            "failedCount",
            "blockedCount",
            "unsupportedCapabilityCount",
            "scopeMismatchCount",
            "templateMetadataFailureCount",
            "verificationFailureCount",
            "requestedApplyBlockedCount",
            "handlerExecutionCount"
        )) {
            Assert-KitMatch $script:Doc ('\| {0} \| pending \|' -f [regex]::Escape($field))
        }

        Assert-KitMatch $script:Doc '\| trueExecution \| false \|'
        Assert-KitMatch $script:Doc '\| whatIf \| true \|'
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

        Assert-KitMatch $script:Doc '\| Current readiness \| pending-main-validation \|'
        Assert-KitMatch $script:Doc '\| Required next evidence \| main/workflow validation \|'
    }
}
