Describe "Effective configuration local override" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Resolve-KitPath.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Resolve-KitEffectiveConfiguration.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-effective-local-{0}" -f ([guid]::NewGuid().ToString("N")))
        New-Item -ItemType Directory -Path (Join-Path $script:TempRoot "manifests") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TempRoot "profiles") -Force | Out-Null
        $manifest = @{
            manifestVersion = 1
            mergePolicy = @{ object = "deep-merge"; array = "replace"; scalar = "replace"; null = "remove" }
            layers = @(
                @{ id = "repo-default"; kind = "repo-default"; required = $true; tracked = $true; path = "manifests/base.json"; schema = "schemas/config-layer-fragment.schema.json"; description = "base" },
                @{ id = "profile-default"; kind = "profile"; required = $true; tracked = $true; path = "profiles/default.json"; schema = "schemas/config-layer-fragment.schema.json"; description = "profile" },
                @{ id = "local-private"; kind = "local"; required = $false; tracked = $false; path = "manifests/paths.local.json"; schema = "schemas/config-layer-fragment.schema.json"; description = "local" }
            )
            stacks = @(@{ name = "default"; layers = @("repo-default", "profile-default"); description = "default" })
            localOverrideLayer = "local-private"
            safety = @{ allowedPathTokens = @("Root", "ToolRoot"); forbiddenPathPatterns = @(); forbidTrackedLocalOverrides = $true }
        }
        $manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $script:TempRoot "manifests/config-layers.json") -Encoding UTF8
        @{ layerId = "repo-default"; paths = @{ Root = "C:\base"; ToolRoot = "C:\tools" } } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $script:TempRoot "manifests/base.json") -Encoding UTF8
        @{ layerId = "profile-default"; paths = @{} } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $script:TempRoot "profiles/default.json") -Encoding UTF8
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:TempRoot) {
            Remove-Item -LiteralPath $script:TempRoot -Recurse -Force
        }
    }

    It "warns but does not fail when IncludeLocal has no local file" {
        $reportPath = Join-Path $script:TempRoot "local-missing-report.json"
        & (Join-Path $script:RepoRoot "scripts\validate\Test-EffectiveConfiguration.ps1") -ConfigLayersPath (Join-Path $script:TempRoot "manifests/config-layers.json") -RepoRoot $script:TempRoot -IncludeLocal -ReportPath $reportPath
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $report.failedCount 0
        Assert-KitMatch ((@($report.effectiveConfiguration.warnings)) -join "`n") "Optional configuration layer is missing"
    }

    It "applies present local override and supports redacted report values" {
        @{ layerId = "local-private"; paths = @{ ToolRoot = "E:\private-tools" } } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $script:TempRoot "manifests/paths.local.json") -Encoding UTF8
        $report = Resolve-KitEffectiveConfiguration -ConfigLayersPath "manifests/config-layers.json" -RepoRoot $script:TempRoot -IncludeLocal -RedactLocalValues
        $toolRoot = @($report.pathSources | Where-Object { $_.key -eq "ToolRoot" })[0]

        Assert-KitEqual $toolRoot.sourceLayer "local-private"
        Assert-KitEqual $toolRoot.value "E:\private-tools"
        Assert-KitEqual $toolRoot.redactedValue "<redacted>"
    }

    It "fails when local override is malformed" {
        Set-Content -LiteralPath (Join-Path $script:TempRoot "manifests/paths.local.json") -Encoding UTF8 -Value "{ bad json"

        Assert-KitThrows {
            Resolve-KitEffectiveConfiguration -ConfigLayersPath "manifests/config-layers.json" -RepoRoot $script:TempRoot -IncludeLocal | Out-Null
        }
    }

    It "keeps real local override out of Build Lock required entries" {
        $gitignore = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".gitignore") -Raw -Encoding UTF8
        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $paths = @($buildLock.entries.path)

        Assert-KitMatch $gitignore "manifests/paths\.local\.json"
        Assert-KitEqual ($paths -contains "manifests/paths.local.json") $false
        Assert-KitEqual ($paths -contains "manifests/paths.local.example.json") $true
    }
}
