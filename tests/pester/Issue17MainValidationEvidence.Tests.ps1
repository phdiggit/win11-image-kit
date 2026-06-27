Describe "Issue 17 main validation evidence scaffold" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\57-issue17-main-validation-evidence.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
    }

    It "keeps docs/57 pending and rejects PR Fast CI or simulation substitutes" {
        Assert-KitMatch $script:Doc 'Status:\s*`pending-main-validation`'
        Assert-KitMatch $script:Doc "Pull request-only Fast CI is not a substitute"
        Assert-KitMatch $script:Doc "Native command simulation is not a substitute"
        Assert-KitMatch $script:Doc '\| PR Fast CI substitute allowed \| `false` \|'
        Assert-KitMatch $script:Doc '\| Simulation substitute allowed \| `false` \|'
        Assert-KitNotMatch $script:Doc "(?i)\b(fixes|closes|resolves)\s+#17\b"
    }

    It "keeps current evidence pending" {
        foreach ($field in @("Trigger source", "Main SHA", "Workflow run", "Full Validate job", "Result")) {
            Assert-KitMatch $script:Doc ('\| {0} \| `pending` \|' -f [regex]::Escape($field))
        }
        Assert-KitMatch $script:Doc '\| Notes \| `pending post-PR main/workflow evidence` \|'
    }

    It "keeps controlled execution report evidence pending with safety flags fixed" {
        foreach ($field in @("Report status", "failedCount", "blockedCount", "authorizationFailureCount", "executeRequestBlockedCount", "simulatedFailureCount", "dependencyBlockedCount")) {
            Assert-KitMatch $script:Doc ('\| {0} \| `pending` \|' -f [regex]::Escape($field))
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

        Assert-KitMatch $script:Doc '\| Current readiness \| `pending-main-validation` \|'
        Assert-KitMatch $script:Doc '\| Required next evidence \| `main/workflow validation` \|'
    }
}
