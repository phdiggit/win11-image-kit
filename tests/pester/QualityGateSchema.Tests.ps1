Describe "Quality gate schema" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "keeps the quality gate manifest closed and explicit" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\quality-gates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $schema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\quality-gates.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $gateSchema = $schema.defs.gate
        if ($null -eq $gateSchema) {
            $gateSchema = $schema.'$defs'.gate
        }

        Assert-KitEqual $manifest.manifestVersion 1
        Assert-KitEqual $schema.additionalProperties $false
        Assert-KitEqual $gateSchema.additionalProperties $false

        foreach ($name in @("id", "displayName", "layer", "trigger", "mode", "required", "blocking", "entrypoint", "evidence", "notes")) {
            Assert-KitEqual (@($gateSchema.required) -contains $name) $true
        }

        foreach ($gate in @($manifest.gates)) {
            Assert-KitMatch $gate.id "^[a-z0-9]+(-[a-z0-9]+)*$"
            Assert-KitEqual ([string]::IsNullOrWhiteSpace($gate.entrypoint)) $false
            Assert-KitEqual ([string]::IsNullOrWhiteSpace($gate.notes)) $false
        }
    }

    It "registers quality gates in project config validation" {
        $validator = Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\validate\Test-ProjectConfig.ps1") -Raw -Encoding UTF8

        Assert-KitMatch $validator "quality-gates\.json"
        Assert-KitMatch $validator "quality-gates\.schema\.json"
    }
}
