Describe "Evidence chain schema and manifest" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "keeps evidence chain JSON parseable and schemas closed" {
        foreach ($relativePath in @(
            "manifests\evidence-chain.json",
            "schemas\evidence-chain.schema.json",
            "schemas\evidence-chain-report.schema.json"
        )) {
            Assert-KitDoesNotThrow {
                Get-Content -LiteralPath (Join-Path $script:RepoRoot $relativePath) -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null
            }
        }

        foreach ($schemaPath in @("schemas\evidence-chain.schema.json", "schemas\evidence-chain-report.schema.json")) {
            $schemaText = Get-Content -LiteralPath (Join-Path $script:RepoRoot $schemaPath) -Raw -Encoding UTF8
            $schema = $schemaText | ConvertFrom-Json
            Assert-KitEqual $schema.additionalProperties $false
            Assert-KitNotMatch $schemaText "https://json-schema.org"
        }
    }

    It "declares stable stages, modes, and unique producers without true execution" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\evidence-chain.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $schema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\evidence-chain.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $stageEnum = @($schema.'$defs'.stage.enum)
        $modeEnum = @($schema.'$defs'.mode.enum)
        $producerIds = @($manifest.producers.id)

        foreach ($stage in @("config", "validate", "build", "capture", "deploy", "acceptance")) {
            Assert-KitEqual ($stageEnum -contains $stage) $true
            Assert-KitEqual (@($manifest.stages) -contains $stage) $true
        }

        foreach ($mode in @("static", "fixture", "report-only", "manual")) {
            Assert-KitEqual ($modeEnum -contains $mode) $true
        }

        Assert-KitEqual ($modeEnum -contains "true-execution") $false
        Assert-KitEqual ($producerIds | Select-Object -Unique).Count $producerIds.Count

        foreach ($id in @("project-config", "build-lock", "quality-gates", "effective-configuration", "pester-summary", "real-build", "capture", "deploy", "admin-vm-smoke")) {
            Assert-KitEqual ($producerIds -contains $id) $true
        }
    }

    It "keeps producer entrypoints present or explicitly manual placeholders" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\evidence-chain.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        foreach ($producer in @($manifest.producers)) {
            if ([string]$producer.entrypoint -like "manual://*") {
                Assert-KitEqual ([string]$producer.mode) "manual"
            } else {
                Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot ([string]$producer.entrypoint))) $true
            }
        }
    }
}
