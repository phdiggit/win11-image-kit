Describe "Future True UX presentation script governance" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "tests\pester\FutureTrueUxPesterHelpers.ps1")

        $script:QualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:BuildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        $script:PresentationEntrypoints = @(
            [pscustomobject][ordered]@{
                path = "scripts/config/Show-FutureTrueUxRestoreAuthorizationPlan.ps1"
                title = "Future true UX restore authorization intake plan"
                parameters = @("ManifestPath", "AuthorizationPath")
            },
            [pscustomobject][ordered]@{
                path = "scripts/config/Show-FutureTrueUxRestoreCurrentUserDryRunPlan.ps1"
                title = "Future true UX restore current-user dry-run plan"
                parameters = @("ManifestPath", "RequestPath")
            },
            [pscustomobject][ordered]@{
                path = "scripts/config/Show-FutureTrueUxRestoreScopeDryRunPlan.ps1"
                title = "Future true UX restore scope dry-run plan"
                parameters = @("ManifestPath")
            },
            [pscustomobject][ordered]@{
                path = "scripts/config/Show-FutureTrueUxRestoreAuthorizationReviewPlan.ps1"
                title = "Future true UX restore authorization review plan"
                parameters = @("ManifestPath", "RequestPath")
            },
            [pscustomobject][ordered]@{
                path = "scripts/config/Show-FutureTrueUxRestoreMockReviewDrillPlan.ps1"
                title = "Future true UX restore mock review drill plan"
                parameters = @("ManifestPath", "RequestPath")
            }
        )
    }

    It "keeps every Future True UX gate report-only and on existing entrypoints" {
        $futureGates = @($script:QualityGates.gates | Where-Object { $_.id -like "future-true-ux*" })
        Assert-KitEqual @($futureGates).Count 17

        foreach ($gate in $futureGates) {
            Assert-FutureTrueUxQualityGateSemantics -Gate $gate -RepoRoot $script:RepoRoot
        }
    }

    It "keeps show/config entrypoints and public parameters stable" {
        Assert-KitEqual @($script:PresentationEntrypoints).Count 5

        foreach ($entrypoint in $script:PresentationEntrypoints) {
            Assert-FutureTrueUxPresentationEntrypointExists -RepoRoot $script:RepoRoot -RelativePath $entrypoint.path
            $content = Get-Content -LiteralPath (Join-Path $script:RepoRoot $entrypoint.path) -Raw -Encoding UTF8

            foreach ($parameterName in @($entrypoint.parameters)) {
                Assert-KitMatch $content ("\[string\]\$" + [regex]::Escape($parameterName) + "(\s|,|=)")
            }
        }
    }

    It "uses shared presentation primitives and keeps scripts read-only" {
        $primitivePath = "scripts/common/FutureTrueUxRestore.PresentationPrimitives.ps1"
        $primitiveContent = Get-Content -LiteralPath (Join-Path $script:RepoRoot $primitivePath) -Raw -Encoding UTF8

        foreach ($functionName in @(
            "Get-FutureTrueUxRestorePresentationRepoRoot",
            "Resolve-FutureTrueUxRestorePresentationPath",
            "Read-FutureTrueUxRestorePresentationJson",
            "Write-FutureTrueUxRestorePresentationHeader",
            "Write-FutureTrueUxRestorePresentationLine",
            "Write-FutureTrueUxRestorePresentationList",
            "Write-FutureTrueUxRestorePresentationObjectProperties",
            "Write-FutureTrueUxRestorePresentationReportJson"
        )) {
            Assert-KitMatch $primitiveContent ("function\s+" + [regex]::Escape($functionName))
        }

        Assert-FutureTrueUxPresentationReadOnly -Content $primitiveContent
        Assert-KitMatch $primitiveContent "ConvertFrom-Json"
        Assert-KitMatch $primitiveContent "ConvertTo-Json"

        foreach ($entrypoint in $script:PresentationEntrypoints) {
            $content = Get-Content -LiteralPath (Join-Path $script:RepoRoot $entrypoint.path) -Raw -Encoding UTF8
            Assert-FutureTrueUxPresentationUsesSharedPrimitives -Content $content
            Assert-FutureTrueUxPresentationReadOnly -Content $content
        }
    }

    It "smoke-runs read-only presentation scripts with no true execution wording" {
        foreach ($entrypoint in $script:PresentationEntrypoints) {
            $result = Invoke-FutureTrueUxPresentationSmoke -RepoRoot $script:RepoRoot -RelativePath $entrypoint.path
            Assert-KitMatch $result.text ([regex]::Escape($entrypoint.title))
            Assert-KitMatch $result.text "True execution: false"
            Assert-KitMatch $result.text "Mutation count: 0"
            Assert-KitNotMatch $result.text "(?i)\btrue execution:\s*true\b"
            Assert-KitNotMatch $result.text "(?i)\b(Fixes|Closes|Resolves)\s+#19\b"
        }
    }

    It "keeps presentation governance files tracked by Build Lock" {
        $expectedPaths = @(
            "docs/archive/future-true-ux-restore/00-governance/112-future-true-ux-validator-script-governance.md",
            "scripts/common/FutureTrueUxRestore.PresentationPrimitives.ps1",
            "tests/pester/FutureTrueUxPesterHelpers.ps1",
            "tests/pester/FutureTrueUxPresentationGovernance.Tests.ps1"
        ) + @($script:PresentationEntrypoints.path)

        foreach ($path in $expectedPaths) {
            Assert-FutureTrueUxBuildLockTracksPath -BuildLock $script:BuildLock -Path $path
        }
    }
}
