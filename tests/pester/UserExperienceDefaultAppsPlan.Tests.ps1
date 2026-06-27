Describe "User experience default apps plan" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitUserExperienceRestoreReport.ps1")

        $script:ReadJson = {
            param([string]$Path)
            Get-Content -LiteralPath (Join-Path $script:RepoRoot $Path) -Raw -Encoding UTF8 | ConvertFrom-Json
        }
    }

    It "plans extension and protocol associations without execution" {
        $fixture = & $script:ReadJson "tests\fixtures\user-experience\default-apps\baseline.json"
        $report = New-KitUserExperienceRestoreReport `
            -Manifest (& $script:ReadJson "manifests\user-experience-restore.json") `
            -RepoRoot $script:RepoRoot `
            -WindowsContext (& $script:ReadJson "tests\fixtures\user-experience\windows-context\windows-11-24h2.json") `
            -DefaultApps $fixture `
            -StartMenu (& $script:ReadJson "tests\fixtures\user-experience\start-menu\baseline.json") `
            -Taskbar (& $script:ReadJson "tests\fixtures\user-experience\taskbar\baseline.json") `
            -WhatIf
        $defaultPlan = @($report.plans | Where-Object { $_.id -eq "default-app-baseline" })[0]

        Assert-KitEqual $defaultPlan.status "planned"
        Assert-KitEqual $defaultPlan.executed $false
        Assert-KitEqual $defaultPlan.plannedChangeCount 2
        Assert-KitEqual (@($fixture.associations | Where-Object { $_.kind -eq "extension" }).Count -gt 0) $true
        Assert-KitEqual (@($fixture.associations | Where-Object { $_.kind -eq "protocol" }).Count -gt 0) $true
    }
}
