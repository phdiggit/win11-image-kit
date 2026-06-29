Describe "Future True UX validator script governance" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")

        $script:DocPath = Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\112-future-true-ux-validator-script-governance.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
        $script:QualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:BuildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:FutureGates = @($script:QualityGates.gates | Where-Object { $_.id -like "future-true-ux*" })
    }

    It "documents the governance state without closing Issue 19" {
        Assert-KitEqual (Test-Path -LiteralPath $script:DocPath) $true
        Assert-KitMatch $script:Doc 'Status:\s*`future-true-ux-validator-script-governance`'
        Assert-KitMatch $script:Doc "Refs #19"
        Assert-KitNotMatch $script:Doc "(?i)\b(fixes|closes|resolves)\s+#19\b"
        Assert-KitMatch $script:Doc '\| `authorizationApproved` \| `false` \|'
        Assert-KitMatch $script:Doc '\| `executionApproved` \| `false` \|'
        Assert-KitMatch $script:Doc '\| `executeReady` \| `false` \|'
        Assert-KitMatch $script:Doc '\| `trueExecution` \| `false` \|'
        Assert-KitMatch $script:Doc '\| `mutationCount` \| `0` \|'
    }

    It "keeps every Future True UX gate report-only and on existing entrypoints" {
        Assert-KitEqual @($script:FutureGates).Count 17
        foreach ($gate in $script:FutureGates) {
            Assert-KitEqual $gate.layer "pr-fast"
            Assert-KitEqual $gate.trigger "pull_request"
            Assert-KitEqual $gate.mode "report-only"
            Assert-KitEqual $gate.required $true
            Assert-KitEqual $gate.blocking $true
            Assert-KitNotMatch $gate.entrypoint "scripts/(build|postdeploy|presysprep|winpe)/"
            Assert-KitNotMatch $gate.entrypoint "Restore-UserExperience|Invoke-GoldenImageBuild|Install-|Set-|Clear-|New-WinPE"

            $entrypointPath = Join-Path $script:RepoRoot $gate.entrypoint
            Assert-KitEqual (Test-Path -LiteralPath $entrypointPath) $true
        }
    }

    It "keeps validator entrypoints free of direct dangerous commands" {
        $dangerousCommands = @(
            "Start-Process",
            "Invoke-Expression",
            "Set-ItemProperty",
            "New-ItemProperty",
            "Remove-AppxPackage",
            "Add-MpPreference",
            "dism",
            "winget",
            "choco",
            "msiexec",
            "Invoke-WebRequest",
            "Invoke-RestMethod",
            "Install-Module"
        )

        $validatorPaths = @($script:FutureGates.entrypoint | Where-Object { $_ -like "scripts/validate/*.ps1" } | Sort-Object -Unique)
        foreach ($relativePath in $validatorPaths) {
            $content = Get-Content -LiteralPath (Join-Path $script:RepoRoot $relativePath) -Raw -Encoding UTF8
            foreach ($command in $dangerousCommands) {
                Assert-KitNotMatch $content ("(?i)(^|[^A-Za-z0-9-])" + [regex]::Escape($command) + "([^A-Za-z0-9-]|$)")
            }
        }
    }

    It "centralizes only report-only guard values" {
        $guardPath = Join-Path $script:RepoRoot "scripts\common\FutureTrueUxRestore.Guards.ps1"
        $guardContent = Get-Content -LiteralPath $guardPath -Raw -Encoding UTF8
        Assert-KitMatch $guardContent "function Get-FutureTrueUxRestoreFrozenFlagNames"
        Assert-KitMatch $guardContent "function New-FutureTrueUxRestoreFrozenExecutionState"
        Assert-KitMatch $guardContent "function Test-FutureTrueUxRestoreTruthy"
        Assert-KitMatch $guardContent "function Get-FutureTrueUxRestoreDangerousVocabularyPattern"
        Assert-KitNotMatch $guardContent "Start-Process|Invoke-Expression|Set-ItemProperty|New-ItemProperty|Remove-AppxPackage|Add-MpPreference"
    }

    It "keeps the changed governance surface tracked by Build Lock" {
        $expectedPaths = @(
            "docs/archive/future-true-ux-restore/00-governance/112-future-true-ux-validator-script-governance.md",
            "scripts/common/FutureTrueUxRestore.Guards.ps1",
            "scripts/common/New-FutureTrueUxRestoreMockReviewDrillReport.ps1",
            "scripts/common/New-FutureTrueUxRestoreNegativeReviewDrillReport.ps1",
            "tests/pester/FutureTrueUxValidatorScriptGovernance.Tests.ps1"
        )

        $lockedPaths = @($script:BuildLock.entries.path)
        foreach ($path in $expectedPaths) {
            Assert-KitEqual ($lockedPaths -contains $path) $true
        }
    }
}
