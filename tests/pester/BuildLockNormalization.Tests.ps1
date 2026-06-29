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

    It "tracks the normalization doc, test, and helper in Build Lock" {
        foreach ($path in @(
            "docs/archive/build-lock/121-build-lock-normalization.md",
            "scripts/dev/update_build_lock_hashes.py",
            "tests/pester/BuildLockNormalization.Tests.ps1"
        )) {
            Assert-FutureTrueUxBuildLockTracksPath -BuildLock $script:BuildLock -Path $path
        }
    }

    It "keeps every Future True UX gate report-only and blocking on pull requests" {
        $futureGates = @($script:QualityGates.gates | Where-Object { $_.id -like "future-true-ux*" })
        Assert-KitEqual @($futureGates).Count 17

        foreach ($gate in $futureGates) {
            Assert-FutureTrueUxQualityGateSemantics -Gate $gate -RepoRoot $script:RepoRoot
        }
    }

    It "keeps workflow and line-ending policy out of this normalization change" {
        $workflowPath = Join-Path $script:RepoRoot ".github\workflows\ci.yml"
        $workflowHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $workflowPath).Hash.ToLowerInvariant()

        Assert-KitEqual $workflowHash "2e709f3b39858cb0c026734f9fd2dd57e6868e68395e789c579d198458705835"
        Assert-KitMatch $script:Doc '`\.github/workflows/ci\.yml`'

        $attributesPath = Join-Path $script:RepoRoot ".gitattributes"
        if (Test-Path -LiteralPath $attributesPath) {
            $attributes = Get-Content -LiteralPath $attributesPath -Raw -Encoding UTF8
            Assert-KitNotMatch $attributes "(?m)^\*\s+text=auto\b"
        } else {
            Assert-KitMatch $script:Doc '`\.gitattributes`'
        }
    }

    It "keeps the Build Lock helper scoped, dry-run first, and offline" {
        $helperPath = Join-Path $script:RepoRoot "scripts\dev\update_build_lock_hashes.py"
        $helper = Get-Content -LiteralPath $helperPath -Raw -Encoding UTF8

        foreach ($needle in @("--paths", "--from-report", "--dry-run", "--write", "--allow-many", "--max-updates")) {
            Assert-KitMatch $helper ([regex]::Escape($needle))
        }

        Assert-KitMatch $helper "dry-run is the default"
        Assert-KitNotMatch $helper "(?i)\b(requests|urllib|socket|subprocess|Invoke-WebRequest|Invoke-RestMethod|Start-Process)\b"
    }
}
