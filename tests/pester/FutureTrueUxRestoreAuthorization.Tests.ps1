Describe "Future true UX restore authorization intake" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-FutureTrueUxRestoreAuthorizationReport.ps1")
    }

    It "keeps authorization manifest default-deny" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $manifest.mode "authorization-intake"
        Assert-KitEqual $manifest.defaultDecision "blocked"
        foreach ($flagName in @("allowRegistryMutation", "allowProfileMutation", "allowDefaultUserHiveMutation", "allowDefaultAppMutation", "allowStartMenuMutation", "allowTaskbarMutation", "allowDismMutation", "allowAppxMutation", "allowNetworkDownload")) {
            Assert-KitEqual $manifest.$flagName $false
        }
        foreach ($field in @("scope", "targetIdentity", "mutationType", "rollbackPlan", "beforeEvidence", "afterEvidence", "independentVerification", "failurePropagation", "reviewCheckpoint")) {
            Assert-KitEqual (@($manifest.requiredAuthorizationFields) -contains $field) $true
        }
        Assert-KitEqual $manifest.currentUserDryRun.scope "current-user"
        Assert-KitEqual $manifest.currentUserDryRun.authorizationApproved $false
        Assert-KitEqual $manifest.currentUserDryRun.executionApproved $false
        Assert-KitEqual $manifest.currentUserDryRun.allowCurrentUserMutation $false
    }

    It "blocks baseline and unsafe authorization requests" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $baseline = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\user-experience\future-true-restore\authorization\baseline-blocked.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $report = New-FutureTrueUxRestoreAuthorizationReport -Manifest $manifest -AuthorizationRequest $baseline -RepoRoot $script:RepoRoot

        Assert-KitEqual $report.decision "blocked"
        Assert-KitEqual $report.trueExecution $false
        Assert-KitEqual $report.mutationCount 0
        Assert-KitEqual $report.commandExitCodeSufficient $false
        Assert-KitEqual $report.userConfigurationConfirmed $false
        Assert-KitEqual (@($report.missingAuthorizationFields).Count -gt 0) $true
    }

    It "allows only dry-run-ready when all required fields are present and safe" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\future-true-ux-restore-authorization.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $request = [pscustomobject]@{
            scope = "machine"
            targetIdentity = "machine:redacted"
            mutationType = "policy"
            expectedBeforeState = "fixture-before"
            allowedCommand = "future-approved-command-envelope"
            rollbackPlan = "fixture-rollback"
            beforeEvidence = "fixture-before-evidence"
            afterEvidence = "fixture-after-evidence"
            independentVerification = "fixture-independent-verification"
            failurePropagation = "stop-on-failure"
            reviewCheckpoint = "maintainer-review-required"
        }
        $report = New-FutureTrueUxRestoreAuthorizationReport -Manifest $manifest -AuthorizationRequest $request -RepoRoot $script:RepoRoot

        Assert-KitEqual $report.decision "dry-run-ready"
        Assert-KitEqual $report.trueExecution $false
        Assert-KitEqual $report.mutationCount 0
    }
}
