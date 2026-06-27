Describe "User experience restore schema" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "keeps the manifest and schemas parseable and closed" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\user-experience-restore.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $schema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\user-experience-restore.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $reportSchema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\user-experience-restore-report.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $manifest.defaultMode "plan-only"
        Assert-KitEqual $manifest.allowProfileMutation $false
        Assert-KitEqual $manifest.allowRegistryMutation $false
        Assert-KitEqual $manifest.allowDefaultAppMutation $false
        Assert-KitEqual $schema.additionalProperties $false
        Assert-KitEqual $schema.'$defs'.plan.additionalProperties $false
        Assert-KitEqual $reportSchema.additionalProperties $false
        Assert-KitEqual $reportSchema.'$defs'.summary.additionalProperties $false
    }
}
