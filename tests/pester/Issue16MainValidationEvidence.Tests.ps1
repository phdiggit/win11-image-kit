Describe "Issue 16 main validation evidence scaffold" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-16\51-issue16-main-validation-evidence.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
    }

    It "keeps an allowed evidence state and rejects PR Fast CI as a substitute" {
        $statusMatch = [regex]::Match($script:Doc, 'Status:\s*`([^`]+)`')

        Assert-KitEqual $statusMatch.Success $true
        Assert-KitEqual (@("pending-main-validation", "ready-for-manual-closure") -contains $statusMatch.Groups[1].Value) $true
        Assert-KitMatch $script:Doc "Pull request-only Fast CI is not a substitute"
        Assert-KitMatch $script:Doc '\| PR Fast CI substitute allowed \| `false` \|'
        Assert-KitNotMatch $script:Doc "(?i)\b(fixes|closes|resolves)\s+#16\b"
    }

    It "keeps main evidence either pending or fully recorded" {
        $status = ([regex]::Match($script:Doc, 'Status:\s*`([^`]+)`')).Groups[1].Value

        if ($status -eq "pending-main-validation") {
            foreach ($field in @("Trigger source", "Main SHA", "Workflow run", "Full Validate job", "Result")) {
                Assert-KitMatch $script:Doc ('\| {0} \| `pending` \|' -f [regex]::Escape($field))
            }
            Assert-KitMatch $script:Doc '\| Notes \| `(?:pending|[^`]*not acceptable ready evidence[^`]*)` \|'
        } else {
            Assert-KitMatch $script:Doc '\| Trigger source \| `(?:main push|workflow_dispatch)` \|'
            Assert-KitMatch $script:Doc '\| Main SHA \| `[0-9a-f]{40}` \|'
            Assert-KitMatch $script:Doc '\| Workflow run \| `https://github\.com/phdiggit/win11-image-kit/actions/runs/[0-9]+` \|'
            Assert-KitMatch $script:Doc '\| Full Validate job \| `https://github\.com/phdiggit/win11-image-kit/actions/runs/[0-9]+/job/[0-9]+` \|'
            Assert-KitMatch $script:Doc '\| Result \| `success` \|'
            Assert-KitMatch $script:Doc 'checkout log.*git log -1'
        }
    }

    It "keeps evidence chain report counters consistent with the current state" {
        $status = ([regex]::Match($script:Doc, 'Status:\s*`([^`]+)`')).Groups[1].Value

        if ($status -eq "pending-main-validation") {
            foreach ($field in @("Report status", "failedCount", "blockedCount", "runId", "artifactCount", "producerCount", "normalizedCount", "missingRequiredCount", "reportTypeMismatchCount", "disallowedManualCount", "disallowedNotCapturedCount", "inputPolicyViolationCount")) {
                Assert-KitMatch $script:Doc ('\| {0} \| `pending` \|' -f [regex]::Escape($field))
            }
        } else {
            Assert-KitMatch $script:Doc '\| Report status \| `(passed|manual)` \|'
            Assert-KitMatch $script:Doc '\| failedCount \| `0` \|'
            Assert-KitMatch $script:Doc '\| blockedCount \| `0` \|'
            Assert-KitMatch $script:Doc '\| runId \| `(kit-run-[^`]+|not-captured)` \|'
            Assert-KitMatch $script:Doc '\| artifactCount \| `([0-9]+|not-captured)` \|'
            Assert-KitMatch $script:Doc '\| producerCount \| `([0-9]+|not-captured)` \|'
            Assert-KitMatch $script:Doc '\| normalizedCount \| `([0-9]+|not-captured)` \|'
            foreach ($field in @("missingRequiredCount", "reportTypeMismatchCount", "disallowedManualCount", "disallowedNotCapturedCount", "inputPolicyViolationCount")) {
                Assert-KitMatch $script:Doc ('\| {0} \| `0` \|' -f [regex]::Escape($field))
            }
        }

        foreach ($field in @("trueExecution", "localPrivateIncluded", "networkUsed", "mutationUsed")) {
            Assert-KitMatch $script:Doc ('\| {0} \| `false` \|' -f [regex]::Escape($field))
        }
    }

    It "keeps real lifecycle evidence not-run or not-captured" {
        foreach ($field in @(
            'Real build | `not-run`',
            'Capture | `not-run`',
            'Deploy | `not-run`',
            'Admin/VM smoke | `not-provided`',
            'Real WIM SHA256 | `not-captured`',
            'DISM image info | `not-captured`'
        )) {
            Assert-KitMatch $script:Doc ([regex]::Escape($field))
        }

        Assert-KitMatch $script:Doc '\| Current readiness \| `(pending-main-validation|ready-for-manual-closure)` \|'
    }
}
