Describe "User experience manual checklist" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitUserExperienceHandlerReport.ps1")
        $script:ReadJson = {
            param([string]$Path)
            Get-Content -LiteralPath (Join-Path $script:RepoRoot $Path) -Raw -Encoding UTF8 | ConvertFrom-Json
        }
    }

    It "creates checklist items without success evidence claims" {
        $handler = ConvertTo-KitTaskbarPlan -InputObject (& $script:ReadJson "tests\fixtures\user-experience\handlers\taskbar\current-user-manual-checklist.json")
        $checklist = @(New-KitUserExperienceManualChecklist -Handlers @($handler))

        Assert-KitEqual $checklist.Count 1
        Assert-KitEqual $checklist[0].status "manual"
        Assert-KitEqual $checklist[0].commandExitCodeSufficient $false
        Assert-KitEqual $checklist[0].userConfigurationConfirmed $false
    }
}
