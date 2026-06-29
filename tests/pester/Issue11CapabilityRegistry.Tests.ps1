Describe "Issue 11 capability registry guardrails" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Get-KitCapabilityRegistry.ps1")
    }

    It "documents the capability registry and links it from README" {
        $docPath = Join-Path $script:RepoRoot "docs\archive\completed-roadmap\issue-11\28-issue11-capability-registry.md"
        $readmePath = Join-Path $script:RepoRoot "README.md"

        Assert-KitEqual (Test-Path -LiteralPath $docPath) $true
        $doc = Get-Content -LiteralPath $docPath -Raw -Encoding UTF8
        $readme = Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8

        foreach ($term in @("capability registry", "mutationLevel", "context", "Test-CapabilityRegistry.ps1", "PR Fast CI Boundary")) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }
        Assert-KitMatch $readme "docs/archive/completed-roadmap/issue-11/28-issue11-capability-registry\.md"
    }

    It "wires Issue 11 tests into PR Fast CI" {
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
        foreach ($testPath in @(
            "tests/pester/CapabilityRegistrySchema.Tests.ps1",
            "tests/pester/CapabilityRegistryConsistency.Tests.ps1",
            "tests/pester/CapabilityRegistryReport.Tests.ps1",
            "tests/pester/Issue11CapabilityRegistry.Tests.ps1"
        )) {
            Assert-KitMatch $workflow ([regex]::Escape($testPath))
        }
    }

    It "keeps active capability scripts free of real mutation commands and network access" {
        $files = @(
            "scripts\common\Get-KitCapabilityRegistry.ps1",
            "scripts\common\Test-KitCapabilityConsistency.ps1",
            "scripts\common\New-KitCapabilityConsistencyReport.ps1",
            "scripts\validate\Test-CapabilityRegistry.ps1"
        )

        foreach ($relativePath in $files) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $relativePath) -Raw -Encoding UTF8
            Assert-KitNotMatch $text "sysprep\.exe|Remove-AppxPackage|Remove-AppxProvisionedPackage|dism\s+/Remove"
            Assert-KitNotMatch $text "reg\s+load|reg\.exe\s+load|reg\s+unload|reg\.exe\s+unload"
            Assert-KitNotMatch $text "Set-ItemProperty\s+-Path\s+HKLM|Set-ItemProperty\s+-Path\s+HKCU"
            Assert-KitNotMatch $text "New-ItemProperty\s+-Path\s+HKLM|New-ItemProperty\s+-Path\s+HKCU"
            Assert-KitNotMatch $text "Invoke-WebRequest|Invoke-RestMethod|Start-BitsTransfer|gh\s+|curl\s+"
        }
    }

    It "records representative Issue 7 through Issue 10 capabilities" {
        $registry = Get-KitCapabilityRegistry -Path "manifests/capability-registry.json" -RepoRoot $script:RepoRoot
        $issues = @($registry.capabilities | ForEach-Object { [string]$_.issue })
        foreach ($issue in @("#7", "#8", "#9", "#10")) {
            Assert-KitEqual ($issues -contains $issue) $true
        }

        foreach ($capability in @($registry.capabilities)) {
            Assert-KitNotNullOrEmpty $capability.notes
            Assert-KitEqual ([string]$capability.mutationLevel -ne "unknown") $true
        }
    }

    It "does not contain issue-closing keywords aimed at issue 11" {
        $files = @(
            "docs\archive\completed-roadmap\issue-11\28-issue11-capability-registry.md",
            "tests\pester\Issue11CapabilityRegistry.Tests.ps1"
        )

        foreach ($relativePath in $files) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $relativePath) -Raw -Encoding UTF8
            Assert-KitNotMatch $text "(?i)\b(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\s+#11\b"
        }
    }
}
