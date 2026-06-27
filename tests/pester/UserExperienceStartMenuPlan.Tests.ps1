Describe "User experience Start menu plan" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitUserExperienceRestoreReport.ps1")

        $script:ReadJson = {
            param([string]$Path)
            Get-Content -LiteralPath (Join-Path $script:RepoRoot $Path) -Raw -Encoding UTF8 | ConvertFrom-Json
        }
    }

    It "plans Start menu pins and taskbar visibility without execution" {
        $startMenu = & $script:ReadJson "tests\fixtures\user-experience\start-menu\baseline.json"
        $taskbar = & $script:ReadJson "tests\fixtures\user-experience\taskbar\baseline.json"
        $report = New-KitUserExperienceRestoreReport `
            -Manifest (& $script:ReadJson "manifests\user-experience-restore.json") `
            -RepoRoot $script:RepoRoot `
            -WindowsContext (& $script:ReadJson "tests\fixtures\user-experience\windows-context\windows-11-24h2.json") `
            -DefaultApps (& $script:ReadJson "tests\fixtures\user-experience\default-apps\baseline.json") `
            -StartMenu $startMenu `
            -Taskbar $taskbar `
            -WhatIf
        $startPlan = @($report.plans | Where-Object { $_.id -eq "start-menu-baseline" })[0]
        $taskbarPlan = @($report.plans | Where-Object { $_.id -eq "taskbar-baseline" })[0]

        Assert-KitEqual $startPlan.status "planned"
        Assert-KitEqual $startPlan.executed $false
        Assert-KitEqual $startPlan.plannedChangeCount 1
        Assert-KitEqual $taskbarPlan.status "planned"
        Assert-KitEqual $taskbarPlan.executed $false
        Assert-KitEqual $taskbarPlan.plannedChangeCount 1
    }
}
