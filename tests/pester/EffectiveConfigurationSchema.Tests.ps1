Describe "Effective configuration schema" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "uses local closed schemas and parseable layer manifests" {
        $schemaText = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\config-layers.schema.json") -Raw -Encoding UTF8
        $fragmentSchemaText = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\config-layer-fragment.schema.json") -Raw -Encoding UTF8
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\config-layers.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitNotMatch $schemaText "https?://"
        Assert-KitNotMatch $fragmentSchemaText "https?://"
        Assert-KitMatch $schemaText '"additionalProperties": false'
        Assert-KitMatch $fragmentSchemaText '"additionalProperties": false'
        Assert-KitEqual $manifest.mergePolicy.object "deep-merge"
        Assert-KitEqual $manifest.mergePolicy.array "replace"
        Assert-KitEqual $manifest.mergePolicy.scalar "replace"
        Assert-KitEqual $manifest.mergePolicy.null "remove"

        foreach ($layer in @($manifest.layers | Where-Object { $_.required })) {
            Assert-KitEqual (Test-Path -LiteralPath (Join-Path $script:RepoRoot $layer.path)) $true
        }
    }

    It "registers optional local override as untracked and ignored" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\config-layers.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $gitignore = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".gitignore") -Raw -Encoding UTF8
        $localLayer = @($manifest.layers | Where-Object { $_.id -eq $manifest.localOverrideLayer })[0]

        Assert-KitEqual $localLayer.required $false
        Assert-KitEqual $localLayer.tracked $false
        Assert-KitEqual $localLayer.path "manifests/paths.local.json"
        Assert-KitMatch $gitignore "manifests/paths\.local\.json"
    }
}
