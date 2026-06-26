Describe "Effective configuration validation" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "validates default stack and writes failedCount zero report" {
        $reportPath = Join-Path ([IO.Path]::GetTempPath()) ("effective-config-validation-{0}.json" -f ([guid]::NewGuid().ToString("N")))
        try {
            & (Join-Path $script:RepoRoot "scripts\validate\Test-EffectiveConfiguration.ps1") -ReportPath $reportPath
            $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

            Assert-KitEqual $report.reportType "effective-configuration-validation"
            Assert-KitEqual $report.failedCount 0
            Assert-KitEqual $report.effectiveConfiguration.reportType "effective-configuration"
        } finally {
            if (Test-Path -LiteralPath $reportPath) {
                Remove-Item -LiteralPath $reportPath -Force
            }
        }
    }

    It "keeps runner scripts report-only and free of mutation or network commands" {
        $scriptText = @(
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\common\Resolve-KitEffectiveConfiguration.ps1") -Raw -Encoding UTF8
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\config\Show-EffectiveConfiguration.ps1") -Raw -Encoding UTF8
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "scripts\validate\Test-EffectiveConfiguration.ps1") -Raw -Encoding UTF8
        ) -join "`n"

        foreach ($pattern in @(
            "\bInvoke-WebRequest\b",
            "\bInvoke-RestMethod\b",
            "\bStart-Service\b",
            "\bStop-Service\b",
            "\bNew-Service\b",
            "\bRemove-Service\b",
            "\bSet-ItemProperty\b",
            "\bNew-ItemProperty\b",
            "\bRemove-ItemProperty\b",
            "\bGet-AppxPackage\b",
            "\bRemove-AppxPackage\b",
            "\bAdd-MpPreference\b",
            "\bRemove-MpPreference\b",
            "\bDISM\b",
            "\bsysprep\b",
            "\bwinget\b",
            "\bchoco\b",
            "\bInstall-Module\b"
        )) {
            Assert-KitNotMatch $scriptText $pattern
        }
    }
}
