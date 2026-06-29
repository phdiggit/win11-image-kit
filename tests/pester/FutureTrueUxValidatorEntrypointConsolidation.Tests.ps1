Describe "Future True UX validator entrypoint consolidation" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "tests\pester\FutureTrueUxPesterHelpers.ps1")

        $script:QualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:BuildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:SmokeRunId = [guid]::NewGuid().ToString("N")

        $script:ValidatorEntrypoints = @(
            [pscustomobject][ordered]@{
                gateId = "future-true-ux-restore-authorization"
                path = "scripts/validate/Test-FutureTrueUxRestoreAuthorization.ps1"
                reportType = "future-true-ux-restore-authorization-validation"
                parameters = @("ManifestPath", "BaselineAuthorizationPath", "ReportPath")
            },
            [pscustomobject][ordered]@{
                gateId = "future-true-ux-current-user-dry-run"
                path = "scripts/validate/Test-FutureTrueUxRestoreCurrentUserDryRun.ps1"
                reportType = "future-true-ux-restore-current-user-dry-run-validation"
                parameters = @("ManifestPath", "BaselinePath", "ReportPath")
            },
            [pscustomobject][ordered]@{
                gateId = "future-true-ux-scope-dry-run"
                path = "scripts/validate/Test-FutureTrueUxRestoreScopeDryRun.ps1"
                reportType = "future-true-ux-restore-scope-dry-run-validation"
                parameters = @("ManifestPath", "ReportPath")
            },
            [pscustomobject][ordered]@{
                gateId = "future-true-ux-authorization-review"
                path = "scripts/validate/Test-FutureTrueUxRestoreAuthorizationReview.ps1"
                reportType = "future-true-ux-restore-authorization-review-validation"
                parameters = @("ManifestPath", "ReportPath")
            },
            [pscustomobject][ordered]@{
                gateId = "future-true-ux-mock-review-drill"
                path = "scripts/validate/Test-FutureTrueUxRestoreMockReviewDrill.ps1"
                reportType = "future-true-ux-restore-mock-review-drill-validation"
                parameters = @("ManifestPath", "ReportPath")
            },
            [pscustomobject][ordered]@{
                gateId = "future-true-ux-negative-review-drill"
                path = "scripts/validate/Test-FutureTrueUxRestoreNegativeReviewDrill.ps1"
                reportType = "future-true-ux-restore-negative-review-drill-validation"
                parameters = @("ManifestPath", "FixtureRoot", "ReportPath")
            },
            [pscustomobject][ordered]@{
                gateId = "future-true-ux-approval-checklist-ergonomics"
                path = "scripts/validate/Test-FutureTrueUxRestoreApprovalChecklistErgonomics.ps1"
                reportType = "future-true-ux-restore-approval-checklist-ergonomics-validation"
                parameters = @("ManifestPath", "ReportPath")
            },
            [pscustomobject][ordered]@{
                gateId = "future-true-ux-integrated-packet-preview"
                path = "scripts/validate/Test-FutureTrueUxRestoreIntegratedPacketPreview.ps1"
                reportType = "future-true-ux-restore-integrated-packet-preview-validation"
                parameters = @("ManifestPath", "ReportPath")
            },
            [pscustomobject][ordered]@{
                gateId = "future-true-ux-human-authorization-handoff"
                path = "scripts/validate/Test-FutureTrueUxRestoreHumanAuthorizationHandoff.ps1"
                reportType = "future-true-ux-restore-human-authorization-handoff-validation"
                parameters = @("ManifestPath", "ReportPath")
            },
            [pscustomobject][ordered]@{
                gateId = "future-true-ux-end-to-end-no-execution-readiness-audit"
                path = "scripts/validate/Test-FutureTrueUxRestoreEndToEndNoExecutionReadinessAudit.ps1"
                reportType = "future-true-ux-restore-end-to-end-no-execution-readiness-audit-validation"
                parameters = @("ManifestPath", "ReportPath")
            },
            [pscustomobject][ordered]@{
                gateId = "future-true-ux-final-stop-line-handoff"
                path = "scripts/validate/Test-FutureTrueUxRestoreFinalStopLineHandoff.ps1"
                reportType = "future-true-ux-restore-final-stop-line-handoff-validation"
                parameters = @("ManifestPath", "ReportPath")
            }
        )

        $script:RepresentativeEntrypoints = @(
            "future-true-ux-restore-authorization",
            "future-true-ux-authorization-review",
            "future-true-ux-mock-review-drill",
            "future-true-ux-negative-review-drill",
            "future-true-ux-end-to-end-no-execution-readiness-audit",
            "future-true-ux-final-stop-line-handoff"
        )
    }

    It "keeps validate quality gate entrypoints and semantics stable" {
        Assert-KitEqual @($script:ValidatorEntrypoints).Count 11

        foreach ($expected in $script:ValidatorEntrypoints) {
            $gate = @($script:QualityGates.gates | Where-Object { $_.id -eq $expected.gateId })[0]
            Assert-KitNotNullOrEmpty $gate
            Assert-FutureTrueUxQualityGateSemantics -Gate $gate -RepoRoot $script:RepoRoot
            Assert-FutureTrueUxQualityGateEntrypointStable -Gate $gate -ExpectedId $expected.gateId -ExpectedEntrypoint $expected.path
            Assert-FutureTrueUxValidatorEntrypointExists -RepoRoot $script:RepoRoot -RelativePath $expected.path
        }
    }

    It "keeps validator CLI parameter names unchanged" {
        foreach ($expected in $script:ValidatorEntrypoints) {
            $content = Get-Content -LiteralPath (Join-Path $script:RepoRoot $expected.path) -Raw -Encoding UTF8

            foreach ($parameterName in @($expected.parameters)) {
                Assert-KitMatch $content ("\[string\]\$" + [regex]::Escape($parameterName) + "(\s|,|=)")
            }
        }
    }

    It "uses shared validator primitives without inline report writes" {
        $primitivePath = "scripts/common/FutureTrueUxRestore.ValidatorPrimitives.ps1"
        $primitiveContent = Get-Content -LiteralPath (Join-Path $script:RepoRoot $primitivePath) -Raw -Encoding UTF8

        foreach ($functionName in @(
            "Get-FutureTrueUxRestoreValidatorRepoRoot",
            "New-FutureTrueUxRestoreValidatorState",
            "Read-FutureTrueUxRestoreValidatorJson",
            "Add-FutureTrueUxRestoreValidatorFailure",
            "Add-FutureTrueUxRestoreValidatorCheck",
            "Get-FutureTrueUxRestoreValidatorStatus",
            "Get-FutureTrueUxRestoreValidatorFailureCount",
            "Write-FutureTrueUxRestoreValidatorReport",
            "Complete-FutureTrueUxRestoreValidatorRun"
        )) {
            Assert-KitMatch $primitiveContent ("function\s+" + [regex]::Escape($functionName))
        }

        Assert-KitMatch $primitiveContent ([regex]::Escape('Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $RepoRoot -Path $ReportPath'))
        Assert-KitMatch $primitiveContent ([regex]::Escape('$ReportObject | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8'))
        Assert-KitMatch $primitiveContent ([regex]::Escape('New-Item -ItemType Directory -Path $reportDirectory -Force'))

        foreach ($expected in $script:ValidatorEntrypoints) {
            $content = Get-Content -LiteralPath (Join-Path $script:RepoRoot $expected.path) -Raw -Encoding UTF8
            Assert-FutureTrueUxNoDangerousCommands -Content $content
            Assert-FutureTrueUxValidatorUsesSharedPrimitives -Content $content
            Assert-FutureTrueUxValidatorNoInlineReportWrites -Content $content
        }
    }

    It "writes representative validator reports only to the caller-provided .tmp report path" {
        foreach ($gateId in $script:RepresentativeEntrypoints) {
            $expected = @($script:ValidatorEntrypoints | Where-Object { $_.gateId -eq $gateId })[0]
            $fileName = ($expected.path -replace '^scripts/validate/', '') -replace '\.ps1$', '.json'
            $relativeReportPath = ".tmp/future-true-ux-validator-entrypoints-119-pester/$($script:SmokeRunId)/$fileName"

            $result = Invoke-FutureTrueUxValidatorSmoke -RepoRoot $script:RepoRoot -RelativePath $expected.path -ReportPath $relativeReportPath
            Assert-FutureTrueUxValidatorReportShape -Report $result.report -ExpectedReportType $expected.reportType
            Assert-KitMatch $result.reportPath ([regex]::Escape((Join-Path $script:RepoRoot ".tmp\future-true-ux-validator-entrypoints-119-pester")))
        }
    }

    It "keeps entrypoint consolidation files tracked by Build Lock" {
        $expectedPaths = @(
            "docs/archive/future-true-ux-restore/00-governance/112-future-true-ux-validator-script-governance.md",
            "scripts/common/FutureTrueUxRestore.ValidatorPrimitives.ps1",
            "tests/pester/FutureTrueUxPesterHelpers.ps1",
            "tests/pester/FutureTrueUxValidatorEntrypointConsolidation.Tests.ps1",
            "tests/pester/FutureTrueUxValidatorScriptGovernance.Tests.ps1"
        ) + @($script:ValidatorEntrypoints.path)

        foreach ($path in $expectedPaths) {
            Assert-FutureTrueUxBuildLockTracksPath -BuildLock $script:BuildLock -Path $path
        }
    }
}
