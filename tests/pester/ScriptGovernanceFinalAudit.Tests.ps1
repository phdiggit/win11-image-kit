Describe "Script governance final audit stop-line" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "tests\pester\FutureTrueUxPesterHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Get-KitBuildLock.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitBuildLockReport.ps1")

        $script:DocPath = Join-Path $script:RepoRoot "docs\archive\script-governance\122-script-governance-final-audit.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
        $script:QualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:BuildLock = Get-KitBuildLock -Path "manifests/build-lock.json" -RepoRoot $script:RepoRoot
        $script:BuildLockReport = New-KitBuildLockReport -BuildLock $script:BuildLock -RepoRoot $script:RepoRoot -WhatIf
    }

    It "records the final audit without Issue 19 auto-close wording" {
        Assert-KitEqual (Test-Path -LiteralPath $script:DocPath) $true
        Assert-FutureTrueUxGovernanceBoundary -DocumentText $script:Doc -IssueNumber 19
        Assert-KitMatch $script:Doc "Script governance stop-line: reached"
        Assert-KitMatch $script:Doc "No further broad script consolidation is recommended"
        Assert-KitMatch $script:Doc "Issue #8-#13 Roadmap Re-entry Planning"
    }

    It "contains the required script surface inventory areas" {
        foreach ($path in @(
            "scripts/common/",
            "scripts/validate/",
            "scripts/config/",
            "scripts/dev/",
            "tests/pester/",
            "tests/fixtures/",
            "manifests/build-lock.json",
            "manifests/quality-gates.json",
            "docs/archive/"
        )) {
            Assert-KitMatch $script:Doc ([regex]::Escape($path))
        }

        foreach ($classification in @(
            "Stable / stop broad governance",
            "Stable / lifecycle monitoring only",
            "Intentionally separate",
            "Needs lifecycle monitoring only",
            "Stable / deletion-first lifecycle"
        )) {
            Assert-KitMatch $script:Doc ([regex]::Escape($classification))
        }
    }

    It "documents lifecycle rules for validators and Pester tests" {
        Assert-KitMatch $script:Doc "## .*scripts/validate/.* Lifecycle Status"
        Assert-KitMatch $script:Doc "Lifecycle rule for adding new validators"
        Assert-KitMatch $script:Doc "Retirement criteria for old validators"
        Assert-KitMatch $script:Doc "No standalone migration-only validator remains"

        Assert-KitMatch $script:Doc "## .*tests/pester/.* Lifecycle Status"
        Assert-KitMatch $script:Doc "Lifecycle rule for adding new Pester tests"
        Assert-KitMatch $script:Doc "Retirement criteria for old stage-specific tests"
        Assert-KitMatch $script:Doc "Pester files are not runtime scripts"
    }

    It "documents the Anti-bloat Contract" {
        Assert-KitMatch $script:Doc "## Anti-Bloat Contract"

        foreach ($needle in @(
            "No new script without checking the existing helper family first",
            "No new validator if an existing validator can be parameterized safely",
            "No new Pester file if an existing governance test can be extended readably",
            "No new archive doc unless it records a durable decision or handoff",
            "One-time migration, normalization, or governance helper scripts must be deleted before the stop-line unless they are promoted to a documented recurring workflow",
            "Build Lock updates must be scoped except in dedicated normalization PRs",
            "Quality gate changes must preserve IDs and report-only semantics unless explicitly approved",
            "Future True UX true-execution work must remain outside the current report-only chain"
        )) {
            Assert-KitMatch $script:Doc ([regex]::Escape($needle))
        }
    }

    It "documents and enforces ephemeral script deletion" {
        Assert-KitMatch $script:Doc "## Ephemeral Script Deletion Audit"

        foreach ($path in @(
            "scripts/dev/",
            "scripts/config/",
            "scripts/validate/",
            "tests/pester/"
        )) {
            Assert-KitMatch $script:Doc ([regex]::Escape($path))
        }

        Assert-KitMatch $script:Doc 'Delete `scripts/dev/update_build_lock_hashes\.py`'
        Assert-KitMatch $script:Doc "No other ephemeral script is left resident"

        $deletedHelperPath = Join-Path $script:RepoRoot "scripts\dev\update_build_lock_hashes.py"
        Assert-KitEqual (Test-Path -LiteralPath $deletedHelperPath) $false
        Assert-KitEqual (@($script:BuildLock.entries.path) -contains "scripts/dev/update_build_lock_hashes.py") $false
    }

    It "keeps every Future True UX quality gate report-only and blocking on pull requests" {
        $futureGates = @($script:QualityGates.gates | Where-Object { $_.id -like "future-true-ux*" })
        Assert-KitEqual @($futureGates).Count 11

        foreach ($gate in $futureGates) {
            Assert-FutureTrueUxQualityGateSemantics -Gate $gate -RepoRoot $script:RepoRoot
        }
    }

    It "keeps public Future True UX validate entrypoints present" {
        $futureValidateEntrypoints = @(
            $script:QualityGates.gates |
                Where-Object { $_.id -like "future-true-ux*" -and $_.entrypoint -like "scripts/validate/Test-FutureTrueUxRestore*.ps1" } |
                ForEach-Object { $_.entrypoint }
        )
        Assert-KitEqual $futureValidateEntrypoints.Count 6

        foreach ($entrypoint in $futureValidateEntrypoints) {
            Assert-FutureTrueUxValidatorEntrypointExists -RepoRoot $script:RepoRoot -RelativePath $entrypoint
        }
    }

    It "keeps Build Lock normalized and tracks this final audit surface" {
        Assert-KitEqual $script:BuildLockReport.summary.failedCount 0
        Assert-KitEqual $script:BuildLockReport.summary.mismatchCount 0
        Assert-KitEqual $script:BuildLockReport.summary.missingCount 0
        Assert-KitEqual $script:BuildLockReport.summary.manualCount 1
        Assert-KitEqual (@($script:BuildLockReport.untrackedWatchedFiles) -contains "manifests/build-lock.json") $true

        foreach ($path in @(
            "docs/archive/script-governance/122-script-governance-final-audit.md",
            "tests/pester/ScriptGovernanceFinalAudit.Tests.ps1"
        )) {
            Assert-FutureTrueUxBuildLockTracksPath -BuildLock $script:BuildLock -Path $path
        }
    }

    It "keeps PR Fast workflow free of deleted historical Pester references" {
        $workflowPath = Join-Path $script:RepoRoot ".github\workflows\ci.yml"
        $workflow = Get-Content -LiteralPath $workflowPath -Raw -Encoding UTF8

        Assert-KitMatch $script:Doc 'CI repair in this PR may remove `\.github/workflows/ci\.yml` PR Fast Pester references to files deleted by this same PR'
        Assert-KitMatch $script:Doc "does not change workflow triggers, runner choice, quality gate semantics, or execution behavior"

        $workflowPesterPaths = @(
            [regex]::Matches($workflow, '"(tests/pester/[^"]+\.Tests\.ps1)"') |
                ForEach-Object { $_.Groups[1].Value }
        )
        $missingWorkflowPesterPaths = @(
            $workflowPesterPaths |
                Where-Object { -not (Test-Path -LiteralPath (Join-Path $script:RepoRoot ($_ -replace '/', '\'))) }
        )

        Assert-KitEqual $missingWorkflowPesterPaths.Count 0
        Assert-KitEqual ([regex]::IsMatch($workflow, 'tests/pester/(Issue1[4-8].*|EvidenceChainClosePrep)\.Tests\.ps1')) $false

        Assert-KitMatch $workflow "QualityGateSchema\.Tests\.ps1"
        Assert-KitMatch $workflow "FutureTrueUxRestoreMockReviewSafety\.Tests\.ps1"
    }
}
