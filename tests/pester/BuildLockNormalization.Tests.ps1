Describe "Build Lock normalization governance" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "tests\pester\FutureTrueUxPesterHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Get-KitBuildLock.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitBuildLockReport.ps1")

        $script:DocPath = Join-Path $script:RepoRoot "docs\archive\build-lock\121-build-lock-normalization.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
        $script:BuildLock = Get-KitBuildLock -Path "manifests/build-lock.json" -RepoRoot $script:RepoRoot
        $script:Report = New-KitBuildLockReport -BuildLock $script:BuildLock -RepoRoot $script:RepoRoot -WhatIf
        $script:QualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    }

    It "records the Task 121 drift inventory without Issue 19 auto-close wording" {
        Assert-KitEqual (Test-Path -LiteralPath $script:DocPath) $true
        Assert-KitMatch $script:Doc 'Refs #19'
        Assert-KitNotMatch $script:Doc '(?i)\b(fixes|closes|resolves)\s+#19\b'
        Assert-KitMatch $script:Doc '\| `failedCount` \| `118` \|'
        Assert-KitMatch $script:Doc '\| `mismatchCount` \| `118` \|'
        Assert-KitMatch $script:Doc '\| line-ending-only drift \| `85` \|'
        Assert-KitMatch $script:Doc '\| accepted content drift \| `33` \|'
        Assert-KitMatch $script:Doc 'manual by policy'
    }

    It "keeps Build Lock normalized with only the documented self-watch manual item" {
        Assert-KitEqual $script:Report.summary.failedCount 0
        Assert-KitEqual $script:Report.summary.mismatchCount 0
        Assert-KitEqual $script:Report.summary.missingCount 0
        Assert-KitEqual $script:Report.summary.manualCount 1
        Assert-KitEqual $script:Report.summary.untrackedWatchedCount 1
        Assert-KitEqual (@($script:Report.untrackedWatchedFiles) -contains "manifests/build-lock.json") $true
        Assert-KitEqual (@($script:BuildLock.entries.path) -contains "manifests/build-lock.json") $false
    }

    It "tracks the normalization doc and test in Build Lock" {
        foreach ($path in @(
            "docs/archive/build-lock/121-build-lock-normalization.md",
            "tests/pester/BuildLockNormalization.Tests.ps1"
        )) {
            Assert-FutureTrueUxBuildLockTracksPath -BuildLock $script:BuildLock -Path $path
        }
    }

    It "keeps every Future True UX gate report-only and blocking on pull requests" {
        $futureGates = @($script:QualityGates.gates | Where-Object { $_.id -like "future-true-ux*" })
        Assert-KitEqual @($futureGates).Count 13

        foreach ($gate in $futureGates) {
            Assert-FutureTrueUxQualityGateSemantics -Gate $gate -RepoRoot $script:RepoRoot
        }
    }

    It "keeps line-ending policy unchanged and PR Fast workflow paths current" {
        $workflowPath = Join-Path $script:RepoRoot ".github\workflows\ci.yml"
        $workflow = Get-Content -LiteralPath $workflowPath -Raw -Encoding UTF8
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
        Assert-KitMatch $script:Doc '`\.github/workflows/ci\.yml`'

        $attributesPath = Join-Path $script:RepoRoot ".gitattributes"
        if (Test-Path -LiteralPath $attributesPath) {
            $attributes = Get-Content -LiteralPath $attributesPath -Raw -Encoding UTF8
            Assert-KitNotMatch $attributes "(?m)^\*\s+text=auto\b"
        } else {
            Assert-KitMatch $script:Doc '`\.gitattributes`'
        }
    }

    It "does not keep the one-time Build Lock normalization helper resident" {
        $helperPath = Join-Path $script:RepoRoot "scripts\dev\update_build_lock_hashes.py"
        Assert-KitEqual (Test-Path -LiteralPath $helperPath) $false
        Assert-KitEqual (@($script:BuildLock.entries.path) -contains "scripts/dev/update_build_lock_hashes.py") $false
        Assert-KitMatch $script:Doc "one-time helper"
        Assert-KitMatch $script:Doc "must not remain resident"
    }
}
