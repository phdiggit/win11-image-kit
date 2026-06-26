Describe "Effective configuration report" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Resolve-KitPath.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Resolve-KitEffectiveConfiguration.ps1")
    }

    It "resolves default stack without changing current single-file defaults" {
        $report = Resolve-KitEffectiveConfiguration -StackName "default" -RepoRoot $script:RepoRoot
        $paths = @($report.pathSources)
        $workRoot = @($paths | Where-Object { $_.key -eq "WorkRoot" })[0]

        Assert-KitEqual $report.reportType "effective-configuration"
        Assert-KitEqual $report.stackName "default"
        Assert-KitEqual (@($report.appliedLayers.id) -contains "repo-default") $true
        Assert-KitEqual (@($report.appliedLayers.id) -contains "profile-default") $true
        Assert-KitEqual $workRoot.sourceLayer "repo-default"
        Assert-KitNotMatch (($paths.value) -join "`n") '\$\{[^}]+\}'
    }

    It "applies profile and hardware overrides deterministically" {
        $release = Resolve-KitEffectiveConfiguration -StackName "release" -RepoRoot $script:RepoRoot
        $air15 = Resolve-KitEffectiveConfiguration -StackName "air15" -RepoRoot $script:RepoRoot
        $releaseWorkRoot = @($release.pathSources | Where-Object { $_.key -eq "WorkRoot" })[0]
        $air15WorkRoot = @($air15.pathSources | Where-Object { $_.key -eq "WorkRoot" })[0]

        Assert-KitEqual $releaseWorkRoot.sourceLayer "profile-release"
        Assert-KitMatch $releaseWorkRoot.value "\\work\\release$"
        Assert-KitEqual $air15WorkRoot.sourceLayer "hardware-air15"
        Assert-KitMatch $air15WorkRoot.value "\\work\\air15$"
    }

    It "writes a report from Show-EffectiveConfiguration" {
        $reportPath = Join-Path ([IO.Path]::GetTempPath()) ("effective-config-{0}.json" -f ([guid]::NewGuid().ToString("N")))
        try {
            & (Join-Path $script:RepoRoot "scripts\config\Show-EffectiveConfiguration.ps1") -StackName "release" -ReportPath $reportPath
            $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

            Assert-KitEqual $report.reportType "effective-configuration"
            Assert-KitEqual $report.stackName "release"
            Assert-KitEqual (@($report.pathSources | Where-Object { $_.key -eq "WorkRoot" })[0].sourceLayer) "profile-release"
        } finally {
            if (Test-Path -LiteralPath $reportPath) {
                Remove-Item -LiteralPath $reportPath -Force
            }
        }
    }
}
