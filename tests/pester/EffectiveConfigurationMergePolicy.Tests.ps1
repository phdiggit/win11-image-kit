Describe "Effective configuration merge policy" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Resolve-KitPath.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Resolve-KitEffectiveConfiguration.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-effective-merge-{0}" -f ([guid]::NewGuid().ToString("N")))
        New-Item -ItemType Directory -Path (Join-Path $script:TempRoot "manifests") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TempRoot "profiles") -Force | Out-Null
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:TempRoot) {
            Remove-Item -LiteralPath $script:TempRoot -Recurse -Force
        }
    }

    It "deep merges objects, replaces arrays and scalars, and removes null values" {
        @{
            manifestVersion = 1
            mergePolicy = @{ object = "deep-merge"; array = "replace"; scalar = "replace"; null = "remove" }
            layers = @(
                @{ id = "repo-default"; kind = "repo-default"; required = $true; tracked = $true; path = "manifests/base.json"; schema = "schemas/config-layer-fragment.schema.json"; description = "base" },
                @{ id = "profile-default"; kind = "profile"; required = $true; tracked = $true; path = "profiles/default.json"; schema = "schemas/config-layer-fragment.schema.json"; description = "profile" }
            )
            stacks = @(@{ name = "default"; layers = @("repo-default", "profile-default"); description = "default" })
            localOverrideLayer = "local-private"
            safety = @{ allowedPathTokens = @("Root", "WorkRoot"); forbiddenPathPatterns = @(); forbidTrackedLocalOverrides = $true }
        } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $script:TempRoot "manifests/config-layers.json") -Encoding UTF8

        @{
            layerId = "repo-default"
            paths = @{ Root = "C:\base"; WorkRoot = '${Root}\work' }
            settings = @{
                nested = @{ keep = "base"; replace = "base"; remove = "gone" }
                list = @("base-a", "base-b")
                scalar = "base"
            }
        } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $script:TempRoot "manifests/base.json") -Encoding UTF8

        @{
            layerId = "profile-default"
            paths = @{ WorkRoot = '${Root}\profile-work' }
            settings = @{
                nested = @{ replace = "profile"; remove = $null; add = "profile" }
                list = @("profile-only")
                scalar = "profile"
            }
        } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $script:TempRoot "profiles/default.json") -Encoding UTF8

        $report = Resolve-KitEffectiveConfiguration -ConfigLayersPath "manifests/config-layers.json" -RepoRoot $script:TempRoot

        Assert-KitEqual $report.configuration.settings.nested.keep "base"
        Assert-KitEqual $report.configuration.settings.nested.replace "profile"
        Assert-KitEqual $report.configuration.settings.nested.add "profile"
        Assert-KitEqual ($report.configuration.settings.nested.PSObject.Properties.Name -contains "remove") $false
        Assert-KitEqual (@($report.configuration.settings.list).Count) 1
        Assert-KitEqual (@($report.configuration.settings.list)[0]) "profile-only"
        Assert-KitEqual $report.configuration.settings.scalar "profile"
        Assert-KitEqual (@($report.pathSources | Where-Object { $_.key -eq "WorkRoot" })[0].sourceLayer) "profile-default"
    }
}
