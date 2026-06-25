Describe "Build lock schema" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Get-KitBuildLock.ps1")
        $script:ManifestPath = Join-Path $script:RepoRoot "manifests\build-lock.json"
        $script:SchemaPath = Join-Path $script:RepoRoot "schemas\build-lock.schema.json"
    }

    It "has build lock manifest and schema files" {
        Assert-KitEqual (Test-Path -LiteralPath $script:ManifestPath) $true
        Assert-KitEqual (Test-Path -LiteralPath $script:SchemaPath) $true
    }

    It "keeps schema objects closed and required fields complete" {
        $schema = Get-Content -LiteralPath $script:SchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-KitEqual $schema.additionalProperties $false
        Assert-KitEqual $schema.'$defs'.entry.additionalProperties $false
        Assert-KitEqual $schema.'$defs'.policy.additionalProperties $false

        foreach ($name in @("lockVersion", "algorithm", "mode", "entries", "watchGlobs", "policy")) {
            Assert-KitEqual (@($schema.required) -contains $name) $true
        }

        foreach ($name in @("path", "category", "required", "hash", "reason")) {
            Assert-KitEqual (@($schema.'$defs'.entry.required) -contains $name) $true
        }
    }

    It "restricts algorithm, category, hash, and policy values" {
        $schema = Get-Content -LiteralPath $script:SchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual ((@($schema.properties.algorithm.enum) -join ",") -eq "SHA256") $true
        foreach ($category in @("manifest", "schema", "script", "test", "doc", "workflow", "config")) {
            Assert-KitEqual (@($schema.'$defs'.category.enum) -contains $category) $true
        }
        Assert-KitEqual $schema.'$defs'.entry.properties.hash.pattern "^[A-Fa-f0-9]{64}$"
        Assert-KitEqual ((@($schema.'$defs'.policyValue.enum) -join ",") -eq "pass,manual,fail") $true
    }

    It "includes build lock in project config and capability registry" {
        $scriptText = Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\validate\Test-ProjectConfig.ps1") -Raw -Encoding UTF8
        $registry = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\capability-registry.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $capability = @($registry.capabilities | Where-Object { $_.id -eq "immutable-build-lock" })[0]

        Assert-KitMatch $scriptText "build-lock\.json"
        Assert-KitMatch $scriptText "build-lock\.schema\.json"
        Assert-KitEqual $capability.issue "#12"
        Assert-KitEqual $capability.manifest "manifests/build-lock.json"
        Assert-KitEqual $capability.schema "schemas/build-lock.schema.json"
    }

    It "loads the checked-in build lock and rejects duplicate entry paths" {
        $lock = Get-KitBuildLock -Path "manifests/build-lock.json" -RepoRoot $script:RepoRoot
        Assert-KitEqual $lock.lockVersion 1
        Assert-KitEqual $lock.algorithm "SHA256"
        Assert-KitEqual (@($lock.entries).Count -ge 12) $true

        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-build-lock-schema-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory((Join-Path $tempRoot "manifests")) | Out-Null
        $badLockPath = Join-Path $tempRoot "manifests\build-lock.json"
        try {
            ([ordered]@{
                lockVersion = 1
                algorithm = "SHA256"
                mode = "verify"
                entries = @(
                    [ordered]@{ path = "a.txt"; category = "config"; required = $true; hash = ("0" * 64); reason = "fixture" },
                    [ordered]@{ path = "a.txt"; category = "config"; required = $true; hash = ("0" * 64); reason = "fixture" }
                )
                watchGlobs = @()
                policy = [ordered]@{ missingRequired = "fail"; hashMismatch = "fail"; untrackedWatchedFile = "manual"; unsupportedAlgorithm = "fail" }
            }) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $badLockPath -Encoding UTF8

            Assert-KitThrows -ScriptBlock {
                Get-KitBuildLock -Path $badLockPath -RepoRoot $tempRoot | Out-Null
            } -ExpectedMessage "duplicate build lock entry path"
        } finally {
            if ([IO.Directory]::Exists($tempRoot)) {
                [IO.Directory]::Delete($tempRoot, $true)
            }
        }
    }
}
