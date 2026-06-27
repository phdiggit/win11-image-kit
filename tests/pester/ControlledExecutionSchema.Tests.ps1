Describe "Controlled execution schema and manifest" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "parses the manifest and schemas as JSON" {
        foreach ($path in @(
            "manifests\controlled-execution.json",
            "schemas\controlled-execution.schema.json",
            "schemas\controlled-execution-report.schema.json",
            "schemas\winpe-disk-identity.schema.json",
            "schemas\confirmation-token.schema.json",
            "schemas\wim-image-metadata.schema.json",
            "schemas\winre-plan.schema.json",
            "schemas\native-command-plan.schema.json",
            "schemas\controlled-execution-authorization.schema.json",
            "schemas\native-command-simulation.schema.json"
        )) {
            $json = Get-Content -LiteralPath (Join-Path $script:RepoRoot $path) -Raw -Encoding UTF8 | ConvertFrom-Json
            Assert-KitNotNullOrEmpty $json
        }
    }

    It "uses closed schemas and excludes default true execution" {
        $manifestSchema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\controlled-execution.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $reportSchema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\controlled-execution-report.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $manifestSchema.additionalProperties $false
        Assert-KitEqual $manifestSchema.'$defs'.action.additionalProperties $false
        Assert-KitEqual $manifestSchema.'$defs'.safety.additionalProperties $false
        Assert-KitEqual $reportSchema.additionalProperties $false
        Assert-KitEqual $reportSchema.'$defs'.action.additionalProperties $false
        Assert-KitEqual $reportSchema.'$defs'.inputs.additionalProperties $false
        Assert-KitEqual $manifestSchema.properties.allowTrueExecution.const $false

        $modes = @($manifestSchema.'$defs'.executionMode.enum)
        if ($modes -contains "controlled-real" -or $modes -contains "true-execution") {
            throw "Issue 17 baseline schema must not allow true execution modes."
        }
    }

    It "keeps the checked-in manifest in dry-run mode with true execution disabled" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\controlled-execution.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $manifest.defaultMode "dry-run"
        Assert-KitEqual $manifest.allowTrueExecution $false
        Assert-KitEqual $manifest.safety.trueExecutionDefault $false
        Assert-KitEqual $manifest.safety.allowDiskMutation $false
        Assert-KitEqual $manifest.safety.allowNetworkDownload $false
    }
}
