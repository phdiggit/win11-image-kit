Describe "Issue 17 controlled execution hardening acceptance" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "adds docs/54 as in-acceptance and keeps docs/52 and docs/53 staged" {
        $doc52 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\52-issue17-controlled-execution-intake.md") -Raw -Encoding UTF8
        $doc53 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\53-issue17-controlled-execution-acceptance.md") -Raw -Encoding UTF8
        $doc54 = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\54-issue17-controlled-execution-safety-hardening.md") -Raw -Encoding UTF8

        Assert-KitMatch $doc52 'Status: `in-progress`'
        Assert-KitMatch $doc53 'Status: `in-acceptance`'
        Assert-KitMatch $doc54 'Status: `in-acceptance`'
        Assert-KitNotMatch $doc54 'ready-for-manual-closure'
    }

    It "does not create Issue 17 close-prep, main-evidence, or completion summary" {
        foreach ($path in @(
            "docs\55-issue17-close-preparation.md",
            "docs\55-issue17-main-validation-evidence.md",
            "docs\55-issue17-completion-summary.md",
            "docs\56-issue17-close-preparation.md",
            "docs\56-issue17-main-validation-evidence.md",
            "docs\56-issue17-completion-summary.md"
        )) {
            if (Test-Path -LiteralPath (Join-Path $script:RepoRoot $path)) {
                throw "Issue 17 closure document should not exist: $path"
            }
        }
    }

    It "keeps Quality Gates wired for hardening submodels" {
        $qualityGates = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $ids = @($qualityGates.gates.id)

        foreach ($id in @(
            "controlled-execution-disk-identity",
            "controlled-execution-confirmation-token",
            "controlled-execution-wim-plan",
            "controlled-execution-winre-plan",
            "controlled-execution-native-command"
        )) {
            Assert-KitEqual ($ids -contains $id) $true
        }
    }
}
