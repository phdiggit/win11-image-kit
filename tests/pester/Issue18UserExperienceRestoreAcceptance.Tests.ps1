Describe "Issue 18 user experience restore acceptance scaffold" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "keeps acceptance in the current report-only stage" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\59-issue18-user-experience-restore-acceptance.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc 'Status: `in-acceptance`'
        Assert-KitMatch $doc "PR Fast CI is not main/workflow evidence"
        Assert-KitMatch $doc "Fixture/report-only validation is not real UX restore evidence"
        Assert-KitMatch $doc "does not confirm that user configuration has taken effect"
    }

    It "keeps Quality Gates and Build Lock wired for Issue 18" {
        $qualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $gateIds = @($qualityGates.gates | ForEach-Object { [string]$_.id })
        $lockedPaths = @($buildLock.entries | ForEach-Object { [string]$_.path })

        foreach ($id in @(
            "user-experience-restore",
            "issue18-intake",
            "issue18-acceptance",
            "user-experience-default-apps-plan",
            "user-experience-start-menu-plan"
        )) {
            Assert-KitEqual ($gateIds -contains $id) $true
        }

        foreach ($path in @(
            "docs/58-issue18-user-experience-restore-intake.md",
            "docs/59-issue18-user-experience-restore-acceptance.md",
            "manifests/user-experience-restore.json",
            "scripts/validate/Test-UserExperienceRestore.ps1"
        )) {
            Assert-KitEqual ($lockedPaths -contains $path) $true
        }

        Assert-KitEqual ($lockedPaths -contains "manifests/paths.local.json") $false
    }
}
