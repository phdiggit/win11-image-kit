Describe "Effective configuration CLI override" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Resolve-KitPath.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Resolve-KitEffectiveConfiguration.ps1")
    }

    It "makes CLI explicit source win over hardware profile stack" {
        $report = Resolve-KitEffectiveConfiguration -StackName "air15" -RepoRoot $script:RepoRoot -PathOverride @{ ToolRoot = "D:\tools"; WorkRoot = "D:\work\cli" }
        $toolRoot = @($report.pathSources | Where-Object { $_.key -eq "ToolRoot" })[0]
        $workRoot = @($report.pathSources | Where-Object { $_.key -eq "WorkRoot" })[0]

        Assert-KitEqual $toolRoot.sourceLayer "cli-explicit"
        Assert-KitEqual $toolRoot.value "D:\tools"
        Assert-KitEqual $workRoot.sourceLayer "cli-explicit"
        Assert-KitEqual $workRoot.value "D:\work\cli"
        Assert-KitEqual (@($report.appliedLayers.id) -contains "cli-explicit") $true
    }

    It "validates PathOverrideJson through the CLI entrypoint" {
        $reportPath = Join-Path ([IO.Path]::GetTempPath()) ("effective-config-cli-{0}.json" -f ([guid]::NewGuid().ToString("N")))
        try {
            & (Join-Path $script:RepoRoot "scripts\validate\Test-EffectiveConfiguration.ps1") -StackName "air15" -PathOverrideJson '{"ToolRoot":"D:\\tools","DataRoot":"D:\\data"}' -ReportPath $reportPath
            $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $toolRoot = @($report.effectiveConfiguration.pathSources | Where-Object { $_.key -eq "ToolRoot" })[0]

            Assert-KitEqual $report.failedCount 0
            Assert-KitEqual $toolRoot.sourceLayer "cli-explicit"
            Assert-KitEqual $toolRoot.value "D:\tools"
        } finally {
            if (Test-Path -LiteralPath $reportPath) {
                Remove-Item -LiteralPath $reportPath -Force
            }
        }
    }
}
