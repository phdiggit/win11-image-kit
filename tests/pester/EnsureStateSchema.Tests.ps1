$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
. (Join-Path $RepoRoot "tests\pester\TestHelpers.ps1")

Describe "Ensure-State schema" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:SoftwareManifestPath = Join-Path $script:RepoRoot "manifests\software.json"
        $script:ServicesManifestPath = Join-Path $script:RepoRoot "manifests\services.json"
        $script:SoftwareSchemaPath = Join-Path $script:RepoRoot "schemas\software.schema.json"
        $script:ServicesSchemaPath = Join-Path $script:RepoRoot "schemas\services.schema.json"
    }

    It "keeps software and service manifest pairs present" {
        Assert-KitEqual (Test-Path -LiteralPath $script:SoftwareManifestPath) $true
        Assert-KitEqual (Test-Path -LiteralPath $script:ServicesManifestPath) $true
        Assert-KitEqual (Test-Path -LiteralPath $script:SoftwareSchemaPath) $true
        Assert-KitEqual (Test-Path -LiteralPath $script:ServicesSchemaPath) $true
    }

    It "closes schema objects and keeps required fields complete" {
        $softwareSchema = Get-Content -LiteralPath $script:SoftwareSchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $servicesSchema = Get-Content -LiteralPath $script:ServicesSchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $softwareSchema.additionalProperties $false
        Assert-KitEqual $softwareSchema.properties.software.items.additionalProperties $false
        Assert-KitEqual $servicesSchema.additionalProperties $false
        Assert-KitEqual $servicesSchema.properties.services.items.additionalProperties $false

        foreach ($name in @("manifestVersion", "software")) {
            Assert-KitEqual (@($softwareSchema.required) -contains $name) $true
        }
        foreach ($name in @("manifestVersion", "services")) {
            Assert-KitEqual (@($servicesSchema.required) -contains $name) $true
        }
    }

    It "keeps ensure-state enums aligned with the task card" {
        $softwareSchema = Get-Content -LiteralPath $script:SoftwareSchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $servicesSchema = Get-Content -LiteralPath $script:ServicesSchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual ((@($softwareSchema.properties.software.items.properties.ensure.enum) -join ",") -eq "present,absent,latest,pinned,manual") $true
        Assert-KitEqual ((@($softwareSchema.properties.software.items.properties.installMode.enum) -join ",") -eq "planned,manual,disabled") $true
        Assert-KitEqual ((@($servicesSchema.properties.services.items.properties.ensure.enum) -join ",") -eq "running,stopped,disabled,manual,absent,ignore") $true
        Assert-KitEqual ((@($servicesSchema.properties.services.items.properties.changeMode.enum) -join ",") -eq "planned,manual,disabled") $true
    }

    It "wires project config, capability registry, and build lock to issue 13 files" {
        $projectConfigText = Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\validate\Test-ProjectConfig.ps1") -Raw -Encoding UTF8
        $registry = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\capability-registry.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $buildLock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $capability = @($registry.capabilities | Where-Object { $_.id -eq "ensure-state-convergence" })[0]
        $paths = @($buildLock.entries.path) + @($buildLock.watchGlobs)

        Assert-KitMatch $projectConfigText "software\.json"
        Assert-KitMatch $projectConfigText "services\.json"
        Assert-KitEqual $capability.issue "#13"
        Assert-KitEqual ($paths -contains "scripts/validate/Test-EnsureState.ps1") $true
        Assert-KitEqual ($paths -contains "tests/pester/Issue13EnsureState.Tests.ps1") $true
        Assert-KitEqual ($paths -contains "docs/36-issue13-ensure-state.md") $true
    }
}
