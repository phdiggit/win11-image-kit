Describe "Future True UX validator script governance" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "tests\pester\FutureTrueUxPesterHelpers.ps1")

        $script:DocPath = Join-Path $script:RepoRoot "docs\archive\future-true-ux-restore\00-governance\112-future-true-ux-validator-script-governance.md"
        $script:Doc = Get-Content -LiteralPath $script:DocPath -Raw -Encoding UTF8
        $script:QualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:BuildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:FutureGates = @($script:QualityGates.gates | Where-Object { $_.id -like "future-true-ux*" })
        $script:ChangedReportHelpers = @(
            "scripts/common/New-FutureTrueUxRestoreAuthorizationReport.ps1",
            "scripts/common/New-FutureTrueUxRestoreAuthorizationReviewReport.ps1",
            "scripts/common/New-FutureTrueUxRestoreEndToEndNoExecutionReadinessAuditReport.ps1",
            "scripts/common/New-FutureTrueUxRestoreFinalStopLineHandoffReport.ps1"
        )
    }

    It "documents the governance state without closing Issue 19" {
        Assert-KitEqual (Test-Path -LiteralPath $script:DocPath) $true
        Assert-KitMatch $script:Doc 'Status:\s*`future-true-ux-validator-script-governance`'
        Assert-FutureTrueUxGovernanceBoundary -DocumentText $script:Doc -IssueNumber 19
    }

    It "keeps every Future True UX gate report-only and on existing entrypoints" {
        Assert-KitEqual @($script:FutureGates).Count 12
        foreach ($gate in $script:FutureGates) {
            Assert-FutureTrueUxQualityGateSemantics -Gate $gate -RepoRoot $script:RepoRoot
        }
    }

    It "keeps validator entrypoints free of direct dangerous commands" {
        $validatorPaths = @($script:FutureGates.entrypoint | Where-Object { $_ -like "scripts/validate/*.ps1" } | Sort-Object -Unique)
        foreach ($relativePath in $validatorPaths) {
            $content = Get-Content -LiteralPath (Join-Path $script:RepoRoot $relativePath) -Raw -Encoding UTF8
            Assert-FutureTrueUxNoDangerousCommands -Content $content
        }
    }

    It "centralizes only report-only guard values" {
        $guardPath = Join-Path $script:RepoRoot "scripts\common\FutureTrueUxRestore.Guards.ps1"
        $guardContent = Get-Content -LiteralPath $guardPath -Raw -Encoding UTF8
        Assert-KitMatch $guardContent "function Get-FutureTrueUxRestoreFrozenFlagNames"
        Assert-KitMatch $guardContent "function New-FutureTrueUxRestoreFrozenExecutionState"
        Assert-KitMatch $guardContent "function Get-FutureTrueUxRestoreSupportedScopes"
        Assert-KitMatch $guardContent "function Get-FutureTrueUxRestoreFrozenStateDrift"
        Assert-KitMatch $guardContent "function Get-FutureTrueUxRestoreFrozenStateMessages"
        Assert-KitMatch $guardContent "function Get-FutureTrueUxRestoreIssueAutoClosePattern"
        Assert-KitMatch $guardContent "function Get-FutureTrueUxRestoreStatePromotionPattern"
        Assert-KitMatch $guardContent "function Get-FutureTrueUxRestoreEvidencePromotionPattern"
        Assert-KitMatch $guardContent "function Get-FutureTrueUxRestoreDangerousCommandPatterns"
        Assert-KitMatch $guardContent "function Get-FutureTrueUxRestoreDocumentText"
        Assert-KitMatch $guardContent "function Test-FutureTrueUxRestoreStatusMarker"
        Assert-KitNotMatch $guardContent "Start-Process|Invoke-Expression|Set-ItemProperty|New-ItemProperty|Remove-AppxPackage|Add-MpPreference"
    }

    It "uses the shared guard helpers across the Batch 2 report helpers" {
        $expectedHelperUsage = @{
            "scripts/common/New-FutureTrueUxRestoreAuthorizationReport.ps1" = @(
                "FutureTrueUxRestore.Guards.ps1"
            )
            "scripts/common/New-FutureTrueUxRestoreAuthorizationReviewReport.ps1" = @(
                "Get-FutureTrueUxRestoreSupportedScopes",
                "Get-FutureTrueUxRestoreFrozenStateMessages",
                "Get-FutureTrueUxRestoreIssueAutoClosePattern"
            )
            "scripts/common/New-FutureTrueUxRestoreEndToEndNoExecutionReadinessAuditReport.ps1" = @(
                "Get-FutureTrueUxRestoreFrozenStateDrift",
                "Get-FutureTrueUxRestoreDocumentText",
                "Test-FutureTrueUxRestoreStatusMarker",
                "Get-FutureTrueUxRestoreDangerousCommandPatterns"
            )
            "scripts/common/New-FutureTrueUxRestoreFinalStopLineHandoffReport.ps1" = @(
                "Get-FutureTrueUxRestoreFrozenStateDrift",
                "Get-FutureTrueUxRestoreIssueAutoClosePattern",
                "Get-FutureTrueUxRestoreDocumentText",
                "Test-FutureTrueUxRestoreStatusMarker",
                "Get-FutureTrueUxRestoreDangerousCommandPatterns"
            )
        }

        foreach ($relativePath in $script:ChangedReportHelpers) {
            $content = Get-Content -LiteralPath (Join-Path $script:RepoRoot $relativePath) -Raw -Encoding UTF8
            foreach ($helperName in $expectedHelperUsage[$relativePath]) {
                Assert-KitMatch $content ([regex]::Escape($helperName))
            }
        }
    }

    It "keeps the changed governance surface tracked by Build Lock" {
        $expectedPaths = @(
            "docs/archive/future-true-ux-restore/00-governance/112-future-true-ux-validator-script-governance.md",
            "scripts/common/FutureTrueUxRestore.Guards.ps1",
            "scripts/common/New-FutureTrueUxRestoreAuthorizationReport.ps1",
            "scripts/common/New-FutureTrueUxRestoreAuthorizationReviewReport.ps1",
            "scripts/common/New-FutureTrueUxRestoreEndToEndNoExecutionReadinessAuditReport.ps1",
            "scripts/common/New-FutureTrueUxRestoreFinalStopLineHandoffReport.ps1",
            "tests/pester/FutureTrueUxQualityGateGovernance.Tests.ps1",
            "tests/pester/FutureTrueUxPesterHelpers.ps1",
            "tests/pester/FutureTrueUxValidatorScriptGovernance.Tests.ps1"
        )

        foreach ($path in $expectedPaths) {
            Assert-FutureTrueUxBuildLockTracksPath -BuildLock $script:BuildLock -Path $path
        }
    }
}
