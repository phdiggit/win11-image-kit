Describe "Issue 12 build lock acceptance" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitBuildLockReport.ps1")
    }

    It "documents acceptance scope, non-goals, matrix, update checklist, and CI boundary" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\33-issue12-build-lock-acceptance.md") -Raw -Encoding UTF8
        $statusMatch = [regex]::Match($doc, '(?m)^Status: `([^`]+)`')

        Assert-KitEqual $statusMatch.Success $true
        Assert-KitEqual (@("in-acceptance", "accepted-ready-for-manual-closure") -contains $statusMatch.Groups[1].Value) $true
        foreach ($term in @(
            "## Scope",
            "## Non-goals",
            "## Acceptance Matrix",
            "## Build Lock Update Checklist",
            "## CI Boundary",
            "docs/32",
            "32-issue12-build-lock.md"
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }

        if ($statusMatch.Groups[1].Value -eq "accepted-ready-for-manual-closure") {
            Assert-KitMatch $doc ([regex]::Escape("Close preparation and main validation evidence are recorded in docs/34 and docs/35."))
        }
    }

    It "keeps build lock manifest and schema strict" {
        $manifestPath = Join-Path $script:RepoRoot "manifests\build-lock.json"
        $schemaPath = Join-Path $script:RepoRoot "schemas\build-lock.schema.json"
        $schema = Get-Content -LiteralPath $schemaPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual (Test-Path -LiteralPath $manifestPath) $true
        Assert-KitEqual (Test-Path -LiteralPath $schemaPath) $true
        Assert-KitEqual $schema.additionalProperties $false
        Assert-KitEqual $schema.'$defs'.entry.additionalProperties $false
        Assert-KitEqual $schema.'$defs'.policy.additionalProperties $false

        foreach ($field in @("lockVersion", "algorithm", "mode", "entries", "watchGlobs", "policy")) {
            Assert-KitEqual (@($schema.required) -contains $field) $true
        }
        foreach ($field in @("path", "category", "required", "hash", "reason")) {
            Assert-KitEqual (@($schema.'$defs'.entry.required) -contains $field) $true
        }
        Assert-KitEqual ((@($schema.properties.algorithm.enum) -join ",") -eq "SHA256") $true
        foreach ($category in @("manifest", "schema", "script", "test", "doc", "workflow", "config")) {
            Assert-KitEqual (@($schema.'$defs'.category.enum) -contains $category) $true
        }
        Assert-KitEqual $schema.'$defs'.entry.properties.hash.pattern "^[A-Fa-f0-9]{64}$"
        Assert-KitEqual ((@($schema.'$defs'.policyValue.enum) -join ",") -eq "pass,manual,fail") $true
    }

    It "keeps active build lock code free of real build, mutation, and network access" {
        $files = @(
            "scripts\common\Get-KitFileHash.ps1",
            "scripts\common\Get-KitBuildLock.ps1",
            "scripts\common\Test-KitBuildLock.ps1",
            "scripts\common\New-KitBuildLockReport.ps1",
            "scripts\validate\Test-BuildLock.ps1"
        )

        foreach ($relativePath in $files) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $relativePath) -Raw -Encoding UTF8
            Assert-KitNotMatch $text "Invoke-WebRequest|Invoke-RestMethod|Start-BitsTransfer"
            Assert-KitNotMatch $text "Invoke-GoldenImageBuild|Invoke-PostDeploy|Start-Process\s+.*sysprep"
            Assert-KitNotMatch $text "sysprep\.exe|Remove-AppxPackage|Remove-AppxProvisionedPackage|dism\s+/Remove"
            Assert-KitNotMatch $text "reg\s+load|reg\.exe\s+load|reg\s+unload|reg\.exe\s+unload"
            Assert-KitNotMatch $text "Set-ItemProperty\s+-Path\s+HKLM|Set-ItemProperty\s+-Path\s+HKCU"
            Assert-KitNotMatch $text "New-ItemProperty\s+-Path\s+HKLM|New-ItemProperty\s+-Path\s+HKCU"
        }
    }

    It "preserves the build lock report field contract" {
        $lock = [pscustomobject]@{
            lockVersion = 1
            algorithm = "SHA256"
            mode = "verify"
            entries = @([pscustomobject]@{
                path = "docs/32-issue12-build-lock.md"
                category = "doc"
                required = $true
                hash = "9b724b7875c7a7a6d25bb8c7a4b349a9fdb2d82aa451ed5b06fe0615aa6cf940"
                reason = "fixture"
            })
            watchGlobs = @("docs/32-issue12-build-lock.md")
            policy = [pscustomobject]@{
                missingRequired = "fail"
                hashMismatch = "manual"
                untrackedWatchedFile = "manual"
                unsupportedAlgorithm = "fail"
            }
        }
        $report = New-KitBuildLockReport -BuildLock $lock -RepoRoot $script:RepoRoot -WhatIf

        foreach ($field in @("reportType", "status", "summary", "entries", "untrackedWatchedFiles", "algorithm", "mode", "whatIf")) {
            Assert-KitEqual ($null -ne $report.$field) $true
        }
        Assert-KitEqual $report.reportType "build-lock"
        Assert-KitEqual $report.whatIf $true
    }

    It "links acceptance docs from README and PR Fast CI" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8

        Assert-KitMatch $readme "docs/33-issue12-build-lock-acceptance\.md"
        foreach ($testPath in @(
            "tests/pester/BuildLockSchema.Tests.ps1",
            "tests/pester/BuildLockHash.Tests.ps1",
            "tests/pester/BuildLockValidation.Tests.ps1",
            "tests/pester/BuildLockReport.Tests.ps1",
            "tests/pester/Issue12BuildLock.Tests.ps1",
            "tests/pester/Issue12BuildLockAcceptance.Tests.ps1"
        )) {
            Assert-KitMatch $workflow ([regex]::Escape($testPath))
        }
    }
}
