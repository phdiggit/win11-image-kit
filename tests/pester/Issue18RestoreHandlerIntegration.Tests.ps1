Describe "Issue 18 restore handler integration" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "keeps docs/61 accepted and ready for manual closure" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-18\61-issue18-restore-handler-integration.md") -Raw -Encoding UTF8
        Assert-KitMatch $doc 'Status: `accepted-ready-for-manual-closure`'
        Assert-KitMatch $doc "report-only"
        Assert-KitMatch $doc "post-PR #96 main/workflow Full Validate success"
        Assert-KitMatch $doc "handler report.*real UX restore evidence"

        $docs = @(Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "docs") -File | Where-Object {
            $_.Name -match "issue18" -and $_.Name -match "completion-summary"
        })
        Assert-KitEqual $docs.Count 0
    }

    It "keeps customization scope UX restore semantics locked down" {
        $scope = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\customization-scope.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $scope.userExperienceRestore.defaultMode "plan-only"
        Assert-KitEqual $scope.userExperienceRestore.defaultUserIsCurrentUser $false
        Assert-KitEqual $scope.userExperienceRestore.offlineImageIsCurrentMachine $false
        Assert-KitEqual $scope.userExperienceRestore.allowRegistryMutation $false
        Assert-KitEqual $scope.userExperienceRestore.allowProfileMutation $false
        Assert-KitEqual $scope.userExperienceRestore.allowDefaultAppMutation $false
        Assert-KitEqual $scope.userExperienceRestore.allowStartMenuMutation $false
        Assert-KitEqual $scope.userExperienceRestore.allowTaskbarMutation $false
    }

    It "keeps metadata files parseable and generic" {
        foreach ($path in @(
            "configs\default-apps\default-apps.metadata.json",
            "configs\start-menu\start-menu.metadata.json"
        )) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $path) -Raw -Encoding UTF8
            $metadata = $text | ConvertFrom-Json
            Assert-KitEqual ([string]::IsNullOrWhiteSpace([string]$metadata.sourceWindows.buildNumber)) $false
            Assert-KitNotMatch $text "C:\\Users\\|\\\\192\\.168\\.1\\.37"
        }
    }
}
