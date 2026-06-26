Describe "Customization scope effective configuration metadata" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:Scope = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\customization-scope.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:Schema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\customization-scope.schema.json") -Raw -Encoding UTF8
        $script:ConfigLayers = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\config-layers.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    }

    It "keeps pathsManifest and adds optional layered configuration references" {
        Assert-KitEqual $script:Scope.pathsManifest "manifests/paths.json"
        Assert-KitEqual $script:Scope.configLayersManifest "manifests/config-layers.json"
        Assert-KitEqual $script:Scope.defaultStack "default"
        Assert-KitMatch $script:Schema '"pathsManifest"'
        Assert-KitMatch $script:Schema '"configLayersManifest"'
        Assert-KitMatch $script:Schema '"defaultStack"'
    }

    It "points defaultStack at an existing config layer stack" {
        $stackNames = @($script:ConfigLayers.stacks | ForEach-Object { [string]$_.name })
        Assert-KitEqual ($stackNames -contains [string]$script:Scope.defaultStack) $true
    }

    It "keeps local private override out of tracked required policy and keeps the example safe" {
        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $paths = @($buildLock.entries | Where-Object { $_.required } | ForEach-Object { [string]$_.path })
        $example = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\paths.local.example.json") -Raw -Encoding UTF8

        Assert-KitEqual ($paths -contains "manifests/paths.local.json") $false
        Assert-KitEqual ($paths -contains "manifests/paths.local.example.json") $true
        Assert-KitNotMatch $example "\\\\192\.168\.1\.37"
        Assert-KitNotMatch $example "(?i)(token|secret|password|apikey|api_key)"
    }

    It "has project config validation checks for layered references" {
        $scriptText = Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\validate\Test-ProjectConfig.ps1") -Raw -Encoding UTF8

        Assert-KitMatch $scriptText "Test-ConfigLayersReference"
        Assert-KitMatch $scriptText "configLayersManifest"
        Assert-KitMatch $scriptText "defaultStack"
        Assert-KitMatch $scriptText "Build Lock required entries"
    }
}
