Describe "User experience capability matrix" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitUserExperienceRestoreReport.ps1")

        $script:ReadJson = {
            param([string]$Path)
            Get-Content -LiteralPath (Join-Path $script:RepoRoot $Path) -Raw -Encoding UTF8 | ConvertFrom-Json
        }
    }

    It "passes supported Windows 11 capability fixtures" {
        foreach ($path in @(
            "tests\fixtures\user-experience\capability-matrix\windows-11-24h2-supported.json",
            "tests\fixtures\user-experience\capability-matrix\windows-11-23h2-supported.json"
        )) {
            $result = ConvertTo-KitUserExperienceCapabilityMatrix -InputObject (& $script:ReadJson $path)
            Assert-KitEqual $result.status "passed"
            Assert-KitEqual $result.unsupportedCapabilityCount 0
            Assert-KitEqual (@($result.capabilities | Where-Object { $_.executed }).Count) 0
        }
    }

    It "blocks unsupported feature and unsupported build fixtures" {
        foreach ($path in @(
            "tests\fixtures\user-experience\capability-matrix\unsupported-feature.json",
            "tests\fixtures\user-experience\capability-matrix\unsupported-build-feature.json"
        )) {
            $result = ConvertTo-KitUserExperienceCapabilityMatrix -InputObject (& $script:ReadJson $path)
            Assert-KitEqual $result.status "failed"
            if ($result.unsupportedCapabilityCount -lt 1) {
                throw "Expected unsupportedCapabilityCount to be greater than zero."
            }
        }
    }
}
