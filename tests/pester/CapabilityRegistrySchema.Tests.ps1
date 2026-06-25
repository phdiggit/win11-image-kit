Describe "Capability registry schema" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Get-KitCapabilityRegistry.ps1")
        $script:ManifestPath = Join-Path $script:RepoRoot "manifests\capability-registry.json"
        $script:SchemaPath = Join-Path $script:RepoRoot "schemas\capability-registry.schema.json"
    }

    It "has registry manifest and schema files" {
        Assert-KitEqual (Test-Path -LiteralPath $script:ManifestPath) $true
        Assert-KitEqual (Test-Path -LiteralPath $script:SchemaPath) $true
    }

    It "keeps schema objects closed and required fields complete" {
        $schema = Get-Content -LiteralPath $script:SchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-KitEqual $schema.additionalProperties $false
        Assert-KitEqual $schema.'$defs'.capability.additionalProperties $false

        foreach ($name in @("id", "issue", "status", "context", "mutationLevel", "manifest", "schema", "entrypoints", "validateEntrypoints", "tests", "docs", "notes")) {
            Assert-KitEqual (@($schema.'$defs'.capability.required) -contains $name) $true
        }
    }

    It "restricts status, context, mutation level, id, and issue formats" {
        $schema = Get-Content -LiteralPath $script:SchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual ((@($schema.'$defs'.status.enum) -join ",") -eq "planned,implemented,deprecated,static-only") $true
        Assert-KitEqual ((@($schema.'$defs'.context.enum) -join ",") -eq "machine,default-user,current-user,mixed,none") $true
        Assert-KitEqual (@($schema.'$defs'.mutationLevel.enum) -contains "real-mutation") $true
        Assert-KitEqual $schema.'$defs'.capability.properties.id.pattern "^[a-z0-9]+(-[a-z0-9]+)*$"
        Assert-KitEqual $schema.'$defs'.capability.properties.issue.pattern "^#[0-9]+$"
    }

    It "parses the registry and rejects duplicate capability ids through the loader" {
        $registry = Get-KitCapabilityRegistry -Path "manifests/capability-registry.json" -RepoRoot $script:RepoRoot
        Assert-KitEqual $registry.registryVersion 1
        Assert-KitEqual $registry.defaultValidationMode "static"
        Assert-KitEqual (@($registry.capabilities).Count -ge 4) $true

        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-capability-schema-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory((Join-Path $tempRoot "manifests")) | Out-Null
        $badRegistryPath = Join-Path $tempRoot "manifests\capability-registry.json"
        try {
            ([ordered]@{
                registryVersion = 1
                defaultValidationMode = "static"
                capabilities = @(
                    [ordered]@{ id = "duplicate"; issue = "#11"; status = "planned"; context = "none"; mutationLevel = "audit-only"; manifest = "manifests/a.json"; schema = "schemas/a.schema.json"; entrypoints = @(); validateEntrypoints = @(); tests = @(); docs = @(); notes = "planned" },
                    [ordered]@{ id = "duplicate"; issue = "#11"; status = "planned"; context = "none"; mutationLevel = "audit-only"; manifest = "manifests/b.json"; schema = "schemas/b.schema.json"; entrypoints = @(); validateEntrypoints = @(); tests = @(); docs = @(); notes = "planned" }
                )
            }) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $badRegistryPath -Encoding UTF8

            Assert-KitThrows -ScriptBlock {
                Get-KitCapabilityRegistry -Path $badRegistryPath -RepoRoot $tempRoot | Out-Null
            } -ExpectedMessage "duplicate capability id"
        } finally {
            if ([IO.Directory]::Exists($tempRoot)) {
                [IO.Directory]::Delete($tempRoot, $true)
            }
        }
    }

    It "includes capability registry in project config schema validation" {
        $scriptText = Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\validate\Test-ProjectConfig.ps1") -Raw -Encoding UTF8
        Assert-KitMatch $scriptText "capability-registry\.json"
        Assert-KitMatch $scriptText "capability-registry\.schema\.json"
    }
}
