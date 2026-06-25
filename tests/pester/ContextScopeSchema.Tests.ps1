Describe "Context scope schema" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:ManifestPath = Join-Path $script:RepoRoot "manifests\context-scope.json"
        $script:SchemaPath = Join-Path $script:RepoRoot "schemas\context-scope.schema.json"
        $script:ValidationScript = Join-Path $script:RepoRoot "scripts\validate\Test-ProjectConfig.ps1"
        $script:ContextValidationScript = Join-Path $script:RepoRoot "scripts\validate\Test-ContextScope.ps1"
    }

    It "has manifest and schema files" {
        Assert-KitEqual (Test-Path -LiteralPath $script:ManifestPath) $true
        Assert-KitEqual (Test-Path -LiteralPath $script:SchemaPath) $true
    }

    It "restricts context, phase, target type, policy, and registry root enums" {
        $schema = Get-Content -LiteralPath $script:SchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-KitEqual ((@($schema.'$defs'.context.enum) -join ",") -eq "machine,default-user,current-user") $true
        Assert-KitEqual ((@($schema.'$defs'.phase.enum) -join ",") -eq "build,postdeploy,interactive,validate") $true
        Assert-KitEqual (@($schema.'$defs'.targetType.enum) -contains "unknown") $true
        Assert-KitEqual ((@($schema.'$defs'.mutationPolicy.enum) -join ",") -eq "planned,manual,blocked") $true
        Assert-KitEqual ((@($schema.'$defs'.target.properties.root.enum) -join ",") -eq "HKLM,HKU_DEFAULT,HKCU") $true
    }

    It "requires target identity, context, phase, policy, and reason" {
        $schema = Get-Content -LiteralPath $script:SchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $required = @($schema.'$defs'.target.required)

        foreach ($name in @("id", "context", "targetType", "phase", "mutationPolicy", "reason")) {
            Assert-KitEqual ($required -contains $name) $true
        }

        Assert-KitEqual $schema.additionalProperties $false
        Assert-KitEqual $schema.'$defs'.target.additionalProperties $false
    }

    It "rejects unknown top-level fields and missing target reason through the context validator" {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-context-schema-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
        $badManifest = Join-Path $tempRoot "context-scope.json"
        try {
            ([ordered]@{
                defaultMode = "plan"
                allowedContexts = @("machine")
                phasePolicy = [ordered]@{ build = @("machine") }
                unexpected = $true
                targets = @(
                    [ordered]@{
                        id = "bad"
                        context = "machine"
                        targetType = "registry"
                        root = "HKLM"
                        phase = "build"
                        mutationPolicy = "planned"
                    }
                )
            }) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $badManifest -Encoding UTF8

            Assert-KitThrows -ScriptBlock {
                & $script:ContextValidationScript -ManifestPath $badManifest -SchemaPath $script:SchemaPath -WhatIf | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    throw "context validation failed"
                }
            } -ExpectedMessage "context validation failed"
        } finally {
            if ([IO.Directory]::Exists($tempRoot)) {
                [IO.Directory]::Delete($tempRoot, $true)
            }
        }
    }

    It "includes context-scope in project config schema validation" {
        $scriptText = Get-Content -LiteralPath $script:ValidationScript -Raw -Encoding UTF8
        Assert-KitMatch $scriptText "context-scope\.json"
        Assert-KitMatch $scriptText "context-scope\.schema\.json"
    }
}
