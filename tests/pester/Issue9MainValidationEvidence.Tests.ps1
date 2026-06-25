$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Issue 9 main validation evidence scaffold" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:Doc23 = Join-Path $script:RepoRoot "docs\23-issue9-main-validation-evidence.md"
    }

    It "uses an allowed evidence status" {
        $doc = Get-Content -LiteralPath $script:Doc23 -Raw -Encoding UTF8
        $statusLine = @($doc -split "`r?`n" | Where-Object { $_ -like "Status:*" })[0]

        if ($statusLine -notin @("Status: pending-main-validation", "Status: ready-for-manual-closure")) {
            throw "Unexpected Issue 9 main validation status: $statusLine"
        }
    }

    It "keeps pending evidence pending or validates ready evidence" {
        $doc = Get-Content -LiteralPath $script:Doc23 -Raw -Encoding UTF8
        $statusLine = @($doc -split "`r?`n" | Where-Object { $_ -like "Status:*" })[0]
        $readinessLine = @($doc -split "`r?`n" | Where-Object { $_ -like "- Current readiness:*" })[0]
        $triggerLine = @($doc -split "`r?`n" | Where-Object { $_ -like "- Trigger source:*" })[0]
        $shaLine = @($doc -split "`r?`n" | Where-Object { $_ -like "- Main SHA:*" })[0]
        $runLine = @($doc -split "`r?`n" | Where-Object { $_ -like "- Workflow run:*" })[0]
        $resultLine = @($doc -split "`r?`n" | Where-Object { $_ -like "- Result:*" })[0]

        if ($statusLine -eq "Status: pending-main-validation") {
            Assert-KitEqual $triggerLine "- Trigger source: pending"
            Assert-KitEqual $shaLine "- Main SHA: pending"
            Assert-KitEqual $runLine "- Workflow run: pending"
            Assert-KitEqual $resultLine "- Result: pending"
            Assert-KitEqual $readinessLine "- Current readiness: pending-main-validation"
            return
        }

        Assert-KitMatch $triggerLine "^- Trigger source: (main push|workflow_dispatch)$"
        Assert-KitMatch $shaLine "^- Main SHA: [0-9a-f]{40}$"
        Assert-KitMatch $runLine "^- Workflow run: https://github\.com/phdiggit/win11-image-kit/actions/runs/[0-9]+$"
        Assert-KitEqual $resultLine "- Result: success"
        Assert-KitEqual $readinessLine "- Current readiness: ready-for-manual-closure"
        Assert-KitMatch $doc "Full Validate succeeded|Windows CI / Full Validate succeeded"
    }

    It "documents ready-state rules for future main evidence" {
        $doc = Get-Content -LiteralPath $script:Doc23 -Raw -Encoding UTF8

        Assert-KitMatch $doc "main push or workflow_dispatch"
        Assert-KitMatch $doc "40-character main SHA"
        Assert-KitMatch $doc "Actions workflow URL"
        Assert-KitMatch $doc "Result: success"
        Assert-KitMatch $doc "Current readiness: ready-for-manual-closure"
    }

    It "keeps PR Fast CI separate from main validation evidence" {
        $doc = Get-Content -LiteralPath $script:Doc23 -Raw -Encoding UTF8

        Assert-KitMatch $doc "cannot|不能|must not"
        Assert-KitMatch $doc "PR Fast CI"
        Assert-KitMatch $doc "main validation evidence"
        Assert-KitMatch $doc "Real VM/admin Smoke|Real VM/admin smoke"
        Assert-KitMatch $doc "optional"
        Assert-KitMatch $doc "not-run"
    }

    It "does not contain Issue 9 auto-close keyword combinations" {
        $doc = Get-Content -LiteralPath $script:Doc23 -Raw -Encoding UTF8

        Assert-KitNotMatch $doc "(?i)(close[sd]?|fix(e[sd])?|resolve[sd]?)\s+#9"
    }

    It "is included in PR Fast CI" {
        $ci = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8

        Assert-KitMatch $ci ([regex]::Escape("tests/pester/Issue9MainValidationEvidence.Tests.ps1"))
    }
}
