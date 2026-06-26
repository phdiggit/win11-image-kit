$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
. (Join-Path $RepoRoot "tests\pester\TestHelpers.ps1")

Describe "Issue 13 ensure-state guardrails" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "keeps docs and README entry wired" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\36-issue13-ensure-state.md") -Raw -Encoding UTF8

        Assert-KitMatch $readme "docs/36-issue13-ensure-state\.md"
        Assert-KitMatch $doc "fixture.*report-only"
        Assert-KitNotMatch $doc "(?i)closes #13|fixes #13|resolves #13"
    }

    It "keeps PR fast CI wired to the five issue 13 test files" {
        $ci = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8

        foreach ($path in @(
            "tests/pester/EnsureStateSchema.Tests.ps1",
            "tests/pester/EnsureStatePlan.Tests.ps1",
            "tests/pester/EnsureStateReport.Tests.ps1",
            "tests/pester/EnsureStateValidation.Tests.ps1",
            "tests/pester/Issue13EnsureState.Tests.ps1"
        )) {
            Assert-KitMatch $ci ([regex]::Escape($path))
        }
    }

    It "keeps ensure-state scripts free of real mutation and network commands" {
        $paths = @(
            "scripts/common/Resolve-KitSoftwareState.ps1",
            "scripts/common/Resolve-KitServiceState.ps1",
            "scripts/common/New-KitEnsureStatePlan.ps1",
            "scripts/common/Test-KitEnsureState.ps1",
            "scripts/common/New-KitEnsureStateReport.ps1",
            "scripts/validate/Test-EnsureState.ps1"
        )
        $text = foreach ($path in $paths) {
            Get-Content -LiteralPath (Join-Path $script:RepoRoot $path) -Raw -Encoding UTF8
        }
        $joined = $text -join "`n"

        foreach ($pattern in @(
            "Invoke-WebRequest",
            "Invoke-RestMethod",
            "Start-BitsTransfer",
            "winget install",
            "winget uninstall",
            "winget upgrade",
            "choco install",
            "choco uninstall",
            "msiexec /i",
            "msiexec /x",
            "Install-Package",
            "Uninstall-Package",
            "Set-Service",
            "Start-Service",
            "Stop-Service",
            "sc\.exe config",
            "sc\.exe delete",
            "reg load",
            "reg unload",
            "Set-ItemProperty",
            "New-ItemProperty"
        )) {
            Assert-KitNotMatch $joined $pattern
        }
    }
}
