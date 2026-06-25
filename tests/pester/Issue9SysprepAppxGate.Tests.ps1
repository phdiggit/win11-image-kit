$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Issue 9 Sysprep AppX gate acceptance" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "includes the Issue 9 docs manifest schema and entrypoint files" {
        foreach ($relativePath in @(
            "docs\20-issue9-sysprep-appx-gate.md",
            "manifests\sysprep-appx-gate.json",
            "schemas\sysprep-appx-gate.schema.json",
            "scripts\common\Get-KitAppxInventory.ps1",
            "scripts\common\Test-KitSysprepAppxReadiness.ps1",
            "scripts\validate\Test-SysprepReadiness.ps1"
        )) {
            Assert-KitNotNullOrEmpty (Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot $relativePath) -ErrorAction SilentlyContinue)
        }
    }

    It "keeps the manifest schema closed to unknown and mutation fields" {
        $schema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\sysprep-appx-gate.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\sysprep-appx-gate.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $topProperties = @($schema.properties.PSObject.Properties.Name)
        $ruleAdditionalProperties = $schema.properties.rules.additionalProperties

        Assert-KitEqual $schema.additionalProperties $false
        Assert-KitEqual $ruleAdditionalProperties $false
        Assert-KitNotMatch ($topProperties -join ",") "remove|mutation|command|script"
        Assert-KitEqual $manifest.mode "audit"
        Assert-KitEqual $manifest.failurePolicy "fail"
    }

    It "does not add mutating Sysprep AppX or DISM calls to Issue 9 active scripts" {
        $activeText = @(
            (Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\common\Get-KitAppxInventory.ps1") -Raw -Encoding UTF8),
            (Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\common\Test-KitSysprepAppxReadiness.ps1") -Raw -Encoding UTF8),
            (Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\validate\Test-SysprepReadiness.ps1") -Raw -Encoding UTF8)
        ) -join "`n"

        Assert-KitNotMatch $activeText "sysprep\.exe"
        Assert-KitNotMatch $activeText "Remove-AppxPackage"
        Assert-KitNotMatch $activeText "Remove-AppxProvisionedPackage"
        Assert-KitNotMatch $activeText "DISM\s+.*Remove"
    }

    It "adds Issue 9 tests to PR Fast CI without admin requirements" {
        $ci = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8

        foreach ($path in @(
            "tests/pester/SysprepAppxInventory.Tests.ps1",
            "tests/pester/SysprepAppxReadiness.Tests.ps1",
            "tests/pester/SysprepAppxReport.Tests.ps1",
            "tests/pester/Issue9SysprepAppxGate.Tests.ps1"
        )) {
            Assert-KitMatch $ci ([regex]::Escape($path))
        }

        Assert-KitNotMatch $ci "RunAsAdministrator|Start-Process\s+.*-Verb\s+RunAs"
    }

    It "links the Issue 9 document from README" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8

        Assert-KitMatch $readme "20-issue9-sysprep-appx-gate\.md"
    }
}
