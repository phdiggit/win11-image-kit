Describe "Issue 15 main validation evidence scaffold" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:DocPath = Join-Path $script:RepoRoot "docs\47-issue15-main-validation-evidence.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
    }

    It "keeps an allowed evidence state and rejects PR Fast CI as a substitute" {
        $statusMatch = [regex]::Match($script:Doc, 'Status:\s*`([^`]+)`')
        Assert-KitEqual $statusMatch.Success $true
        Assert-KitEqual (@("pending-main-validation", "ready-for-manual-closure") -contains $statusMatch.Groups[1].Value) $true
        Assert-KitMatch $script:Doc "Pull request-only Fast CI is not a substitute"
        Assert-KitMatch $script:Doc '\| PR Fast CI substitute allowed \| `false` \|'
        Assert-KitNotMatch $script:Doc "(?i)(Fixes|Closes|Resolves)\s+#15"
    }

    It "keeps main evidence either pending or fully recorded" {
        $status = ([regex]::Match($script:Doc, 'Status:\s*`([^`]+)`')).Groups[1].Value

        if ($status -eq "pending-main-validation") {
            foreach ($field in @("Trigger source", "Main SHA", "Workflow run", "Full Validate job", "Result", "Notes")) {
                Assert-KitMatch $script:Doc ('\| {0} \| `pending` \|' -f [regex]::Escape($field))
            }
        } else {
            Assert-KitMatch $script:Doc '\| Trigger source \| `(?:main push|workflow_dispatch)` \|'
            Assert-KitMatch $script:Doc '\| Main SHA \| `[0-9a-f]{40}` \|'
            Assert-KitMatch $script:Doc '\| Workflow run \| `https://github\.com/phdiggit/win11-image-kit/actions/runs/[0-9]+` \|'
            Assert-KitMatch $script:Doc '\| Full Validate job \| `https://github\.com/phdiggit/win11-image-kit/actions/runs/[0-9]+/job/[0-9]+` \|'
            Assert-KitMatch $script:Doc '\| Result \| `success` \|'
            Assert-KitMatch $script:Doc 'checkout log.*git log -1'
        }
    }

    It "keeps effective configuration evidence consistent with the current state" {
        $status = ([regex]::Match($script:Doc, 'Status:\s*`([^`]+)`')).Groups[1].Value

        if ($status -eq "pending-main-validation") {
            foreach ($field in @("Report status", "failedCount", "stackCount", "CLI override fixture")) {
                Assert-KitMatch $script:Doc ('\| {0} \| `pending` \|' -f [regex]::Escape($field))
            }
        } else {
            Assert-KitMatch $script:Doc '\| Report status \| `(passed|manual)` \|'
            Assert-KitMatch $script:Doc '\| failedCount \| `0` \|'
            Assert-KitMatch $script:Doc '\| stackCount \| `([0-9]+|not-captured)` \|'
            Assert-KitMatch $script:Doc '\| CLI override fixture \| `(passed|not-captured)` \|'
            Assert-KitMatch $script:Doc '\| Consumer integration \| `(passed|not-captured)` \|'
            Assert-KitMatch $script:Doc '\| Build Lock \| `(passed|manual|not-captured)` \|'
            Assert-KitMatch $script:Doc '\| Quality Gates \| `(passed|manual|not-captured)` \|'
        }

        Assert-KitMatch $script:Doc '\| local override included \| `false` \|'
    }

    It "keeps real smoke evidence explicit and manual closure readiness guarded" {
        Assert-KitMatch $script:Doc '\| Environment \| `not-run` \|'
        Assert-KitMatch $script:Doc '\| Operator \| `not-provided` \|'
        Assert-KitMatch $script:Doc '\| Date \| `not-provided` \|'
        Assert-KitMatch $script:Doc '\| Scope \| `not-provided` \|'
        Assert-KitMatch $script:Doc '\| Result \| `not-run` \|'
        Assert-KitMatch $script:Doc '\| Current readiness \| `(pending-main-validation|ready-for-manual-closure)` \|'
    }
}
