Describe "Issue 12 build lock guardrails" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Get-KitBuildLock.ps1")
    }

    It "documents build lock and links it from README" {
        $docPath = Join-Path $script:RepoRoot "docs\32-issue12-build-lock.md"
        $readmePath = Join-Path $script:RepoRoot "README.md"

        Assert-KitEqual (Test-Path -LiteralPath $docPath) $true
        $doc = Get-Content -LiteralPath $docPath -Raw -Encoding UTF8
        $readme = Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8

        foreach ($term in @("trusted inputs ledger", "hash drift detection", "watched but untracked file warning", "report evidence", "Test-BuildLock.ps1")) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }
        foreach ($term in @("no network", "no signing", "no real build", "no automatic trust")) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }
        Assert-KitMatch $readme "docs/32-issue12-build-lock\.md"
    }

    It "wires Issue 12 tests into PR Fast CI" {
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
        foreach ($testPath in @(
            "tests/pester/BuildLockSchema.Tests.ps1",
            "tests/pester/BuildLockHash.Tests.ps1",
            "tests/pester/BuildLockValidation.Tests.ps1",
            "tests/pester/BuildLockReport.Tests.ps1",
            "tests/pester/Issue12BuildLock.Tests.ps1"
        )) {
            Assert-KitMatch $workflow ([regex]::Escape($testPath))
        }
    }

    It "keeps active build lock scripts free of real mutation commands and network access" {
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
            Assert-KitNotMatch $text "sysprep\.exe|Remove-AppxPackage|Remove-AppxProvisionedPackage|dism\s+/Remove"
            Assert-KitNotMatch $text "reg\s+load|reg\.exe\s+load|reg\s+unload|reg\.exe\s+unload"
            Assert-KitNotMatch $text "Set-ItemProperty\s+-Path\s+HKLM|Set-ItemProperty\s+-Path\s+HKCU"
            Assert-KitNotMatch $text "New-ItemProperty\s+-Path\s+HKLM|New-ItemProperty\s+-Path\s+HKCU"
        }
    }

    It "records immutable build lock as an audit-only capability" {
        $registry = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\capability-registry.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $capability = @($registry.capabilities | Where-Object { $_.id -eq "immutable-build-lock" })[0]

        Assert-KitEqual $capability.issue "#12"
        Assert-KitEqual $capability.context "none"
        Assert-KitEqual $capability.mutationLevel "audit-only"
        Assert-KitEqual (@($capability.validateEntrypoints) -contains "scripts/validate/Test-BuildLock.ps1") $true
        Assert-KitEqual (@($capability.docs) -contains "docs/32-issue12-build-lock.md") $true
    }

    It "keeps issue 12 docs free of auto-closing keyword references" {
        $files = @(
            "docs\32-issue12-build-lock.md",
            "tests\pester\Issue12BuildLock.Tests.ps1"
        )

        foreach ($relativePath in $files) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $relativePath) -Raw -Encoding UTF8
            Assert-KitNotMatch $text "(?i)\b(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+#12\b"
        }
    }
}
