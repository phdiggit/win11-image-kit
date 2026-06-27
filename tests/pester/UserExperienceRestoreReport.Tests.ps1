Describe "User experience restore report" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitUserExperienceRestoreReport.ps1")

        $script:ReadJson = {
            param([string]$Path)
            Get-Content -LiteralPath (Join-Path $script:RepoRoot $Path) -Raw -Encoding UTF8 | ConvertFrom-Json
        }
    }

    It "creates a passing baseline report without mutation" {
        $report = New-KitUserExperienceRestoreReport `
            -Manifest (& $script:ReadJson "manifests\user-experience-restore.json") `
            -RepoRoot $script:RepoRoot `
            -WindowsContext (& $script:ReadJson "tests\fixtures\user-experience\windows-context\windows-11-24h2.json") `
            -DefaultApps (& $script:ReadJson "tests\fixtures\user-experience\default-apps\baseline.json") `
            -StartMenu (& $script:ReadJson "tests\fixtures\user-experience\start-menu\baseline.json") `
            -Taskbar (& $script:ReadJson "tests\fixtures\user-experience\taskbar\baseline.json") `
            -WhatIf

        Assert-KitEqual $report.reportType "user-experience-restore"
        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.trueExecution $false
        Assert-KitEqual $report.whatIf $true
        Assert-KitEqual $report.summary.registryWriteCount 0
        Assert-KitEqual $report.summary.profileWriteCount 0
        Assert-KitEqual $report.summary.defaultAppMutationCount 0
        Assert-KitEqual $report.summary.startMenuMutationCount 0
        Assert-KitEqual $report.summary.taskbarMutationCount 0
    }
}
