Describe "Issue 17 main validation evidence scaffold" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\57-issue17-main-validation-evidence.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
    }

    It "keeps docs/57 ready and rejects PR Fast CI or simulation substitutes" {
        Assert-KitMatch $script:Doc 'Status:\s*`ready-for-manual-closure`'
        Assert-KitMatch $script:Doc "Pull request-only Fast CI is not a substitute"
        Assert-KitMatch $script:Doc "Native command simulation is not a substitute"
        Assert-KitMatch $script:Doc '\| PR Fast CI substitute allowed \| `false` \|'
        Assert-KitMatch $script:Doc '\| Simulation substitute allowed \| `false` \|'
        Assert-KitNotMatch $script:Doc "(?i)\b(fixes|closes|resolves)\s+#17\b"
    }

    It "records post-PR main Full Validate success evidence" {
        Assert-KitMatch $script:Doc '\| Trigger source \| `(?:main push|workflow_dispatch)` \|'
        Assert-KitMatch $script:Doc '\| Main SHA \| `[0-9a-f]{40}` \|'
        Assert-KitMatch $script:Doc '\| Workflow run \| `https://github\.com/phdiggit/win11-image-kit/actions/runs/[0-9]+` \|'
        Assert-KitMatch $script:Doc '\| Full Validate job \| `https://github\.com/phdiggit/win11-image-kit/actions/runs/[0-9]+/job/[0-9]+` \|'
        Assert-KitMatch $script:Doc '\| Result \| `success` \|'
        Assert-KitMatch $script:Doc "checkout log fetched"
        Assert-KitMatch $script:Doc "local git log -1 confirmed"
    }

    It "records controlled execution report evidence with zero failure counts" {
        Assert-KitMatch $script:Doc '\| Report status \| `(passed|manual)` \|'
        foreach ($field in @(
            "failedCount",
            "blockedCount",
            "authorizationFailureCount",
            "executeRequestBlockedCount",
            "simulatedFailureCount",
            "dependencyBlockedCount",
            "diskIdentityMismatchCount",
            "confirmationTokenFailureCount",
            "wimValidationFailureCount",
            "winrePlanFailureCount",
            "nativeCommandFailureCount",
            "executedActionCount"
        )) {
            Assert-KitMatch $script:Doc ('\| {0} \| `0` \|' -f [regex]::Escape($field))
        }

        Assert-KitMatch $script:Doc '\| trueExecution \| `false` \|'
        Assert-KitMatch $script:Doc '\| whatIf \| `true` \|'
    }

    It "keeps real lifecycle evidence not-run, not-captured, or not-provided" {
        foreach ($field in @(
            'Real disk query | `not-run`',
            'Disk mutation | `not-run`',
            'DISM apply/capture | `not-run`',
            'bcdboot | `not-run`',
            'reagentc | `not-run`',
            'WinRE mutation | `not-run`',
            'Real WIM SHA256 | `not-captured`',
            'Admin/VM smoke | `not-provided`'
        )) {
            Assert-KitMatch $script:Doc ([regex]::Escape($field))
        }

        Assert-KitMatch $script:Doc '\| Current readiness \| `ready-for-manual-closure` \|'
        Assert-KitMatch $script:Doc '\| Required next evidence \| `maintainer manual review` \|'
    }
}
